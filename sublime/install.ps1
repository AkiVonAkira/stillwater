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

$Id = "sublime"
$Label = "Sublime Text"
$Src = Join-Path $Root "sublime\Stillwater.sublime-color-scheme"

function Get-SublimeDirs {
  @(
    (Join-Path $env:APPDATA "Sublime Text"),
    (Join-Path $env:APPDATA "Sublime Text 3"),
    (Join-Path $env:XDG_CONFIG_HOME "sublime-text")
  )
}

function Test-SublimeFound {
  if (Test-StillwaterAnyCommand @("subl", "sublime_text")) { return $true }
  return Test-StillwaterAnyDir (Get-SublimeDirs)
}

function Get-SublimeDest {
  foreach ($dir in Get-SublimeDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      return (Join-Path $dir "Packages\Stillwater\Stillwater.sublime-color-scheme")
    }
  }
  return (Join-Path $env:APPDATA "Sublime Text\Packages\Stillwater\Stillwater.sublime-color-scheme")
}

switch ($Action) {
  "status" {
    $state = if (Test-SublimeFound) { "found" } else { "skip" }
    Write-Output ("{0}|{1}|{2}" -f $Id, $Label, $state)
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-SublimeDest
    Copy-StillwaterFile $Src $dest
    Write-Output $dest
  }
}
