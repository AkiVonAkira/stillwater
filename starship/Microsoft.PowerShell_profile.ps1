# Stillwater. kayzel.
if ($Host.Name -ne "ConsoleHost") { return }
try {
  if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return }
} catch { }

if ($env:WT_SESSION -and -not $env:CURSOR_AGENT -and -not $env:STILLWATER_FETCHED) {
  $env:STILLWATER_FETCHED = "1"
  $extra = [Environment]::GetCommandLineArgs() | Select-Object -Skip 1
  $scripted = $extra | Where-Object {
    $_ -like '*.ps1' -or $_ -match '^(?i)-+(f|c|file|command|encodedcommand)$'
  }
  if (-not $scripted -and (Get-Command neofetch -ErrorAction SilentlyContinue)) {
    neofetch
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
