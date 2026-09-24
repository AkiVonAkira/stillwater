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
  foreach ($script in Get-AdapterScripts) {
    & $script -Action status
  }
}

function Write-StillwaterList {
  Write-Host ("Stillwater  {0}  {1}" -f (Get-StillwaterOsLabel), (Get-StillwaterVersion))
  foreach ($row in Get-StillwaterStatus) {
    $id, $label, $state = $row.Split("|")
    Write-Host ("  {0,-22}  {1}  {2}" -f $label, $state, $id)
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
  Write-StillwaterList
  Write-Host ""
  $choice = (Read-Host "Install to all found apps? [Y/s/n]").Trim().ToLowerInvariant()
  if ($choice -eq "n" -or $choice -eq "no") { exit 0 }
  if ($choice -eq "s" -or $choice -eq "select") {
    return @((Read-Host "Ids (space separated)") -split "\s+")
  }
  $found = @()
  foreach ($row in Get-StillwaterStatus) {
    $id, $label, $state = $row.Split("|")
    if ($state -eq "found") { $found += $id }
  }
  return $found
}

if ($All) {
  $Only = @()
} elseif ($Only -and -not $Interactive) {
  :
} else {
  $Only = @(Invoke-StillwaterInteractive)
}

$installed = 0
$skipped = 0
foreach ($row in Get-StillwaterStatus) {
  $id, $label, $state = $row.Split("|")
  if (-not (Test-StillwaterIdWanted $id $Only)) { continue }
  if ($state -ne "found") {
    Write-Host "skip  $label ($id) - not found"
    $skipped++
    continue
  }
  $script = $null
  foreach ($candidate in Get-AdapterScripts) {
    $owns = & $candidate -Action owns -Only @($id)
    if ($owns -eq "yes") { $script = $candidate; break }
  }
  if (-not $script) {
    Write-Host "skip  $label ($id) - no installer"
    $skipped++
    continue
  }
  $dest = & $script -Action install -Only @($id)
  if ($env:STILLWATER_DRY_RUN -eq "1") {
    Write-Host "would install  $label -> $dest"
  } else {
    Write-Host "install  $label -> $dest"
  }
  $installed++
}

Write-Host "$installed installed, $skipped skipped"
