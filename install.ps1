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
  Write-Error "use -All or adapter ids, not both"
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
    Write-Host ("  {0}{1,-22}{2}  {3,-8}  {0}{4,-10}{2}  {5,-16}  {6}" -f $paint, $item.Label, $style.Reset, $item.App, $item.Theme, $item.Note, $item.Id)
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
      Write-Error "unknown adapter: $id"
      exit 1
    }
  }
}

function Invoke-StillwaterInteractive {
  if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) {
    Write-Error "install.ps1 needs a terminal, or pass -All / adapter ids"
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
foreach ($row in Get-StillwaterStatus) {
  $item = Split-StillwaterStatusRow $row
  if ($Filter) {
    if (-not $Only -or -not ($Only -contains $item.Id)) { continue }
  }
  if ($item.App -ne "found") {
    Write-Host "skip  $($item.Label) ($($item.Id)) - not found"
    $skipped++
    continue
  }
  $script = $null
  foreach ($candidate in Get-AdapterScripts) {
    $owns = & $candidate -Action owns -Only @($item.Id)
    if ($owns -eq "yes") { $script = $candidate; break }
  }
  if (-not $script) {
    Write-Host "skip  $($item.Label) ($($item.Id)) - no installer"
    $skipped++
    continue
  }
  $dest = & $script -Action install -Only @($item.Id)
  if ($env:STILLWATER_DRY_RUN -eq "1") {
    Write-Host "would install  $($item.Label) -> $dest"
  } else {
    Write-Host "install  $($item.Label) -> $dest"
  }
  $installed++
}

Write-Host "$installed installed, $skipped skipped"
