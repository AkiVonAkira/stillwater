#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="zed"
LABEL="Zed"
THEME_SRC="$ROOT/zed/themes/stillwater.json"

detect_dirs() {
  printf '%s\n' "$XDG_CONFIG_HOME/zed" "$HOME/.zed" "$STILLWATER_SUPPORT/Zed" "$APPDATA/Zed"
}

found() {
  if stillwater_any_cmd zed zeditor; then
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

theme_dest() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir/themes/stillwater.json"
      return 0
    fi
  done < <(detect_dirs)
  if [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/Zed/themes/stillwater.json"
  elif [[ "$(stillwater_platform)" == darwin ]]; then
    printf '%s\n' "$STILLWATER_SUPPORT/Zed/themes/stillwater.json"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/zed/themes/stillwater.json"
  fi
}

ext_dest() {
  case "$(stillwater_platform)" in
    windows) printf '%s\n' "$LOCALAPPDATA/Zed/extensions/installed/stillwater" ;;
    darwin) printf '%s\n' "$STILLWATER_SUPPORT/Zed/extensions/installed/stillwater" ;;
    *) printf '%s\n' "$XDG_DATA_HOME/zed/extensions/installed/stillwater" ;;
  esac
}

install_extension() {
  local dest
  dest="$(ext_dest)"
  stillwater_copy_file "$ROOT/zed/extension.toml" "$dest/extension.toml"
  stillwater_copy_file "$THEME_SRC" "$dest/themes/stillwater.json"
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    dest="$(theme_dest)"
    ext="$(ext_dest)"
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(stillwater_payload_state \
      "$THEME_SRC" "$dest" \
      "$ROOT/zed/extension.toml" "$ext/extension.toml" \
      "$THEME_SRC" "$ext/themes/stillwater.json")" \
      "$dest" "$ext/extension.toml" "$ext/themes/stillwater.json"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$(theme_dest)"
    stillwater_copy_file "$THEME_SRC" "$dest"
    install_extension
    settings="$(dirname "$(dirname "$dest")")/settings.json"
    if [[ -f "$settings" ]] && grep -q '"theme"[[:space:]]*:[[:space:]]*"' "$settings"; then
      if [[ "${STILLWATER_DRY_RUN:-0}" != 1 ]]; then
        tmp="$(mktemp)"
        sed 's/"theme"[[:space:]]*:[[:space:]]*"[^"]*"/"theme": "Stillwater"/' "$settings" >"$tmp"
        mv "$tmp" "$settings"
      fi
    fi
    printf '%s\n' "$dest"
    ;;
  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
