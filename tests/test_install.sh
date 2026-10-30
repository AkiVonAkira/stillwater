#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASH_EXE="${BASH:-bash}"

NODE_BIN="$(command -v node || true)"
export STILLWATER_HOME="$TMP"
# T3 agent shells set T3CODE_HOME, which would point the T3 adapter at the real install.
unset T3CODE_HOME
export PATH="$TMP/bin:/usr/bin:/bin"
if [[ -n "$NODE_BIN" ]]; then
  export PATH="$(dirname "$NODE_BIN"):$PATH"
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

export STILLWATER_ROOT="$ROOT"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
# shellcheck source=../install/picker.sh
source "$ROOT/install/picker.sh"
stillwater_init_paths
version="$(stillwater_version)"
version_re="${version//./\\.}"
stillwater_picker_parse $'cursor|Cursor|found|none||/tmp/cursor\nvscode|Visual Studio Code|skip|none||\nhelix|Helix|found|current||\nzed|Zed|found|update|modified|/tmp/zed'
[[ "${SW_SELECTED[0]}" == 1 ]] || fail "install target should be preselected"
[[ "${SW_SELECTED[1]}" == 0 ]] || fail "missing app should stay off"
[[ "${SW_SELECTED[2]}" == 0 ]] || fail "up to date app should stay off"
[[ "${SW_SELECTED[3]}" == 1 ]] || fail "update target should be preselected"
[[ "${SW_DESTS[0]}" == /tmp/cursor ]] || fail "picker should keep dest paths"
if grep -E -q 'param\([^)]*\$home([, )])' "$ROOT/install.ps1"; then
  fail "nested install job must not bind \$home; HOME is read-only in a nested runspace"
fi
stillwater_picker_selectable found || fail "found should be selectable"
if stillwater_picker_selectable skip; then fail "skip should not be selectable"; fi
stillwater_picker_init_style
# Rows arrive while the picker is open: a re-sort keeps the user's toggles and
# the app under the cursor.
SW_IDS=()
stillwater_picker_merge $'zed|Zed|found|update||/tmp/zed'
SW_MOVED=0
SW_SELECTED[0]=0
stillwater_picker_merge $'cursor|Cursor|found|none||/tmp/c\nzed|Zed|found|update||/tmp/zed'
[[ "${SW_IDS[0]}" == cursor && "$SW_CURSOR" == 0 ]] || fail "before the user moves, the cursor should sit on the first app"
[[ "${SW_SELECTED[1]}" == 0 && "${SW_SELECTED[0]}" == 1 ]] || fail "a re-sort should keep a toggled-off row off and preselect the new one"
SW_CURSOR=1
SW_MOVED=1
stillwater_picker_merge $'btop|btop|found|none||/tmp/b\ncursor|Cursor|found|none||/tmp/c\nzed|Zed|found|update||/tmp/zed'
[[ "${SW_IDS[$SW_CURSOR]}" == zed ]] || fail "after the user moves, the cursor should stay on its app"
bar="$(stillwater_progress_bar 1 2 4 1)"
[[ "$bar" == $'██▒░' ]] || fail "progress bar should fill completed cells and mark the busy cell"
SW_COLS=40
SW_FOOTER_LINES=2
[[ "$(stillwater_keymap_select | wc -l)" -eq 2 ]] || fail "narrow terminals should wrap the keymap"
SW_COLS=120
SW_FOOTER_LINES=1
[[ "$(stillwater_keymap_select | wc -l)" -eq 1 ]] || fail "wide terminals should keep the keymap on one line"
unset SW_COLS SW_FOOTER_LINES
stillwater_picker_parse $'vencord|Vencord|found|current||/tmp/v|base=Base,midnight=Midnight,comfy=Comfy (Outdated)|midnight\nspicetify|Spicetify|skip|none||/tmp/s|base=Base,dribbblish=Dribbblish|dribbblish\ncursor|Cursor|found|none||/tmp/c'
[[ "$SW_HAS_BASES" == 1 ]] || fail "picker should notice base themes"
[[ "${SW_B_COUNT[0]}" == 3 && "${SW_B_SEL[0]}" == 1 ]] || fail "picker should start on the installed base"
[[ "${SW_B_COUNT[2]}" == 0 ]] || fail "apps without bases should have none"
[[ "${SW_SELECTED[0]}" == 0 ]] || fail "up to date row with bases should start off"
stillwater_picker_cycle_base 0 1 || fail "right should move the base"
[[ "$(stillwater_picker_base_key 0)" == comfy ]] || fail "right from Midnight is Comfy"
[[ "${SW_SELECTED[0]}" == 1 ]] || fail "changing the base should select the row"
stillwater_picker_theme_into t 0
[[ "$t" == switch ]] || fail "a new base on an installed app is a switch"
SW_STRIP_MODE=full
SW_W_STRIP=0
SW_ACCENT="<accent>" SW_ACCENT_DEEP="<deep>" SW_MUTED="<muted>" stillwater_picker_strip_into strip 0 1
[[ "$strip" == *"<deep>Midnight"* ]] || fail "on a switch the installed base should keep the Up to date color"
[[ "$strip" == *"<accent>Comfy (Outdated)"* ]] || fail "on a switch the chosen base should be the accent"
stillwater_picker_cycle_base 0 1
[[ "$(stillwater_picker_base_key 0)" == base ]] || fail "right from the last base wraps to the first"
stillwater_picker_cycle_base 0 1
[[ "${SW_SELECTED[0]}" == 0 ]] || fail "back on the installed base should restore the row's default"
if stillwater_picker_cycle_base 2 1; then fail "apps without bases should not cycle"; fi
SW_CURSOR=0
COLUMNS=200 LINES=40 stillwater_picker_layout
[[ "$SW_STRIP_MODE" == full ]] || fail "wide terminals should show every base"
stillwater_picker_strip_into strip 0 1
plain="$(printf '%s' "$strip" | sed 's/\x1b\[[0-9;]*m//g')"
[[ "$plain" == "[ Base / Midnight / Comfy (Outdated) ]" ]] || fail "base strip should list every base: $plain"
stillwater_picker_keymap_text="$(stillwater_keymap_select)"
printf '%s' "$stillwater_picker_keymap_text" | grep -q 'base' || fail "keymap should name the base keys when an app has bases"
COLUMNS=60 LINES=40 stillwater_picker_layout
[[ "$SW_STRIP_MODE" == tag ]] || fail "narrow terminals should show only the chosen base"
for cols in 30 60 90 200; do
  COLUMNS=$cols LINES=12 stillwater_picker_layout
  for i in 0 1 2; do
    stillwater_picker_row_into row "$i"
    plain="$(printf '%s' "$row" | sed 's/\x1b\[[0-9;]*m//g')"
    [[ ${#plain} -lt "$cols" ]] || fail "picker rows must not reach the last column at $cols cols"
  done
done
COLUMNS=80 LINES=8 stillwater_picker_layout
[[ $((SW_HEAD_LINES + SW_LIST_H + SW_FOOTER_LINES)) -le 8 ]] || fail "picker frame must fit the terminal height"
unset COLUMNS LINES
[[ "$(stillwater_display_path "$HOME/foo/bar")" == "~/foo/bar" ]] || fail "display path should use ~"
[[ "$(stillwater_display_path "$HOME/.t3/userdata/themes/stillwater.json")" == "~/.t3/userdata/themes" ]] || fail "display path should drop the file name"
[[ "$(stillwater_display_path "$HOME/.cursor/extensions/kayzel.stillwater-theme-$version")" == "~/.cursor/extensions" ]] || fail "display path should drop the extension folder name"
# Status reads an installed copy's stamp to tell an old version from a modified
# file. One file per stamp format; npm run version:check covers every file.
for file in vscode/package.json zed/extension.toml vencord/midnight/Stillwater.theme.css spicetify/color.ini kitty/Stillwater.conf; do
  [[ "$(stillwater_peek_version "$ROOT/$file")" == "$version" ]] || fail "status should read the version stamp in $file"
done
for base in base midnight system24 oldcord surcord; do
  [[ "$(stillwater_peek_base "$ROOT/vencord/$base/Stillwater.theme.css")" == "$base" ]] || fail "vencord $base file should stamp its base"
done
[[ "$(stillwater_base_label "base=Base,comfy=Comfy (Outdated)" comfy)" == "Comfy (Outdated)" ]] || fail "base label lookup"
stillwater_base_valid "base=Base,comfy=Comfy (Outdated)" comfy || fail "comfy is a valid base"
if stillwater_base_valid "base=Base" comfy; then fail "comfy is not in that spec"; fi
[[ "$(stillwater_peek_base "$ROOT/spicetify/dribbblish/user.css")" == dribbblish ]] || fail "spicetify dribbblish should stamp its base"
[[ "$(stillwater_peek_base "$ROOT/spicetify/base/user.css")" == base ]] || fail "spicetify base should stamp its base"
[[ -z "$(stillwater_peek_version "$ROOT/t3/stillwater.json")" ]] || fail "t3 schema version is not a theme stamp"
[[ -z "$(stillwater_status_note current "$version")" ]] || fail "current rows should omit the shared version"
[[ "$(stillwater_status_note update 0.0.1)" == "0.0.1 to $version" ]] || fail "behind apps should show old version to new version"
[[ "$(stillwater_status_note update "$version")" == Modified ]] || fail "same stamp with file drift is Modified"
[[ "$(stillwater_status_note update "")" == Modified ]] || fail "no dest stamp with file drift is Modified"

list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -q 'Stillwater' || fail "missing OS header"
printf '%s\n' "$list" | grep -qF "$version" || fail "list should show version"
printf '%s\n' "$list" | grep -q 'Cursor' || fail "missing Cursor row"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+skip' || fail "empty home should skip Cursor"
printf '%s\n' "$list" | grep -E -q 'Spotifast[[:space:]]+skip' || fail "empty home should skip Spotifast"
printf '%s\n' "$list" | grep -E -q 'Harbor[[:space:]]+skip' || fail "empty home should skip Harbor"
printf '%s\n' "$list" | grep -E -q 'Starship[[:space:]]+skip' || fail "empty home should skip Starship"
printf '%s\n' "$list" | grep -E -q 'Visual Studio Code[[:space:]]+skip' || fail "empty home should skip VS Code"
code_n="$(printf '%s\n' "$list" | grep -n 'Code - OSS' | head -n 1 | cut -d: -f1)"
cursor_n="$(printf '%s\n' "$list" | grep -n 'Cursor' | head -n 1 | cut -d: -f1)"
[[ "$code_n" -lt "$cursor_n" ]] || fail "missing apps should sort by name"

if err="$("$BASH_EXE" "$ROOT/install.sh" </dev/null 2>&1)"; then
  fail "bare install without a terminal should fail"
fi
printf '%s\n' "$err" | grep -q -- '--all' || fail "bare install should mention --all"

mkdir -p "$TMP/.cursor"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+found[[:space:]]+none' || fail "found Cursor should need install"
printf '%s\n' "$list" | grep -E -q 'Visual Studio Code[[:space:]]+skip[[:space:]]+none' || fail "VS Code should stay skipped"
cursor_n="$(printf '%s\n' "$list" | grep -n 'Cursor' | head -n 1 | cut -d: -f1)"
code_n="$(printf '%s\n' "$list" | grep -n 'Code - OSS' | head -n 1 | cut -d: -f1)"
[[ "$cursor_n" -lt "$code_n" ]] || fail "found apps should sort above missing ones"

out="$("$BASH_EXE" "$ROOT/install.sh" --dry-run cursor 2>&1)"
printf '%s\n' "$out" | grep -q 'Would install Cursor.' || fail "dry-run should install found Cursor"
printf '%s\n' "$out" | grep -q 'Skipped Visual Studio Code' && fail "dry-run cursor should not mention skipped VS Code"
printf '%s\n' "$out" | grep -q 'would copy' && fail "dry-run should not leak copy noise"
printf '%s\n' "$out" | grep -q 'would register' && fail "dry-run should not leak register noise"
printf '%s\n' "$out" | grep -q 'Color Theme' || fail "dry-run should show Cursor next step"
[[ ! -d "$TMP/.cursor/extensions" ]] || fail "dry-run must not create Cursor dest"

out="$("$BASH_EXE" "$ROOT/install.sh" --all)"
printf '%s\n' "$out" | grep -q 'Installed Cursor.' || fail "--all should install found Cursor"
printf '%s\n' "$out" | grep -q 'Skipped Visual Studio Code' && fail "--all should not list every skipped app"
printf '%s\n' "$out" | grep -q 'Color Theme' || fail "--all should show Cursor next step"
printf '%s\n' "$out" | grep -E -q 'Installed [1-9]' || fail "--all should summarize skipped apps"
printf '%s\n' "$out" | grep -q ' -> ' && fail "install status should not dump dest paths"
[[ -f "$TMP/.cursor/extensions/kayzel.stillwater-theme-$version/package.json" ]] || fail "Cursor extension files missing"
grep -q 'kayzel.stillwater-theme' "$TMP/.cursor/extensions/extensions.json" || fail "Cursor should register Stillwater in extensions.json"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
row="$(printf '%s\n' "$list" | grep -E 'Cursor[[:space:]]+found')"
printf '%s\n' "$row" | grep -E -q 'found[[:space:]]+current' || fail "installed Cursor should be current"
if printf '%s\n' "$row" | grep -E -q "found[[:space:]]+current[[:space:]]+$version_re"; then
  fail "current Cursor should not repeat the shared version"
fi
printf '%s\n' "$row" | grep -q '.cursor/extensions' || fail "list should show Cursor dest"

pkg="$TMP/.cursor/extensions/kayzel.stillwater-theme-$version/package.json"
printf '\n' >>"$pkg"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+found[[:space:]]+update[[:space:]]+Modified' || fail "edited Cursor theme should show update"
"$BASH_EXE" "$ROOT/install.sh" cursor >/dev/null
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+found[[:space:]]+current' || fail "reinstall should bring Cursor current"

rm -rf "$TMP/.cursor/extensions/kayzel.stillwater-theme-$version"
mkdir -p "$TMP/.cursor/extensions/kayzel.stillwater-theme-0.9.0"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q "Cursor[[:space:]]+found[[:space:]]+update[[:space:]]+0\.9\.0 to $version_re" || fail "old Cursor theme should show version update"
"$BASH_EXE" "$ROOT/install.sh" cursor >/dev/null

out="$("$BASH_EXE" "$ROOT/install.sh" cursor vscode)"
printf '%s\n' "$out" | grep -q 'Installed Cursor.' || fail "should install Cursor"
printf '%s\n' "$out" | grep -q 'Skipped Visual Studio Code' || fail "should skip VS Code"

mkdir -p "$TMP/.vscode/extensions" "$TMP/.config/Code/User" "$TMP/AppData/Roaming/Code/User"
printf '{"kayzel.stillwater-theme-%s":true}\n' "$version" >"$TMP/.vscode/extensions/.obsolete"
printf '%s\n' '[]' >"$TMP/.vscode/extensions/extensions.json"
feppz='{
    "workbench.colorTheme": "feppz!"
}'
printf '%s\n' "$feppz" >"$TMP/.config/Code/User/settings.json"
printf '%s\n' "$feppz" >"$TMP/AppData/Roaming/Code/User/settings.json"
out="$("$BASH_EXE" "$ROOT/install.sh" vscode)"
printf '%s\n' "$out" | grep -q 'Installed Visual Studio Code.' || fail "should install VS Code"
[[ -f "$TMP/.vscode/extensions/kayzel.stillwater-theme-$version/package.json" ]] || fail "VS Code extension files missing"
grep -q 'kayzel.stillwater-theme' "$TMP/.vscode/extensions/extensions.json" || fail "VS Code should register Stillwater in extensions.json"
if grep -qF "kayzel.stillwater-theme-$version\":true" "$TMP/.vscode/extensions/.obsolete"; then
  fail "VS Code should un-obsolete Stillwater"
fi
applied=0
for settings in "$TMP/.config/Code/User/settings.json" "$TMP/AppData/Roaming/Code/User/settings.json"; do
  if grep -q '"workbench.colorTheme": "Stillwater"' "$settings"; then
    applied=1
  fi
done
[[ "$applied" == 1 ]] || fail "VS Code should switch workbench.colorTheme to Stillwater"

mkdir -p "$TMP/.config/vesktop"
printf '%s\n' '{}' >"$TMP/.config/vesktop/settings.json"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Vesktop[[:space:]]+found[[:space:]]+none' || fail "Vesktop-only should label as Vesktop"
if printf '%s\n' "$list" | grep -q 'Vencord /'; then fail "Vencord should not appear unless Vencord itself is installed"; fi
mkdir -p "$TMP/.config/equibop/themes"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
if printf '%s\n' "$list" | grep -E -q 'Equibop[[:space:]]+found'; then fail "a leftover equibop themes dir is not Equibop"; fi
if printf '%s\n' "$list" | grep -E -q 'Equicord[[:space:]]+found'; then fail "a leftover equibop themes dir is not Equicord"; fi
rm -rf "$TMP/.config/vesktop" "$TMP/.config/equibop"
mkdir -p "$TMP/.config/Vencord"
printf '%s\n' '{}' >"$TMP/.config/Vencord/settings.json"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Vencord[[:space:]]+found[[:space:]]+none' || fail "Vencord-only should label as Vencord"
if printf '%s\n' "$list" | grep -q 'Vencord / Vesktop'; then fail "Vesktop should not appear until it is installed"; fi
mkdir -p "$TMP/.config/vesktop"
printf '%s\n' '{}' >"$TMP/.config/vesktop/settings.json"
out="$("$BASH_EXE" "$ROOT/install.sh" vencord)"
printf '%s\n' "$out" | grep -q 'Installed Vencord' || fail "should install Vencord"
theme="$TMP/.config/vesktop/themes/Stillwater.theme.css"
[[ -f "$theme" ]] || fail "Vencord theme missing"
grep -q "midnight-discord" "$theme" || fail "Vencord theme should be a midnight flavor"
grep -q "#5aa8b4" "$theme" || fail "Vencord theme should map Stillwater accent"
grep -q "improvedSpotifyControls" "$theme" || fail "Vencord theme should import Akira Spotify panel snippet"
grep -q "IconConsistencySource" "$theme" || fail "Vencord theme should import plugin icon consistency"
grep -q "compact-server-shortcuts" "$theme" || fail "Vencord theme should import compact server shortcuts"
grep -q "SimplifiedPanelArea" "$theme" || fail "Vencord theme should import Simplified Panel Area"
if grep -q "ImageViewerTweaks" "$theme"; then fail "Vencord theme should not import Image Viewer Tweaks"; fi
grep -Fq -- "--ics-full-album-art: false" "$theme" || fail "Vencord theme should not force ISOUL's album-art square"
grep -Fq -- "wrapper_e131a9:not(:has(.rtcConnectionStatus__06d62))" "$theme" || fail "Vencord theme should hide the empty voice wrapper"
grep -Fq "overflow: visible !important" "$theme" || fail "Vencord theme should not clip Spotify hover controls"
grep -Fq "var(--radius-lg) var(--radius-lg) 0 0" "$theme" || fail "Vencord theme should match midnight panel corner radius"
grep -Fq ".vc-spotify-progress-time" "$theme" || fail "Vencord theme should keep Spotify duration visible"
grep -Fq 'content: none !important' "$theme" || fail "Vencord theme should not render a slash between Spotify times"
grep -Fq "#vc-spotify-album-title" "$theme" || fail "Vencord theme should hide Spotify album metadata"
grep -q "custom-channel-textarea-text-area-height" "$theme" || fail "Vencord theme should align the chat box with the user panel"
if grep -Fq '[class*="container_"]' "$theme"; then fail "Vencord theme should not use global container :has() selectors"; fi
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
row="$(printf '%s\n' "$list" | grep 'Vencord / Vesktop')"
printf '%s\n' "$row" | grep -E -q 'found[[:space:]]+current' || fail "installed Vencord should be current"
if printf '%s\n' "$row" | grep -E -q "found[[:space:]]+current[[:space:]]+$version_re"; then
  fail "current Vencord should not repeat the shared version"
fi
tmpcss="$(mktemp)"
sed "s/@version $version/@version 0.9.0/" "$theme" >"$tmpcss"
mv "$tmpcss" "$theme"
vencord_theme="$TMP/.config/Vencord/themes/Stillwater.theme.css"
if [[ -f "$vencord_theme" ]]; then
  sed "s/@version $version/@version 0.9.0/" "$vencord_theme" >"$tmpcss"
  mv "$tmpcss" "$vencord_theme"
fi
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q "Vencord / Vesktop[[:space:]]+found[[:space:]]+update[[:space:]]+0\.9\.0 to $version_re" || fail "old Vencord stamp should show version update"
"$BASH_EXE" "$ROOT/install.sh" vencord >/dev/null
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Vencord / Vesktop[[:space:]]+found[[:space:]]+current[[:space:]]+midnight' || fail "Vencord should default to the Midnight base"
out="$("$BASH_EXE" "$ROOT/install.sh" vencord:base)"
printf '%s\n' "$out" | grep -q 'Installed Vencord / Vesktop on Base.' || fail "should install Vencord on Base: $out"
grep -q '@base base' "$vencord_theme" || fail "Base should be installed"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Vencord / Vesktop[[:space:]]+found[[:space:]]+current[[:space:]]+base' || fail "installed Base should be current on base"
"$BASH_EXE" "$ROOT/install.sh" vencord >/dev/null
grep -q '@base base' "$vencord_theme" || fail "a bare reinstall should keep the installed base"
if grep -q '@import' "$vencord_theme"; then fail "Base should not load anything at runtime"; fi
if grep -q '@container' "$vencord_theme"; then fail "Base colors should not hide behind a container query"; fi
grep -Fq -- '--background-base-low: var(--bg-4)' "$vencord_theme" || fail "Base should map Discord's surfaces"
grep -Fq '.theme-midnight:not(.custom-user-profile-theme)' "$vencord_theme" || fail "Base should cover Discord's Onyx theme"
if grep -E -q ':\s*(lime|magenta)\s*;' "$vencord_theme"; then fail "Base should drop midnight's placeholder colors"; fi
"$BASH_EXE" "$ROOT/install.sh" vencord:midnight >/dev/null
grep -q 'RoundedDiscord, radius rules only' "$vencord_theme" || fail "Midnight should round its corners with RoundedDiscord"
if sed -n '/RoundedDiscord, radius rules only/,$p' "$vencord_theme" | grep -E -q '^[[:space:]]*(margin|padding|width|height)'; then fail "RoundedDiscord on Midnight should only round corners, not move panels"; fi
if sed -n '/RoundedDiscord, radius rules only/,$p' "$vencord_theme" | grep -E -q '\.(chat_f75fb0|sidebar__5e434|page__5e434)'; then fail "RoundedDiscord should leave Midnight's panels alone"; fi
grep -Fq -- '--radius: 16px' "$vencord_theme" || fail "Midnight should set RoundedDiscord's radius"
if grep -q 'form_f75fb0 > .base_b88801' "$vencord_theme"; then fail "the typing row must stay absolute so it does not push the chat up"; fi
if sed -n '/RoundedDiscord, radius rules only/,$p' "$vencord_theme" | grep -E -q '^\.(header_f37cb1|sidebarListRounded__5e434),'; then fail "RoundedDiscord should leave the server header and channel list to Midnight"; fi
grep -Fq '.bannerVisible_f37cb1 .header_f37cb1' "$vencord_theme" || fail "Midnight should match the banner header corners to the channel list"
for pair in "system24|system24/build/system24.css" "oldcord|milbits.github.io/oldcord/src/main.css" "surcord|surCord/src/source.css"; do
  key="${pair%%|*}"
  "$BASH_EXE" "$ROOT/install.sh" "vencord:$key" >/dev/null
  grep -q "@base $key" "$vencord_theme" || fail "$key should be installed"
  grep -q "${pair#*|}" "$vencord_theme" || fail "$key should load its theme"
  grep -qi '#5aa8b4' "$vencord_theme" || fail "$key should use the Stillwater accent"
  if [[ "$key" == system24 ]]; then
    grep -q SimplifiedPanelArea "$vencord_theme" || fail "system24 should hide panel buttons until hover"
  fi
done
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Vencord / Vesktop[[:space:]]+found[[:space:]]+current[[:space:]]+surcord' || fail "installed surCord should be current"
"$BASH_EXE" "$ROOT/install.sh" vencord:base >/dev/null
if err="$("$BASH_EXE" "$ROOT/install.sh" vencord:bogus 2>&1)"; then fail "unknown base should fail"; fi
printf '%s\n' "$err" | grep -q 'Unknown base for vencord: bogus' || fail "unknown base should name the base"
printf '%s\n' "$err" | grep -q 'midnight' || fail "unknown base should list the bases"
grep -v '@base' "$ROOT/vencord/midnight/Stillwater.theme.css" >"$vencord_theme"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Vencord / Vesktop[[:space:]]+found[[:space:]]+update[[:space:]]+Modified[[:space:]]+midnight' || fail "an unstamped install is the old Midnight theme"
"$BASH_EXE" "$ROOT/install.sh" vencord >/dev/null
grep -q '@base midnight' "$vencord_theme" || fail "updating an unstamped install should stamp Midnight"
if err="$("$BASH_EXE" "$ROOT/install.sh" cursor:dark 2>&1)"; then fail "a base on an app without bases should fail"; fi
printf '%s\n' "$err" | grep -q 'cursor has no base themes' || fail "should say cursor has no bases"

mkdir -p "$TMP/.config/spicetify"
out="$("$BASH_EXE" "$ROOT/install.sh" spicetify)"
printf '%s\n' "$out" | grep -q 'Installed Spicetify.' || fail "should install Spicetify"
printf '%s\n' "$out" | grep -q 'Restart Spotify.' || fail "Spicetify should tell you to restart Spotify"
printf '%s\n' "$out" | grep -qi 'spicetify apply' && fail "should not print spicetify apply output"
dest="$TMP/.config/spicetify/Themes/stillwater"
[[ -f "$dest/color.ini" && -f "$dest/user.css" && -f "$dest/theme.js" ]] || fail "Spicetify theme files missing"
grep -q "spicetify-themes@master/Dribbblish" "$dest/user.css" || fail "Spicetify CSS should import Dribbblish"
grep -q "Dribbblish/theme.js" "$dest/theme.js" || fail "Spicetify JS should load Dribbblish"
grep -q "5aa8b4" "$dest/color.ini" || fail "Spicetify colors should map Stillwater accent"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Spicetify[[:space:]]+found[[:space:]]+current[[:space:]]+dribbblish' || fail "Spicetify should default to Dribbblish"
out="$("$BASH_EXE" "$ROOT/install.sh" spicetify:base)"
printf '%s\n' "$out" | grep -q 'Installed Spicetify on Base.' || fail "should install Spicetify on Base"
[[ ! -f "$dest/theme.js" ]] || fail "Base should drop Dribbblish's theme.js"
grep -q '@base base' "$dest/user.css" || fail "Base user.css should be installed"
if grep -q 'Dribbblish/user.css' "$dest/user.css"; then fail "Base should not import Dribbblish"; fi
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Spicetify[[:space:]]+found[[:space:]]+current[[:space:]]+base' || fail "installed Base should be current"
"$BASH_EXE" "$ROOT/install.sh" spicetify:dribbblish >/dev/null
[[ -f "$dest/theme.js" ]] || fail "Dribbblish should bring theme.js back"
printf '%s\n' '/* Stillwater Spicetify adapter. Chrome from Dribbblish */' >"$dest/user.css"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Spicetify[[:space:]]+found[[:space:]]+update[[:space:]]+[^[:space:]]*.*dribbblish' || fail "an unstamped install is the old Dribbblish theme"
"$BASH_EXE" "$ROOT/install.sh" spicetify >/dev/null
grep -q '@base dribbblish' "$dest/user.css" || fail "updating an unstamped install should stamp Dribbblish"

mkdir -p "$TMP/.t3"
out="$("$BASH_EXE" "$ROOT/install.sh" t3)"
printf '%s\n' "$out" | grep -q 'Installed T3 Code.' || fail "should install T3"
[[ -f "$TMP/.t3/userdata/themes/stillwater.json" ]] || fail "T3 theme should be copied"
printf '%s\n' "$out" | grep -q 'Select Stillwater in T3 Code.' || fail "T3 next step"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'T3 Code[[:space:]]+found[[:space:]]+current' || fail "matching T3 theme file should be current"
printf 'x' >>"$TMP/.t3/userdata/themes/stillwater.json"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'T3 Code[[:space:]]+found[[:space:]]+update' || fail "edited T3 theme should show update"

mkdir -p "$TMP/.config/equibop"
printf '%s\n' '{}' >"$TMP/.config/equibop/settings.json"
out="$("$BASH_EXE" "$ROOT/install.sh" vencord)"
printf '%s\n' "$out" | grep -q 'Installed Vencord' || fail "reinstall Vencord should still work"
[[ ! -f "$TMP/.config/equibop/themes/Stillwater.theme.css" ]] || fail "Vencord install should not write Equibop"
out="$("$BASH_EXE" "$ROOT/install.sh" equicord)"
printf '%s\n' "$out" | grep -q 'Installed Equibop' || fail "should install Equibop on the Equicord picker"
[[ -f "$TMP/.config/equibop/themes/Stillwater.theme.css" ]] || fail "Equicord theme missing"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Equibop[[:space:]]+found[[:space:]]+current' || fail "installed Equibop should be its own row"
printf '%s\n' "$out" | grep -q 'Enable Stillwater in Equicord themes.' || fail "Equicord next step"

mkdir -p "$TMP/.config/obsidian" "$TMP/vault/.obsidian"
printf '%s\n' '{"vaults":{"t":{"path":"'"$TMP"'/vault"}}}' >"$TMP/.config/obsidian/obsidian.json"
out="$("$BASH_EXE" "$ROOT/install.sh" obsidian)"
printf '%s\n' "$out" | grep -q 'Installed Obsidian.' || fail "should install Obsidian"
[[ -f "$TMP/vault/.obsidian/themes/Stillwater/theme.css" ]] || fail "Obsidian theme.css missing"
[[ -f "$TMP/vault/.obsidian/themes/Stillwater/manifest.json" ]] || fail "Obsidian manifest missing"
grep -q '"cssTheme": "Stillwater"' "$TMP/vault/.obsidian/appearance.json" || fail "Obsidian should select Stillwater"
grep -q "#5aa8b4" "$TMP/vault/.obsidian/themes/Stillwater/theme.css" || fail "Obsidian theme should map Stillwater accent"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Obsidian[[:space:]]+found[[:space:]]+current' || fail "installed Obsidian should be current"

mkdir -p "$TMP/.local/share/PrismLauncher"
out="$("$BASH_EXE" "$ROOT/install.sh" prism)"
printf '%s\n' "$out" | grep -q 'Installed Prism Launcher.' || fail "should install Prism Launcher"
[[ -f "$TMP/.local/share/PrismLauncher/themes/Stillwater/theme.json" ]] || fail "Prism theme.json missing"
[[ -f "$TMP/.local/share/PrismLauncher/themes/Stillwater/themeStyle.css" ]] || fail "Prism themeStyle.css missing"
grep -q '"widgets": "windows11"' "$TMP/.local/share/PrismLauncher/themes/Stillwater/theme.json" || fail "Prism should use the Windows 11 widget style"
grep -q "#5aa8b4" "$TMP/.local/share/PrismLauncher/themes/Stillwater/theme.json" || fail "Prism theme should map Stillwater accent"

mkdir -p "$TMP/.config/yasb"
printf '%s\n' ':root {
  --background: #ff00ff;
  --text: #00ff00;
  --accent: #0000ff;
}
.yasb-bar {
  padding: 99px;
  background-color: var(--background);
}' >"$TMP/.config/yasb/styles.css"
out="$("$BASH_EXE" "$ROOT/install.sh" yasb)"
printf '%s\n' "$out" | grep -q 'Installed YASB.' || fail "should install YASB"
grep -q 'padding: 99px' "$TMP/.config/yasb/styles.css" || fail "YASB should keep layout CSS"
grep -q 'background-color: var(--background)' "$TMP/.config/yasb/styles.css" || fail "YASB should keep layout var() use"
grep -q -- '--background: #1d2021' "$TMP/.config/yasb/styles.css" || fail "YASB should patch background regardless of the old hex"
grep -q -- '--text: #ebdbb2' "$TMP/.config/yasb/styles.css" || fail "YASB should patch text regardless of the old hex"
grep -q -- '--accent: #5aa8b4' "$TMP/.config/yasb/styles.css" || fail "YASB should patch accent regardless of the old hex"
if grep -q '#ff00ff' "$TMP/.config/yasb/styles.css"; then fail "YASB should not leave the old background hex"; fi
printf '%s\n' ':root {
  --base: #11111b;
  --blue: #89b4fa;
}
.widget { margin: 7px; }' >"$TMP/.config/yasb/styles.css"
"$BASH_EXE" "$ROOT/install.sh" yasb >/dev/null
grep -q 'margin: 7px' "$TMP/.config/yasb/styles.css" || fail "YASB should keep a different theme layout"
grep -q -- '--base: #1d2021' "$TMP/.config/yasb/styles.css" || fail "YASB should map --base by name"
grep -q -- '--blue: #5aa8b4' "$TMP/.config/yasb/styles.css" || fail "YASB should map --blue by name"
printf '%s\n' ':root {
  --base: #11111b;
}
.yasb-bar {
  padding: 12px;
  background-color: #1e1e2e;
  color: #cdd6f4;
}
.media-menu .source.spotify {
  background-color: #199143;
}
.icon { color: rgb(203, 166, 247); }' >"$TMP/.config/yasb/styles.css"
"$BASH_EXE" "$ROOT/install.sh" yasb >/dev/null
grep -q 'padding: 12px' "$TMP/.config/yasb/styles.css" || fail "YASB should keep hardcoded-theme layout"
grep -q 'background-color: #1d2021' "$TMP/.config/yasb/styles.css" || fail "YASB should patch mocha bar fill"
grep -q 'color: #ebdbb2' "$TMP/.config/yasb/styles.css" || fail "YASB should patch mocha bar text"
grep -q 'background-color: #199143' "$TMP/.config/yasb/styles.css" || fail "YASB should keep Spotify brand color"
grep -q 'color: rgb(174, 129, 255)' "$TMP/.config/yasb/styles.css" || fail "YASB should patch mocha rgb() literals"
if grep -q '#1e1e2e' "$TMP/.config/yasb/styles.css"; then fail "YASB should not leave mocha base hex in widget CSS"; fi
if grep -q '#cdd6f4' "$TMP/.config/yasb/styles.css"; then fail "YASB should not leave mocha text hex in widget CSS"; fi

rm -rf "$TMP/.config/kitty"
mkdir -p "$TMP/.config/kitty"
printf '%s\n' 'background #000000' >"$TMP/.config/kitty/current-theme.conf"
printf '%s\n' 'include current-theme.conf' >"$TMP/.config/kitty/kitty.conf"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Kitty[[:space:]]+found[[:space:]]+none' || fail "foreign current-theme.conf is not a Stillwater dest"
printf '%s\n' 'font_size 11' >"$TMP/.config/kitty/kitty.conf"
rm -f "$TMP/.config/kitty/current-theme.conf"
rm -f "$TMP/.config/kitty/themes/Stillwater.conf"
out="$("$BASH_EXE" "$ROOT/install.sh" kitty)"
printf '%s\n' "$out" | grep -q 'Installed Kitty.' || fail "should install Kitty"
[[ -f "$TMP/.config/kitty/themes/Stillwater.conf" ]] || fail "Kitty theme missing"
grep -q 'themes/Stillwater.conf' "$TMP/.config/kitty/kitty.conf" || fail "Kitty config should include Stillwater"
grep -q "#5aa8b4" "$TMP/.config/kitty/themes/Stillwater.conf" || fail "Kitty theme should map Stillwater accent"

# Ryoku re-renders current-theme.conf, so Stillwater goes in user.conf.
printf '%s\n' 'include current-theme.conf' 'globinclude user.conf' >"$TMP/.config/kitty/kitty.conf"
printf '%s\n' 'background #000000' >"$TMP/.config/kitty/current-theme.conf"
"$BASH_EXE" "$ROOT/install.sh" kitty >/dev/null
"$BASH_EXE" "$ROOT/install.sh" kitty >/dev/null
[[ "$(grep -c 'themes/Stillwater.conf' "$TMP/.config/kitty/user.conf")" == 1 ]] || fail "Ryoku kitty should include Stillwater once in user.conf"
grep -q '#000000' "$TMP/.config/kitty/current-theme.conf" || fail "Ryoku kitty should leave current-theme.conf to matugen"
if [[ "$(stillwater_platform)" == linux ]]; then
  mkdir -p "$TMP/.config/fish" "$TMP/.local/share/ryoku"
  printf '%s\n' 'set -g foo bar' >"$TMP/.config/fish/user.fish"
  "$BASH_EXE" "$ROOT/install.sh" ryoku >/dev/null
  "$BASH_EXE" "$ROOT/install.sh" ryoku >/dev/null
  grep -q 'fish_color_command 5aa8b4' "$TMP/.config/fish/stillwater.fish" || fail "Ryoku fish palette missing"
  [[ "$(grep -c 'stillwater.fish' "$TMP/.config/fish/user.fish")" == 1 ]] || fail "user.fish should source Stillwater once"
  grep -q 'set -g foo bar' "$TMP/.config/fish/user.fish" || fail "user.fish should keep the user's lines"
fi

mkdir -p "$TMP/.config/ghostty"
printf '%s\n' 'theme = something' >"$TMP/.config/ghostty/config"
out="$("$BASH_EXE" "$ROOT/install.sh" ghostty)"
printf '%s\n' "$out" | grep -q 'Installed Ghostty.' || fail "should install Ghostty"
[[ -f "$TMP/.config/ghostty/themes/Stillwater" ]] || fail "Ghostty theme missing"
grep -q '^theme = Stillwater$' "$TMP/.config/ghostty/config" || fail "Ghostty config should set Stillwater"
grep -q "#5aa8b4" "$TMP/.config/ghostty/themes/Stillwater" || fail "Ghostty theme should map Stillwater accent"
printf '%s\n' 'config-file = ryoku-colors' >"$TMP/.config/ghostty/config"
"$BASH_EXE" "$ROOT/install.sh" ghostty >/dev/null
grep -q '^config-file = ryoku-colors$' "$TMP/.config/ghostty/config" || fail "Ghostty should keep config-file includes"
if grep -q '^theme =' "$TMP/.config/ghostty/config"; then fail "Ghostty should not add theme = when absent"; fi

mkdir -p "$TMP/.config/btop"
printf '%s\n' 'color_theme = "Default"' >"$TMP/.config/btop/btop.conf"
out="$("$BASH_EXE" "$ROOT/install.sh" btop)"
printf '%s\n' "$out" | grep -q 'Installed btop.' || fail "should install btop"
[[ -f "$TMP/.config/btop/themes/stillwater.theme" ]] || fail "btop theme missing"
grep -q 'color_theme = "stillwater"' "$TMP/.config/btop/btop.conf" || fail "btop.conf should set stillwater"
grep -q "#5aa8b4" "$TMP/.config/btop/themes/stillwater.theme" || fail "btop theme should map Stillwater accent"
mkdir -p "$TMP/.config/fastfetch"
printf '%s\n' '{ "logo": { "type": "kitty-direct" } }' >"$TMP/.config/fastfetch/config.jsonc"
out="$("$BASH_EXE" "$ROOT/install.sh" fastfetch)"
printf '%s\n' "$out" | grep -q 'Installed fastfetch.' || fail "should install fastfetch"
grep -q 'Stillwater fastfetch' "$TMP/.config/fastfetch/config.jsonc" || fail "fastfetch config missing"
grep -q 'kitty-direct' "$TMP/.config/fastfetch/config.jsonc.bak" || fail "fastfetch should keep the replaced config"
grep -q '38;2;90;168;180' "$TMP/.config/fastfetch/config.jsonc" || fail "fastfetch keys should use Stillwater accent"

mkdir -p "$TMP/AppData/Local/Microsoft/Windows Terminal"
out="$("$BASH_EXE" "$ROOT/install.sh" windows-terminal)"
printf '%s\n' "$out" | grep -q 'Installed Windows Terminal.' || fail "should install Windows Terminal"
[[ -f "$TMP/AppData/Local/Microsoft/Windows Terminal/Fragments/Stillwater/stillwater.json" ]] || fail "Windows Terminal fragment missing"
grep -q '5AA8B4' "$TMP/AppData/Local/Microsoft/Windows Terminal/Fragments/Stillwater/stillwater.json" || fail "Windows Terminal scheme should map Stillwater accent"

mkdir -p "$TMP/Documents/PowerShell"
out="$("$BASH_EXE" "$ROOT/install.sh" starship)"
printf '%s\n' "$out" | grep -q 'Installed Starship.' || fail "should install Starship"
[[ -f "$TMP/.config/starship.toml" ]] || fail "starship.toml missing"
[[ -f "$TMP/Documents/PowerShell/Microsoft.PowerShell_profile.ps1" ]] || fail "PowerShell profile missing"
grep -q '#5aa8b4' "$TMP/.config/starship.toml" || fail "starship.toml should map Stillwater accent"
grep -q 'starship init powershell' "$TMP/Documents/PowerShell/Microsoft.PowerShell_profile.ps1" || fail "PowerShell profile should init starship"
grep -q 'fastfetch' "$TMP/Documents/PowerShell/Microsoft.PowerShell_profile.ps1" || fail "PowerShell profile should run fastfetch"
grep -q 'STILLWATER_FETCHED' "$TMP/Documents/PowerShell/Microsoft.PowerShell_profile.ps1" || fail "fetch should run once per terminal"
grep -q 'GetCommandLineArgs' "$TMP/Documents/PowerShell/Microsoft.PowerShell_profile.ps1" || fail "neofetch should skip scripted pwsh launches"
printf '%s\n' "$out" | grep -q 'Open a new PowerShell tab.' || fail "Starship next step"

case "$(stillwater_platform)" in
  windows) spotifast_cfg="$TMP/AppData/Roaming/paolino/spotifast/config" ;;
  darwin) spotifast_cfg="$TMP/Library/Application Support/me.paolino.spotifast" ;;
  *) spotifast_cfg="$TMP/.config/spotifast" ;;
esac
mkdir -p "$spotifast_cfg"
printf '%s\n' '{
  "volume": 37,
  "custom_theme": null
}' >"$spotifast_cfg/settings.json"
out="$("$BASH_EXE" "$ROOT/install.sh" spotifast)"
printf '%s\n' "$out" | grep -q 'Installed Spotifast.' || fail "should install Spotifast"
[[ -f "$spotifast_cfg/themes/stillwater.json" ]] || fail "Spotifast theme missing"
grep -q '#5aa8b4' "$spotifast_cfg/themes/stillwater.json" || fail "Spotifast theme should map Stillwater accent"
grep -q '"window": "#1d2021"' "$spotifast_cfg/themes/stillwater.json" || fail "Spotifast theme should map Stillwater canvas"
grep -q '"custom_theme": "stillwater.json"' "$spotifast_cfg/settings.json" || fail "Spotifast settings should select stillwater.json"
grep -q '"volume": 37' "$spotifast_cfg/settings.json" || fail "Spotifast settings should keep other preferences"
if grep -q '"version"' "$spotifast_cfg/themes/stillwater.json"; then fail "Spotifast palette files reject unknown fields"; fi

case "$(stillwater_platform)" in
  windows) harbor_data="$TMP/AppData/Roaming/app.harbor" ;;
  darwin) harbor_data="$TMP/Library/Application Support/app.harbor" ;;
  *) harbor_data="$TMP/.local/share/app.harbor" ;;
esac
mkdir -p "$harbor_data"
out="$("$BASH_EXE" "$ROOT/install.sh" harbor)"
printf '%s\n' "$out" | grep -q 'Installed Harbor.' || fail "should install Harbor"
[[ -f "$harbor_data/themes/Stillwater.harborstyle" ]] || fail "Harbor theme missing"
grep -q '#5aa8b4' "$harbor_data/themes/Stillwater.harborstyle" || fail "Harbor theme should map Stillwater accent"
grep -q '#1d2021' "$harbor_data/themes/Stillwater.harborstyle" || fail "Harbor theme should map Stillwater canvas"
grep -q 'name: Stillwater' "$harbor_data/themes/Stillwater.harborstyle" || fail "Harbor theme should be named Stillwater"
grep -q 'layout: sidebar' "$harbor_data/themes/Stillwater.harborstyle" || fail "Harbor theme should use the sidebar layout"
printf '%s\n' "$out" | grep -q 'Import Stillwater.harborstyle' || fail "Harbor next step"

echo "ok"
