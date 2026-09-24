#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASH_EXE="${BASH:-bash}"

NODE_BIN="$(command -v node || true)"
export STILLWATER_HOME="$TMP"
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
stillwater_picker_parse $'cursor|Cursor|found|none||/tmp/cursor\nvscode|Visual Studio Code|skip|none||\nhelix|Helix|found|current||\nzed|Zed|found|update|modified|/tmp/zed'
[[ "${SW_SELECTED[0]}" == 1 ]] || fail "install target should be preselected"
[[ "${SW_SELECTED[1]}" == 0 ]] || fail "missing app should stay off"
[[ "${SW_SELECTED[2]}" == 0 ]] || fail "up to date app should stay off"
[[ "${SW_SELECTED[3]}" == 1 ]] || fail "update target should be preselected"
[[ "${SW_DESTS[0]}" == /tmp/cursor ]] || fail "picker should keep dest paths"
[[ "$(stillwater_picker_action found none)" == Install ]] || fail "found+none is Install"
[[ "$(stillwater_picker_action skip none)" == "Not found" ]] || fail "skip is Not found"
[[ "$(stillwater_picker_action found current)" == "Up to date" ]] || fail "current label"
[[ "$(stillwater_picker_action found update)" == Update ]] || fail "update label"
[[ "$(stillwater_palette_hex accent)" == 5aa8b4 ]] || fail "picker colors should read palette.json"
stillwater_picker_selectable found || fail "found should be selectable"
if stillwater_picker_selectable skip; then fail "skip should not be selectable"; fi
stillwater_picker_init_style
[[ "$SW_ON" == "●" && "$SW_OFF" == "○" ]] || fail "picker selection should use circles"
[[ "$(stillwater_display_path "$HOME/foo/bar")" == "~/foo/bar" ]] || fail "display path should use ~"
[[ "$(stillwater_display_path "$HOME/.t3/userdata/themes/stillwater.json")" == "~/.t3/userdata/themes" ]] || fail "display path should drop the file name"
[[ "$(stillwater_display_path "$HOME/.cursor/extensions/kayzel.stillwater-theme-1.0.0")" == "~/.cursor/extensions" ]] || fail "display path should drop the extension folder name"
[[ "$(stillwater_next_step cursor)" == "Set Color Theme to Stillwater." ]] || fail "cursor next step"
[[ "$(stillwater_next_step zed)" == "Set the theme to Stillwater." ]] || fail "zed next step"
[[ "$(stillwater_next_step neovim)" == "Run :colorscheme stillwater." ]] || fail "neovim next step"
[[ "$(stillwater_next_step vencord)" == "Enable Stillwater in Vencord themes." ]] || fail "vencord next step"
[[ "$(stillwater_next_step spicetify)" == "Restart Spotify." ]] || fail "spicetify next step"
[[ "$(stillwater_peek_version "$ROOT/vscode/package.json")" == 1.0.0 ]] || fail "peek vscode package version"
[[ "$(stillwater_peek_version "$ROOT/zed/extension.toml")" == 1.0.0 ]] || fail "peek zed toml version"
[[ "$(stillwater_peek_version "$ROOT/vencord/Stillwater.theme.css")" == 1.0.0 ]] || fail "peek vencord @version"
[[ "$(stillwater_peek_version "$ROOT/spicetify/color.ini")" == 1.0.0 ]] || fail "peek spicetify ini version"
[[ -z "$(stillwater_peek_version "$ROOT/t3/stillwater.json")" ]] || fail "t3 schema version is not a theme stamp"
[[ -z "$(stillwater_status_note current 1.0.0)" ]] || fail "current rows should omit the shared version"
[[ "$(stillwater_status_note update 0.9.0)" == "0.9.0 to 1.0.0" ]] || fail "behind apps should show old version to new version"
[[ "$(stillwater_status_note update 1.0.0)" == Modified ]] || fail "same stamp with file drift is Modified"
[[ "$(stillwater_status_note update "")" == Modified ]] || fail "no dest stamp with file drift is Modified"

list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -q 'Stillwater' || fail "missing OS header"
printf '%s\n' "$list" | grep -q '1.0.0' || fail "list should show version"
printf '%s\n' "$list" | grep -q 'Cursor' || fail "missing Cursor row"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+skip' || fail "empty home should skip Cursor"
printf '%s\n' "$list" | grep -E -q 'Visual Studio Code[[:space:]]+skip' || fail "empty home should skip VS Code"
code_n="$(printf '%s\n' "$list" | grep -n 'Code - OSS' | head -n 1 | cut -d: -f1)"
cursor_n="$(printf '%s\n' "$list" | grep -n 'Cursor' | head -n 1 | cut -d: -f1)"
[[ "$code_n" -lt "$cursor_n" ]] || fail "missing apps should sort by name"

if err="$("$BASH_EXE" "$ROOT/install.sh" 2>&1)"; then
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
printf '%s\n' "$out" | grep -q 'Installed 1' || fail "--all should summarize skipped apps"
printf '%s\n' "$out" | grep -q ' -> ' && fail "install status should not dump dest paths"
[[ -f "$TMP/.cursor/extensions/kayzel.stillwater-theme-1.0.0/package.json" ]] || fail "Cursor extension files missing"
grep -q 'kayzel.stillwater-theme' "$TMP/.cursor/extensions/extensions.json" || fail "Cursor should register Stillwater in extensions.json"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
row="$(printf '%s\n' "$list" | grep -E 'Cursor[[:space:]]+found')"
printf '%s\n' "$row" | grep -E -q 'found[[:space:]]+current' || fail "installed Cursor should be current"
if printf '%s\n' "$row" | grep -E -q 'found[[:space:]]+current[[:space:]]+1\.0\.0'; then
  fail "current Cursor should not repeat the shared version"
fi
printf '%s\n' "$row" | grep -q '.cursor/extensions' || fail "list should show Cursor dest"

pkg="$TMP/.cursor/extensions/kayzel.stillwater-theme-1.0.0/package.json"
printf '\n' >>"$pkg"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+found[[:space:]]+update[[:space:]]+Modified' || fail "edited Cursor theme should show update"
"$BASH_EXE" "$ROOT/install.sh" cursor >/dev/null
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+found[[:space:]]+current' || fail "reinstall should bring Cursor current"

rm -rf "$TMP/.cursor/extensions/kayzel.stillwater-theme-1.0.0"
mkdir -p "$TMP/.cursor/extensions/kayzel.stillwater-theme-0.9.0"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+found[[:space:]]+update[[:space:]]+0\.9\.0 to 1\.0\.0' || fail "old Cursor theme should show version update"
"$BASH_EXE" "$ROOT/install.sh" cursor >/dev/null

out="$("$BASH_EXE" "$ROOT/install.sh" cursor vscode)"
printf '%s\n' "$out" | grep -q 'Installed Cursor.' || fail "should install Cursor"
printf '%s\n' "$out" | grep -q 'Skipped Visual Studio Code' || fail "should skip VS Code"

mkdir -p "$TMP/.vscode/extensions" "$TMP/.config/Code/User" "$TMP/AppData/Roaming/Code/User"
printf '%s\n' '{"kayzel.stillwater-theme-1.0.0":true}' >"$TMP/.vscode/extensions/.obsolete"
printf '%s\n' '[]' >"$TMP/.vscode/extensions/extensions.json"
feppz='{
    "workbench.colorTheme": "feppz!"
}'
printf '%s\n' "$feppz" >"$TMP/.config/Code/User/settings.json"
printf '%s\n' "$feppz" >"$TMP/AppData/Roaming/Code/User/settings.json"
out="$("$BASH_EXE" "$ROOT/install.sh" vscode)"
printf '%s\n' "$out" | grep -q 'Installed Visual Studio Code.' || fail "should install VS Code"
[[ -f "$TMP/.vscode/extensions/kayzel.stillwater-theme-1.0.0/package.json" ]] || fail "VS Code extension files missing"
grep -q 'kayzel.stillwater-theme' "$TMP/.vscode/extensions/extensions.json" || fail "VS Code should register Stillwater in extensions.json"
if grep -q 'kayzel.stillwater-theme-1.0.0":true' "$TMP/.vscode/extensions/.obsolete"; then
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
if printf '%s\n' "$row" | grep -E -q 'found[[:space:]]+current[[:space:]]+1\.0\.0'; then
  fail "current Vencord should not repeat the shared version"
fi
tmpcss="$(mktemp)"
sed 's/@version 1.0.0/@version 0.9.0/' "$theme" >"$tmpcss"
mv "$tmpcss" "$theme"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Vencord / Vesktop[[:space:]]+found[[:space:]]+update[[:space:]]+0\.9\.0 to 1\.0\.0' || fail "old Vencord stamp should show version update"
"$BASH_EXE" "$ROOT/install.sh" vencord >/dev/null

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

echo "ok"
