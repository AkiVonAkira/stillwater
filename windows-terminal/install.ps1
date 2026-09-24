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

$Id = "windows-terminal"
$Label = "Windows Terminal"
$Src = Join-Path $Root "windows-terminal\stillwater.json"

function Get-WindowsTerminalDirs {
  @(
    (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal Preview")
  )
}

function Test-WindowsTerminalFound {
  if (Test-StillwaterAnyCommand @("wt", "windowsterminal", "windows-terminal")) { return $true }
  return Test-StillwaterAnyDir (Get-WindowsTerminalDirs)
}

function Get-WindowsTerminalDest {
  foreach ($dir in Get-WindowsTerminalDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "Fragments\Stillwater\stillwater.json")
    }
  }
  return (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\Fragments\Stillwater\stillwater.json")
}

switch ($Action) {
  "status" {
    $app = if (Test-WindowsTerminalFound) { "found" } else { "skip" }
    $dest = Get-WindowsTerminalDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-WindowsTerminalDest
    Copy-StillwaterFile $Src $dest
    Write-Output $dest
  }
}
