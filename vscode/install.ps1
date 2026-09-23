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

$ExtId = "kayzel.stillwater-theme-1.0.0"
$Src = Join-Path $Root "vscode"
$Platform = Get-StillwaterPlatform

$Products = @(
  @{ Id = "cursor"; Label = "Cursor"; Cmd = @("cursor") },
  @{ Id = "vscode"; Label = "Visual Studio Code"; Cmd = @("code") },
  @{ Id = "vscode-insiders"; Label = "VS Code Insiders"; Cmd = @("code-insiders") },
  @{ Id = "vscodium"; Label = "VSCodium"; Cmd = @("codium") },
  @{ Id = "code-oss"; Label = "Code - OSS"; Cmd = @("code-oss") },
  @{ Id = "windsurf"; Label = "Windsurf"; Cmd = @("windsurf") }
)

function Get-DetectDirs([string]$Id) {
  switch ($Id) {
    "cursor" {
      @((Join-Path $env:HOME ".cursor"), (Join-Path $env:APPDATA "Cursor"))
    }
    "vscode" {
      @((Join-Path $env:HOME ".vscode"), (Join-Path $env:APPDATA "Code"))
    }
    "vscode-insiders" {
      @((Join-Path $env:HOME ".vscode-insiders"), (Join-Path $env:APPDATA "Code - Insiders"))
    }
    "vscodium" {
      @((Join-Path $env:HOME ".vscode-oss"), (Join-Path $env:APPDATA "VSCodium"))
    }
    "code-oss" {
      @(Join-Path $env:APPDATA "Code - OSS")
    }
    "windsurf" {
      @((Join-Path $env:HOME ".windsurf"), (Join-Path $env:APPDATA "Windsurf"))
    }
  }
}

function Get-ExtDir([string]$Id) {
  switch ($Id) {
    "cursor" { Join-Path $env:HOME ".cursor\extensions\$ExtId" }
    "vscode" { Join-Path $env:HOME ".vscode\extensions\$ExtId" }
    "vscode-insiders" { Join-Path $env:HOME ".vscode-insiders\extensions\$ExtId" }
    "vscodium" { Join-Path $env:HOME ".vscode-oss\extensions\$ExtId" }
    "code-oss" { Join-Path $env:HOME ".vscode-oss\extensions\$ExtId" }
    "windsurf" { Join-Path $env:HOME ".windsurf\extensions\$ExtId" }
  }
}

function Get-SettingsPath([string]$Id) {
  switch ($Id) {
    "cursor" { Join-Path $env:APPDATA "Cursor\User\settings.json" }
    "vscode" { Join-Path $env:APPDATA "Code\User\settings.json" }
    "vscode-insiders" { Join-Path $env:APPDATA "Code - Insiders\User\settings.json" }
    "vscodium" { Join-Path $env:APPDATA "VSCodium\User\settings.json" }
    "code-oss" { Join-Path $env:APPDATA "Code - OSS\User\settings.json" }
    "windsurf" { Join-Path $env:APPDATA "Windsurf\User\settings.json" }
  }
}

function Test-ProductFound($Product) {
  if (Test-StillwaterAnyDir (Get-DetectDirs $Product.Id)) { return $true }
  if (Test-StillwaterAnyCommand $Product.Cmd) { return $true }
  return $false
}

switch ($Action) {
  "status" {
    foreach ($product in $Products) {
      $state = if (Test-ProductFound $product) { "found" } else { "skip" }
      Write-Output ("{0}|{1}|{2}" -f $product.Id, $product.Label, $state)
    }
  }
  "owns" {
    $id = $Only[0]
    if ($Products.Id -contains $id) { Write-Output "yes" } else { Write-Output "no" }
  }
  "install" {
    $id = $Only[0]
    $dest = Get-ExtDir $id
    Copy-StillwaterFile (Join-Path $Src "package.json") (Join-Path $dest "package.json")
    Copy-StillwaterTree (Join-Path $Src "themes") (Join-Path $dest "themes")
    Set-StillwaterVsCodeTheme (Get-SettingsPath $id)
    Write-Output $dest
  }
}
