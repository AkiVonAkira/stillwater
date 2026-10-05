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

$Id = "spotifast"
$Label = "Spotifast"
$Src = Join-Path $Root "spotifast\stillwater.json"

function Get-SpotifastConfigDirs {
  switch (Get-StillwaterPlatform) {
    "windows" {
      @(Join-Path $env:APPDATA "paolino\spotifast\config")
    }
    "darwin" {
      @(Join-Path $env:HOME "Library/Application Support/me.paolino.spotifast")
    }
    default {
      @(
        (Join-Path $env:XDG_CONFIG_HOME "spotifast"),
        (Join-Path $env:HOME ".var/app/rocks.spotifast.Spotifast/config/spotifast")
      )
    }
  }
}

function Get-SpotifastConfigDir {
  foreach ($dir in Get-SpotifastConfigDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) { return $dir }
  }
  return (Get-SpotifastConfigDirs)[0]
}

function Test-SpotifastInstalled {
  switch (Get-StillwaterPlatform) {
    "windows" {
      return Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA "Programs\Spotifast\spotifast.exe")
    }
    "darwin" {
      if (Test-Path -LiteralPath "/Applications/Spotifast.app") { return $true }
      return Test-Path -LiteralPath (Join-Path $env:HOME "Applications/Spotifast.app")
    }
    default { return $false }
  }
}

function Test-SpotifastFound {
  if (Test-StillwaterAnyCommand @("spotifast", "fastpotify")) { return $true }
  if (Test-SpotifastInstalled) { return $true }
  return Test-StillwaterAnyDir (Get-SpotifastConfigDirs)
}

function Set-SpotifastTheme([string]$Dir) {
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  $settings = Join-Path $Dir "settings.json"
  if (-not (Test-Path -LiteralPath $settings -PathType Leaf)) {
    [System.IO.File]::WriteAllText($settings, "{`n  `"custom_theme`": `"stillwater.json`"`n}`n")
    return
  }
  $raw = [System.IO.File]::ReadAllText($settings)
  if ($raw -match '"custom_theme"') {
    $raw = [regex]::new('"custom_theme"\s*:\s*(null|"[^"]*")').Replace($raw, '"custom_theme": "stillwater.json"', 1)
  } else {
    $raw = [regex]::new('\{').Replace($raw, "{`n  `"custom_theme`": `"stillwater.json`",", 1)
  }
  [System.IO.File]::WriteAllText($settings, $raw)
}

switch ($Action) {
  "status" {
    $app = if (Test-SpotifastFound) { "found" } else { "skip" }
    $dest = Join-Path (Get-SpotifastConfigDir) "themes\stillwater.json"
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dir = Get-SpotifastConfigDir
    $dest = Join-Path $dir "themes\stillwater.json"
    Copy-StillwaterFile $Src $dest
    Set-SpotifastTheme $dir
    if (Test-StillwaterCommand "spotifast") {
      Invoke-StillwaterCmd @("spotifast", "reload-themes") | Out-Null
    }
    Write-Output $dest
  }
}
