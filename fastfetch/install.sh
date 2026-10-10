#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="fastfetch"
LABEL="fastfetch"
SRC="$ROOT/fastfetch/config.jsonc"

dest_file() {
  printf '%s\n' "$XDG_CONFIG_HOME/fastfetch/config.jsonc"
}

found() {
  if stillwater_has_cmd fastfetch; then
    return 0
  fi
  stillwater_any_dir "$XDG_CONFIG_HOME/fastfetch"
}

# Keep the first config we replace, such as Ryoku's, as config.jsonc.bak.
backup() {
  local dest="$1"
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 || ! -f "$dest" || -e "$dest.bak" ]]; then
    return 0
  fi
  if ! grep -q 'Stillwater fastfetch' "$dest"; then
    cp -a "$dest" "$dest.bak"
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
    backup "$dest"
    stillwater_copy_file "$SRC" "$dest"
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
