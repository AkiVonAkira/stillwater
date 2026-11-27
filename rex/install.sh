#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="rex"
LABEL="Rex"
SRC="$ROOT/rex/stillwater.ini"
# Rex for Windows. Rex for Mac imports ghostty/Stillwater under Settings, Themes.
DIR="$LOCALAPPDATA/Superlogical/Rex"

dest_file() {
  printf '%s\n' "$DIR/palettes/stillwater.ini"
}

# Rex reads palettes from the palettes folder next to config.ini, by file name. Its config.ini
# has a global section first, so the two keys go there, never after a [section] line. Without
# use_system_accent_color = false the Windows accent replaces Stillwater's.
set_palette() {
  local conf="$DIR/config.ini"
  local tmp
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 || ! -f "$conf" ]]; then
    return 0
  fi
  tmp="$(mktemp)"
  awk '
    function put(i) { print key[i] " = " val[i]; done[i] = 1 }
    function rest(i) { for (i = 1; i <= 2; i++) if (!done[i]) put(i) }
    BEGIN {
      key[1] = "dark_theme_color_palette"; val[1] = "stillwater"
      key[2] = "use_system_accent_color"; val[2] = "false"
      global = 1
    }
    global && /^[[:space:]]*\[/ { rest(); global = 0 }
    global {
      line = $0
      sub(/\r$/, "", line)
      for (i = 1; i <= 2; i++) {
        if (!done[i] && line ~ ("^[[:space:]]*#?[[:space:]]*" key[i] "[[:space:]]*=")) { put(i); next }
      }
    }
    { print }
    END { if (global) rest() }
  ' "$conf" >"$tmp"
  mv "$tmp" "$conf"
}

case "$ACTION" in
  status)
    app="skip"
    if [[ -d "$DIR" ]]; then
      app="found"
    fi
    dest="$(dest_file)"
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(stillwater_copy_state "$SRC" "$dest")" "$dest"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$(dest_file)"
    stillwater_copy_file "$SRC" "$dest"
    set_palette
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
