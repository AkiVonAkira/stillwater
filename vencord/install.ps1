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
$Label = "Vencord / Vesktop"
$Src = Join-Path $Root "vencord\Stillwater.theme.css"

function Get-VencordRoots {
  @(
    (Join-Path $env:APPDATA "Vencord"),
    (Join-Path $env:APPDATA "vesktop"),
    (Join-Path $env:APPDATA "Vesktop"),
    (Join-Path $env:APPDATA "equicord"),
    (Join-Path $env:APPDATA "Equicord"),
    (Join-Path $env:XDG_CONFIG_HOME "Vencord"),
    (Join-Path $env:XDG_CONFIG_HOME "vesktop"),
    (Join-Path $env:XDG_CONFIG_HOME "Vesktop"),
    (Join-Path $env:XDG_CONFIG_HOME "equicord"),
    (Join-Path $env:XDG_CONFIG_HOME "Equicord")
  )
}

function Test-VencordFound {
  return Test-StillwaterAnyDir (Get-VencordRoots)
}

switch ($Action) {
  "status" {
    $app = if (Test-VencordFound) { "found" } else { "skip" }
    $pairs = @()
    $dests = @()
    foreach ($dir in Get-VencordRoots) {
      if (Test-Path -LiteralPath $dir -PathType Container) {
        $dest = Join-Path $dir "themes\Stillwater.theme.css"
        $pairs += $Src
        $pairs += $dest
        $dests += $dest
      }
    }
    $theme = Get-StillwaterPayloadState $pairs
    Write-StillwaterCopyStatus $Id $Label $app $theme $dests
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
