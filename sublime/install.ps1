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
    $app = if (Test-SublimeFound) { "found" } else { "skip" }
    $dest = Get-SublimeDest
    Write-StillwaterCopyStatus $Id $Label $app (Get-StillwaterCopyState $Src $dest) $dest
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $dest = Get-SublimeDest
    Copy-StillwaterFile $Src $dest
    if ($env:STILLWATER_DRY_RUN -ne "1") {
      $prefs = Join-Path (Split-Path (Split-Path $dest -Parent) -Parent) "User\Preferences.sublime-settings"
      if ((Test-Path -LiteralPath $prefs) -and (Select-String -LiteralPath $prefs -Pattern '"color_scheme"' -Quiet)) {
        $raw = [System.IO.File]::ReadAllText($prefs)
        $raw = [regex]::Replace($raw, '"color_scheme"\s*:\s*"[^"]*"', '"color_scheme": "Packages/Stillwater/Stillwater.sublime-color-scheme"')
        [System.IO.File]::WriteAllText($prefs, $raw)
      }
    }
    Write-Output $dest
  }
}
