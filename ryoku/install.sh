#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="ryoku"
LABEL="Ryoku"

FISH_SRC="$ROOT/ryoku/stillwater.fish"

# Ryoku's config.fish pins its own syntax colours and sources user.fish last.
apply_fish() {
  local dir="$XDG_CONFIG_HOME/fish"
  local user="$dir/user.fish"
  [[ -d "$dir" ]] || return 0
  stillwater_copy_file "$FISH_SRC" "$dir/stillwater.fish"
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    return 0
  fi
  if [[ ! -f "$user" ]] || ! grep -q 'stillwater.fish' "$user"; then
    printf '%s
' 'source $__fish_config_dir/stillwater.fish' >>"$user"
  fi
}

found() {
  if stillwater_has_cmd ryoku-shell; then
    return 0
  fi
  stillwater_any_dir "$XDG_CONFIG_HOME/ryoku" "$XDG_DATA_HOME/ryoku"
}

case "$ACTION" in
  status)
    if [[ "$(stillwater_platform)" != linux ]]; then
      stillwater_print_copy_status "$ID" "$LABEL" "n/a" "none" "$XDG_DATA_HOME/ryoku/themes/stillwater"
      exit 0
    fi
    app="skip"
    if found; then
      app="found"
    fi
    dest="$XDG_DATA_HOME/ryoku/themes/stillwater"
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(stillwater_payload_state \
      "$ROOT/ryoku/scheme.json" "$dest/scheme.json" \
      "$ROOT/ryoku/meta.json" "$dest/meta.json")" \
      "$dest"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$XDG_DATA_HOME/ryoku/themes/stillwater"
    if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
      printf '%s\n' "$dest"
      exit 0
    fi
    mkdir -p "$dest"
    cp -a "$ROOT/ryoku/scheme.json" "$ROOT/ryoku/meta.json" "$dest/"
    theme_json="$XDG_CONFIG_HOME/ryoku/theme.json"
    mkdir -p "$(dirname "$theme_json")"
    if [[ ! -f "$theme_json" ]]; then
      printf '%s\n' '{
  "followWallpaper": false
}' >"$theme_json"
    elif grep -q '"followWallpaper"' "$theme_json"; then
      tmp="$(mktemp)"
      sed 's/"followWallpaper"[[:space:]]*:[[:space:]]*[^,}[:space:]]*/"followWallpaper": false/' "$theme_json" >"$tmp"
      mv "$tmp" "$theme_json"
    fi
    apply_fish
    if stillwater_has_cmd ryoku-shell; then
      stillwater_run ryoku-shell theme stillwater || true
    fi
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
