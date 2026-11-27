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

$Id = "rex"
$Label = "Rex"
$Src = Join-Path $Root "rex\stillwater.ini"
$Dir = Join-Path $env:LOCALAPPDATA "Superlogical\Rex"

function Get-RexDest {
  Join-Path $Dir "palettes\stillwater.ini"
}

# Rex reads palettes from the palettes folder next to config.ini, by file name. Its config.ini
# has a global section first, so the two keys go there, never after a [section] line. Without
# use_system_accent_color = false the Windows accent replaces Stillwater's.
function Set-RexPalette {
  $conf = Join-Path $Dir "config.ini"
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  if (-not (Test-Path -LiteralPath $conf -PathType Leaf)) { return }
  $want = [ordered]@{ "dark_theme_color_palette" = "stillwater"; "use_system_accent_color" = "false" }
  $lines = [System.Collections.Generic.List[string]]::new([System.IO.File]::ReadAllLines($conf))
  $section = $lines.Count
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\[') { $section = $i; break }
  }
  $done = @{}
  for ($i = 0; $i -lt $section; $i++) {
    foreach ($key in $want.Keys) {
      if (-not $done[$key] -and $lines[$i] -match "^\s*#?\s*$key\s*=") {
        $lines[$i] = "$key = $($want[$key])"
        $done[$key] = $true
      }
    }
  }
  foreach ($key in $want.Keys) {
    if (-not $done[$key]) {
      $lines.Insert($section, "$key = $($want[$key])")
      $section++
    }
  }
  [System.IO.File]::WriteAllLines($conf, $lines)
}

switch ($Action) {
  "status" {
    $app = if (Test-Path -LiteralPath $Dir -PathType Container) { "found" } else { "skip" }
    $dest = Get-RexDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-RexDest
    Copy-StillwaterFile $Src $dest
    Set-RexPalette
    Write-Output $dest
  }
}
