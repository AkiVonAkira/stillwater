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

$Id = "yasb"
$Label = "YASB"
$Src = Join-Path $Root "yasb\styles.css"

function Get-YasbDirs {
  $dirs = @()
  if ($env:YASB_CONFIG_HOME) { $dirs += $env:YASB_CONFIG_HOME }
  $dirs += (Join-Path $env:HOME ".config\yasb")
  $dirs += (Join-Path $env:XDG_CONFIG_HOME "yasb")
  return $dirs
}

function Test-YasbFound {
  if (Test-StillwaterAnyCommand @("yasb", "yasbc")) { return $true }
  return Test-StillwaterAnyDir (Get-YasbDirs)
}

function Get-YasbDest {
  foreach ($dir in Get-YasbDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "styles.css")
    }
  }
  return (Join-Path $env:HOME ".config\yasb\styles.css")
}

switch ($Action) {
  "status" {
    $app = if (Test-YasbFound) { "found" } else { "skip" }
    $dest = Get-YasbDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-YasbDest
    Copy-StillwaterFile $Src $dest
    Write-Output $dest
  }
}
