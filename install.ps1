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

function Write-StillwaterClackHeader($Style) {
  Write-Host ("{0}{1}┌  {2}Stillwater{3}  {4}{5}  {6}{3}" -f $Style.Clear, $Style.Muted, $Style.Accent, $Style.Reset, $Style.Warm, (Get-StillwaterOsLabel), (Get-StillwaterVersion))
}

function Write-StillwaterClackStep($Style, [string]$Color, [string]$Mark, [string]$Text) {
  Write-Host ("{0}{1}{2}  {3}{4}{5}" -f $Style.Clear, $Color, $Mark, $Style.Text, $Text, $Style.Reset)
}

function Write-StillwaterClackRow($Style, [string]$State, [string]$Label, [string]$Hint = "") {
  if ($State -eq "next") {
    Write-Host ("{0}{1}│  {2}{3,-22}{4}  {1}{5}{4}" -f $Style.Clear, $Style.Muted, $Style.Text, $Label, $Style.Reset, $Hint)
    return
  }
  $mark = "○"
  $color = $Style.Muted
  $labelfg = $Style.Muted
  $hintfg = $Style.Muted
  switch ($State) {
    "ok" { $mark = "●"; $color = $Style.Accent; $labelfg = $Style.Text }
    "fail" { $mark = "■"; $color = $Style.Error; $labelfg = $Style.Text; $hintfg = $Style.Error }
    "busy" { $mark = "○"; $color = $Style.AccentHover; $labelfg = $Style.Text }
    "skip" { $mark = "○"; $color = $Style.Muted; $labelfg = $Style.Muted }
  }
  Write-Host ("{0}{1}│  {2}{3}{4}  {5}{6,-22}{4}  {7}{8}{4}" -f `
    $Style.Clear, $Style.Muted, $color, $mark, $Style.Reset, $labelfg, $Label, $hintfg, $Hint)
}

function Write-StillwaterClackEnd($Style, [string]$Text) {
  Write-Host ("{0}{1}└  {2}{3}" -f $Style.Clear, $Style.Muted, $Text, $Style.Reset)
}

function Write-StillwaterClackUp([int]$Rows) {
  Write-Host ("`e[{0}A" -f $Rows) -NoNewline
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
        Id = $item.Id; Label = $item.Label; Kind = "skip"; State = "skip"; Hint = "Not found."; Next = ""
      }
    }
    continue
  }
  $jobs += [pscustomobject]@{
    Id = $item.Id; Label = $item.Label; Kind = "install"; State = "pending"; Hint = ""; Next = (Get-StillwaterNextStep $item.Id)
  }
}
$jobs = @($jobs)

$style = Get-StillwaterPickerStyle
$clack = Test-StillwaterClack
function Write-StillwaterJobs {
  Write-StillwaterClackStep $style $style.Accent "◆" "Installing Stillwater."
  foreach ($job in $jobs) {
    Write-StillwaterClackRow $style $job.State $job.Label $job.Hint
  }
}

if ($clack) {
  if (-not $UsedPicker) { Write-StillwaterClackHeader $style }
  if ($jobs.Count -gt 0) { Write-StillwaterJobs }
}

foreach ($job in $jobs) {
  if ($job.Kind -ne "install") {
    if (-not $clack) { Write-Host ("Skipped {0}. Not found." -f $job.Label) }
    continue
  }
  if ($clack) {
    $job.State = "busy"
    Write-StillwaterClackUp ($jobs.Count + 1)
    Write-StillwaterJobs
  }
  $script = Get-StillwaterAdapterScript $job.Id
  if (-not $script) {
    $job.State = "fail"
    $job.Hint = "No installer."
    $job.Next = ""
    $failed++
    if (-not $clack) { Write-Host ("Skipped {0}. No installer." -f $job.Label) }
  } else {
    try {
      $null = & $script -Action install -Only @($job.Id)
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
      $job.Hint = "Failed."
      $job.Next = ""
      $failed++
      if (-not $clack) { Write-Host ("Failed {0}." -f $job.Label) }
    }
  }
  if ($clack) {
    Write-StillwaterClackUp ($jobs.Count + 1)
    Write-StillwaterJobs
  }
}

$nextJobs = @($jobs | Where-Object { $_.State -eq "ok" -and $_.Next })
if ($nextJobs.Count -gt 0) {
  if ($clack) {
    Write-StillwaterClackStep $style $style.AccentHover "◇" "Do this next."
    foreach ($job in $nextJobs) {
      Write-StillwaterClackRow $style "next" $job.Label $job.Next
    }
  } else {
    Write-Host "Do this next."
    foreach ($job in $nextJobs) {
      Write-Host ("  {0,-22}  {1}" -f $job.Label, $job.Next)
    }
  }
}

$summary = "Installed {0}, skipped {1}." -f $installed, $skipped
if ($failed -gt 0) { $summary = "Installed {0}, skipped {1}, failed {2}." -f $installed, $skipped, $failed }
if ($clack) {
  Write-StillwaterClackEnd $style $summary
} else {
  Write-Host $summary
}
