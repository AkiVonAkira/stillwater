#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="helix"
LABEL="Helix"
SRC="$ROOT/helix/themes/stillwater.toml"

detect_dirs() {
  printf '%s\n' "$XDG_CONFIG_HOME/helix" "$APPDATA/helix"
}

found() {
  if stillwater_any_cmd hx helix; then
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
      printf '%s\n' "$dir/themes/stillwater.toml"
      return 0
    fi
  done < <(detect_dirs)
  if [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/helix/themes/stillwater.toml"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/helix/themes/stillwater.toml"
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
    config="$(dirname "$(dirname "$dest")")/config.toml"
    if [[ -f "$config" && "${STILLWATER_DRY_RUN:-0}" != 1 ]]; then
      tmp="$(mktemp)"
      if grep -q '^theme[[:space:]]*=' "$config"; then
        sed 's/^theme[[:space:]]*=.*/theme = "stillwater"/' "$config" >"$tmp"
      else
        printf '%s\n' 'theme = "stillwater"' >"$tmp"
        cat "$config" >>"$tmp"
      fi
      mv "$tmp" "$config"
    fi
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
