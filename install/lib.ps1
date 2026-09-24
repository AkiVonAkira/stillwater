# Shared helpers for Stillwater install scripts. Dotted from install.ps1 and */install.ps1.

function Get-StillwaterPlatform {
  if ($env:OS -match "Windows") { return "windows" }
  switch ([System.Environment]::OSVersion.Platform) {
    "Win32NT" { return "windows" }
    "Unix" {
      if ($IsMacOS) { return "darwin" }
      return "linux"
    }
    default { return "windows" }
  }
}

function Get-StillwaterOsLabel {
  switch (Get-StillwaterPlatform) {
    "darwin" { return "macos" }
    "windows" { return "windows" }
    default {
      $release = "/etc/os-release"
      if (Test-Path $release) {
        $id = (Select-String -Path $release -Pattern '^ID=(.*)$').Matches.Groups[1].Value.Trim('"')
        if ($id) { return "linux/$id" }
      }
      return "linux"
    }
  }
}

function Initialize-StillwaterPaths {
  if ($env:STILLWATER_HOME) {
    $env:HOME = $env:STILLWATER_HOME
    $env:USERPROFILE = $env:STILLWATER_HOME
    $env:XDG_CONFIG_HOME = Join-Path $env:STILLWATER_HOME ".config"
    $env:XDG_DATA_HOME = Join-Path $env:STILLWATER_HOME ".local/share"
    $env:APPDATA = Join-Path $env:STILLWATER_HOME "AppData/Roaming"
    $env:LOCALAPPDATA = Join-Path $env:STILLWATER_HOME "AppData/Local"
  }
  if (-not $env:HOME) { $env:HOME = $env:USERPROFILE }
  if (-not $env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME = Join-Path $env:HOME ".config" }
  if (-not $env:XDG_DATA_HOME) { $env:XDG_DATA_HOME = Join-Path $env:HOME ".local/share" }
  if (-not $env:APPDATA) { $env:APPDATA = Join-Path $env:HOME "AppData/Roaming" }
  if (-not $env:LOCALAPPDATA) { $env:LOCALAPPDATA = Join-Path $env:HOME "AppData/Local" }
}

function Test-StillwaterCommand([string]$Name) {
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-StillwaterAnyCommand([string[]]$Names) {
  foreach ($name in $Names) {
    if (Test-StillwaterCommand $name) { return $true }
  }
  return $false
}

function Test-StillwaterAnyDir([string[]]$Dirs) {
  foreach ($dir in $Dirs) {
    if ($dir -and (Test-Path -LiteralPath $dir -PathType Container)) { return $true }
  }
  return $false
}

function Copy-StillwaterTree([string]$Src, [string]$Dest) {
  if ($env:STILLWATER_DRY_RUN -eq "1") {
    Write-Host "would copy $Src -> $Dest"
    return
  }
  $parent = Split-Path -Parent $Dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  Copy-Item -Recurse -Force $Src $Dest
}

function Copy-StillwaterFile([string]$Src, [string]$Dest) {
  if ($env:STILLWATER_DRY_RUN -eq "1") {
    Write-Host "would copy $Src -> $Dest"
    return
  }
  $parent = Split-Path -Parent $Dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  Copy-Item -Force $Src $Dest
}

function Get-StillwaterVersion {
  $file = Join-Path $env:STILLWATER_ROOT "palette.json"
  $spec = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json
  return [string]$spec.version
}

function Get-StillwaterVsCodeExtId {
  return ("kayzel.stillwater-theme-{0}" -f (Get-StillwaterVersion))
}

function ConvertTo-StillwaterVsCodePath([string]$Path) {
  $norm = $Path.Replace("\", "/")
  if ($norm -match '^([A-Za-z]):/(.*)$') {
    return ("/{0}:/{1}" -f $Matches[1].ToLowerInvariant(), $Matches[2])
  }
  return $norm
}

function Remove-StillwaterOldVsCodeExtensions([string]$Parent, [string]$Keep) {
  if ($env:STILLWATER_DRY_RUN -eq "1") {
    Write-Host "would retire old Stillwater folders in $Parent"
    return
  }
  if (-not (Test-Path -LiteralPath $Parent -PathType Container)) { return }
  Get-ChildItem -LiteralPath $Parent -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like "kayzel.stillwater-theme-*" -and $_.Name -ne $Keep } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
}

function Register-StillwaterVsCodeExtension([string]$Dest) {
  $version = Get-StillwaterVersion
  $id = "kayzel.stillwater-theme"
  $root = Split-Path -Parent $Dest
  $folder = Split-Path -Leaf $Dest
  $jsonPath = Join-Path $root "extensions.json"
  $obsoletePath = Join-Path $root ".obsolete"
  if ($env:STILLWATER_DRY_RUN -eq "1") {
    Write-Host "would register $id $version -> $Dest"
    return
  }
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  if (Test-Path -LiteralPath $obsoletePath) {
    $obsolete = Get-Content -Raw -LiteralPath $obsoletePath | ConvertFrom-Json
    $map = @{}
    $obsolete.PSObject.Properties | ForEach-Object {
      if ($_.Name -notlike "kayzel.stillwater-theme*") { $map[$_.Name] = $_.Value }
    }
    $obsoleteJson = if ($map.Count -eq 0) { "{}" } else { $map | ConvertTo-Json -Compress }
    [System.IO.File]::WriteAllText($obsoletePath, $obsoleteJson + "`n")
  }
  $list = @()
  if (Test-Path -LiteralPath $jsonPath) {
    $parsed = Get-Content -Raw -LiteralPath $jsonPath | ConvertFrom-Json
    if ($parsed) { $list = @($parsed) }
  }
  $list = @($list | Where-Object { $_.identifier.id -ne $id })
  $entry = [pscustomobject]@{
    identifier = [pscustomobject]@{ id = $id }
    version = $version
    location = [pscustomobject]@{
      '$mid' = 1
      path = ConvertTo-StillwaterVsCodePath ((Resolve-Path -LiteralPath $Dest).Path)
      scheme = "file"
    }
    relativeLocation = $folder
    metadata = [pscustomobject]@{
      installedTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
      pinned = $true
      source = "vsix"
      isPreReleaseVersion = $false
      hasPreReleaseVersion = $false
    }
  }
  $list += $entry
  $payload = @($list)
  $text = ConvertTo-Json -Depth 8 -Compress $payload
  if ($payload.Count -eq 1 -and $text -notmatch '^\s*\[') {
    $text = "[$text]"
  }
  [System.IO.File]::WriteAllText($jsonPath, $text + "`n")
}

function Set-StillwaterVsCodeTheme([string]$SettingsPath) {
  if ($env:STILLWATER_DRY_RUN -eq "1") {
    Write-Host "would set workbench.colorTheme in $SettingsPath"
    return
  }
  $dir = Split-Path -Parent $SettingsPath
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $seed = "{`n  `"workbench.colorTheme`": `"Stillwater`"`n}`n"
  if (-not (Test-Path -LiteralPath $SettingsPath)) {
    Set-Content -Encoding utf8 -Path $SettingsPath -Value $seed
    return
  }
  $raw = [System.IO.File]::ReadAllText($SettingsPath)
  if ($raw -match '"workbench\.colorTheme"') {
    $raw = [regex]::Replace($raw, '"workbench\.colorTheme"\s*:\s*"[^"]*"', '"workbench.colorTheme": "Stillwater"')
  } else {
    $raw = [regex]::Replace($raw, '\{', "{`n  `"workbench.colorTheme`": `"Stillwater`",", 1)
  }
  [System.IO.File]::WriteAllText($SettingsPath, $raw)
}

function Invoke-StillwaterCmd([string[]]$Cmd) {
  if ($env:STILLWATER_DRY_RUN -eq "1") {
    Write-Host ("would run: " + ($Cmd -join " "))
    return $true
  }
  try {
    & $Cmd[0] @($Cmd | Select-Object -Skip 1) | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Test-StillwaterIdWanted([string]$Id, [string[]]$Only) {
  if (-not $Only -or $Only.Count -eq 0) { return $true }
  return $Only -contains $Id
}
