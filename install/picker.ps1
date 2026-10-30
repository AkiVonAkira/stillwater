# Clack-style multi-select for install.ps1. Colors come from palette.json.
# The picker and the install progress repaint whole frames on the alternate
# screen, so scrollback and resizes cannot tear them. The result prints once to
# the normal screen.

function Enable-StillwaterVirtualTerminal {
  # PowerShell 7 turns VT on itself; Add-Type compiles C# and costs ~0.5 s.
  try { if ($Host.UI.SupportsVirtualTerminal) { return } } catch { }
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
  if ($env:NO_COLOR) { $style.Clear = "`e[2K" }
  $style.Hide = "`e[?25l"
  $style.Show = "`e[?25h"
  $style.Home = "`e[H"
  $style.Eos = "`e[J"
  $style.Wipe = "`e[2J"
  # 1049 is the alternate screen. 1007 turns the mouse wheel into arrow keys there.
  $style.AltOn = "`e[?1049h`e[?1007h"
  $style.AltOff = "`e[?1007l`e[?1049l"
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

function Enter-StillwaterScreen($Style) {
  if (-not $script:StillwaterAlt) {
    [Console]::Write($Style.AltOn + $Style.Hide + $Style.Wipe)
    $script:StillwaterAlt = $true
  }
  try { [Console]::CursorVisible = $false } catch { }
}

function Exit-StillwaterScreen($Style) {
  if ($script:StillwaterAlt) {
    [Console]::Write($Style.AltOff)
    $script:StillwaterAlt = $false
  }
  [Console]::Write($Style.Show)
  try { [Console]::CursorVisible = $true } catch { }
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
        "switch" { return "Switch" }
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
    { $_ -in @("update", "switch") } { return $Style.Warn }
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
        "switch" { return "switching" }
        default { return "installing" }
      }
    }
    "ok" {
      switch ($Theme) {
        "current" { return "refreshed" }
        "update" { return "updated" }
        "switch" { return "switched" }
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
      if ($Theme -in @("update", "switch")) { return $Style.Warn }
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

# Pads text to width, or cuts it with an ellipsis.
function Get-StillwaterPad([string]$Text, [int]$Width) {
  if ($Width -le 0) { return "" }
  if ($Text.Length -gt $Width) {
    if ($Width -le 1) { return "…" }
    return $Text.Substring(0, $Width - 1) + "…"
  }
  return $Text.PadRight($Width)
}

function ConvertTo-StillwaterPickerItems([string[]]$Rows) {
  $items = @()
  foreach ($row in $Rows) {
    if (-not $row) { continue }
    $parts = $row.Split("|")
    $app = $parts[2]
    $theme = if ($parts.Count -gt 3) { $parts[3] } else { "none" }
    $dest = if ($parts.Count -gt 5) { $parts[5] } else { "" }
    $bases = @(Get-StillwaterBaseList $(if ($parts.Count -gt 6) { $parts[6] } else { "" }))
    $base = if ($parts.Count -gt 7) { $parts[7] } else { "" }
    $sel = 0
    for ($k = 0; $k -lt $bases.Count; $k++) {
      if ($bases[$k].Key -eq $base) { $sel = $k }
    }
    $on = (Test-StillwaterPickerSelectable $app) -and ($theme -ne "current")
    $items += [pscustomobject]@{
      Id = $parts[0]
      Label = $parts[1]
      App = $app
      Theme = $theme
      Note = if ($parts.Count -gt 4) { $parts[4] } else { "" }
      Dest = $dest
      Path = Get-StillwaterDisplayPath $dest
      Selected = $on
      Default = $on
      Bases = $bases
      BaseSel = $sel
      BaseInit = $sel
    }
  }
  return @($items)
}

# A row whose base moved off the installed one is a switch, unless nothing is installed yet.
function Get-StillwaterPickerTheme($Item) {
  if ($Item.BaseSel -ne $Item.BaseInit -and $Item.Theme -ne "none") { return "switch" }
  return $Item.Theme
}

function Get-StillwaterPickerBase($Item) {
  if ($Item.Bases.Count -eq 0) { return "" }
  return $Item.Bases[$Item.BaseSel].Key
}

function Step-StillwaterPickerBase($Item, [int]$Dir) {
  $n = $Item.Bases.Count
  if ($n -le 1) { return $false }
  $Item.BaseSel = (($Item.BaseSel + $Dir) % $n + $n) % $n
  if ($Item.BaseSel -ne $Item.BaseInit) {
    $Item.Selected = $true
  } else {
    $Item.Selected = $Item.Default
  }
  return $true
}

# Rebuilds the rows from a newer status list and keeps what the user changed,
# matched by id, so rows can arrive while the picker is open. The cursor stays
# on its app once the user has moved it, else on the first app found.
function Update-StillwaterPickerItems($Old, [string[]]$Rows) {
  $ui = $script:StillwaterUi
  $prev = @{}
  foreach ($item in $Old) { $prev[$item.Id] = $item }
  $cursorId = $null
  if ($ui.Moved -and $ui.Cursor -ge 0 -and $ui.Cursor -lt $Old.Count) { $cursorId = $Old[$ui.Cursor].Id }
  $items = @(ConvertTo-StillwaterPickerItems $Rows)
  $ui.Cursor = -1
  for ($i = 0; $i -lt $items.Count; $i++) {
    $was = $prev[$items[$i].Id]
    if ($was) {
      $items[$i].Selected = $was.Selected
      $items[$i].BaseSel = $was.BaseSel
    }
    if ($cursorId -and $items[$i].Id -eq $cursorId) { $ui.Cursor = $i }
  }
  if ($ui.Cursor -lt 0) { $ui.Cursor = Get-StillwaterPickerCursor $items }
  return $items
}

function Get-StillwaterPickerCursor($Items) {
  for ($i = 0; $i -lt $Items.Count; $i++) {
    if (Test-StillwaterPickerSelectable $Items[$i].App) { return $i }
  }
  return 0
}

# Moves to the next selectable row. Past the last one it scrolls the view so
# missing apps can still be read, then wraps.
function Move-StillwaterPickerCursor($Items, [int]$Dir) {
  $ui = $script:StillwaterUi
  $n = $Items.Count
  if ($n -le 0) { return }
  $ui.Follow = $true
  $ui.Moved = $true
  $i = $ui.Cursor
  while ($true) {
    $i += $Dir
    if ($i -lt 0 -or $i -ge $n) { break }
    if (Test-StillwaterPickerSelectable $Items[$i].App) {
      $ui.Cursor = $i
      return
    }
  }
  if ($Dir -gt 0 -and $ui.ViewLast -lt ($n - 1)) {
    $ui.Follow = $false
    $ui.Top++
    return
  }
  $ui.Top = 0
  $i = if ($Dir -gt 0) { -1 } else { $n }
  while ($true) {
    $i += $Dir
    if ($i -lt 0 -or $i -ge $n) { return }
    if (Test-StillwaterPickerSelectable $Items[$i].App) {
      $ui.Cursor = $i
      return
    }
  }
}

function Move-StillwaterPickerPage($Items, [int]$Dir) {
  $ui = $script:StillwaterUi
  for ($k = 0; $k -lt $ui.ListH; $k++) {
    $before = $ui.Cursor
    Move-StillwaterPickerCursor $Items $Dir
    if (($Dir -gt 0 -and $ui.Cursor -lt $before) -or ($Dir -lt 0 -and $ui.Cursor -gt $before)) {
      $ui.Cursor = $before
      $ui.Follow = $true
      return
    }
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

function Get-StillwaterKeymapPairs([bool]$HasBases) {
  $pairs = @(, @("↑↓ jk", "nav"))
  if ($HasBases) { $pairs += , @("←→ hl", "base") }
  $pairs += , @("space", "toggle")
  $pairs += , @("a", "all")
  $pairs += , @("n", "none")
  $pairs += , @("enter", "apply")
  $pairs += , @("q", "abort")
  return $pairs
}

# Wraps the key hints so no line reaches the last column.
function Get-StillwaterKeymapLines($Style, [int]$Cols, [bool]$HasBases) {
  $lines = @()
  $line = "{0}{1}{2}  " -f $Style.Muted, $Style.Corner, $Style.Reset
  $used = 3
  foreach ($pair in Get-StillwaterKeymapPairs $HasBases) {
    $w = $pair[0].Length + 1 + $pair[1].Length
    if ($used -gt 3 -and ($used + 5 + $w) -ge $Cols) {
      $lines += $line
      $line = "   "
      $used = 3
    }
    if ($used -gt 3) {
      $line += "  {0}·{1}  " -f $Style.Muted, $Style.Reset
      $used += 5
    }
    $line += "{0}{1}{2} {3}{4}{2}" -f $Style.Accent, $pair[0], $Style.Reset, $Style.Muted, $pair[1]
    $used += $w
  }
  $lines += $line
  return $lines
}

# Fits the columns to the terminal. Path goes first, then the note column,
# then the base strip shrinks to the chosen base, then labels shrink.
function Update-StillwaterPickerLayout($Style, $Items) {
  $ui = $script:StillwaterUi
  $size = Get-StillwaterTermSize
  $ui.Cols = $size.Cols
  $ui.Lines = $size.Lines
  $wl = 0; $wn = 0; $ws = 0; $wt = 0; $wa = 10
  $hasBases = $false
  foreach ($item in $Items) {
    if ($item.Label.Length -gt $wl) { $wl = $item.Label.Length }
    if ($item.Note.Length -gt $wn) { $wn = $item.Note.Length }
    if ($item.Bases.Count -gt 0) {
      $hasBases = $true
      $strip = 4 + 3 * ($item.Bases.Count - 1)
      foreach ($b in $item.Bases) {
        $strip += $b.Label.Length
        if ($b.Label.Length + 4 -gt $wt) { $wt = $b.Label.Length + 4 }
      }
      if ($strip -gt $ws) { $ws = $strip }
    }
  }
  if ($wl -gt 22) { $wl = 22 }
  $avail = $ui.Cols - 1
  $used = 6 + $wl + 2 + $wa
  $mode = "none"
  if ($ws -gt 0) {
    if ($used + 2 + $wn + 2 + $ws -le $avail) { $mode = "full" }
    elseif ($used + 2 + $ws -le $avail) { $mode = "full"; $wn = 0 }
    elseif ($used + 2 + $wn + 2 + $wt -le $avail) { $mode = "tag" }
    else { $mode = "tag"; $wn = 0 }
  }
  if ($wn -gt 0) { $used += 2 + $wn }
  if ($mode -eq "full") { $used += 2 + $ws }
  if ($mode -eq "tag") { $used += 2 + $wt }
  if ($used -gt $avail) {
    $used -= $wl
    $wl = [Math]::Max(6, $avail - $used)
    $used += $wl
  }
  # Tiny terminals: drop the strip, then narrow the label and action columns.
  if ($used -gt $avail -and $mode -ne "none") {
    $used -= 2 + $(if ($mode -eq "full") { $ws } else { $wt })
    $mode = "none"
  }
  if ($used -gt $avail) {
    $used -= $wl
    $wl = [Math]::Max(4, $avail - $used)
    $used += $wl
  }
  if ($used -gt $avail) {
    $wa = [Math]::Max(1, $wa - ($used - $avail))
    $used = 6 + $wl + 2 + $wa
  }
  $ui.WLabel = $wl
  $ui.WAction = $wa
  $ui.WNote = $wn
  $ui.StripMode = $mode
  $ui.WStrip = switch ($mode) { "full" { $ws } "tag" { $wt } default { 0 } }
  $ui.WPath = $avail - $used - 2
  if ($ui.WPath -lt 8) { $ui.WPath = 0 }
  foreach ($item in $Items) {
    $item | Add-Member -NotePropertyName LabelPad -NotePropertyValue (Get-StillwaterPad $item.Label $wl) -Force
    $item | Add-Member -NotePropertyName NotePad -NotePropertyValue (Get-StillwaterPad $item.Note $wn) -Force
    $item | Add-Member -NotePropertyName PathPad -NotePropertyValue (Get-StillwaterFitLeft $item.Path $ui.WPath) -Force
  }
  $ui.Keymap = @(Get-StillwaterKeymapLines $Style $ui.Cols $hasBases)
  Set-StillwaterListHeight $ui $ui.Keymap.Count
}

function Set-StillwaterListHeight($Ui, [int]$Footer) {
  $Ui.HeadLines = 2
  $Ui.ListH = $Ui.Lines - $Ui.HeadLines - $Footer
  while ($Ui.ListH -lt 3 -and $Ui.HeadLines -gt 0) {
    $Ui.HeadLines--
    $Ui.ListH++
  }
  if ($Ui.ListH -lt 1) { $Ui.ListH = 1 }
}

function Get-StillwaterPickerStrip($Style, $Item, [bool]$Live) {
  $ui = $script:StillwaterUi
  $out = ""
  $plain = 0
  if ($Item.Bases.Count -gt 0) {
    $pick = if ($Live) { $Style.Accent } else { $Style.Muted }
    # On a switch, the installed base keeps the Up to date color.
    $installed = if ($Live -and $Item.BaseSel -ne $Item.BaseInit -and $Item.Theme -ne "none") { $Item.BaseInit } else { -1 }
    if ($ui.StripMode -eq "full") {
      $out = "{0}[ " -f $Style.Muted
      $plain = 2
      for ($j = 0; $j -lt $Item.Bases.Count; $j++) {
        $lab = $Item.Bases[$j].Label
        if ($j -gt 0) {
          $out += "{0} / " -f $Style.Muted
          $plain += 3
        }
        $paint = if ($j -eq $Item.BaseSel) { $pick } elseif ($j -eq $installed) { $Style.AccentDeep } else { $Style.Muted }
        $out += $paint + $lab
        $plain += $lab.Length
      }
      $out += "{0} ]" -f $Style.Muted
      $plain += 2
    } else {
      $lab = $Item.Bases[$Item.BaseSel].Label
      $out = "{0}‹ {1}{2}{0} ›" -f $Style.Muted, $pick, $lab
      $plain = $lab.Length + 4
    }
  }
  if ($plain -lt $ui.WStrip) { $out += "".PadRight($ui.WStrip - $plain) }
  return $out
}

function Get-StillwaterPickerRow($Style, $Item, [int]$Index) {
  $ui = $script:StillwaterUi
  $theme = Get-StillwaterPickerTheme $Item
  $action = Get-StillwaterPad (Get-StillwaterPickerAction $Item.App $theme) $ui.WAction
  $live = Test-StillwaterPickerSelectable $Item.App
  $tail = ""
  if ($ui.WNote -gt 0) { $tail += "  " + $Style.Muted + $Item.NotePad }
  if ($ui.StripMode -ne "none") { $tail += "  " + (Get-StillwaterPickerStrip $Style $Item $live) }
  if ($Item.PathPad) { $tail += "  " + $Style.Muted + $Item.PathPad }
  if (-not $live) {
    return ("{0}{1}     {2}  {3}{4}{5}" -f $Style.Muted, $Style.Pipe, $Item.LabelPad, $action, $tail, $Style.Reset)
  }
  $check = if ($Item.Selected) {
    $Style.Accent + $Style.On
  } elseif ($Index -eq $ui.Cursor) {
    $Style.AccentHover + $Style.Off
  } else {
    $Style.Muted + $Style.Off
  }
  $labelfg = if ($Index -eq $ui.Cursor) { $Style.Text } else { $Style.Muted }
  $color = Get-StillwaterPickerActionColor $Style $Item.App $theme
  return ("{0}{1}{2}  {3}{2}  {4}{5}  {6}{7}{8}{2}" -f `
    $Style.Muted, $Style.Pipe, $Style.Reset, $check, $labelfg, $Item.LabelPad, $color, $action, $tail)
}

# Picks the first visible row so the focus row stays on screen.
function Update-StillwaterView([int]$Count, [int]$Focus) {
  $ui = $script:StillwaterUi
  $h = $ui.ListH
  $ui.More = $false
  if ($Count -le $h) {
    $ui.Top = 0
    $ui.ViewFirst = 0
    $ui.ViewLast = $Count - 1
    return
  }
  if ($h -ge 3) {
    $ui.More = $true
    $h -= 2
  }
  if ($ui.Follow -and $Focus -ge 0) {
    if ($Focus -lt $ui.Top) { $ui.Top = $Focus }
    elseif ($Focus -ge $ui.Top + $h) { $ui.Top = $Focus - $h + 1 }
  }
  if ($ui.Top -gt $Count - $h) { $ui.Top = $Count - $h }
  if ($ui.Top -lt 0) { $ui.Top = 0 }
  $ui.ViewFirst = $ui.Top
  $ui.ViewLast = $ui.Top + $h - 1
}

function Get-StillwaterMoreLine($Style, [int]$Count, [string]$Arrow) {
  if ($Count -gt 0) { return ("{0}{1}     {2} {3} more" -f $Style.Muted, $Style.Pipe, $Arrow, $Count) }
  return ("{0}{1}" -f $Style.Muted, $Style.Pipe)
}

function Get-StillwaterHeadLines($Style, [string]$Step, [string]$Mark, [string]$Tail = "") {
  $ui = $script:StillwaterUi
  $lines = @()
  if ($ui.HeadLines -ge 2) {
    $lines += ("{0}{1}{2}  {3}Stillwater{2}  {4}{5}  {6}" -f $Style.Muted, $Style.Start, $Style.Reset, $Style.Accent, $Style.Warm, (Get-StillwaterOsLabel), (Get-StillwaterVersion))
  }
  if ($ui.HeadLines -ge 1) { $lines += ("{0}  {1}{2}{3}" -f $Mark, $Style.Text, $Step, $Tail) }
  return $lines
}

# One write per frame, from the top, with no newline after the last line so the
# alternate screen never scrolls.
# Inline frames (named installs) redraw in place on the normal screen, from the
# first line of the last frame.
function Write-StillwaterFrame($Style, [string[]]$Lines) {
  $sb = [System.Text.StringBuilder]::new()
  if ($script:StillwaterInline) {
    [void]$sb.Append("`r")
    if ($script:StillwaterInlineN -gt 1) { [void]$sb.Append(("`e[{0}A" -f ($script:StillwaterInlineN - 1))) }
    $script:StillwaterInlineN = $Lines.Count
  } else {
    [void]$sb.Append($Style.Home)
  }
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($i -gt 0) { [void]$sb.Append("`n") }
    [void]$sb.Append($Style.Clear).Append($Lines[$i]).Append($Style.Reset)
  }
  [void]$sb.Append($Style.Eos)
  [Console]::Write($sb.ToString())
}

# While adapters still answer, the step line spins and counts them.
function Write-StillwaterPicker($Style, $Items, $Load = $null) {
  $ui = $script:StillwaterUi
  $mark = $Style.Accent + $Style.Diamond
  $tail = ""
  if ($Load -and $Load.Done -lt $Load.Total) {
    $mark = $Style.AccentHover + (Get-StillwaterSpinFrame $Style $Load.Spin)
    if ($Load.Done -ge 0) { $tail = "  {0}checking apps {1}/{2}" -f $Style.Muted, $Load.Done, $Load.Total }
  }
  $lines = @(Get-StillwaterHeadLines $Style "select" $mark $tail)
  Update-StillwaterView $Items.Count $ui.Cursor
  if ($ui.More) { $lines += Get-StillwaterMoreLine $Style $ui.ViewFirst "↑" }
  for ($i = $ui.ViewFirst; $i -le $ui.ViewLast; $i++) {
    $lines += Get-StillwaterPickerRow $Style $Items[$i] $i
  }
  if ($ui.More) { $lines += Get-StillwaterMoreLine $Style ($Items.Count - 1 - $ui.ViewLast) "↓" }
  $lines += $ui.Keymap
  Write-StillwaterFrame $Style $lines
}

# Waits for a key, or returns "resize" when the window size changes. With
# -Tick it returns "tick" after one wait, so the caller can take new rows.
function Read-StillwaterPickerKey([switch]$Tick) {
  $size = Get-StillwaterTermSize
  while (-not [Console]::KeyAvailable) {
    Start-Sleep -Milliseconds 40
    $now = Get-StillwaterTermSize
    if ($now.Cols -ne $size.Cols -or $now.Lines -ne $size.Lines) { return "resize" }
    if ($Tick) { return "tick" }
  }
  $key = [Console]::ReadKey($true)
  if ($key.Key -eq "UpArrow" -or $key.KeyChar -eq "k") { return "up" }
  if ($key.Key -eq "DownArrow" -or $key.KeyChar -eq "j") { return "down" }
  if ($key.Key -eq "LeftArrow" -or $key.KeyChar -eq "h") { return "left" }
  if ($key.Key -eq "RightArrow" -or $key.KeyChar -eq "l") { return "right" }
  if ($key.Key -eq "PageUp") { return "pgup" }
  if ($key.Key -eq "PageDown") { return "pgdn" }
  if ($key.Key -eq "Spacebar") { return "space" }
  if ($key.Key -eq "Enter") { return "enter" }
  if ($key.Key -eq "Escape" -or $key.KeyChar -eq "q" -or [int]$key.KeyChar -eq 3) { return "quit" }
  if ($key.KeyChar -eq "a" -or $key.KeyChar -eq "A") { return "all" }
  if ($key.KeyChar -eq "n" -or $key.KeyChar -eq "N") { return "none" }
  return "other"
}

function New-StillwaterUi {
  $script:StillwaterUi = [pscustomobject]@{
    Cols = 80; Lines = 24; Cursor = 0; Top = 0; Follow = $true; Moved = $false
    ViewFirst = 0; ViewLast = 0; More = $false; ListH = 1; HeadLines = 2
    WLabel = 22; WAction = 10; WNote = 0; WStrip = 0; StripMode = "none"; WPath = 0
    Keymap = @(); WBase = 0; WNext = 0
  }
}

# Returns the chosen adapter ids, as id or id:base. Throws "cancelled" on quit so
# the caller can exit 0. Stays on the alternate screen on confirm so install.ps1
# can draw progress there.
# $Poll returns the status read so far as { Rows; Done; Total }. The picker
# opens at once, sorts rows in as adapters answer, and takes enter once the
# last one has.
function Invoke-StillwaterPicker([scriptblock]$Poll) {
  Enable-StillwaterVirtualTerminal
  try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
  } catch { }
  $style = Get-StillwaterPickerStyle
  New-StillwaterUi
  $ui = $script:StillwaterUi
  $load = [pscustomobject]@{ Done = -1; Total = 1; Spin = 0 }
  $items = @()
  $oldCtrlC = $false
  try { $oldCtrlC = [Console]::TreatControlCAsInput; [Console]::TreatControlCAsInput = $true } catch { }
  $keep = $false
  Enter-StillwaterScreen $style
  try {
    Update-StillwaterPickerLayout $style $items
    Write-StillwaterPicker $style $items $load
    while ($true) {
      if ($load -and $load.Done -lt $load.Total) {
        $state = & $Poll
        $load.Total = $state.Total
        if ($state.Done -ne $load.Done) {
          $load.Done = $state.Done
          $items = @(Update-StillwaterPickerItems $items @($state.Rows))
          Update-StillwaterPickerLayout $style $items
        }
        if ($load.Done -ge $load.Total -and $items.Count -eq 0) {
          throw "No adapters found."
        }
      }
      Write-StillwaterPicker $style $items $load
      $loading = $load -and $load.Done -lt $load.Total
      $key = Read-StillwaterPickerKey -Tick:$loading
      if ($loading) { $load.Spin++ }
      switch ($key) {
        "resize" {
          Update-StillwaterPickerLayout $style $items
          [Console]::Write($style.Wipe)
        }
        "up" { Move-StillwaterPickerCursor $items -1 }
        "down" { Move-StillwaterPickerCursor $items 1 }
        "pgup" { Move-StillwaterPickerPage $items -1 }
        "pgdn" { Move-StillwaterPickerPage $items 1 }
        "left" { if ($items.Count) { [void](Step-StillwaterPickerBase $items[$ui.Cursor] -1) } }
        "right" { if ($items.Count) { [void](Step-StillwaterPickerBase $items[$ui.Cursor] 1) } }
        "space" {
          if ($items.Count -and (Test-StillwaterPickerSelectable $items[$ui.Cursor].App)) {
            $items[$ui.Cursor].Selected = -not $items[$ui.Cursor].Selected
          }
        }
        "all" { Set-StillwaterPickerAll $items }
        "none" { foreach ($item in $items) { $item.Selected = $false } }
        "enter" {
          if ($loading) { continue }
          $keep = $true
          return @($items | Where-Object { $_.Selected } | ForEach-Object {
              $base = Get-StillwaterPickerBase $_
              if ($base) { "{0}:{1}" -f $_.Id, $base } else { $_.Id }
            })
        }
        "quit" {
          Exit-StillwaterScreen $style
          Write-Host ("{0}■  Cancelled.{1}" -f $style.Error, $style.Reset)
          throw "cancelled"
        }
        default { continue }
      }
    }
  } finally {
    try { [Console]::TreatControlCAsInput = $oldCtrlC } catch { }
    if (-not $keep) { Exit-StillwaterScreen $style }
  }
}

function Update-StillwaterJobsLayout($Jobs) {
  if (-not $script:StillwaterUi) { New-StillwaterUi }
  $ui = $script:StillwaterUi
  $size = Get-StillwaterTermSize
  $ui.Cols = $size.Cols
  $ui.Lines = $size.Lines
  $wl = 0; $wb = 0
  foreach ($job in $Jobs) {
    if ($job.Label.Length -gt $wl) { $wl = $job.Label.Length }
    if ($job.BaseLabel.Length -gt $wb) { $wb = $job.BaseLabel.Length }
  }
  if ($wl -gt 22) { $wl = 22 }
  $avail = $ui.Cols - 1
  $used = 6 + $wl + 2 + 11
  if ($wb -gt 0 -and $used + 2 + $wb -le $avail) { $used += 2 + $wb } else { $wb = 0 }
  if ($used -gt $avail) {
    $wl -= ($used - $avail)
    if ($wl -lt 4) { $wl = 4 }
    $used = $avail
  }
  $ui.WLabel = $wl
  $ui.WBase = $wb
  $ui.WNext = $avail - $used - 2
  if ($ui.WNext -lt 8) { $ui.WNext = 0 }
  Set-StillwaterListHeight $ui 1
}

function Get-StillwaterJobRow($Style, $Job, [int]$SpinI) {
  $ui = $script:StillwaterUi
  $verb = Get-StillwaterPad (Get-StillwaterJobVerb $Job.Theme $Job.State) 11
  $vcolor = Get-StillwaterJobVerbColor $Style $Job.Theme $Job.State
  $mark = switch ($Job.State) {
    "ok" { $vcolor + $Style.On }
    "fail" { $vcolor + $Style.Cancel }
    "busy" { $vcolor + (Get-StillwaterSpinFrame $Style $SpinI) }
    default { $vcolor + $Style.Off }
  }
  $labelfg = if ($Job.State -in @("ok", "fail")) { $Style.Text } else { $Style.Muted }
  $tail = ""
  if ($ui.WBase -gt 0) { $tail += "  " + $Style.Muted + (Get-StillwaterPad $Job.BaseLabel $ui.WBase) }
  if ($Job.Next -and $ui.WNext -gt 0 -and $Job.State -in @("ok", "fail")) {
    $nextfg = if ($Job.State -eq "fail") { $Style.Error } else { $Style.Muted }
    $tail += "  " + $nextfg + (Get-StillwaterPad $Job.Next $ui.WNext).TrimEnd()
  }
  return ("{0}{1}{2}  {3}{2}  {4}{5}  {6}{7}{8}{2}" -f `
    $Style.Muted, $Style.Pipe, $Style.Reset, $mark, $labelfg, (Get-StillwaterPad $Job.Label $ui.WLabel), $vcolor, $verb, $tail)
}

function Get-StillwaterJobCounts($Jobs) {
  $c = [pscustomobject]@{ Done = 0; Busy = $false; Running = $false; Focus = -1 }
  for ($i = 0; $i -lt $Jobs.Count; $i++) {
    switch ($Jobs[$i].State) {
      { $_ -in @("busy", "pending") } {
        if ($_ -eq "busy") { $c.Busy = $true }
        $c.Running = $true
        if ($c.Focus -lt 0) { $c.Focus = $i }
      }
      default { $c.Done++ }
    }
  }
  return $c
}

function Get-StillwaterJobFooter($Style, $Jobs, $Counts, [string]$Summary) {
  if ($Counts.Running) {
    $bar = Get-StillwaterProgressBar $Counts.Done $Jobs.Count 24 $Counts.Busy
    return ("{0}{1}{2}  {3}{4}/{5}{2}  {6}{7}" -f $Style.Muted, $Style.Corner, $Style.Reset, $Style.Text, $Counts.Done, $Jobs.Count, $Style.Accent, $bar)
  }
  return ("{0}{1}{2}  {3}{4}" -f $Style.Muted, $Style.Corner, $Style.Reset, $Style.Text, $Summary)
}

function Write-StillwaterJobs($Style, $Jobs, [int]$SpinI, [string]$Summary = "") {
  $size = Get-StillwaterTermSize
  $key = "{0}x{1}" -f $size.Cols, $size.Lines
  if ($script:StillwaterJobsSize -ne $key) {
    Update-StillwaterJobsLayout $Jobs
    if (-not $script:StillwaterInline) { [Console]::Write($Style.Wipe) }
    $script:StillwaterJobsSize = $key
  }
  $ui = $script:StillwaterUi
  $counts = Get-StillwaterJobCounts $Jobs
  $mark = if ($counts.Running) { $Style.Accent + $Style.Diamond } else { $Style.AccentHover + $Style.Done }
  $lines = @(Get-StillwaterHeadLines $Style "install" $mark)
  # Inline, a list taller than the terminal shows only its progress line; the full
  # list prints once at the end. Clearing a full-screen frame would push it into
  # the scrollback.
  $script:StillwaterInlineCompact = $false
  if ($script:StillwaterInline -and ($Jobs.Count + 3) -ge $size.Lines) {
    $script:StillwaterInlineCompact = $true
    $line = Get-StillwaterJobFooter $Style $Jobs $counts $Summary
    if ($counts.Focus -ge 0) { $line += "  " + $Style.Muted + $Jobs[$counts.Focus].Label }
    $lines += $line
    Write-StillwaterFrame $Style $lines
    return
  }
  $ui.Follow = $true
  Update-StillwaterView $Jobs.Count $counts.Focus
  if ($ui.More) { $lines += Get-StillwaterMoreLine $Style $ui.ViewFirst "↑" }
  for ($i = $ui.ViewFirst; $i -le $ui.ViewLast; $i++) {
    $lines += Get-StillwaterJobRow $Style $Jobs[$i] $SpinI
  }
  if ($ui.More) { $lines += Get-StillwaterMoreLine $Style ($Jobs.Count - 1 - $ui.ViewLast) "↓" }
  $lines += Get-StillwaterJobFooter $Style $Jobs $counts $Summary
  Write-StillwaterFrame $Style $lines
}

# Prints the finished install once to the normal screen, every row, no viewport.
function Write-StillwaterJobsFinal($Style, $Jobs, [string]$Summary) {
  Update-StillwaterJobsLayout $Jobs
  $counts = Get-StillwaterJobCounts $Jobs
  Write-Host ("{0}{1}{2}  {3}Stillwater{2}  {4}{5}  {6}{2}" -f $Style.Muted, $Style.Start, $Style.Reset, $Style.Accent, $Style.Warm, (Get-StillwaterOsLabel), (Get-StillwaterVersion))
  Write-Host ("{0}{1}{2}  {3}install{2}" -f $Style.AccentHover, $Style.Done, $Style.Reset, $Style.Text)
  foreach ($job in $Jobs) {
    Write-Host (Get-StillwaterJobRow $Style $job 0)
  }
  Write-Host ((Get-StillwaterJobFooter $Style $Jobs $counts $Summary) + $Style.Reset)
}

# Named installs show a count while the adapters answer; the rows come with
# the progress. Returns when the job is done.
function Show-StillwaterLoading($Job, [int]$Total) {
  if (-not $script:StillwaterLoadingStyle) {
    Enable-StillwaterVirtualTerminal
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
    $script:StillwaterLoadingStyle = Get-StillwaterPickerStyle
    New-StillwaterUi
  }
  $style = $script:StillwaterLoadingStyle
  $spin = 0
  while ($true) {
    $done = @($Job.ChildJobs | Where-Object { $_.State -eq "Completed" -or $_.State -eq "Failed" }).Count
    $script:StillwaterUi.Lines = (Get-StillwaterTermSize).Lines
    Set-StillwaterListHeight $script:StillwaterUi 1
    $mark = Get-StillwaterSpinFrame $style $spin
    $lines = @(Get-StillwaterHeadLines $style "install" ($style.Accent + $style.Diamond))
    $lines += "{0}{1}  {2}{3}{0} checking apps {4}/{5}" -f $style.Muted, $style.Corner, $style.AccentHover, $mark, $done, $Total
    Write-StillwaterFrame $style $lines
    if ($done -ge $Total -or $Job.State -ne "Running") { break }
    $spin++
    Start-Sleep -Milliseconds 50
  }
}

# Starts drawing frames inline on the normal screen.
function Start-StillwaterInline($Style) {
  $script:StillwaterInline = $true
  $script:StillwaterInlineN = 0
  [Console]::Write($Style.Hide)
  try { [Console]::CursorVisible = $false } catch { }
}

# Ends inline drawing. -Erase removes the last frame, otherwise it stays as output.
function Stop-StillwaterInline($Style, [switch]$Erase) {
  if (-not $script:StillwaterInline) { return }
  if ($Erase -and $script:StillwaterInlineN -gt 0) {
    $up = if ($script:StillwaterInlineN -gt 1) { "`e[{0}A" -f ($script:StillwaterInlineN - 1) } else { "" }
    [Console]::Write("`r" + $up + $Style.Eos)
  } elseif ($script:StillwaterInlineN -gt 0) {
    [Console]::Write("`n")
  }
  $script:StillwaterInline = $false
  $script:StillwaterInlineN = 0
  [Console]::Write($Style.Show)
  try { [Console]::CursorVisible = $true } catch { }
}
