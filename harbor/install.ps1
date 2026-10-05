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

$Id = "harbor"
$Label = "Harbor"
$Src = Join-Path $Root "harbor\Stillwater.harborstyle"

function Get-HarborDataDirs {
  @(
    (Join-Path $env:XDG_DATA_HOME "app.harbor"),
    (Join-Path $env:HOME ".var\app\site.harbor.Harbor\data\app.harbor"),
    (Join-Path $env:HOME "Library\Application Support\app.harbor"),
    (Join-Path $env:APPDATA "app.harbor")
  )
}

function Get-HarborInstallDirs {
  @(
    (Join-Path $env:LOCALAPPDATA "Harbor"),
    "/Applications/Harbor.app",
    (Join-Path $env:HOME "Applications\Harbor.app"),
    (Join-Path $env:HOME ".var\app\site.harbor.Harbor")
  )
}

function Test-HarborFound {
  if (Test-StillwaterCommand "harbor") { return $true }
  if (Test-StillwaterAnyDir (Get-HarborDataDirs)) { return $true }
  return (Test-StillwaterAnyDir (Get-HarborInstallDirs))
}

function Get-HarborDest {
  foreach ($dir in Get-HarborDataDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "themes\Stillwater.harborstyle")
    }
  }
  switch (Get-StillwaterPlatform) {
    "windows" { return (Join-Path $env:APPDATA "app.harbor\themes\Stillwater.harborstyle") }
    "darwin" { return (Join-Path $env:HOME "Library\Application Support\app.harbor\themes\Stillwater.harborstyle") }
    default { return (Join-Path $env:XDG_DATA_HOME "app.harbor\themes\Stillwater.harborstyle") }
  }
}

switch ($Action) {
  "status" {
    $app = if (Test-HarborFound) { "found" } else { "skip" }
    $dest = Get-HarborDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-HarborDest
    Copy-StillwaterFile $Src $dest
    Write-Output $dest
  }
}
