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

function Get-YasbRoleMap {
  $map = @{}
  foreach ($line in Get-Content -LiteralPath $MapFile) {
    if ($line -match '^(\S+)\s+(\S+)$') {
      $map[$Matches[1]] = $Matches[2]
    }
  }
  return $map
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

function Rewrite-YasbLine([string]$Line, $RoleMap) {
  if ($Line -notmatch '^(?<indent>\s*)--(?<name>[A-Za-z0-9-]+)\s*:\s*(?<value>[^;]+);(?<rest>.*)$') {
    return $Line
  }
  $name = $Matches.name
  $value = $Matches.value.Trim()
  $lookup = $name.ToLowerInvariant()
  $role = $RoleMap[$lookup]
  if (-not $role -and $lookup.EndsWith("-rgb")) {
    $role = $RoleMap[$lookup.Substring(0, $lookup.Length - 4)]
  }
  if (-not $role -or $value.StartsWith("var(") -or $value -eq "transparent" -or $value -eq "none") {
    return $Line
  }
  $hex = Get-YasbHex $role
  if (-not $hex) { return $Line }
  return "{0}--{1}: {2};{3}" -f $Matches.indent, $name, (Format-YasbValue $value $hex), $Matches.rest
}

function Rewrite-YasbFile([string]$Dest) {
  $version = Get-StillwaterVersion
  $roleMap = Get-YasbRoleMap
  $depth = 0
  $inRoot = $false
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
    $was = $depth
    $opens = ([regex]::Matches($line, '\{')).Count
    $closes = ([regex]::Matches($line, '\}')).Count
    if ($line.Contains(":root")) { $inRoot = $true }
    if ($inRoot) {
      $out.Add((Rewrite-YasbLine $line $roleMap))
    } else {
      $out.Add($line)
    }
    $depth = $was + $opens - $closes
    if ($depth -lt 0) { $depth = 0 }
    if ($inRoot -and $depth -eq 0) { $inRoot = $false }
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
