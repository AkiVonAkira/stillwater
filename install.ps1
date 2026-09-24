param(
  [switch]$List,
  [switch]$DryRun,
  [switch]$Interactive,
  [switch]$All,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Only
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
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

function Get-StillwaterStatus {
  $rows = @(
    foreach ($script in Get-AdapterScripts) {
      & $script -Action status
    }
  )
  Sort-StillwaterStatus $rows
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
    Write-Host ("  {0}{1,-22}{2}  {3,-8}  {0}{4,-10}{2}  {5,-16}  {6}{7,-16}{2}  {6}{8}{2}" -f `
      $paint, $item.Label, $style.Reset, $item.App, $item.Theme, $item.Note, $style.Muted, $item.Id, $path)
  }
}

if ($List) {
  Write-StillwaterList
  exit 0
}

$known = @{}
foreach ($row in Get-StillwaterStatus) {
  $id = $row.Split("|")[0]
  $known[$id] = $true
}
if ($Only) {
  foreach ($id in $Only) {
    if (-not $known.ContainsKey($id)) {
      Write-Error "Unknown adapter: $id"
      exit 1
    }
  }
}

function Get-StillwaterAdapterScript([string]$Id) {
  foreach ($candidate in Get-AdapterScripts) {
    $owns = & $candidate -Action owns -Only @($Id)
    if ($owns -eq "yes") { return $candidate }
  }
  return $null
}

function Test-StillwaterClack {
  try { return -not [Console]::IsOutputRedirected } catch { return $true }
}

function Restore-StillwaterUi($Style) {
  try { [Console]::CursorVisible = $true } catch { }
  if ($Style.Show) { Write-Host $Style.Show -NoNewline }
}

function Invoke-StillwaterInteractive {
  if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
    Write-Error "install.ps1 needs a terminal, or pass -All or adapter ids."
    exit 1
  }
  try {
    return @(Invoke-StillwaterPicker -Rows @(Get-StillwaterStatus))
  } catch {
    if ($_.Exception.Message -eq "cancelled") { exit 0 }
    throw
  }
}

$Filter = $false
$UsedPicker = $false
if ($All) {
  $Only = @()
  $Filter = $false
} elseif ($Only -and -not $Interactive) {
  $Filter = $true
} else {
  $Only = @(Invoke-StillwaterInteractive)
  $Filter = $true
  $UsedPicker = $true
}

$installed = 0
$skipped = 0
$failed = 0
$jobs = @()
foreach ($row in Get-StillwaterStatus) {
  $item = Split-StillwaterStatusRow $row
  if ($Filter) {
    if (-not $Only -or -not ($Only -contains $item.Id)) { continue }
  }
  if ($item.App -ne "found") {
    $skipped++
    if ($Filter) {
      $jobs += [pscustomobject]@{
        Id = $item.Id; Label = $item.Label; Theme = $item.Theme
        Kind = "skip"; State = "skip"; Next = ""
      }
    }
    continue
  }
  $jobs += [pscustomobject]@{
    Id = $item.Id; Label = $item.Label; Theme = $item.Theme
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

function Invoke-StillwaterInstallJob($Script, [string]$Id) {
  if (-not $clack) {
    $null = & $Script -Action install -Only @($Id)
    return
  }
  $ps = [powershell]::Create()
  try {
    # Do not name the home argument $home. $HOME is a read-only automatic
    # variable, and binding it in a nested runspace fails every adapter.
    [void]$ps.AddScript({
      param($path, $ident, $root, $stillwaterHome, $dry)
      $env:STILLWATER_ROOT = $root
      if ($stillwaterHome) { $env:STILLWATER_HOME = $stillwaterHome }
      $env:STILLWATER_DRY_RUN = $dry
      & $path -Action install -Only @($ident)
    }).AddArgument($Script).AddArgument($Id).AddArgument($Root).AddArgument($env:STILLWATER_HOME).AddArgument($env:STILLWATER_DRY_RUN)
    $handle = $ps.BeginInvoke()
    while (-not $handle.IsCompleted) {
      $script:spinI++
      Write-Host ("`e[{0}A" -f ($jobs.Count + 3)) -NoNewline
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
  try { [Console]::CursorVisible = $false } catch { }
  Write-Host $style.Hide -NoNewline
  if ($UsedPicker -and $script:StillwaterPickerRows) {
    Write-Host ("`e[{0}A" -f $script:StillwaterPickerRows) -NoNewline
  }
  Write-StillwaterJobFrame
}

foreach ($job in $jobs) {
  if ($job.Kind -ne "install") {
    if (-not $clack) { Write-Host ("Skipped {0}. Not found." -f $job.Label) }
    continue
  }
  if ($clack) {
    $job.State = "busy"
    Write-Host ("`e[{0}A" -f ($jobs.Count + 3)) -NoNewline
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
      Invoke-StillwaterInstallJob $script $job.Id
      $job.State = "ok"
      $installed++
      if (-not $clack) {
        if ($env:STILLWATER_DRY_RUN -eq "1") {
          Write-Host ("Would install {0}." -f $job.Label)
        } else {
          Write-Host ("Installed {0}." -f $job.Label)
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
    Write-Host ("`e[{0}A" -f ($jobs.Count + 3)) -NoNewline
    Write-StillwaterJobFrame
  }
}

$nextJobs = @($jobs | Where-Object { $_.State -eq "ok" -and $_.Next })
$summary = Get-StillwaterJobSummary
if ($clack) {
  Write-Host ("`e[{0}A" -f ($jobs.Count + 3)) -NoNewline
  Write-StillwaterJobFrame
  Restore-StillwaterUi $style
} else {
  if ($nextJobs.Count -gt 0) {
    Write-Host "Do this next."
    foreach ($job in $nextJobs) {
      Write-Host ("  {0,-22}  {1}" -f $job.Label, $job.Next)
    }
  }
  Write-Host $summary
}
