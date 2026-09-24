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

$Id = "btop"
$Label = "btop"
$Src = Join-Path $Root "btop\stillwater.theme"

function Get-BtopDirs {
  @((Join-Path $env:XDG_CONFIG_HOME "btop"), (Join-Path $env:APPDATA "btop"))
}

function Test-BtopFound {
  if (Test-StillwaterAnyCommand @("btop", "btop4win")) { return $true }
  return Test-StillwaterAnyDir (Get-BtopDirs)
}

function Get-BtopDir {
  foreach ($dir in Get-BtopDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) { return $dir }
  }
  return (Join-Path $env:APPDATA "btop")
}

function Get-BtopDest {
  Join-Path (Get-BtopDir) "themes\stillwater.theme"
}

function Set-BtopTheme {
  $conf = Join-Path (Get-BtopDir) "btop.conf"
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  if (-not (Test-Path -LiteralPath $conf -PathType Leaf)) { return }
  $raw = [System.IO.File]::ReadAllText($conf)
  if ($raw -match '(?m)^color_theme\s*=') {
    $raw = [regex]::Replace($raw, '(?m)^color_theme\s*=.*', 'color_theme = "stillwater"')
    [System.IO.File]::WriteAllText($conf, $raw)
  }
}

switch ($Action) {
  "status" {
    $app = if (Test-BtopFound) { "found" } else { "skip" }
    $dest = Get-BtopDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-BtopDest
    Copy-StillwaterFile $Src $dest
    Set-BtopTheme
    Write-Output $dest
  }
}
