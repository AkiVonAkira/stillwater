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

$Id = "neovim"
$Label = "Neovim"

function Get-NvimDirs {
  @(
    (Join-Path $env:XDG_CONFIG_HOME "nvim"),
    (Join-Path $env:LOCALAPPDATA "nvim"),
    (Join-Path $env:LOCALAPPDATA "nvim-data")
  )
}

function Test-NvimFound {
  if (Test-StillwaterCommand "nvim") { return $true }
  return Test-StillwaterAnyDir (Get-NvimDirs)
}

function Get-NvimPluginDest {
  Join-Path $env:LOCALAPPDATA "nvim-data\site\pack\kayzel\start\stillwater"
}

switch ($Action) {
  "status" {
    $state = if (Test-NvimFound) { "found" } else { "skip" }
    Write-Output ("{0}|{1}|{2}" -f $Id, $Label, $state)
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-NvimPluginDest
    Copy-StillwaterFile (Join-Path $Root "neovim\colors\stillwater.lua") (Join-Path $dest "colors\stillwater.lua")
    Copy-StillwaterFile (Join-Path $Root "neovim\lua\stillwater\init.lua") (Join-Path $dest "lua\stillwater\init.lua")
    Write-Output $dest
  }
}
