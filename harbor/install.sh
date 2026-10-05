#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="harbor"
LABEL="Harbor"
SRC="$ROOT/harbor/Stillwater.harborstyle"

# Harbor Style file. elevated is the same surface lift T3 uses.
# Harbor stores applied themes in WebView storage, so this copies the file
# into the app data themes folder. Import it under Settings, Theme & appearance.
# https://github.com/harborstremio/harbor/blob/main/src/lib/harborstyle.ts

data_dirs() {
  printf '%s\n' \
    "$XDG_DATA_HOME/app.harbor" \
    "$HOME/.var/app/site.harbor.Harbor/data/app.harbor" \
    "$STILLWATER_SUPPORT/app.harbor" \
    "$APPDATA/app.harbor"
}

install_dirs() {
  printf '%s\n' \
    "$LOCALAPPDATA/Harbor" \
    "/Applications/Harbor.app" \
    "$HOME/Applications/Harbor.app" \
    "$HOME/.var/app/site.harbor.Harbor"
}

any_dir() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      return 0
    fi
  done
  return 1
}

found() {
  if stillwater_has_cmd harbor; then
    return 0
  fi
  if any_dir < <(data_dirs); then
    return 0
  fi
  any_dir < <(install_dirs)
}

dest_file() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir/themes/Stillwater.harborstyle"
      return 0
    fi
  done < <(data_dirs)
  case "$(stillwater_platform)" in
    windows)
      printf '%s\n' "$APPDATA/app.harbor/themes/Stillwater.harborstyle"
      ;;
    darwin)
      printf '%s\n' "$STILLWATER_SUPPORT/app.harbor/themes/Stillwater.harborstyle"
      ;;
    *)
      printf '%s\n' "$XDG_DATA_HOME/app.harbor/themes/Stillwater.harborstyle"
      ;;
  esac
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
