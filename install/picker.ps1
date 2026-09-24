function Enable-StillwaterVirtualTerminal {
  try {
    if (-not ("StillwaterConsole" -as [type])) {
      Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class StillwaterConsole {
  [DllImport("kernel32.dll", SetLastError = true)]
  public static extern IntPtr GetStdHandle(int nStdHandle);
  [DllImport("kernel32.dll")]
  public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
  [DllImport("kernel32.dll")]
  public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
}
"@
    }
    $handle = [StillwaterConsole]::GetStdHandle(-11)
    [uint32]$mode = 0
    if ([StillwaterConsole]::GetConsoleMode($handle, [ref]$mode)) {
      [void][StillwaterConsole]::SetConsoleMode($handle, ($mode -bor 4))
    }
  } catch { }
}

function Get-StillwaterPickerStyle {
  $style = Get-StillwaterThemeAnsi
  if ($env:NO_COLOR) { $style.Clear = "" }
  return $style
}

function Test-StillwaterPickerSelectable([string]$App) {
  return $App -eq "found"
}

function Get-StillwaterPickerAction([string]$App, [string]$Theme) {
  switch ($App) {
    "skip" { return "Not found" }
    "n/a" { return "Linux only" }
    default {
      switch ($Theme) {
        "none" { return "Install" }
        "current" { return "Up to date" }
        "update" { return "Update" }
        default { return $Theme }
      }
    }
  }
}

function Get-StillwaterPickerSummaryName([string]$Label, [string]$Theme) {
  switch ($Theme) {
    "none" { return ("{0} to install" -f $Label) }
    "update" { return ("{0} to update" -f $Label) }
    "current" { return ("{0}, already current" -f $Label) }
    default { return $Label }
  }
}

function Get-StillwaterPickerActionColor($Style, [string]$App, [string]$Theme) {
  if (-not (Test-StillwaterPickerSelectable $App)) { return $Style.Muted }
  switch ($Theme) {
    "none" { return $Style.Accent }
    "current" { return $Style.AccentDeep }
    "update" { return $Style.Warn }
    default { return $Style.Text }
  }
}

function ConvertTo-StillwaterPickerItems([string[]]$Rows) {
  $items = @()
  foreach ($row in $Rows) {
    if (-not $row) { continue }
    $parts = $row.Split("|")
    $id = $parts[0]
    $label = $parts[1]
    $app = $parts[2]
    $theme = if ($parts.Count -gt 3) { $parts[3] } else { "none" }
    $note = if ($parts.Count -gt 4) { $parts[4] } else { "" }
    $dest = if ($parts.Count -gt 5) { $parts[5] } else { "" }
    $selected = (Test-StillwaterPickerSelectable $app) -and ($theme -ne "current")
    $items += [pscustomobject]@{
      Id = $id
      Label = $label
      App = $app
      Theme = $theme
      Note = $note
      Dest = $dest
      Selected = $selected
    }
  }
  return @($items)
}

function Get-StillwaterPickerCursor($Items) {
  for ($i = 0; $i -lt $Items.Count; $i++) {
    if (Test-StillwaterPickerSelectable $Items[$i].App) { return $i }
  }
  return 0
}

function Move-StillwaterPickerCursor($Items, [int]$Cursor, [int]$Dir) {
  $n = $Items.Count
  if ($n -le 0) { return $Cursor }
  $i = $Cursor
  $start = $Cursor
  while ($true) {
    $i = (($i + $Dir) % $n + $n) % $n
    if (Test-StillwaterPickerSelectable $Items[$i].App) { return $i }
    if ($i -eq $start) { return $Cursor }
  }
}

function Set-StillwaterPickerAll($Items) {
  $on = $true
  foreach ($item in $Items) {
    if ((Test-StillwaterPickerSelectable $item.App) -and -not $item.Selected) {
      $on = $false
      break
    }
  }
  foreach ($item in $Items) {
    if (Test-StillwaterPickerSelectable $item.App) {
      $item.Selected = -not $on
    }
  }
}

function Get-StillwaterPickerPath([string]$Dest) {
  $max = (Get-StillwaterTermCols) - 60
  if ($max -lt 8) { return "" }
  return (Get-StillwaterFitLeft (Get-StillwaterDisplayPath $Dest) $max)
}

function Write-StillwaterPicker($Style, $Items, [int]$Cursor) {
  $os = Get-StillwaterOsLabel
  $version = Get-StillwaterVersion
  Write-Host ("{0}{1}┌  {2}Stillwater{3}  {4}{5}  {6}{3}" -f $Style.Clear, $Style.Muted, $Style.Accent, $Style.Reset, $Style.Warm, $os, $version)
  Write-Host ("{0}{1}◆  {2}Which apps should get Stillwater?{3}" -f $Style.Clear, $Style.Accent, $Style.Text, $Style.Reset)
  for ($i = 0; $i -lt $Items.Count; $i++) {
    $item = $Items[$i]
    $label = "{0,-22}" -f $item.Label
    $action = "{0,-10}" -f (Get-StillwaterPickerAction $item.App $item.Theme)
    $note = "{0,-16}" -f $item.Note
    $path = Get-StillwaterPickerPath $item.Dest
    $color = Get-StillwaterPickerActionColor $Style $item.App $item.Theme
    if (-not (Test-StillwaterPickerSelectable $item.App)) {
      Write-Host ("{0}{1}│     {2}  {3}  {4}  {5}{6}" -f $Style.Clear, $Style.Muted, $label, $action, $note, $path, $Style.Reset)
      continue
    }
    $check = if ($item.Selected) {
      "{0}●{1}" -f $Style.Accent, $Style.Reset
    } elseif ($i -eq $Cursor) {
      "{0}○{1}" -f $Style.AccentHover, $Style.Reset
    } else {
      "{0}○{1}" -f $Style.Muted, $Style.Reset
    }
    $labelfg = if ($i -eq $Cursor) { $Style.Text } else { $Style.Muted }
    Write-Host ("{0}{1}│{2}  {3}  {4}{5}  {6}{7}  {8}{9}  {10}{2}" -f `
      $Style.Clear, $Style.Muted, $Style.Reset, $check, $labelfg, $label, $color, $action, $Style.Muted, $note, $path)
  }
  Write-Host ("{0}{1}└  Space selects, a selects all found, Enter installs{2}" -f $Style.Clear, $Style.Muted, $Style.Reset)
}

function Write-StillwaterPickerSummary($Style, $Items) {
  $names = @()
  foreach ($item in $Items) {
    if ($item.Selected) {
      $names += (Get-StillwaterPickerSummaryName $item.Label $item.Theme)
    }
  }
  $os = Get-StillwaterOsLabel
  $version = Get-StillwaterVersion
  Write-Host ("{0}{1}┌  {2}Stillwater{3}  {4}{5}  {6}{3}" -f $Style.Clear, $Style.Muted, $Style.Accent, $Style.Reset, $Style.Warm, $os, $version)
  Write-Host ("{0}{1}◇  {2}Which apps should get Stillwater?{3}" -f $Style.Clear, $Style.AccentHover, $Style.Text, $Style.Reset)
  if ($names.Count -eq 0) {
    Write-Host ("{0}{1}│  Nothing selected.{2}" -f $Style.Clear, $Style.Muted, $Style.Reset)
  } else {
    Write-Host ("{0}{1}│  {2}{3}{4}" -f $Style.Clear, $Style.Muted, $Style.Text, ($names -join ", "), $Style.Reset)
  }
  Write-Host "`e[J" -NoNewline
}

function Read-StillwaterPickerKey {
  $key = [Console]::ReadKey($true)
  if ($key.Key -eq "UpArrow" -or $key.KeyChar -eq "k") { return "up" }
  if ($key.Key -eq "DownArrow" -or $key.KeyChar -eq "j") { return "down" }
  if ($key.Key -eq "Spacebar") { return "space" }
  if ($key.Key -eq "Enter") { return "enter" }
  if ($key.Key -eq "Escape" -or $key.KeyChar -eq "q" -or [int]$key.KeyChar -eq 3) { return "quit" }
  if ($key.KeyChar -eq "a" -or $key.KeyChar -eq "A") { return "all" }
  if ($key.KeyChar -eq "n" -or $key.KeyChar -eq "N") { return "none" }
  return "other"
}

# Returns selected adapter ids. Throws "cancelled" on quit so the caller can exit 0.
function Invoke-StillwaterPicker([string[]]$Rows) {
  Enable-StillwaterVirtualTerminal
  try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
  } catch { }
  $style = Get-StillwaterPickerStyle
  $items = @(ConvertTo-StillwaterPickerItems $Rows)
  if ($items.Count -eq 0) {
    Write-Error "No adapters found."
    return @()
  }
  $cursor = Get-StillwaterPickerCursor $items
  $rowsCount = $items.Count + 3
  $oldVisible = $true
  try {
    $oldVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false
  } catch { }
  Write-StillwaterPicker $style $items $cursor
  try {
    while ($true) {
      $key = Read-StillwaterPickerKey
      switch ($key) {
        "up" { $cursor = Move-StillwaterPickerCursor $items $cursor -1 }
        "down" { $cursor = Move-StillwaterPickerCursor $items $cursor 1 }
        "space" {
          if (Test-StillwaterPickerSelectable $items[$cursor].App) {
            $items[$cursor].Selected = -not $items[$cursor].Selected
          }
        }
        "all" { Set-StillwaterPickerAll $items }
        "none" { foreach ($item in $items) { $item.Selected = $false } }
        "enter" {
          Write-Host ("`e[{0}A" -f $rowsCount) -NoNewline
          Write-StillwaterPickerSummary $style $items
          return @($items | Where-Object { $_.Selected } | ForEach-Object { $_.Id })
        }
        "quit" {
          Write-Host ("`e[{0}A" -f $rowsCount) -NoNewline
          Write-Host ("{0}{1}■  Cancelled.{2}" -f $style.Clear, $style.Error, $style.Reset)
          Write-Host "`e[J" -NoNewline
          throw "cancelled"
        }
      }
      Write-Host ("`e[{0}A" -f $rowsCount) -NoNewline
      Write-StillwaterPicker $style $items $cursor
    }
  } finally {
    try { [Console]::CursorVisible = $oldVisible } catch { }
  }
}
