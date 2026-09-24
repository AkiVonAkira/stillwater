#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="ghostty"
LABEL="Ghostty"
SRC="$ROOT/ghostty/Stillwater"

detect_dirs() {
  printf '%s\n' \
    "$XDG_CONFIG_HOME/ghostty" \
    "$STILLWATER_SUPPORT/com.mitchellh.ghostty" \
    "$APPDATA/ghostty"
}

found() {
  if stillwater_has_cmd ghostty; then
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
  if [[ "$(stillwater_platform)" == darwin ]]; then
    printf '%s\n' "$STILLWATER_SUPPORT/com.mitchellh.ghostty"
  elif [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/ghostty"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/ghostty"
  fi
}

dest_file() {
  printf '%s\n' "$(config_dir)/themes/Stillwater"
}

set_theme() {
  local conf="$1/config"
  local tmp
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 || ! -f "$conf" ]]; then
    return 0
  fi
  if grep -q '^theme[[:space:]]*=' "$conf"; then
    tmp="$(mktemp)"
    sed 's/^theme[[:space:]]*=.*/theme = Stillwater/' "$conf" >"$tmp"
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
