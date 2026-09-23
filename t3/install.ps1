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

$Id = "t3"
$Label = "T3 Code"
$Src = Join-Path $Root "t3\stillwater.json"

function Test-T3Found {
  if (Test-StillwaterCommand "t3") { return $true }
  return Test-StillwaterAnyDir @(
    (Join-Path $env:APPDATA "t3"),
    (Join-Path $env:LOCALAPPDATA "t3"),
    (Join-Path $env:HOME ".t3")
  )
}

switch ($Action) {
  "status" {
    $state = if (Test-T3Found) { "found" } else { "skip" }
    Write-Output ("{0}|{1}|{2}" -f $Id, $Label, $state)
  }
  "owns" {
    if ($Only[0] -eq $Id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    if (Test-StillwaterCommand "t3") {
      if (Invoke-StillwaterCmd @("t3", "theme", "set", "--id", "stillwater", $Src)) {
        Write-Output "t3 theme set --id stillwater"
        break
      }
    }
    Write-Output $Src
  }
}
