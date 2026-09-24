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

$Id = "kitty"
$Label = "Kitty"
$Src = Join-Path $Root "kitty\Stillwater.conf"

function Get-KittyDirs {
  @((Join-Path $env:XDG_CONFIG_HOME "kitty"), (Join-Path $env:APPDATA "kitty"))
}

function Test-KittyFound {
  if (Test-StillwaterCommand "kitty") { return $true }
  return Test-StillwaterAnyDir (Get-KittyDirs)
}

function Get-KittyDir {
  foreach ($dir in Get-KittyDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) { return $dir }
  }
  return (Join-Path $env:APPDATA "kitty")
}

function Get-KittyDest {
  Join-Path (Get-KittyDir) "themes\Stillwater.conf"
}

function Set-KittyTheme {
  $dir = Get-KittyDir
  if ($env:STILLWATER_DRY_RUN -eq "1") { return }
  $conf = Join-Path $dir "kitty.conf"
  $current = Join-Path $dir "current-theme.conf"
  $hasCurrent = (Test-Path -LiteralPath $current -PathType Leaf) -or (
    (Test-Path -LiteralPath $conf -PathType Leaf) -and (Select-String -LiteralPath $conf -Pattern "current-theme.conf" -Quiet)
  )
  if ($hasCurrent) {
    Copy-StillwaterFile $Src $current
    return
  }
  if ((Test-Path -LiteralPath $conf -PathType Leaf) -and -not (Select-String -LiteralPath $conf -Pattern "themes/Stillwater.conf" -Quiet)) {
    Add-Content -LiteralPath $conf -Value "`ninclude themes/Stillwater.conf`n"
  }
}

switch ($Action) {
  "status" {
    $app = if (Test-KittyFound) { "found" } else { "skip" }
    $dest = Get-KittyDest
    $dir = Get-KittyDir
    $pairs = @($Src, $dest)
    $dests = @($dest)
    $current = Join-Path $dir "current-theme.conf"
    if ((Test-Path -LiteralPath $dest -PathType Leaf) -and (Test-Path -LiteralPath $current -PathType Leaf)) {
      $pairs += $Src
      $pairs += $current
      $dests += $current
    }
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterPayloadState $pairs) $dests
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-KittyDest
    Copy-StillwaterFile $Src $dest
    Set-KittyTheme
    Write-Output $dest
  }
}
