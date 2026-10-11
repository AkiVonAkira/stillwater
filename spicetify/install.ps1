param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("status", "owns", "install")]
  [string]$Action,
  [string[]]$Only = @(),
  [string]$Base = ""
)

$Root = $env:STILLWATER_ROOT
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
. (Join-Path $Root "install\lib.ps1")
Initialize-StillwaterPaths

$Id = "spicetify"
$Label = "Spicetify"
$Bases = "base=Base,dribbblish=Dribbblish"
$DefaultBase = "dribbblish"

# Installs from before base themes carry no stamp, and they were Dribbblish.
function Get-SpicetifyInstalledBase([string]$Dest) {
  $css = Join-Path $Dest "user.css"
  if (-not (Test-Path -LiteralPath $css -PathType Leaf)) { return $DefaultBase }
  $stamp = Get-StillwaterPeekBase $css
  if ($stamp) { return $stamp }
  return "dribbblish"
}

# Base is color.ini and a stub user.css; Dribbblish adds its theme.js.
function Get-SpicetifyPayload([string]$Dest, [string]$Key) {
  $pairs = @(
    (Join-Path $Root "spicetify\color.ini"), (Join-Path $Dest "color.ini"),
    (Join-Path $Root "spicetify\$Key\user.css"), (Join-Path $Dest "user.css")
  )
  if ($Key -eq "dribbblish") {
    $pairs += (Join-Path $Root "spicetify\dribbblish\theme.js")
    $pairs += (Join-Path $Dest "theme.js")
  }
  return $pairs
}

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
    $base = Get-SpicetifyInstalledBase $dest
    $theme = Get-StillwaterPayloadState @(Get-SpicetifyPayload $dest $base)
    Write-StillwaterCopyStatus $Id $Label $app $theme $dest -Bases $Bases -Base $base
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    if (-not $Base) { $Base = $DefaultBase }
    if (-not (Test-StillwaterBaseValid $Bases $Base)) { throw "Unknown base: $Base" }
    $js = if ($Base -eq "dribbblish") { "1" } else { "0" }
    $dest = Get-SpicetifyDest
    if ($env:STILLWATER_DRY_RUN -ne "1") {
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Copy-Item -Force (Join-Path $Root "spicetify\color.ini") $dest
      Copy-Item -Force (Join-Path $Root "spicetify\$Base\user.css") $dest
      $jsDest = Join-Path $dest "theme.js"
      if ($js -eq "1") {
        Copy-Item -Force (Join-Path $Root "spicetify\$Base\theme.js") $dest
      } elseif (Test-Path -LiteralPath $jsDest) {
        Remove-Item -Force -LiteralPath $jsDest
      }
    }
    if (Test-StillwaterCommand "spicetify") {
      Invoke-StillwaterCmd @("spicetify", "config", "current_theme", "stillwater", "color_scheme", "stillwater") | Out-Null
      Invoke-StillwaterCmd @("spicetify", "config", "inject_css", "1", "replace_colors", "1", "overwrite_assets", "1", "inject_theme_js", $js) | Out-Null
      Invoke-StillwaterCmd @("spicetify", "apply") | Out-Null
    }
    Write-Output $dest
  }
}
