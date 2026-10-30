param(
  [switch]$List,
  [switch]$DryRun,
  [switch]$Interactive,
  [switch]$All,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Only
)

# Run without a checkout (irm ... | iex): download the repo to a temp folder, run its installer
# in PowerShell 7, and delete the folder. `return`, not `exit`, so the caller's shell stays open.
$Root = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $Root -or -not (Test-Path -LiteralPath (Join-Path $Root "install\lib.ps1"))) {
  & {
    $ErrorActionPreference = "Stop"
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
      Write-Host "Stillwater needs PowerShell 7. Install it with: winget install Microsoft.PowerShell"
      return
    }
    $ref = if ($env:STILLWATER_REF) { $env:STILLWATER_REF } else { "main" }
    $url = if ($env:STILLWATER_ARCHIVE) { $env:STILLWATER_ARCHIVE } else { "https://github.com/AkiVonAkira/stillwater/archive/refs/heads/$ref.zip" }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("stillwater-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
      Write-Host "Downloading Stillwater ($ref)..."
      $ProgressPreference = "SilentlyContinue"
      Invoke-WebRequest -Uri $url -OutFile (Join-Path $tmp "stillwater.zip") -UseBasicParsing
      Expand-Archive -Path (Join-Path $tmp "stillwater.zip") -DestinationPath $tmp
      $installer = Get-ChildItem -Path $tmp -Directory | ForEach-Object { Join-Path $_.FullName "install.ps1" } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
      $forward = @()
      if ($List) { $forward += "-List" }
      if ($DryRun) { $forward += "-DryRun" }
      if ($Interactive) { $forward += "-Interactive" }
      if ($All) { $forward += "-All" }
      if ($Only) { $forward += $Only }
      & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $installer @forward
    } finally {
      Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  return
}

$ErrorActionPreference = "Stop"
$env:STILLWATER_ROOT = $Root
. (Join-Path $Root "install\lib.ps1")
. (Join-Path $Root "install\picker.ps1")
Initialize-StillwaterPaths
if ($DryRun) { $env:STILLWATER_DRY_RUN = "1" } else { $env:STILLWATER_DRY_RUN = "0" }

if ($All -and $Only) {
  Write-Error "Use -All or adapter ids, not both."
  exit 1
}

function Get-AdapterScripts {
  Get-ChildItem -Path $Root -Directory | ForEach-Object {
    $script = Join-Path $_.FullName "install.ps1"
    if (Test-Path -LiteralPath $script) { $script }
  }
}

# Runs every adapter's status at once and keeps the result, with the adapter
# that printed each id, so nothing asks the adapters twice.
$script:StatusJob = $null
$script:StatusTotal = 0
$script:StatusRows = $null
$script:StatusOwners = @{}
function Start-StillwaterStatus {
  if ($script:StatusJob -or $null -ne $script:StatusRows) { return }
  $scripts = @(Get-AdapterScripts)
  $script:StatusTotal = $scripts.Count
  $script:StatusJob = $scripts | ForEach-Object -AsJob -ThrottleLimit ([Math]::Max(2, [Environment]::ProcessorCount)) -Parallel {
    [pscustomobject]@{ Script = $_; Rows = @(& $_ -Action status 2>$null) }
  }
}

# The rows of the adapters that have answered so far, sorted.
function Read-StillwaterStatus {
  $rows = @()
  $done = 0
  foreach ($child in $script:StatusJob.ChildJobs) {
    if ($child.State -ne "Completed" -and $child.State -ne "Failed") { continue }
    $done++
    foreach ($result in $child.Output) {
      foreach ($row in $result.Rows) {
        if (-not $row) { continue }
        $rows += [string]$row
        $script:StatusOwners[([string]$row).Split("|")[0]] = $result.Script
      }
    }
  }
  return [pscustomobject]@{ Rows = @(Sort-StillwaterStatus $rows); Done = $done; Total = $script:StatusTotal }
}

# -Progress shows the inline count while the adapters answer.
function Import-StillwaterStatus([switch]$Progress) {
  if ($null -ne $script:StatusRows) { return }
  Start-StillwaterStatus
  if ($Progress) { Show-StillwaterLoading $script:StatusJob $script:StatusTotal }
  $null = Wait-Job $script:StatusJob
  $script:StatusRows = @((Read-StillwaterStatus).Rows)
  Remove-Job $script:StatusJob
  $script:StatusJob = $null
}

function Get-StillwaterStatus {
  Import-StillwaterStatus
  $script:StatusRows
}

function Split-StillwaterStatusRow([string]$Row) {
  $parts = $Row.Split("|")
  return [pscustomobject]@{
    Id = $parts[0]
    Label = $parts[1]
    App = $parts[2]
    Theme = if ($parts.Count -gt 3) { $parts[3] } else { "none" }
    Note = if ($parts.Count -gt 4) { $parts[4] } else { "" }
    Dest = if ($parts.Count -gt 5) { $parts[5] } else { "" }
    Bases = if ($parts.Count -gt 6) { $parts[6] } else { "" }
    Base = if ($parts.Count -gt 7) { $parts[7] } else { "" }
  }
}

function Write-StillwaterList {
  $style = Get-StillwaterThemeAnsi
  Write-Host ("{0}Stillwater{1}  {2}{3}  {4}{1}" -f $style.Accent, $style.Reset, $style.Warm, (Get-StillwaterOsLabel), (Get-StillwaterVersion))
  foreach ($row in Get-StillwaterStatus) {
    $item = Split-StillwaterStatusRow $row
    $paint = $style.Muted
    if ($item.App -eq "found") {
      $paint = switch ($item.Theme) {
        "current" { $style.AccentDeep }
        "update" { $style.Warn }
        default { $style.Accent }
      }
    }
    $path = Get-StillwaterDisplayPath $item.Dest
    Write-Host ("  {0}{1,-22}{2}  {3,-8}  {0}{4,-10}{2}  {5,-16}  {9,-10}  {6}{7,-16}{2}  {6}{8}{2}" -f `
      $paint, $item.Label, $style.Reset, $item.App, $item.Theme, $item.Note, $style.Muted, $item.Id, $path, $item.Base)
  }
}

if ($List) {
  Write-StillwaterList
  exit 0
}

# Named installs and -All draw inline on the normal screen, so the progress you
# watch is the output that stays.
$inlineStyle = $null
if (($All -or ($Only -and -not $Interactive)) -and -not [Console]::IsOutputRedirected) {
  Enable-StillwaterVirtualTerminal
  try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
  $inlineStyle = Get-StillwaterPickerStyle
  Start-StillwaterInline $inlineStyle
  Import-StillwaterStatus -Progress
}

function Stop-StillwaterIdCheck([string]$Message) {
  if ($inlineStyle) { Stop-StillwaterInline $inlineStyle -Erase }
  [Console]::Error.WriteLine($Message)
  exit 1
}

# Adapter ids may carry a base theme, as vencord:comfy.
if ($Only) {
  $known = @{}
  foreach ($row in Get-StillwaterStatus) {
    $item = Split-StillwaterStatusRow $row
    $known[$item.Id] = $item
  }
  foreach ($want in $Only) {
    $id, $base = $want.Split(":", 2)
    if (-not $known.ContainsKey($id)) {
      Stop-StillwaterIdCheck "Unknown adapter: $id"
    }
    if ($want.Contains(":") -and -not (Test-StillwaterBaseValid $known[$id].Bases $base)) {
      $keys = @(Get-StillwaterBaseList $known[$id].Bases | ForEach-Object { $_.Key }) -join " "
      if ($keys) {
        Stop-StillwaterIdCheck "Unknown base for ${id}: $base. Bases: $keys"
      } else {
        Stop-StillwaterIdCheck "$id has no base themes."
      }
    }
  }
}

# Returns $null when id was not asked for, else the base asked for or "".
function Get-StillwaterWantedBase([string]$Id) {
  foreach ($want in $Only) {
    if ($want -eq $Id) { return "" }
    if ($want.StartsWith("${Id}:")) { return $want.Substring($Id.Length + 1) }
  }
  return $null
}

function Get-StillwaterAdapterScript([string]$Id) {
  Import-StillwaterStatus
  return $script:StatusOwners[$Id]
}

function Test-StillwaterClack {
  try { return -not [Console]::IsOutputRedirected } catch { return $true }
}

function Invoke-StillwaterInteractive {
  if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
    Write-Error "install.ps1 needs a terminal, or pass -All or adapter ids."
    exit 1
  }
  try {
    return @(Invoke-StillwaterPicker -Poll { Start-StillwaterStatus; Read-StillwaterStatus })
  } catch {
    if ($_.Exception.Message -eq "cancelled") { exit 0 }
    throw
  }
}

$Filter = $false
if ($All) {
  $Only = @()
  $Filter = $false
} elseif ($Only -and -not $Interactive) {
  $Filter = $true
} else {
  $Only = @(Invoke-StillwaterInteractive)
  $Filter = $true
}

$installed = 0
$skipped = 0
$failed = 0
$jobs = @()
foreach ($row in Get-StillwaterStatus) {
  $item = Split-StillwaterStatusRow $row
  $pick = ""
  if ($Filter) {
    if (-not $Only) { continue }
    $pick = Get-StillwaterWantedBase $item.Id
    if ($null -eq $pick) { continue }
  }
  $theme = $item.Theme
  $base = $item.Base
  if ($pick -and $pick -ne $base) {
    if ($theme -ne "none") { $theme = "switch" }
    $base = $pick
  }
  $baseLabel = if ($base) { Get-StillwaterBaseLabel $item.Bases $base } else { "" }
  if ($item.App -ne "found") {
    $skipped++
    if ($Filter) {
      $jobs += [pscustomobject]@{
        Id = $item.Id; Label = $item.Label; Theme = $theme; Base = $base; BaseLabel = $baseLabel
        Kind = "skip"; State = "skip"; Next = ""
      }
    }
    continue
  }
  $jobs += [pscustomobject]@{
    Id = $item.Id; Label = $item.Label; Theme = $theme; Base = $base; BaseLabel = $baseLabel
    Kind = "install"; State = "pending"; Next = (Get-StillwaterNextStep $item.Id)
  }
}
$jobs = @($jobs)

$style = Get-StillwaterPickerStyle
$clack = Test-StillwaterClack
$spinI = 0

function Get-StillwaterJobSummary {
  if ($failed -gt 0) {
    return ("Installed {0}, skipped {1}, failed {2}." -f $installed, $skipped, $failed)
  }
  return ("Installed {0}, skipped {1}." -f $installed, $skipped)
}

function Write-StillwaterJobFrame {
  Write-StillwaterJobs $style $jobs $spinI (Get-StillwaterJobSummary)
}

function Get-StillwaterFailureMessage($ErrorRecord) {
  $ex = $null
  if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
    $ex = $ErrorRecord.Exception
  } elseif ($ErrorRecord -is [System.Exception]) {
    $ex = $ErrorRecord
  } else {
    $ex = $ErrorRecord.Exception
  }
  while ($ex -and $ex.InnerException) { $ex = $ex.InnerException }
  if ($ex -and $ex.Message) { return $ex.Message }
  return [string]$ErrorRecord
}

# Only adapters with base themes take -Base, so it is passed only when set.
function Invoke-StillwaterInstallJob($Script, [string]$Id, [string]$Base) {
  $extra = @{}
  if ($Base) { $extra.Base = $Base }
  if (-not $clack) {
    $null = & $Script -Action install -Only @($Id) @extra
    return
  }
  $ps = [powershell]::Create()
  try {
    # Do not name the home argument $home. $HOME is a read-only automatic
    # variable, and binding it in a nested runspace fails every adapter.
    [void]$ps.AddScript({
      param($path, $ident, $root, $stillwaterHome, $dry, $extra)
      $env:STILLWATER_ROOT = $root
      if ($stillwaterHome) { $env:STILLWATER_HOME = $stillwaterHome }
      $env:STILLWATER_DRY_RUN = $dry
      & $path -Action install -Only @($ident) @extra
    }).AddArgument($Script).AddArgument($Id).AddArgument($Root).AddArgument($env:STILLWATER_HOME).AddArgument($env:STILLWATER_DRY_RUN).AddArgument($extra)
    $handle = $ps.BeginInvoke()
    while (-not $handle.IsCompleted) {
      $script:spinI++
      Write-StillwaterJobFrame
      Start-Sleep -Milliseconds 70
    }
    $null = $ps.EndInvoke($handle)
    if ($ps.HadErrors) {
      throw $ps.Streams.Error[0]
    }
  } finally {
    $ps.Dispose()
  }
}

if ($clack) {
  Enable-StillwaterVirtualTerminal
  if (-not $script:StillwaterInline) { Enter-StillwaterScreen $style }
  Write-StillwaterJobFrame
}

$finished = $false
try {
foreach ($job in $jobs) {
  if ($job.Kind -ne "install") {
    if (-not $clack) { Write-Host ("Skipped {0}. Not found." -f $job.Label) }
    continue
  }
  if ($clack) {
    $job.State = "busy"
    Write-StillwaterJobFrame
  }
  $script = Get-StillwaterAdapterScript $job.Id
  if (-not $script) {
    $job.State = "fail"
    $job.Next = ""
    $failed++
    if (-not $clack) { Write-Host ("Skipped {0}. No installer." -f $job.Label) }
  } else {
    try {
      Invoke-StillwaterInstallJob $script $job.Id $job.Base
      $job.State = "ok"
      $installed++
      if (-not $clack) {
        $name = if ($job.BaseLabel) { "{0} on {1}" -f $job.Label, $job.BaseLabel } else { $job.Label }
        if ($env:STILLWATER_DRY_RUN -eq "1") {
          Write-Host ("Would install {0}." -f $name)
        } else {
          Write-Host ("Installed {0}." -f $name)
        }
      }
    } catch {
      $job.State = "fail"
      $job.Next = Get-StillwaterFailureMessage $_
      $failed++
      if (-not $clack) { Write-Host ("Failed {0}: {1}" -f $job.Label, $job.Next) }
    }
  }
  if ($clack) {
    Write-StillwaterJobFrame
  }
}
$finished = $true
} finally {
  if ($script:StillwaterInline) {
    if (-not $finished) { Stop-StillwaterInline $style }
  } elseif ($clack) {
    Exit-StillwaterScreen $style
  }
}

$nextJobs = @($jobs | Where-Object { $_.State -eq "ok" -and $_.Next })
$summary = Get-StillwaterJobSummary
if ($script:StillwaterInline) {
  # The last frame is the output, unless the list did not fit and was cut short.
  Write-StillwaterJobFrame
  if ($script:StillwaterInlineCompact) {
    Stop-StillwaterInline $style -Erase
    Write-StillwaterJobsFinal $style $jobs $summary
  } else {
    Stop-StillwaterInline $style
  }
} elseif ($clack) {
  Write-StillwaterJobsFinal $style $jobs $summary
} else {
  if ($nextJobs.Count -gt 0) {
    Write-Host "Do this next."
    foreach ($job in $nextJobs) {
      Write-Host ("  {0,-22}  {1}" -f $job.Label, $job.Next)
    }
  }
  Write-Host $summary
}
