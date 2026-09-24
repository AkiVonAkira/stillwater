#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="btop"
LABEL="btop"
SRC="$ROOT/btop/stillwater.theme"

detect_dirs() {
  printf '%s\n' "$XDG_CONFIG_HOME/btop" "$APPDATA/btop"
}

found() {
  if stillwater_any_cmd btop btop4win; then
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

config_dir() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done < <(detect_dirs)
  if [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/btop"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/btop"
  fi
}

dest_file() {
  printf '%s\n' "$(config_dir)/themes/stillwater.theme"
}

set_theme() {
  local conf="$1/btop.conf"
  local tmp
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 || ! -f "$conf" ]]; then
    return 0
  fi
  if grep -q '^color_theme[[:space:]]*=' "$conf"; then
    tmp="$(mktemp)"
    sed 's/^color_theme[[:space:]]*=.*/color_theme = "stillwater"/' "$conf" >"$tmp"
    mv "$tmp" "$conf"
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
    set_theme "$(config_dir)"
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
