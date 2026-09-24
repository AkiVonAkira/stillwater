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

$Id = "spicetify"
$Label = "Spicetify"

function Get-SpicetifyDirs {
  @((Join-Path $env:APPDATA "spicetify"), (Join-Path $env:XDG_CONFIG_HOME "spicetify"))
}

function Test-SpicetifyFound {
  if (Test-StillwaterCommand "spicetify") { return $true }
  return Test-StillwaterAnyDir (Get-SpicetifyDirs)
}

function Get-SpicetifyDest {
  if (Test-StillwaterCommand "spicetify") {
    try {
      $cfg = (& spicetify -c 2>$null | Select-Object -First 1)
      if ($cfg) {
        $parent = Split-Path -Parent $cfg
        if (Test-Path -LiteralPath $parent -PathType Container) {
          return (Join-Path $parent "Themes\stillwater")
        }
      }
    } catch { }
  }
  foreach ($dir in Get-SpicetifyDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "Themes\stillwater")
    }
  }
  return (Join-Path $env:APPDATA "spicetify\Themes\stillwater")
}

switch ($Action) {
  "status" {
    $app = if (Test-SpicetifyFound) { "found" } else { "skip" }
    $dest = Get-SpicetifyDest
    $theme = Get-StillwaterPayloadState @(
      (Join-Path $Root "spicetify\color.ini"), (Join-Path $dest "color.ini"),
      (Join-Path $Root "spicetify\user.css"), (Join-Path $dest "user.css"),
      (Join-Path $Root "spicetify\theme.js"), (Join-Path $dest "theme.js")
    )
    Write-StillwaterCopyStatus $Id $Label $app $theme $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-SpicetifyDest
    if ($env:STILLWATER_DRY_RUN -ne "1") {
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Copy-Item -Force (Join-Path $Root "spicetify\color.ini") $dest
      Copy-Item -Force (Join-Path $Root "spicetify\user.css") $dest
      Copy-Item -Force (Join-Path $Root "spicetify\theme.js") $dest
    }
    if (Test-StillwaterCommand "spicetify") {
      Invoke-StillwaterCmd @("spicetify", "config", "current_theme", "stillwater", "color_scheme", "stillwater") | Out-Null
      Invoke-StillwaterCmd @("spicetify", "config", "inject_css", "1", "replace_colors", "1", "overwrite_assets", "1", "inject_theme_js", "1") | Out-Null
      Invoke-StillwaterCmd @("spicetify", "apply") | Out-Null
    }
    Write-Output $dest
  }
}
