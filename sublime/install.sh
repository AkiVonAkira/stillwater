#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="sublime"
LABEL="Sublime Text"
SRC="$ROOT/sublime/Stillwater.sublime-color-scheme"

detect_dirs() {
  printf '%s\n' \
    "$XDG_CONFIG_HOME/sublime-text" \
    "$XDG_CONFIG_HOME/sublime-text-3" \
    "$STILLWATER_SUPPORT/Sublime Text" \
    "$STILLWATER_SUPPORT/Sublime Text 3" \
    "$APPDATA/Sublime Text" \
    "$APPDATA/Sublime Text 3"
}

found() {
  if stillwater_any_cmd subl sublime_text; then
    return 0
  fi
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      return 0
    fi
  done < <(detect_dirs)
  return 1
}

dest_file() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir/Packages/Stillwater/Stillwater.sublime-color-scheme"
      return 0
    fi
  done < <(detect_dirs)
  if [[ "$(stillwater_platform)" == darwin ]]; then
    printf '%s\n' "$STILLWATER_SUPPORT/Sublime Text/Packages/Stillwater/Stillwater.sublime-color-scheme"
  elif [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/Sublime Text/Packages/Stillwater/Stillwater.sublime-color-scheme"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/sublime-text/Packages/Stillwater/Stillwater.sublime-color-scheme"
  fi
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
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
    prefs="$(dirname "$(dirname "$dest")")/User/Preferences.sublime-settings"
    if [[ -f "$prefs" && "${STILLWATER_DRY_RUN:-0}" != 1 ]] && grep -q '"color_scheme"' "$prefs"; then
      tmp="$(mktemp)"
      sed 's/"color_scheme"[[:space:]]*:[[:space:]]*"[^"]*"/"color_scheme": "Packages\/Stillwater\/Stillwater.sublime-color-scheme"/' "$prefs" >"$tmp"
      mv "$tmp" "$prefs"
    fi
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
