#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="spicetify"
LABEL="Spicetify"

detect_dirs() {
  printf '%s\n' "$XDG_CONFIG_HOME/spicetify" "$APPDATA/spicetify"
}

found() {
  if stillwater_has_cmd spicetify; then
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
  if stillwater_has_cmd spicetify; then
    local cfg
    cfg="$(spicetify -c 2>/dev/null || true)"
    if [[ -n "$cfg" && -d "$(dirname "$cfg")" ]]; then
      printf '%s\n' "$(dirname "$cfg")/Themes/stillwater"
      return 0
    fi
  fi
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir/Themes/stillwater"
      return 0
    fi
  done < <(detect_dirs)
  if [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/spicetify/Themes/stillwater"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/spicetify/Themes/stillwater"
  fi
}

case "$ACTION" in
  status)
    if found; then
      printf '%s|%s|found\n' "$ID" "$LABEL"
    else
      printf '%s|%s|skip\n' "$ID" "$LABEL"
    fi
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$(dest_dir)"
    if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
      echo "would copy spicetify theme -> $dest" >&2
    else
      mkdir -p "$dest"
      cp -a "$ROOT/spicetify/color.ini" "$ROOT/spicetify/user.css" "$dest/"
    fi
    if stillwater_has_cmd spicetify; then
      stillwater_run spicetify config current_theme stillwater color_scheme stillwater || true
      stillwater_run spicetify apply || true
    fi
    printf '%s\n' "$dest"
    ;;
  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
