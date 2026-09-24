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

$Id = "t3"
$Label = "T3 Code"
$Src = Join-Path $Root "t3\stillwater.json"

function Test-T3Found {
  if (Test-StillwaterCommand "t3") { return $true }
  return Test-StillwaterAnyDir @(
    (Join-Path $env:APPDATA "t3"),
    (Join-Path $env:LOCALAPPDATA "t3"),
    (Join-Path $env:HOME ".t3")
  )
}

function Get-T3ThemeCandidates {
  $paths = @(
    (Join-Path $env:HOME ".t3\userdata\themes\stillwater.json"),
    (Join-Path $env:HOME ".t3\themes\stillwater.json"),
    (Join-Path $env:XDG_CONFIG_HOME "t3\userdata\themes\stillwater.json"),
    (Join-Path $env:XDG_CONFIG_HOME "t3\themes\stillwater.json"),
    (Join-Path $env:APPDATA "t3\userdata\themes\stillwater.json"),
    (Join-Path $env:APPDATA "t3\themes\stillwater.json"),
    (Join-Path $env:LOCALAPPDATA "t3\userdata\themes\stillwater.json"),
    (Join-Path $env:LOCALAPPDATA "t3\themes\stillwater.json")
  )
  if ($env:T3CODE_HOME) {
    $paths += (Join-Path $env:T3CODE_HOME "userdata\themes\stillwater.json")
  }
  return $paths
}

function Get-T3ThemeState {
  $states = @()
  foreach ($file in Get-T3ThemeCandidates) {
    if (Test-Path -LiteralPath $file -PathType Leaf) {
      $states += Get-StillwaterCopyState $Src $file
    }
  }
  return (Merge-StillwaterThemeState $states)
}

switch ($Action) {
  "status" {
    $app = if (Test-T3Found) { "found" } else { "skip" }
    $dests = @(Get-T3ThemeCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    Write-StillwaterCopyStatus $Id $Label $app (Get-T3ThemeState) $dests
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    if (Test-StillwaterCommand "t3") {
      if (Invoke-StillwaterCmd @("t3", "theme", "set", "--id", "stillwater", $Src)) {
        Write-Output "t3 theme set --id stillwater"
        break
      }
    }
    Write-Output $Src
  }
}
