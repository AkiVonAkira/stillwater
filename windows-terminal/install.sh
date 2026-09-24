#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="windows-terminal"
LABEL="Windows Terminal"
SRC="$ROOT/windows-terminal/stillwater.json"

detect_dirs() {
  printf '%s\n' \
    "$LOCALAPPDATA/Microsoft/Windows Terminal" \
    "$LOCALAPPDATA/Microsoft/Windows Terminal Preview"
}

found() {
  if stillwater_any_cmd wt windowsterminal windows-terminal; then
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
      printf '%s\n' "$dir/Fragments/Stillwater/stillwater.json"
      return 0
    fi
  done < <(detect_dirs)
  printf '%s\n' "$LOCALAPPDATA/Microsoft/Windows Terminal/Fragments/Stillwater/stillwater.json"
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
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
