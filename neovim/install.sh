#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="neovim"
LABEL="Neovim"

detect_dirs() {
  printf '%s\n' "$XDG_CONFIG_HOME/nvim" "$LOCALAPPDATA/nvim" "$XDG_DATA_HOME/nvim" "$LOCALAPPDATA/nvim-data"
}

found() {
  if stillwater_any_cmd nvim; then
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

plugin_dest() {
  if [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$LOCALAPPDATA/nvim-data/site/pack/kayzel/start/stillwater"
  else
    printf '%s\n' "$XDG_DATA_HOME/nvim/site/pack/kayzel/start/stillwater"
  fi
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    dest="$(plugin_dest)"
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(stillwater_payload_state \
      "$ROOT/neovim/colors/stillwater.lua" "$dest/colors/stillwater.lua" \
      "$ROOT/neovim/lua/stillwater/init.lua" "$dest/lua/stillwater/init.lua")" \
      "$dest"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$(plugin_dest)"
    stillwater_copy_file "$ROOT/neovim/colors/stillwater.lua" "$dest/colors/stillwater.lua"
    stillwater_copy_file "$ROOT/neovim/lua/stillwater/init.lua" "$dest/lua/stillwater/init.lua"
    printf '%s\n' "$dest"
    ;;
  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
