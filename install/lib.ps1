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
  if ($null -ne $script:StillwaterOsLabel -and $script:StillwaterOsLabel -ne "") {
    return $script:StillwaterOsLabel
  }
  $script:StillwaterOsLabel = switch (Get-StillwaterPlatform) {
    "darwin" { "macos" }
    "windows" { "windows" }
    default {
      $release = "/etc/os-release"
      if (Test-Path $release) {
        $id = (Select-String -Path $release -Pattern '^ID=(.*)$').Matches.Groups[1].Value.Trim('"')
        if ($id) { "linux/$id" } else { "linux" }
      } else {
        "linux"
      }
    }
  }
  return $script:StillwaterOsLabel
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
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  $parent = Split-Path -Parent $Dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  Copy-Item -Recurse -Force $Src $Dest
}

function Copy-StillwaterFile([string]$Src, [string]$Dest) {
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  $parent = Split-Path -Parent $Dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  Copy-Item -Force $Src $Dest
}

function Get-StillwaterPalette {
  if (-not $script:StillwaterPalette) {
    $file = Join-Path $env:STILLWATER_ROOT "palette.json"
    $script:StillwaterPalette = (Get-Content -Raw -LiteralPath $file | ConvertFrom-Json).palette
  }
  return $script:StillwaterPalette
}

function Get-StillwaterVersion {
  if ($null -ne $script:StillwaterVersion -and $script:StillwaterVersion -ne "") {
    return $script:StillwaterVersion
  }
  $file = Join-Path $env:STILLWATER_ROOT "palette.json"
  $spec = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json
  $script:StillwaterVersion = [string]$spec.version
  return $script:StillwaterVersion
}

function ConvertTo-StillwaterFg([string]$Hex) {
  $h = $Hex.TrimStart("#")
  if ($h.Length -ne 6) { return "" }
  $r = [Convert]::ToInt32($h.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($h.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($h.Substring(4, 2), 16)
  return "`e[38;2;${r};${g};${b}m"
}

function Get-StillwaterThemeAnsi {
  $p = Get-StillwaterPalette
  if ($env:NO_COLOR) {
    return @{
      Reset = ""; Accent = ""; AccentHover = ""; AccentDeep = ""
      Text = ""; Muted = ""; Warm = ""; Warn = ""; Error = ""; Clear = ""
    }
  }
  return @{
    Reset = "`e[0m"
    Accent = ConvertTo-StillwaterFg $p.accent
    AccentHover = ConvertTo-StillwaterFg $p.accentHover
    AccentDeep = ConvertTo-StillwaterFg $p.accentDeep
    Text = ConvertTo-StillwaterFg $p.text
    Muted = ConvertTo-StillwaterFg $p.textMuted
    Warm = ConvertTo-StillwaterFg $p.warm
    Warn = ConvertTo-StillwaterFg $p.warning
    Error = ConvertTo-StillwaterFg $p.error
    Clear = "`e[2K"
  }
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
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
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
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
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
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
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
  if ($env:STILLWATER_DRY_RUN -eq "1") { return $true }
  try {
    $global:LASTEXITCODE = 0
    & $Cmd[0] @($Cmd | Select-Object -Skip 1) *> $null
    return ($LASTEXITCODE -eq 0)
  } catch {
    return $false
  }
}

function Test-StillwaterIdWanted([string]$Id, [string[]]$Only) {
  if (-not $Only -or $Only.Count -eq 0) { return $true }
  return $Only -contains $Id
}

function Write-StillwaterStatus([string]$Id, [string]$Label, [string]$App, [string]$Theme, [string]$Note = "", [string]$Dest = "") {
  Write-Output ("{0}|{1}|{2}|{3}|{4}|{5}" -f $Id, $Label, $App, $Theme, $Note, $Dest)
}

function Get-StillwaterDisplayPath([string]$Path) {
  if (-not $Path) { return "" }
  $normalized = $Path.Replace("/", "\").TrimEnd("\")
  $leaf = Split-Path -Leaf $normalized
  if ($leaf -like "*.*") {
    $normalized = Split-Path -Parent $normalized
  }
  $homeDir = $env:HOME
  if (-not $homeDir) { $homeDir = $env:USERPROFILE }
  if ($homeDir) {
    $homeSlash = $homeDir.Replace("/", "\").TrimEnd("\")
    if ($normalized.StartsWith($homeSlash, [StringComparison]::OrdinalIgnoreCase)) {
      return ("~" + $normalized.Substring($homeSlash.Length)).Replace("\", "/")
    }
  }
  return $normalized.Replace("\", "/")
}

function Get-StillwaterTermCols {
  try {
    $n = [Console]::WindowWidth
    if ($n -ge 40) { return $n }
  } catch { }
  return 80
}

function Get-StillwaterFitLeft([string]$Text, [int]$Max) {
  if (-not $Text -or $Max -le 0) { return "" }
  if ($Text.Length -le $Max) { return $Text }
  if ($Max -le 1) { return "…" }
  return "…" + $Text.Substring($Text.Length - $Max + 1)
}

function Get-StillwaterNextStep([string]$Id) {
  switch ($Id) {
    { $_ -in @("cursor", "vscode", "vscode-insiders", "vscodium", "code-oss", "windsurf") } {
      return "Set Color Theme to Stillwater."
    }
    "zed" { return "Set the theme to Stillwater." }
    "helix" { return "Set theme to stillwater in config.toml." }
    "neovim" { return "Run :colorscheme stillwater." }
    "sublime" { return "Set Color Scheme to Stillwater." }
    "vencord" { return "Enable Stillwater in Vencord themes." }
    "equicord" { return "Enable Stillwater in Equicord themes." }
    "t3" { return "Select Stillwater in T3 Code." }
    "spicetify" { return "Restart Spotify." }
    "spotifast" { return "Select Stillwater under Settings, Appearance, Theme." }
    "ryoku" { return "Select Stillwater in Ryoku." }
    "obsidian" { return "Set the Appearance theme to Stillwater." }
    "prism" { return "Set the Widgets theme to Stillwater." }
    "yasb" { return "Reload YASB to apply colors." }
    "kitty" { return "Reload Kitty to apply Stillwater." }
    "ghostty" { return "Set theme = Stillwater in Ghostty config." }
    "harbor" { return "Import Stillwater.harborstyle under Settings, Theme & appearance." }
    "btop" { return "Set color_theme to stillwater in btop.conf." }
    "windows-terminal" { return "Set the color scheme to Stillwater." }
    default { return "" }
  }
}

function Get-StillwaterPeekVersion([string]$Path) {
  if (-not $Path) { return "" }
  $file = $null
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $file = $Path
  } elseif (Test-Path -LiteralPath $Path -PathType Container) {
    foreach ($name in @("package.json", "extension.toml", "color.ini", "Stillwater.theme.css", "meta.json", "manifest.json", "theme.json", "stillwater.json")) {
      $cand = Join-Path $Path $name
      if (Test-Path -LiteralPath $cand -PathType Leaf) {
        $file = $cand
        break
      }
    }
  }
  if (-not $file) { return "" }
  $text = Get-Content -Raw -LiteralPath $file
  foreach ($pattern in @(
      '(?m)^\s*"version"\s*:\s*"([0-9]+\.[0-9][0-9.]*)"',
      '(?m)^\s*version\s*=\s*"([0-9]+\.[0-9][0-9.]*)"',
      '@version\s+([0-9]+\.[0-9][0-9.]*)',
      '(?m)^\s*[;#]\s*version\s+([0-9]+\.[0-9][0-9.]*)'
    )) {
    $m = [regex]::Match($text, $pattern)
    if ($m.Success) { return $m.Groups[1].Value }
  }
  return ""
}

function Get-StillwaterStatusNote([string]$State, [string]$Installed = "") {
  if ($State -ne "update") { return "" }
  $wanted = Get-StillwaterVersion
  if ($Installed -and $Installed -ne $wanted) {
    return ("{0} to {1}" -f $Installed, $wanted)
  }
  return "Modified"
}

function Write-StillwaterCopyStatus([string]$Id, [string]$Label, [string]$App, [string]$State, [string[]]$Dests = @()) {
  $installed = ""
  $destShow = ""
  foreach ($path in @($Dests)) {
    if (-not $path) { continue }
    if (-not $destShow) { $destShow = $path }
    $installed = Get-StillwaterPeekVersion $path
    if ($installed) { break }
  }
  Write-StillwaterStatus $Id $Label $App $State (Get-StillwaterStatusNote $State $installed) $destShow
}

function Sort-StillwaterStatus([string[]]$Rows) {
  if (-not $Rows) { return @() }
  $Rows | ForEach-Object {
    $parts = $_.Split("|")
    [pscustomobject]@{
      Raw = $_
      AppRank = switch ($parts[2]) { "found" { 0 } "skip" { 1 } default { 2 } }
      ThemeRank = switch ($(if ($parts.Count -gt 3) { $parts[3] } else { "none" })) {
        "update" { 0 }
        "none" { 1 }
        "current" { 2 }
        default { 3 }
      }
      Label = $parts[1]
    }
  } | Sort-Object AppRank, ThemeRank, { $_.Label.ToLowerInvariant() } | ForEach-Object { $_.Raw }
}

function Test-StillwaterSameFile([string]$Src, [string]$Dest) {
  if (-not (Test-Path -LiteralPath $Src -PathType Leaf)) { return $false }
  if (-not (Test-Path -LiteralPath $Dest -PathType Leaf)) { return $false }
  $a = Get-FileHash -LiteralPath $Src -Algorithm SHA256
  $b = Get-FileHash -LiteralPath $Dest -Algorithm SHA256
  return $a.Hash -eq $b.Hash
}

function Test-StillwaterSameTree([string]$Src, [string]$Dest) {
  if (-not (Test-Path -LiteralPath $Src -PathType Container)) { return $false }
  if (-not (Test-Path -LiteralPath $Dest -PathType Container)) { return $false }
  $root = (Resolve-Path -LiteralPath $Src).Path.TrimEnd("\", "/")
  foreach ($file in Get-ChildItem -LiteralPath $Src -Recurse -File) {
    $rel = $file.FullName.Substring($root.Length).TrimStart("\", "/")
    $other = Join-Path $Dest $rel
    if (-not (Test-StillwaterSameFile $file.FullName $other)) { return $false }
  }
  return $true
}

function Get-StillwaterCopyState([string]$Src, [string]$Dest) {
  if (Test-Path -LiteralPath $Src -PathType Container) {
    if (-not (Test-Path -LiteralPath $Dest -PathType Container)) { return "none" }
    if (Test-StillwaterSameTree $Src $Dest) { return "current" }
    return "update"
  }
  if (-not (Test-Path -LiteralPath $Dest -PathType Leaf)) { return "none" }
  if (Test-StillwaterSameFile $Src $Dest) { return "current" }
  return "update"
}

function Merge-StillwaterThemeState([string[]]$States) {
  if (-not $States -or $States.Count -eq 0) { return "none" }
  $anyCurrent = $false
  $anyUpdate = $false
  $anyNone = $false
  foreach ($s in $States) {
    switch ($s) {
      "current" { $anyCurrent = $true }
      "update" { $anyUpdate = $true }
      default { $anyNone = $true }
    }
  }
  if ($anyUpdate) { return "update" }
  if ($anyCurrent -and $anyNone) { return "update" }
  if ($anyCurrent) { return "current" }
  return "none"
}

function Get-StillwaterPayloadState([string[]]$Pairs) {
  if (-not $Pairs -or $Pairs.Count -lt 2) { return "none" }
  $states = @()
  for ($i = 0; $i -lt $Pairs.Count; $i += 2) {
    $states += Get-StillwaterCopyState $Pairs[$i] $Pairs[$i + 1]
  }
  return (Merge-StillwaterThemeState $states)
}

function Get-StillwaterVsCodePayloadState([string]$Src, [string]$Dest) {
  $parent = Split-Path -Parent $Dest
  $keep = Split-Path -Leaf $Dest
  $state = Get-StillwaterPayloadState @(
    (Join-Path $Src "package.json"), (Join-Path $Dest "package.json"),
    (Join-Path $Src "themes"), (Join-Path $Dest "themes")
  )
  if ($state -eq "current") { return @{ Theme = "current"; Note = "" } }
  if ($state -eq "update") {
    return @{
      Theme = "update"
      Note = (Get-StillwaterStatusNote "update" (Get-StillwaterPeekVersion (Join-Path $Dest "package.json")))
    }
  }
  if (Test-Path -LiteralPath $parent -PathType Container) {
    $old = Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like "kayzel.stillwater-theme-*" -and $_.Name -ne $keep } |
      Select-Object -First 1
    if ($old) {
      $oldver = Get-StillwaterPeekVersion (Join-Path $old.FullName "package.json")
      if (-not $oldver) {
        $oldver = $old.Name -replace "^kayzel\.stillwater-theme-", ""
      }
      return @{ Theme = "update"; Note = (Get-StillwaterStatusNote "update" $oldver) }
    }
  }
  return @{ Theme = "none"; Note = "" }
}
