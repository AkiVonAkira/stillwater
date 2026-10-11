param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("status", "owns", "install")]
  [string]$Action,
  [string[]]$Only = @(),
  [string]$Base = ""
)

$Root = $env:STILLWATER_ROOT
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
. (Join-Path $Root "install\lib.ps1")
Initialize-StillwaterPaths

$Bases = "base=Base,midnight=Midnight,system24=system24,oldcord=OldCord,surcord=surCord"
$DefaultBase = "midnight"

function Get-VencordSrc([string]$Key) {
  return (Join-Path $Root "vencord\$Key\Stillwater.theme.css")
}

# Installs from before base themes carry no stamp, and they were Midnight.
function Get-VencordInstalledBase([string[]]$Dests) {
  foreach ($dest in $Dests) {
    if (Test-Path -LiteralPath $dest -PathType Leaf) {
      $stamp = Get-StillwaterPeekBase $dest
      if ($stamp) { return $stamp }
      return "midnight"
    }
  }
  return $DefaultBase
}

$Products = @(
  @{
    Id = "vencord"
    SkipLabel = "Vencord"
    SkipName = "Vencord"
    Names = @("Vencord", "vesktop", "Vesktop")
    ModNames = @("Vencord")
    AppNames = @("vesktop", "Vesktop")
    AppLabel = "Vesktop"
  },
  @{
    Id = "equicord"
    SkipLabel = "Equicord"
    SkipName = "Equicord"
    Names = @("equicord", "Equicord", "equibop", "Equibop")
    ModNames = @("equicord", "Equicord")
    AppNames = @("equibop", "Equibop")
    AppLabel = "Equibop"
  }
)

function Get-VencordBases {
  switch (Get-StillwaterPlatform) {
    "windows" { @($env:APPDATA) }
    "darwin" {
      $support = Join-Path $env:HOME "Library\Application Support"
      @($support, $env:XDG_CONFIG_HOME)
    }
    default { @($env:XDG_CONFIG_HOME) }
  }
}

function Get-ProductRoots($Product) {
  $roots = @()
  foreach ($base in Get-VencordBases) {
    if (-not $base) { continue }
    foreach ($name in $Product.Names) {
      $roots += (Join-Path $base $name)
    }
  }
  return $roots
}

function Test-ClientLive([string]$Dir) {
  if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
  if (Test-Path -LiteralPath (Join-Path $Dir "settings.json") -PathType Leaf) { return $true }
  if (Test-Path -LiteralPath (Join-Path $Dir "settings") -PathType Container) { return $true }
  if (Test-Path -LiteralPath (Join-Path $Dir "sessionData") -PathType Container) { return $true }
  return $false
}

function Test-ProductClient($Product, [string[]]$Names) {
  foreach ($base in Get-VencordBases) {
    if (-not $base) { continue }
    foreach ($name in $Names) {
      if (Test-ClientLive (Join-Path $base $name)) { return $true }
    }
  }
  return $false
}

function Get-ProductLabel($Product) {
  $parts = @()
  if (Test-ProductClient $Product $Product.ModNames) { $parts += $Product.SkipLabel }
  if (Test-ProductClient $Product $Product.AppNames) { $parts += $Product.AppLabel }
  if ($parts.Count -eq 0) { return $Product.SkipLabel }
  return ($parts -join " / ")
}

function Get-ProductDest($Product) {
  foreach ($dir in Get-ProductRoots $Product) {
    if (Test-ClientLive $dir) {
      return (Join-Path $dir "themes\Stillwater.theme.css")
    }
  }
  return (Join-Path $env:APPDATA "$($Product.SkipName)\themes\Stillwater.theme.css")
}

switch ($Action) {
  "status" {
    foreach ($product in $Products) {
      $roots = @(Get-ProductRoots $product)
      $app = "skip"
      $lives = @()
      foreach ($dir in $roots) {
        if (Test-ClientLive $dir) {
          $app = "found"
          $lives += (Join-Path $dir "themes\Stillwater.theme.css")
        }
      }
      $base = Get-VencordInstalledBase $lives
      $src = Get-VencordSrc $base
      $pairs = @()
      $dests = @((Get-ProductDest $product))
      foreach ($dest in $lives) {
        $pairs += $src
        $pairs += $dest
        $dests += $dest
      }
      $theme = Get-StillwaterPayloadState $pairs
      Write-StillwaterCopyStatus $product.Id (Get-ProductLabel $product) $app $theme $dests -Bases $Bases -Base $base
    }
  }
  "owns" {
    if ($Only[0] -in @("vencord", "equicord")) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $id = $Only[0]
    $product = $Products | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if (-not $Base) { $Base = $DefaultBase }
    if (-not (Test-StillwaterBaseValid $Bases $Base)) { throw "Unknown base: $Base" }
    $src = Get-VencordSrc $Base
    $written = @()
    foreach ($dir in Get-ProductRoots $product) {
      if (Test-ClientLive $dir) {
        $dest = Join-Path $dir "themes\Stillwater.theme.css"
        Copy-StillwaterFile $src $dest
        $written += $dest
      }
    }
    Write-Output ($written -join ", ")
  }
}
