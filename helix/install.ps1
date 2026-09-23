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

$Id = "helix"
$Label = "Helix"
$Src = Join-Path $Root "helix\themes\stillwater.toml"

function Get-HelixDirs {
  @((Join-Path $env:XDG_CONFIG_HOME "helix"), (Join-Path $env:APPDATA "helix"))
}

function Test-HelixFound {
  if (Test-StillwaterAnyCommand @("hx", "helix")) { return $true }
  return Test-StillwaterAnyDir (Get-HelixDirs)
}

function Get-HelixDest {
  foreach ($dir in Get-HelixDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "themes\stillwater.toml")
    }
  }
  return (Join-Path $env:APPDATA "helix\themes\stillwater.toml")
}

switch ($Action) {
  "status" {
    $state = if (Test-HelixFound) { "found" } else { "skip" }
    Write-Output ("{0}|{1}|{2}" -f $Id, $Label, $state)
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-HelixDest
    Copy-StillwaterFile $Src $dest
    Write-Output $dest
  }
}
