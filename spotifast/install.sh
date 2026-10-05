#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="spotifast"
LABEL="Spotifast"
SRC="$ROOT/spotifast/stillwater.json"

# Palette map, from palette.json. surface_hover is the same lift the
# Spicetify, T3, Zed, and Vencord adapters use. Spotifast rejects unknown
# fields, so this file stays a base plus those colour names.
# https://spotifast.rocks/settings-and-files/#custom-themes

config_candidates() {
  case "$(stillwater_platform)" in
    windows)
      printf '%s\n' "$APPDATA/paolino/spotifast/config"
      ;;
    darwin)
      printf '%s\n' "$STILLWATER_SUPPORT/me.paolino.spotifast"
      ;;
    *)
      printf '%s\n' \
        "$XDG_CONFIG_HOME/spotifast" \
        "$HOME/.var/app/rocks.spotifast.Spotifast/config/spotifast"
      ;;
  esac
}

config_dir() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
  done < <(config_candidates)
  config_candidates | head -n 1
}

app_installed() {
  case "$(stillwater_platform)" in
    windows)
      [[ -f "$LOCALAPPDATA/Programs/Spotifast/spotifast.exe" ]]
      ;;
    darwin)
      [[ -d "/Applications/Spotifast.app" || -d "$HOME/Applications/Spotifast.app" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

found() {
  if stillwater_any_cmd spotifast fastpotify; then
    return 0
  fi
  if app_installed; then
    return 0
  fi
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      return 0
    fi
  done < <(config_candidates)
  return 1
}

dest_file() {
  printf '%s\n' "$(config_dir)/themes/stillwater.json"
}

set_custom_theme() {
  local settings="$1/settings.json"
  local tmp
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    return 0
  fi
  if [[ ! -f "$settings" ]]; then
    printf '%s\n' '{
  "custom_theme": "stillwater.json"
}' >"$settings"
    return 0
  fi
  tmp="$(mktemp)"
  if grep -q '"custom_theme"' "$settings"; then
    sed -E 's/"custom_theme"[[:space:]]*:[[:space:]]*(null|"[^"]*")/"custom_theme": "stillwater.json"/' "$settings" >"$tmp"
  else
    awk 'BEGIN { done=0 }
      /{/ && done==0 { print; print "  \"custom_theme\": \"stillwater.json\","; done=1; next }
      { print }' "$settings" >"$tmp"
  fi
  mv "$tmp" "$settings"
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
    dir="$(config_dir)"
    dest="$(dest_file)"
    stillwater_copy_file "$SRC" "$dest"
    set_custom_theme "$dir"
    if stillwater_has_cmd spotifast; then
      stillwater_run spotifast reload-themes || true
    fi
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
