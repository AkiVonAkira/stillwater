#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="prism"
LABEL="Prism Launcher"
SRC="$ROOT/prism"

detect_dirs() {
  printf '%s\n' \
    "$XDG_DATA_HOME/PrismLauncher" \
    "$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher" \
    "$STILLWATER_SUPPORT/PrismLauncher" \
    "$APPDATA/PrismLauncher" \
    "$HOME/scoop/persist/prismlauncher"
}

found() {
  if stillwater_any_cmd prismlauncher prismlauncher-qt5; then
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

dest_dir() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir/themes/Stillwater"
      return 0
    fi
  done < <(detect_dirs)
  if [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/PrismLauncher/themes/Stillwater"
  elif [[ "$(stillwater_platform)" == darwin ]]; then
    printf '%s\n' "$STILLWATER_SUPPORT/PrismLauncher/themes/Stillwater"
  else
    printf '%s\n' "$XDG_DATA_HOME/PrismLauncher/themes/Stillwater"
  fi
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    dest="$(dest_dir)"
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(stillwater_payload_state \
      "$SRC/theme.json" "$dest/theme.json" \
      "$SRC/themeStyle.css" "$dest/themeStyle.css")" \
      "$dest"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$(dest_dir)"
    stillwater_copy_file "$SRC/theme.json" "$dest/theme.json"
    stillwater_copy_file "$SRC/themeStyle.css" "$dest/themeStyle.css"
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
