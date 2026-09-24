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

$Id = "ghostty"
$Label = "Ghostty"
$Src = Join-Path $Root "ghostty\Stillwater"

function Get-GhosttyDirs {
  @((Join-Path $env:XDG_CONFIG_HOME "ghostty"), (Join-Path $env:APPDATA "ghostty"))
}

function Test-GhosttyFound {
  if (Test-StillwaterCommand "ghostty") { return $true }
  return Test-StillwaterAnyDir (Get-GhosttyDirs)
}

function Get-GhosttyDir {
  foreach ($dir in Get-GhosttyDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) { return $dir }
  }
  return (Join-Path $env:XDG_CONFIG_HOME "ghostty")
}

function Get-GhosttyDest {
  Join-Path (Get-GhosttyDir) "themes\Stillwater"
}

function Set-GhosttyTheme {
  $conf = Join-Path (Get-GhosttyDir) "config"
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  if (-not (Test-Path -LiteralPath $conf -PathType Leaf)) { return }
  $raw = [System.IO.File]::ReadAllText($conf)
  if ($raw -match '(?m)^theme\s*=') {
    $raw = [regex]::Replace($raw, '(?m)^theme\s*=.*', 'theme = Stillwater')
    [System.IO.File]::WriteAllText($conf, $raw)
  }
}

switch ($Action) {
  "status" {
    $app = if (Test-GhosttyFound) { "found" } else { "skip" }
    $dest = Get-GhosttyDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-GhosttyDest
    Copy-StillwaterFile $Src $dest
    Set-GhosttyTheme
    Write-Output $dest
  }
}
