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

$Src = Join-Path $Root "vencord\Stillwater.theme.css"

$Products = @(
  @{ Id = "vencord"; Label = "Vencord / Vesktop"; Names = @("Vencord", "vesktop", "Vesktop") },
  @{ Id = "equicord"; Label = "Equicord / Equibop"; Names = @("equicord", "Equicord", "equibop", "Equibop") }
)

function Get-ProductRoots($Product) {
  $roots = @()
  foreach ($name in $Product.Names) {
    $roots += (Join-Path $env:APPDATA $name)
    $roots += (Join-Path $env:XDG_CONFIG_HOME $name)
  }
  return $roots
}

function Get-ProductDest($Product) {
  foreach ($dir in Get-ProductRoots $Product) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "themes\Stillwater.theme.css")
    }
  }
  $fallback = if ($Product.Id -eq "equicord") { "equibop" } else { "vesktop" }
  return (Join-Path $env:APPDATA "$fallback\themes\Stillwater.theme.css")
}

switch ($Action) {
  "status" {
    foreach ($product in $Products) {
      $roots = @(Get-ProductRoots $product)
      $app = if (Test-StillwaterAnyDir $roots) { "found" } else { "skip" }
      $pairs = @()
      $dests = @((Get-ProductDest $product))
      foreach ($dir in $roots) {
        if (Test-Path -LiteralPath $dir -PathType Container) {
          $dest = Join-Path $dir "themes\Stillwater.theme.css"
          $pairs += $Src
          $pairs += $dest
          $dests += $dest
        }
      }
      $theme = Get-StillwaterPayloadState $pairs
      Write-StillwaterCopyStatus $product.Id $product.Label $app $theme $dests
    }
  }
  "owns" {
    if ($Only[0] -in @("vencord", "equicord")) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $id = $Only[0]
    $product = $Products | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    $written = @()
    foreach ($dir in Get-ProductRoots $product) {
      if (Test-Path -LiteralPath $dir -PathType Container) {
        $dest = Join-Path $dir "themes\Stillwater.theme.css"
        Copy-StillwaterFile $Src $dest
        $written += $dest
      }
    }
    Write-Output ($written -join ", ")
  }
}
