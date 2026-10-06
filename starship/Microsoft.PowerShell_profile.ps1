# Stillwater. kayzel.
if ($Host.Name -ne "ConsoleHost") { return }
try {
  if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return }
} catch { }

if (Get-Command neofetch -ErrorAction SilentlyContinue) {
  neofetch
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
