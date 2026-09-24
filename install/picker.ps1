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
  $style.Hide = "`e[?25l"
  $style.Show = "`e[?25h"
  $style.Start = "┌"
  $style.Diamond = "◆"
  $style.Done = "◇"
  $style.Cancel = "■"
  $style.Pipe = "│"
  $style.Corner = "└"
  $style.On = "●"
  $style.Off = "○"
  $style.BarOn = "█"
  $style.BarBusy = "▒"
  $style.BarOff = "░"
  $style.Spin = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
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

function Get-StillwaterPickerActionColor($Style, [string]$App, [string]$Theme) {
  if (-not (Test-StillwaterPickerSelectable $App)) { return $Style.Muted }
  switch ($Theme) {
    "none" { return $Style.Accent }
    "current" { return $Style.AccentDeep }
    "update" { return $Style.Warn }
    default { return $Style.Text }
  }
}

function Get-StillwaterJobVerb([string]$Theme, [string]$State) {
  switch ($State) {
    "skip" { return "missing" }
    "fail" { return "failed" }
    "pending" { return "queued" }
    "busy" {
      switch ($Theme) {
        "current" { return "refreshing" }
        "update" { return "updating" }
        default { return "installing" }
      }
    }
    "ok" {
      switch ($Theme) {
        "current" { return "refreshed" }
        "update" { return "updated" }
        default { return "installed" }
      }
    }
    default { return $State }
  }
}

function Get-StillwaterJobVerbColor($Style, [string]$Theme, [string]$State) {
  switch ($State) {
    { $_ -in @("skip", "pending") } { return $Style.Muted }
    "fail" { return $Style.Error }
    "busy" {
      if ($Theme -eq "update") { return $Style.Warn }
      return $Style.AccentHover
    }
    "ok" { return $Style.Accent }
    default { return $Style.Text }
  }
}

function Get-StillwaterSpinFrame($Style, [int]$Index) {
  if (-not $Style.Spin -or $Style.Spin.Count -eq 0) { return $Style.Off }
  return $Style.Spin[$Index % $Style.Spin.Count]
}

function Get-StillwaterProgressBar([int]$Done, [int]$Total, [int]$Width = 20, [bool]$Busy = $false) {
  if ($Width -lt 4) { $Width = 4 }
  $filled = 0
  if ($Total -gt 0) { $filled = [int][Math]::Floor($Done * $Width / $Total) }
  if ($filled -gt $Width) { $filled = $Width }
  if ($Busy -and $filled -ge $Width) { $filled = $Width - 1 }
  $chars = for ($i = 0; $i -lt $Width; $i++) {
    if ($i -lt $filled) { "█" }
    elseif ($Busy -and $i -eq $filled) { "▒" }
    else { "░" }
  }
  return (-join $chars)
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

function Get-StillwaterJobsNext([string]$Text) {
  if (-not $Text) { return "" }
  $max = (Get-StillwaterTermCols) - 42
  if ($max -lt 12) { return $Text }
  return (Get-StillwaterFitLeft $Text $max)
}

function Write-StillwaterKeymapSelect($Style) {
  Write-Host ("{0}{1}{2}  {3}↑↓ jk{4}  {3}space{4}  {3}a/n{4}  {3}enter{4}  {3}q{4}{4}" -f `
    $Style.Clear, $Style.Muted, $Style.Corner, $Style.Accent, $Style.Reset)
}

function Write-StillwaterPickerRow($Style, $Item, [int]$Index, [int]$Cursor) {
  $label = $Item.LabelPad
  $action = $Item.ActionPad
  $note = $Item.NotePad
  $path = $Item.PathPad
  $color = $Item.ActionColor
  if (-not (Test-StillwaterPickerSelectable $Item.App)) {
    Write-Host ("{0}{1}│     {2}  {3}  {4}  {5}{6}" -f $Style.Clear, $Style.Muted, $label, $action, $note, $path, $Style.Reset)
    return
  }
  $check = if ($Item.Selected) {
    "{0}●{1}" -f $Style.Accent, $Style.Reset
  } elseif ($Index -eq $Cursor) {
    "{0}○{1}" -f $Style.AccentHover, $Style.Reset
  } else {
    "{0}○{1}" -f $Style.Muted, $Style.Reset
  }
  $labelfg = if ($Index -eq $Cursor) { $Style.Text } else { $Style.Muted }
  Write-Host ("{0}{1}│{2}  {3}  {4}{5}  {6}{7}  {8}{9}  {10}{2}" -f `
    $Style.Clear, $Style.Muted, $Style.Reset, $check, $labelfg, $label, $color, $action, $Style.Muted, $note, $path)
}

function Write-StillwaterPickerRowAt($Style, $Items, [int]$Cursor, [int]$Index) {
  $saved = [Console]::CursorTop
  $line = $saved - (1 + $Items.Count - $Index)
  if ($line -lt 0) { $line = 0 }
  [Console]::SetCursorPosition(0, $line)
  Write-StillwaterPickerRow $Style $Items[$Index] $Index $Cursor
  [Console]::SetCursorPosition(0, $saved)
}

function Initialize-StillwaterPickerLayout($Style, $Items) {
  foreach ($item in $Items) {
    $item | Add-Member -NotePropertyName LabelPad -NotePropertyValue ("{0,-22}" -f $item.Label) -Force
    $item | Add-Member -NotePropertyName ActionPad -NotePropertyValue ("{0,-10}" -f (Get-StillwaterPickerAction $item.App $item.Theme)) -Force
    $item | Add-Member -NotePropertyName NotePad -NotePropertyValue ("{0,-16}" -f $item.Note) -Force
    $item | Add-Member -NotePropertyName PathPad -NotePropertyValue (Get-StillwaterPickerPath $item.Dest) -Force
    $item | Add-Member -NotePropertyName ActionColor -NotePropertyValue (Get-StillwaterPickerActionColor $Style $item.App $item.Theme) -Force
  }
}

function Write-StillwaterPicker($Style, $Items, [int]$Cursor) {
  $os = Get-StillwaterOsLabel
  $version = Get-StillwaterVersion
  Write-Host ("{0}{1}┌  {2}Stillwater{3}  {4}{5}  {6}{3}" -f $Style.Clear, $Style.Muted, $Style.Accent, $Style.Reset, $Style.Warm, $os, $version)
  Write-Host ("{0}{1}◆  {2}select{3}" -f $Style.Clear, $Style.Accent, $Style.Text, $Style.Reset)
  for ($i = 0; $i -lt $Items.Count; $i++) {
    Write-StillwaterPickerRow $Style $Items[$i] $i $Cursor
  }
  Write-StillwaterKeymapSelect $Style
}

function Get-StillwaterJobMark($Style, [string]$Theme, [string]$State, [int]$SpinI) {
  $color = Get-StillwaterJobVerbColor $Style $Theme $State
  switch ($State) {
    "ok" { return ("{0}{1}{2}" -f $color, $Style.On, $Style.Reset) }
    "fail" { return ("{0}{1}{2}" -f $color, $Style.Cancel, $Style.Reset) }
    "busy" { return ("{0}{1}{2}" -f $color, (Get-StillwaterSpinFrame $Style $SpinI), $Style.Reset) }
    default { return ("{0}{1}{2}" -f $color, $Style.Off, $Style.Reset) }
  }
}

function Write-StillwaterJobs($Style, $Jobs, [int]$SpinI, [string]$Summary = "") {
  $done = 0
  $busy = $false
  $running = $false
  foreach ($job in $Jobs) {
    switch ($job.State) {
      "busy" { $busy = $true; $running = $true }
      "pending" { $running = $true }
      default { $done++ }
    }
  }
  $os = Get-StillwaterOsLabel
  $version = Get-StillwaterVersion
  Write-Host ("{0}{1}┌  {2}Stillwater{3}  {4}{5}  {6}{3}" -f $Style.Clear, $Style.Muted, $Style.Accent, $Style.Reset, $Style.Warm, $os, $version)
  if ($running) {
    Write-Host ("{0}{1}◆  {2}install{3}" -f $Style.Clear, $Style.Accent, $Style.Text, $Style.Reset)
  } else {
    Write-Host ("{0}{1}◇  {2}install{3}" -f $Style.Clear, $Style.AccentHover, $Style.Text, $Style.Reset)
  }
  foreach ($job in $Jobs) {
    $label = "{0,-22}" -f $job.Label
    $verb = "{0,-11}" -f (Get-StillwaterJobVerb $job.Theme $job.State)
    $vcolor = Get-StillwaterJobVerbColor $Style $job.Theme $job.State
    $mark = Get-StillwaterJobMark $Style $job.Theme $job.State $SpinI
    $labelfg = $Style.Muted
    $next = ""
    if ($job.State -eq "ok") {
      $labelfg = $Style.Text
      $next = Get-StillwaterJobsNext $job.Next
    } elseif ($job.State -eq "fail") {
      $labelfg = $Style.Text
    }
    Write-Host ("{0}{1}│{2}  {3}  {4}{5}{2}  {6}{7}{2}  {1}{8}{2}" -f `
      $Style.Clear, $Style.Muted, $Style.Reset, $mark, $labelfg, $label, $vcolor, $verb, $next)
  }
  if ($running) {
    $bar = Get-StillwaterProgressBar $done $Jobs.Count 24 $busy
    Write-Host ("{0}{1}└  {2}{3}/{4}{5}  {6}{7}{5}" -f $Style.Clear, $Style.Muted, $Style.Text, $done, $Jobs.Count, $Style.Reset, $Style.Accent, $bar)
  } else {
    Write-Host ("{0}{1}└  {2}{3}{4}" -f $Style.Clear, $Style.Muted, $Style.Text, $Summary, $Style.Reset)
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
# Leaves the cursor hidden on confirm so install.ps1 can reuse the box.
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
  Initialize-StillwaterPickerLayout $style $items
  $rowsCount = $items.Count + 3
  $script:StillwaterPickerRows = $rowsCount
  $script:StillwaterUiKeepHidden = $false
  $oldVisible = $true
  try {
    $oldVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false
  } catch { }
  Write-StillwaterPicker $style $items $cursor
  try {
    while ($true) {
      $key = Read-StillwaterPickerKey
      $prev = $cursor
      switch ($key) {
        "up" {
          $cursor = Move-StillwaterPickerCursor $items $cursor -1
          if ($cursor -ne $prev) {
            Write-StillwaterPickerRowAt $style $items $cursor $prev
            Write-StillwaterPickerRowAt $style $items $cursor $cursor
          }
        }
        "down" {
          $cursor = Move-StillwaterPickerCursor $items $cursor 1
          if ($cursor -ne $prev) {
            Write-StillwaterPickerRowAt $style $items $cursor $prev
            Write-StillwaterPickerRowAt $style $items $cursor $cursor
          }
        }
        "space" {
          if (Test-StillwaterPickerSelectable $items[$cursor].App) {
            $items[$cursor].Selected = -not $items[$cursor].Selected
            Write-StillwaterPickerRowAt $style $items $cursor $cursor
          }
        }
        "all" {
          Set-StillwaterPickerAll $items
          Write-Host ("`e[{0}A" -f $rowsCount) -NoNewline
          Write-StillwaterPicker $style $items $cursor
        }
        "none" {
          foreach ($item in $items) { $item.Selected = $false }
          Write-Host ("`e[{0}A" -f $rowsCount) -NoNewline
          Write-StillwaterPicker $style $items $cursor
        }
        "enter" {
          $script:StillwaterUiKeepHidden = $true
          return @($items | Where-Object { $_.Selected } | ForEach-Object { $_.Id })
        }
        "quit" {
          Write-Host ("`e[{0}A" -f $rowsCount) -NoNewline
          Write-Host ("{0}{1}■  Cancelled.{2}" -f $style.Clear, $style.Error, $style.Reset)
          Write-Host "`e[J" -NoNewline
          throw "cancelled"
        }
      }
    }
  } finally {
    if (-not $script:StillwaterUiKeepHidden) {
      try { [Console]::CursorVisible = $oldVisible } catch { }
    }
  }
}
