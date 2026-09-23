$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExtId = "kayzel.stillwater-theme-1.0.0"

function Install-VsCodeExt([string]$Dest) {
  $parent = Split-Path -Parent $Dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
  Copy-Item -Recurse -Force (Join-Path $Root "vscode") $Dest
}

function Set-ColorTheme([string]$SettingsPath) {
  $dir = Split-Path -Parent $SettingsPath
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $seed = "{`n  `"workbench.colorTheme`": `"Stillwater`"`n}`n"
  if (-not (Test-Path $SettingsPath)) {
    Set-Content -Encoding utf8 -Path $SettingsPath -Value $seed
    return
  }
  $raw = Get-Content -Raw -Encoding utf8 $SettingsPath
  if ($raw -match 'workbench\.colorTheme') {
    $raw = [regex]::Replace($raw, '"workbench\.colorTheme"\s*:\s*"[^"]*"', '"workbench.colorTheme": "Stillwater"')
  } else {
    $raw = $raw.TrimEnd()
    if ($raw.EndsWith("}")) {
      $raw = $raw.Substring(0, $raw.Length - 1) + "  `"workbench.colorTheme`": `"Stillwater`"`r`n}`r`n"
    }
  }
  [System.IO.File]::WriteAllText($SettingsPath, $raw)
}

$cursorExt = Join-Path $env:USERPROFILE ".cursor\extensions\$ExtId"
Install-VsCodeExt $cursorExt
Write-Host "Cursor extension: $cursorExt"

$vscodeExt = Join-Path $env:USERPROFILE ".vscode\extensions\$ExtId"
Install-VsCodeExt $vscodeExt
Write-Host "VS Code extension: $vscodeExt"

$cursorSettings = Join-Path $env:APPDATA "Cursor\User\settings.json"
Set-ColorTheme $cursorSettings
Write-Host "colorTheme Stillwater -> $cursorSettings"

$vscodeSettings = Join-Path $env:APPDATA "Code\User\settings.json"
Set-ColorTheme $vscodeSettings
Write-Host "colorTheme Stillwater -> $vscodeSettings"

$t3Theme = Join-Path $Root "t3\stillwater.json"
$t3 = Get-Command t3 -ErrorAction SilentlyContinue
if ($t3) {
  & t3 theme set --id stillwater $t3Theme
} else {
  Write-Host "t3 CLI not on PATH. Import $t3Theme in T3 Appearance, or install the T3 CLI and rerun."
}
