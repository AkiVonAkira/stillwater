param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("status", "owns", "install")]
  [string]$Action,
  [string[]]$Only = @()
)

$Root = $env:STILLWATER_ROOT
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
. (Join-Path $Root "install\lib.ps1")
Initialize-StillwaterPaths

$Id = "fastfetch"
$Label = "fastfetch"
$Src = Join-Path $Root "fastfetch\config.jsonc"

function Get-FastfetchDest {
  Join-Path $env:XDG_CONFIG_HOME "fastfetch\config.jsonc"
}

function Test-FastfetchFound {
  if (Test-StillwaterCommand "fastfetch") { return $true }
  return Test-StillwaterAnyDir @((Join-Path $env:XDG_CONFIG_HOME "fastfetch"))
}

# Keep the first config we replace as config.jsonc.bak.
function Backup-FastfetchConfig([string]$Dest) {
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  if (-not (Test-Path -LiteralPath $Dest -PathType Leaf)) { return }
  if (Test-Path -LiteralPath "$Dest.bak") { return }
  if ([System.IO.File]::ReadAllText($Dest) -notmatch 'Stillwater fastfetch') {
    Copy-Item -LiteralPath $Dest -Destination "$Dest.bak"
  }
}

switch ($Action) {
  "status" {
    $app = if (Test-FastfetchFound) { "found" } else { "skip" }
    $dest = Get-FastfetchDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-FastfetchDest
    Backup-FastfetchConfig $dest
    Copy-StillwaterFile $Src $dest
    Write-Output $dest
  }
}
