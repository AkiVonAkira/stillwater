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

list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -q 'Stillwater' || fail "missing OS header"
printf '%s\n' "$list" | grep -q '1.0.0' || fail "list should show version"
printf '%s\n' "$list" | grep -q 'Cursor' || fail "missing Cursor row"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+skip' || fail "empty home should skip Cursor"
printf '%s\n' "$list" | grep -E -q 'Visual Studio Code[[:space:]]+skip' || fail "empty home should skip VS Code"

if err="$("$BASH_EXE" "$ROOT/install.sh" 2>&1)"; then
  fail "bare install without a terminal should fail"
fi
printf '%s\n' "$err" | grep -q -- '--all' || fail "bare install should mention --all"

mkdir -p "$TMP/.cursor"
list="$("$BASH_EXE" "$ROOT/install.sh" --list)"
printf '%s\n' "$list" | grep -E -q 'Cursor[[:space:]]+found' || fail "Cursor dir should count as found"
printf '%s\n' "$list" | grep -E -q 'Visual Studio Code[[:space:]]+skip' || fail "VS Code should stay skipped"

out="$("$BASH_EXE" "$ROOT/install.sh" --dry-run cursor)"
printf '%s\n' "$out" | grep -q 'would install  Cursor' || fail "dry-run should install found Cursor"
printf '%s\n' "$out" | grep -q 'skip  Visual Studio Code' && fail "dry-run cursor should not mention skipped VS Code"
[[ ! -d "$TMP/.cursor/extensions" ]] || fail "dry-run must not create Cursor dest"

out="$("$BASH_EXE" "$ROOT/install.sh" --all)"
printf '%s\n' "$out" | grep -q 'install  Cursor' || fail "--all should install found Cursor"
printf '%s\n' "$out" | grep -q 'skip  Visual Studio Code' || fail "--all should report skipped VS Code"
[[ -f "$TMP/.cursor/extensions/kayzel.stillwater-theme-1.0.0/package.json" ]] || fail "Cursor extension files missing"
grep -q 'kayzel.stillwater-theme' "$TMP/.cursor/extensions/extensions.json" || fail "Cursor should register Stillwater in extensions.json"

out="$("$BASH_EXE" "$ROOT/install.sh" cursor vscode)"
printf '%s\n' "$out" | grep -q 'install  Cursor' || fail "should install Cursor"
printf '%s\n' "$out" | grep -q 'skip  Visual Studio Code' || fail "should skip VS Code"

mkdir -p "$TMP/.vscode/extensions" "$TMP/.config/Code/User" "$TMP/AppData/Roaming/Code/User"
printf '%s\n' '{"kayzel.stillwater-theme-1.0.0":true}' >"$TMP/.vscode/extensions/.obsolete"
printf '%s\n' '[]' >"$TMP/.vscode/extensions/extensions.json"
feppz='{
    "workbench.colorTheme": "feppz!"
}'
printf '%s\n' "$feppz" >"$TMP/.config/Code/User/settings.json"
printf '%s\n' "$feppz" >"$TMP/AppData/Roaming/Code/User/settings.json"
out="$("$BASH_EXE" "$ROOT/install.sh" vscode)"
printf '%s\n' "$out" | grep -q 'install  Visual Studio Code' || fail "should install VS Code"
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
printf '%s\n' "$out" | grep -q 'install  Vencord' || fail "should install Vencord"
theme="$TMP/.config/vesktop/themes/Stillwater.theme.css"
[[ -f "$theme" ]] || fail "Vencord theme missing"
grep -q "midnight-discord" "$theme" || fail "Vencord theme should be a midnight flavor"
grep -q "#5aa8b4" "$theme" || fail "Vencord theme should map Stillwater accent"

mkdir -p "$TMP/.config/spicetify"
out="$("$BASH_EXE" "$ROOT/install.sh" spicetify)"
printf '%s\n' "$out" | grep -q 'install  Spicetify' || fail "should install Spicetify"
dest="$TMP/.config/spicetify/Themes/stillwater"
[[ -f "$dest/color.ini" && -f "$dest/user.css" && -f "$dest/theme.js" ]] || fail "Spicetify theme files missing"
grep -q "astromations/hazy" "$dest/user.css" || fail "Spicetify CSS should import Hazy"
grep -q "5aa8b4" "$dest/color.ini" || fail "Spicetify colors should map Stillwater accent"

echo "ok"
