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

$Id = "vencord"
$Src = Join-Path $Root "vencord\Stillwater.theme.css"
$ClientNames = @("Vencord", "vesktop", "Vesktop", "equicord", "Equicord", "equibop", "Equibop")

function Get-VencordBases {
  @($env:APPDATA, $env:XDG_CONFIG_HOME)
}

function Get-VencordRoots {
  $roots = @()
  foreach ($base in Get-VencordBases) {
    if (-not $base) { continue }
    foreach ($name in $ClientNames) {
      $roots += (Join-Path $base $name)
    }
  }
  return $roots
}

function Test-VencordClient([string[]]$Names) {
  foreach ($base in Get-VencordBases) {
    if (-not $base) { continue }
    foreach ($name in $Names) {
      if (Test-Path -LiteralPath (Join-Path $base $name) -PathType Container) { return $true }
    }
  }
  return $false
}

function Get-VencordLabel {
  $parts = @("Vencord")
  if (Test-VencordClient @("vesktop", "Vesktop")) { $parts += "Vesktop" }
  if (Test-VencordClient @("equicord", "Equicord")) { $parts += "Equicord" }
  if (Test-VencordClient @("equibop", "Equibop")) { $parts += "Equibop" }
  return ($parts -join " / ")
}

function Test-VencordFound {
  return Test-StillwaterAnyDir (Get-VencordRoots)
}

function Get-VencordDest {
  foreach ($dir in Get-VencordRoots) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "themes\Stillwater.theme.css")
    }
  }
  return (Join-Path $env:APPDATA "Vencord\themes\Stillwater.theme.css")
}

switch ($Action) {
  "status" {
    $app = if (Test-VencordFound) { "found" } else { "skip" }
    $pairs = @()
    $dests = @((Get-VencordDest))
    foreach ($dir in Get-VencordRoots) {
      if (Test-Path -LiteralPath $dir -PathType Container) {
        $dest = Join-Path $dir "themes\Stillwater.theme.css"
        $pairs += $Src
        $pairs += $dest
        $dests += $dest
      }
    }
    $theme = Get-StillwaterPayloadState $pairs
    Write-StillwaterCopyStatus $Id (Get-VencordLabel) $app $theme $dests
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $written = @()
    foreach ($dir in Get-VencordRoots) {
      if (Test-Path -LiteralPath $dir -PathType Container) {
        $dest = Join-Path $dir "themes\Stillwater.theme.css"
        Copy-StillwaterFile $Src $dest
        $written += $dest
      }
    }
    Write-Output ($written -join ", ")
  }
}
