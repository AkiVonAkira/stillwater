# Runs install.ps1 against an empty home, the path Windows users take.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Installer = Join-Path $Root "install.ps1"
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("stillwater-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $Tmp | Out-Null
$env:STILLWATER_HOME = $Tmp
Remove-Item Env:T3CODE_HOME -ErrorAction SilentlyContinue
# Apps on this machine's PATH would count as found.
$env:PATH = "$PSHOME;$env:SystemRoot\System32"

function Fail([string]$Message) {
  Write-Host "FAIL: $Message"
  exit 1
}

function Invoke-Installer {
  $out = & pwsh -NoProfile -File $Installer @args 2>&1 | Out-String
  return [pscustomobject]@{ Code = $LASTEXITCODE; Out = ($out -replace "`e\[[0-9;]*[A-Za-z]", "") }
}

try {
  $version = (Get-Content -Raw (Join-Path $Root "palette.json") | ConvertFrom-Json).version

  $r = Invoke-Installer -List
  if ($r.Code -ne 0) { Fail "-List exited $($r.Code): $($r.Out)" }
  if ($r.Out -notmatch "Stillwater\s+windows\s+$([regex]::Escape($version))") { Fail "-List should show the OS and version" }
  if ($r.Out -notmatch "T3 Code\s+skip") { Fail "an empty home should skip T3 Code" }

  New-Item -ItemType Directory -Force -Path (Join-Path $Tmp ".t3"), (Join-Path $Tmp ".cursor"), (Join-Path $Tmp ".config\yasb") | Out-Null
  Set-Content -LiteralPath (Join-Path $Tmp ".config\yasb\styles.css") -Value @(
    ":root {", "  --background: #ff00ff;", "}", ".bar { color: #cdd6f4; padding: 7px; }"
  )

  $r = Invoke-Installer -DryRun t3
  if ($r.Out -notmatch "Would install T3 Code") { Fail "-DryRun should name the install: $($r.Out)" }
  if (Test-Path (Join-Path $Tmp ".t3\userdata\themes\stillwater.json")) { Fail "-DryRun must not write" }

  $r = Invoke-Installer t3 cursor yasb
  if ($r.Code -ne 0) { Fail "named install exited $($r.Code): $($r.Out)" }
  foreach ($label in "T3 Code", "Cursor", "YASB") {
    if ($r.Out -notmatch "Installed $label\.") { Fail "should install ${label}: $($r.Out)" }
  }
  $theme = Join-Path $Tmp ".t3\userdata\themes\stillwater.json"
  if ((Get-FileHash $theme).Hash -ne (Get-FileHash (Join-Path $Root "t3\stillwater.json")).Hash) { Fail "T3 theme should be copied as is" }
  if (-not (Test-Path (Join-Path $Tmp ".cursor\extensions\kayzel.stillwater-theme-$version\package.json"))) { Fail "Cursor extension missing" }
  $css = Get-Content -Raw (Join-Path $Tmp ".config\yasb\styles.css")
  if ($css -notmatch "--background: #1d2021;") { Fail "YASB should map --background by name" }
  if ($css -notmatch "color: #ebdbb2;") { Fail "YASB should map a known hex literal" }
  if ($css -notmatch "padding: 7px;") { Fail "YASB should keep layout CSS" }

  $r = Invoke-Installer -List
  foreach ($label in "T3 Code", "Cursor", "YASB") {
    if ($r.Out -notmatch "$label\s+found\s+current") { Fail "$label should be current after install" }
  }

  $r = Invoke-Installer bogus
  if ($r.Code -eq 0) { Fail "an unknown adapter should fail" }
  if ($r.Out -notmatch "Unknown adapter: bogus") { Fail "an unknown adapter should be named: $($r.Out)" }

  Write-Host "ok"
} finally {
  Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
