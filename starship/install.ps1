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

$Id = "starship"
$Label = "Starship"
$ThemeSrc = Join-Path $Root "starship\starship.toml"
$ProfileSrc = Join-Path $Root "starship\Microsoft.PowerShell_profile.ps1"

function Get-StarshipThemeDest {
  Join-Path $env:XDG_CONFIG_HOME "starship.toml"
}

function Get-StarshipProfileDest {
  Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}

function Test-StarshipFound {
  if ((Get-StillwaterPlatform) -eq "windows" -and (Test-StillwaterAnyCommand @("pwsh", "powershell"))) {
    return $true
  }
  $docs = Join-Path $env:USERPROFILE "Documents\PowerShell"
  return (Test-Path -LiteralPath $docs -PathType Container)
}

switch ($Action) {
  "status" {
    $app = if (Test-StarshipFound) { "found" } else { "skip" }
    $themeDest = Get-StarshipThemeDest
    $profileDest = Get-StarshipProfileDest
    $state = Get-StillwaterPayloadState @($ThemeSrc, $themeDest, $ProfileSrc, $profileDest)
    Write-StillwaterCopyStatus $Id $Label $app $state @($themeDest, $profileDest)
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $themeDest = Get-StarshipThemeDest
    $profileDest = Get-StarshipProfileDest
    Copy-StillwaterFile $ThemeSrc $themeDest
    Copy-StillwaterFile $ProfileSrc $profileDest
    Write-Output $themeDest
  }
}
