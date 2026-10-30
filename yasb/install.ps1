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

$Id = "yasb"
$Label = "YASB"
$MapFile = Join-Path $Root "yasb\vars.map"
$HexMapFile = Join-Path $Root "yasb\hex.map"
$Seed = Join-Path $Root "yasb\root.css"

function Get-YasbDirs {
  $dirs = @()
  if ($env:YASB_CONFIG_HOME) { $dirs += $env:YASB_CONFIG_HOME }
  $dirs += (Join-Path $env:HOME ".config\yasb")
  $dirs += (Join-Path $env:XDG_CONFIG_HOME "yasb")
  return $dirs
}

function Test-YasbFound {
  if (Test-StillwaterAnyCommand @("yasb", "yasbc")) { return $true }
  return Test-StillwaterAnyDir (Get-YasbDirs)
}

function Get-YasbDest {
  foreach ($dir in Get-YasbDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "styles.css")
    }
  }
  return (Join-Path $env:HOME ".config\yasb\styles.css")
}

function Test-YasbSkipHex([string]$Hex) {
  return $Hex -in @("0078d4", "199143", "ff583b", "1db954", "ffffff", "000000")
}

function Get-YasbHex([string]$Role) {
  $p = Get-StillwaterPalette
  $hex = switch ($Role) {
    "canvas" { $p.canvas }
    "canvasRaised" { $p.canvasRaised }
    "canvasOverlay" { $p.canvasOverlay }
    "border" { $p.border }
    "text" { $p.text }
    "textMuted" { $p.textMuted }
    "warm" { $p.warm }
    "accent" { $p.accent }
    "accentHover" { $p.accentHover }
    "accentDeep" { $p.accentDeep }
    "error" { $p.error }
    "warning" { $p.warning }
    "selection" { $p.selection }
    "function" { $p.syntax.function }
    "parameter" { $p.syntax.parameter }
    "constant" { $p.syntax.constant }
    "keyword" { $p.syntax.keyword }
    default { "" }
  }
  return ([string]$hex).TrimStart("#").ToLowerInvariant()
}

# Status rewrites the whole stylesheet, so both maps resolve to Stillwater hex
# once: variable name to hex, and old hex to hex.
function Initialize-YasbMaps {
  $script:YasbVars = @{}
  foreach ($line in [System.IO.File]::ReadAllLines($MapFile)) {
    if ($line -match '^(\S+)\s+(\S+)$') {
      $hex = Get-YasbHex $Matches[2]
      if ($hex) { $script:YasbVars[$Matches[1]] = $hex }
    }
  }
  $script:YasbHexes = @{}
  foreach ($line in [System.IO.File]::ReadAllLines($HexMapFile)) {
    if ($line -match '^([0-9A-Fa-f]{6})\s+(\S+)$') {
      $old = $Matches[1].ToLowerInvariant()
      if (Test-YasbSkipHex $old) { continue }
      $hex = Get-YasbHex $Matches[2]
      if ($hex) { $script:YasbHexes[$old] = $hex }
    }
  }
}

function Format-YasbValue([string]$Old, [string]$Hex) {
  $r = [Convert]::ToInt32($Hex.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($Hex.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($Hex.Substring(4, 2), 16)
  if ($Old.StartsWith("rgba(")) {
    $alpha = $Old.Substring($Old.LastIndexOf(",") + 1).TrimEnd(")")
    return "rgba($r, $g, $b,$alpha)"
  }
  if ($Old.StartsWith("rgb(")) {
    return "rgb($r, $g, $b)"
  }
  if ($Old -match '^\d+,') {
    return "$r, $g, $b"
  }
  return "#$Hex"
}

$YasbVarRe = [regex]::new('^(?<indent>\s*)--(?<name>[A-Za-z0-9-]+)\s*:\s*(?<value>[^;]+);(?<rest>.*)$')
$YasbRgbRe = [regex]::new('rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,[^)]*)?\)')
$YasbHexRe = [regex]::new('#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})\b')
$YasbRgbEval = [System.Text.RegularExpressions.MatchEvaluator]{
  param($m)
  $hex = "{0:x2}{1:x2}{2:x2}" -f [int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value
  $mapped = $script:YasbHexes[$hex]
  if (-not $mapped) { return $m.Value }
  $nr = [Convert]::ToInt32($mapped.Substring(0, 2), 16)
  $ng = [Convert]::ToInt32($mapped.Substring(2, 2), 16)
  $nb = [Convert]::ToInt32($mapped.Substring(4, 2), 16)
  if ($m.Value.StartsWith("rgba")) {
    return "rgba($nr, $ng, $nb$($m.Groups[4].Value))"
  }
  return "rgb($nr, $ng, $nb)"
}
$YasbHexEval = [System.Text.RegularExpressions.MatchEvaluator]{
  param($m)
  $hex = $m.Groups[1].Value.ToLowerInvariant()
  if ($hex.Length -eq 3) { $hex = "{0}{0}{1}{1}{2}{2}" -f $hex[0], $hex[1], $hex[2] }
  $mapped = $script:YasbHexes[$hex]
  if (-not $mapped) { return $m.Value }
  return "#$mapped"
}

function Rewrite-YasbLine([string]$Line) {
  if ($Line.Contains("--")) {
    $m = $YasbVarRe.Match($Line)
    if ($m.Success) {
      $name = $m.Groups["name"].Value
      $value = $m.Groups["value"].Value.Trim()
      $lookup = $name.ToLowerInvariant()
      $hex = $script:YasbVars[$lookup]
      if (-not $hex -and $lookup.EndsWith("-rgb")) {
        $hex = $script:YasbVars[$lookup.Substring(0, $lookup.Length - 4)]
      }
      if ($hex -and -not $value.StartsWith("var(") -and $value -ne "transparent" -and $value -ne "none") {
        return "{0}--{1}: {2};{3}" -f $m.Groups["indent"].Value, $name, (Format-YasbValue $value $hex), $m.Groups["rest"].Value
      }
    }
  }
  if (-not $Line.Contains("#") -and -not $Line.Contains("rgb")) { return $Line }
  return $YasbHexRe.Replace($YasbRgbRe.Replace($Line, $YasbRgbEval), $YasbHexEval)
}

function Rewrite-YasbFile([string]$Dest) {
  $version = Get-StillwaterVersion
  if ($null -eq $script:YasbVars) { Initialize-YasbMaps }
  $depth = 0
  $stamped = $false
  $out = New-Object System.Collections.Generic.List[string]
  foreach ($raw in [System.IO.File]::ReadAllLines($Dest)) {
    $line = $raw
    if ($line -match '@version') {
      $line = [regex]::Replace($line, '@version\s*[0-9][0-9.]*[0-9]', "@version $version")
      $stamped = $true
    }
    if ($depth -eq 0 -and -not $stamped -and $line.Contains(":root")) {
      $out.Add("/* @version $version */")
      $stamped = $true
    }
    $out.Add((Rewrite-YasbLine $line))
    $depth += $line.Split("{").Count - $line.Split("}").Count
    if ($depth -lt 0) { $depth = 0 }
  }
  return ($out -join "`n") + "`n"
}

function Get-YasbState([string]$Dest) {
  if (-not (Test-Path -LiteralPath $Dest -PathType Leaf)) { return "none" }
  $raw = [System.IO.File]::ReadAllText($Dest)
  if ($raw -notmatch ':root') { return "none" }
  $rewritten = Rewrite-YasbFile $Dest
  $current = $raw
  if (-not $current.EndsWith("`n")) { $current += "`n" }
  $current = $current -replace "`r`n", "`n"
  $rewritten = $rewritten -replace "`r`n", "`n"
  if ($current -eq $rewritten) { return "current" }
  if ($raw -match '@version') { return "update" }
  return "none"
}

function Install-Yasb([string]$Dest) {
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  $parent = Split-Path -Parent $Dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (-not (Test-Path -LiteralPath $Dest -PathType Leaf)) {
    Copy-StillwaterFile $Seed $Dest
    return
  }
  $raw = [System.IO.File]::ReadAllText($Dest)
  if ($raw -notmatch ':root') {
    $seed = [System.IO.File]::ReadAllText($Seed)
    [System.IO.File]::WriteAllText($Dest, $seed + $raw, [System.Text.UTF8Encoding]::new($false))
    return
  }
  [System.IO.File]::WriteAllText($Dest, (Rewrite-YasbFile $Dest), [System.Text.UTF8Encoding]::new($false))
}

switch ($Action) {
  "status" {
    $app = if (Test-YasbFound) { "found" } else { "skip" }
    $dest = Get-YasbDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-YasbState $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-YasbDest
    Install-Yasb $dest
    Write-Output $dest
  }
}
