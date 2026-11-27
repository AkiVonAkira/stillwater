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

  $rollback = Join-Path $Tmp ".t3\userdata\themes\stillwater-observatory.json"
  New-Item -ItemType Directory -Force -Path (Split-Path $rollback) | Out-Null
  Set-Content -NoNewline -Path $rollback -Value "rollback"
  $r = Invoke-Installer t3 cursor yasb
  if ($r.Code -ne 0) { Fail "named install exited $($r.Code): $($r.Out)" }
  foreach ($label in "T3 Code", "Cursor", "YASB") {
    if ($r.Out -notmatch "Installed $label\.") { Fail "should install ${label}: $($r.Out)" }
  }
  $theme = Join-Path $Tmp ".t3\userdata\themes\stillwater.json"
  if ((Get-FileHash $theme).Hash -ne (Get-FileHash (Join-Path $Root "t3\stillwater.json")).Hash) { Fail "T3 theme should be copied as is" }
  if ((Get-Content -Raw $theme) -notmatch "--stillwater-canvas") { Fail "T3 theme should carry the palette CSS" }
  if ((Get-Content -Raw $rollback) -ne "rollback") { Fail "T3 install should leave the rollback theme alone" }
  if (-not (Test-Path (Join-Path $Tmp ".cursor\extensions\kayzel.stillwater-theme-$version\package.json"))) { Fail "Cursor extension missing" }
  $css = Get-Content -Raw (Join-Path $Tmp ".config\yasb\styles.css")
  if ($css -notmatch "--background: #1d2021;") { Fail "YASB should map --background by name" }
  if ($css -notmatch "color: #ebdbb2;") { Fail "YASB should map a known hex literal" }
  if ($css -notmatch "padding: 7px;") { Fail "YASB should keep layout CSS" }

  $r = Invoke-Installer -List
  foreach ($label in "T3 Code", "Cursor", "YASB") {
    if ($r.Out -notmatch "$label\s+found\s+current") { Fail "$label should be current after install" }
  }

  # A release that only bumps the version stamp leaves installed copies current.
  $yasbCss = Join-Path $Tmp ".config\yasb\styles.css"
  [IO.File]::WriteAllText($yasbCss, ([IO.File]::ReadAllText($yasbCss) -replace "@version $([regex]::Escape($version))", "@version 0.9.0"))
  $cursorExt = Join-Path $Tmp ".cursor\extensions\kayzel.stillwater-theme-$version"
  $oldExt = Join-Path $Tmp ".cursor\extensions\kayzel.stillwater-theme-0.9.0"
  Move-Item -LiteralPath $cursorExt -Destination $oldExt
  $pkg = Join-Path $oldExt "package.json"
  [IO.File]::WriteAllText($pkg, ([IO.File]::ReadAllText($pkg) -replace """version"": ""$([regex]::Escape($version))""", '"version": "0.9.0"'))
  $r = Invoke-Installer -List
  foreach ($label in "Cursor", "YASB") {
    if ($r.Out -notmatch "$label\s+found\s+current") { Fail "$label should stay current when only its version stamp is older: $($r.Out)" }
  }
  Add-Content -LiteralPath $pkg -Value " "
  $r = Invoke-Installer -List
  if ($r.Out -notmatch "Cursor\s+found\s+update\s+0\.9\.0 to $([regex]::Escape($version))") { Fail "an older Cursor install with other changes should show the version update: $($r.Out)" }

  # Ryoku's Ghostty config loads user.conf last, so Stillwater goes there, once.
  $ghostty = Join-Path $Tmp ".config\ghostty"
  New-Item -ItemType Directory -Force -Path $ghostty | Out-Null
  [IO.File]::WriteAllText((Join-Path $ghostty "config"), "config-file = ryoku-colors`nconfig-file = ?user.conf`n")
  [IO.File]::WriteAllText((Join-Path $ghostty "user.conf"), "keybind = ctrl+v=paste_from_clipboard")
  $null = Invoke-Installer ghostty
  $r = Invoke-Installer ghostty
  if ($r.Code -ne 0) { Fail "Ghostty install exited $($r.Code): $($r.Out)" }
  $user = [IO.File]::ReadAllText((Join-Path $ghostty "user.conf"))
  if (([regex]::Matches($user, '(?m)^config-file = themes/Stillwater$')).Count -ne 1) { Fail "Ryoku Ghostty should load Stillwater once from user.conf: $user" }
  if ($user -notmatch '(?m)^keybind = ctrl\+v=paste_from_clipboard\r?$') { Fail "Ryoku Ghostty should keep the user's lines" }
  if ([IO.File]::ReadAllText((Join-Path $ghostty "config")) -match 'Stillwater') { Fail "Ryoku Ghostty should leave config to Ryoku" }

  # Rex keeps its palette keys in config.ini's global section, before the first [section].
  $rex = Join-Path $Tmp "AppData\Local\Superlogical\Rex"
  New-Item -ItemType Directory -Force -Path $rex | Out-Null
  $rexConf = Join-Path $rex "config.ini"
  [IO.File]::WriteAllText($rexConf, "# Rex config`n# use_system_accent_color  = true`n# dark_theme_color_palette  = default_dark`n[server]`ntailscale_enabled = true`n")
  $r = Invoke-Installer rex
  if ($r.Out -notmatch "Installed Rex\.") { Fail "should install Rex: $($r.Out)" }
  $null = Invoke-Installer rex
  if ((Get-Content -Raw (Join-Path $rex "palettes\stillwater.ini")) -notmatch "#5aa8b4") { Fail "Rex palette should map Stillwater accent" }
  $lines = [IO.File]::ReadAllLines($rexConf)
  if (@($lines | Where-Object { $_ -eq "dark_theme_color_palette = stillwater" }).Count -ne 1) { Fail "Rex should select Stillwater once: $($lines -join '|')" }
  if ($lines -notcontains "use_system_accent_color = false") { Fail "Rex should turn off the Windows accent" }
  if ($lines[3] -ne "[server]" -or $lines -notcontains "tailscale_enabled = true") { Fail "Rex should keep its sections and the user's settings: $($lines -join '|')" }
  [IO.File]::WriteAllText($rexConf, "[server]`ntailscale_enabled = true`n")
  $null = Invoke-Installer rex
  if ([IO.File]::ReadAllLines($rexConf)[0] -ne "dark_theme_color_palette = stillwater") { Fail "Rex should add missing keys before the first section" }

  $r = Invoke-Installer bogus
  if ($r.Code -eq 0) { Fail "an unknown adapter should fail" }
  if ($r.Out -notmatch "Unknown adapter: bogus") { Fail "an unknown adapter should be named: $($r.Out)" }

  Write-Host "ok"
} finally {
  Remove-Item -LiteralPath $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
