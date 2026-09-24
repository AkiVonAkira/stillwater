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

$Id = "prism"
$Label = "Prism Launcher"
$Src = Join-Path $Root "prism"

function Get-PrismDirs {
  @(
    (Join-Path $env:XDG_DATA_HOME "PrismLauncher"),
    (Join-Path $env:HOME ".var\app\org.prismlauncher.PrismLauncher\data\PrismLauncher"),
    (Join-Path $env:APPDATA "PrismLauncher"),
    (Join-Path $env:HOME "scoop\persist\prismlauncher")
  )
}

function Test-PrismFound {
  if (Test-StillwaterAnyCommand @("prismlauncher", "prismlauncher-qt5")) { return $true }
  return Test-StillwaterAnyDir (Get-PrismDirs)
}

function Get-PrismDest {
  foreach ($dir in Get-PrismDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "themes\Stillwater")
    }
  }
  return (Join-Path $env:APPDATA "PrismLauncher\themes\Stillwater")
}

switch ($Action) {
  "status" {
    $app = if (Test-PrismFound) { "found" } else { "skip" }
    $dest = Get-PrismDest
    $theme = Get-StillwaterPayloadState @(
      (Join-Path $Src "theme.json"), (Join-Path $dest "theme.json"),
      (Join-Path $Src "themeStyle.css"), (Join-Path $dest "themeStyle.css")
    )
    Write-StillwaterCopyStatus $Id $Label $app $theme $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-PrismDest
    Copy-StillwaterFile (Join-Path $Src "theme.json") (Join-Path $dest "theme.json")
    Copy-StillwaterFile (Join-Path $Src "themeStyle.css") (Join-Path $dest "themeStyle.css")
    Write-Output $dest
  }
}
