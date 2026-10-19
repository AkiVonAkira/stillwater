# Stillwater. kayzel.

# New terminal as administrator, in this folder.
function admin {
  $dir = (Get-Location).ProviderPath
  if (Get-Command wt -ErrorAction SilentlyContinue) {
    Start-Process wt -Verb RunAs -ArgumentList "-d `"$dir`""
  } else {
    Start-Process pwsh -Verb RunAs -ArgumentList "-NoExit -WorkingDirectory `"$dir`""
  }
}

# Update T3: stop the server on 3773 and the "T3 Code server" task's loop
# restarts it on the latest nightly.
function t3up {
  $listen = Get-NetTCPConnection -LocalPort 3773 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $listen) {
    Write-Host "Nothing is listening on 3773."
    return
  }
  $old = $listen.OwningProcess
  Stop-Process -Id $old -Force
  Write-Host "Stopped T3 server ($old). Waiting for the restart..."
  $deadline = (Get-Date).AddMinutes(3)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    $new = Get-NetTCPConnection -LocalPort 3773 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($new -and $new.OwningProcess -ne $old) {
      Write-Host "T3 server is back ($($new.OwningProcess))."
      return
    }
  }
  Write-Host "T3 server did not come back on 3773 within 3 minutes."
}
if ($Host.Name -ne "ConsoleHost") { return }
try {
  if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return }
} catch { }

if (-not $env:STILLWATER_FETCHED -and -not ($env:CURSOR_AGENT -or $env:CLAUDECODE -or $env:CODEX_SANDBOX)) {
  $env:STILLWATER_FETCHED = "1"
  $extra = [Environment]::GetCommandLineArgs() | Select-Object -Skip 1
  $scripted = $extra | Where-Object {
    $_ -like '*.ps1' -or $_ -match '^(?i)-+(f|c|file|command|encodedcommand)$'
  }
  if (-not $scripted) {
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
      # Clear the "PowerShell 7.x" banner hosts print without -NoLogo.
      Clear-Host
      fastfetch
    } elseif (Get-Command neofetch -ErrorAction SilentlyContinue) {
      neofetch
    }
  }
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (& starship init powershell)
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& { zoxide init powershell | Out-String })
}
if (Get-Module PSReadLine) {
  Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView -BellStyle None
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}
