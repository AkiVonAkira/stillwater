#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="kitty"
LABEL="Kitty"
SRC="$ROOT/kitty/Stillwater.conf"

detect_dirs() {
  printf '%s\n' "$XDG_CONFIG_HOME/kitty" "$STILLWATER_SUPPORT/kitty" "$APPDATA/kitty"
}

found() {
  if stillwater_has_cmd kitty; then
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
    printf '%s\n' "$APPDATA/kitty"
  elif [[ "$(stillwater_platform)" == darwin ]]; then
    printf '%s\n' "$STILLWATER_SUPPORT/kitty"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/kitty"
  fi
}

dest_file() {
  printf '%s\n' "$(config_dir)/themes/Stillwater.conf"
}

apply_kitty() {
  local dir="$1"
  local conf="$dir/kitty.conf"
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    return 0
  fi
  if [[ -f "$dir/current-theme.conf" ]] || { [[ -f "$conf" ]] && grep -q 'current-theme.conf' "$conf"; }; then
    stillwater_copy_file "$SRC" "$dir/current-theme.conf"
    return 0
  fi
  if [[ -f "$conf" ]] && ! grep -q 'themes/Stillwater.conf' "$conf"; then
    printf '\ninclude themes/Stillwater.conf\n' >>"$conf"
  fi
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    dest="$(dest_file)"
    dir="$(config_dir)"
    pairs=("$SRC" "$dest")
    dests=("$dest")
    if [[ -f "$dest" && -f "$dir/current-theme.conf" ]]; then
      pairs+=("$SRC" "$dir/current-theme.conf")
      dests+=("$dir/current-theme.conf")
    fi
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(stillwater_payload_state "${pairs[@]}")" "${dests[@]}"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$(dest_file)"
    stillwater_copy_file "$SRC" "$dest"
    apply_kitty "$(config_dir)"
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
