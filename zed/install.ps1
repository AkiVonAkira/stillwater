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

$Id = "zed"
$Label = "Zed"
$ThemeSrc = Join-Path $Root "zed\themes\stillwater.json"

function Get-ZedDirs {
  @(
    (Join-Path $env:XDG_CONFIG_HOME "zed"),
    (Join-Path $env:HOME ".zed"),
    (Join-Path $env:APPDATA "Zed")
  )
}

function Test-ZedFound {
  if (Test-StillwaterAnyCommand @("zed", "zeditor")) { return $true }
  return Test-StillwaterAnyDir (Get-ZedDirs)
}

function Get-ZedThemeDest {
  foreach ($dir in Get-ZedDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "themes\stillwater.json")
    }
  }
  return (Join-Path $env:APPDATA "Zed\themes\stillwater.json")
}

function Get-ZedExtDest {
  Join-Path $env:LOCALAPPDATA "Zed\extensions\installed\stillwater"
}

switch ($Action) {
  "status" {
    $app = if (Test-ZedFound) { "found" } else { "skip" }
    $dest = Get-ZedThemeDest
    $ext = Get-ZedExtDest
    $theme = Get-StillwaterPayloadState @(
      $ThemeSrc, $dest,
      (Join-Path $Root "zed\extension.toml"), (Join-Path $ext "extension.toml"),
      $ThemeSrc, (Join-Path $ext "themes\stillwater.json")
    )
    Write-StillwaterCopyStatus $Id $Label $app $theme @(
      $dest,
      (Join-Path $ext "extension.toml"),
      (Join-Path $ext "themes\stillwater.json")
    )
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-ZedThemeDest
    Copy-StillwaterFile $ThemeSrc $dest
    $ext = Get-ZedExtDest
    Copy-StillwaterFile (Join-Path $Root "zed\extension.toml") (Join-Path $ext "extension.toml")
    Copy-StillwaterFile $ThemeSrc (Join-Path $ext "themes\stillwater.json")
    Write-Output $dest
  }
}
