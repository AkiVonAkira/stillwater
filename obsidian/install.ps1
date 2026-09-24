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

$Id = "obsidian"
$Label = "Obsidian"
$SrcDir = Join-Path $Root "obsidian"

function Get-ObsidianConfigJsons {
  @(
    (Join-Path $env:XDG_CONFIG_HOME "obsidian\obsidian.json"),
    (Join-Path $env:APPDATA "obsidian\obsidian.json")
  )
}

function Get-ObsidianConfigDirs {
  @(
    (Join-Path $env:XDG_CONFIG_HOME "obsidian"),
    (Join-Path $env:APPDATA "obsidian")
  )
}

function Get-ObsidianVaults {
  foreach ($file in Get-ObsidianConfigJsons) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    try {
      $json = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json
      if ($json.vaults) {
        $json.vaults.PSObject.Properties | ForEach-Object { [string]$_.Value.path }
      }
    } catch { }
  }
}

function Get-ObsidianThemeDest([string]$Vault) {
  Join-Path $Vault ".obsidian\themes\Stillwater"
}

function Test-ObsidianFound {
  if (Test-StillwaterCommand "obsidian") { return $true }
  return Test-StillwaterAnyDir (Get-ObsidianConfigDirs)
}

function Get-ObsidianFirstDest {
  foreach ($vault in Get-ObsidianVaults) {
    if ($vault) { return (Get-ObsidianThemeDest $vault) }
  }
  return (Join-Path $env:APPDATA "obsidian\themes\Stillwater")
}

function Set-ObsidianCssTheme([string]$Vault) {
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  $appearance = Join-Path $Vault ".obsidian\appearance.json"
  $dir = Split-Path -Parent $appearance
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $seed = "{`n  `"cssTheme`": `"Stillwater`"`n}`n"
  if (-not (Test-Path -LiteralPath $appearance)) {
    Set-Content -Encoding utf8 -Path $appearance -Value $seed
    return
  }
  $raw = [System.IO.File]::ReadAllText($appearance)
  if ($raw -match '"cssTheme"') {
    $raw = [regex]::Replace($raw, '"cssTheme"\s*:\s*"[^"]*"', '"cssTheme": "Stillwater"')
  } else {
    $raw = [regex]::Replace($raw, '\{', "{`n  `"cssTheme`": `"Stillwater`",", 1)
  }
  [System.IO.File]::WriteAllText($appearance, $raw)
}

switch ($Action) {
  "status" {
    $app = if (Test-ObsidianFound) { "found" } else { "skip" }
    $pairs = @()
    $dests = @((Get-ObsidianFirstDest))
    foreach ($vault in Get-ObsidianVaults) {
      if (-not $vault) { continue }
      $dest = Get-ObsidianThemeDest $vault
      $pairs += (Join-Path $SrcDir "manifest.json")
      $pairs += (Join-Path $dest "manifest.json")
      $pairs += (Join-Path $SrcDir "theme.css")
      $pairs += (Join-Path $dest "theme.css")
      $dests += $dest
    }
    $theme = Get-StillwaterPayloadState $pairs
    Write-StillwaterCopyStatus $Id $Label $app $theme $dests
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $written = @()
    foreach ($vault in Get-ObsidianVaults) {
      if (-not $vault) { continue }
      $dest = Get-ObsidianThemeDest $vault
      Copy-StillwaterFile (Join-Path $SrcDir "manifest.json") (Join-Path $dest "manifest.json")
      Copy-StillwaterFile (Join-Path $SrcDir "theme.css") (Join-Path $dest "theme.css")
      Set-ObsidianCssTheme $vault
      $written += $dest
    }
    Write-Output ($written -join ", ")
  }
}
