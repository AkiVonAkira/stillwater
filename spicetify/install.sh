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
BASES="base=Base,dribbblish=Dribbblish"
DEFAULT_BASE=dribbblish

# Installs from before base themes carry no stamp, and they were Dribbblish.
installed_base() {
  local css="$1/user.css" base
  if [[ ! -f "$css" ]]; then
    printf '%s\n' "$DEFAULT_BASE"
    return 0
  fi
  base="$(stillwater_peek_base "$css")"
  printf '%s\n' "${base:-dribbblish}"
}

# Base is color.ini and a stub user.css; Dribbblish adds its theme.js.
payload_state() {
  local dest="$1" base="$2"
  if [[ "$base" == dribbblish ]]; then
    stillwater_payload_state \
      "$ROOT/spicetify/color.ini" "$dest/color.ini" \
      "$ROOT/spicetify/dribbblish/user.css" "$dest/user.css" \
      "$ROOT/spicetify/dribbblish/theme.js" "$dest/theme.js"
  else
    stillwater_payload_state \
      "$ROOT/spicetify/color.ini" "$dest/color.ini" \
      "$ROOT/spicetify/$base/user.css" "$dest/user.css"
  fi
}

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
    app="skip"
    if found; then
      app="found"
    fi
    dest="$(dest_dir)"
    base="$(installed_base "$dest")"
    SW_STATUS_BASES="$BASES" SW_STATUS_BASE="$base" \
      stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(payload_state "$dest" "$base")" "$dest"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    base="${2:-$DEFAULT_BASE}"
    if ! stillwater_base_valid "$BASES" "$base"; then
      echo "Unknown base: $base" >&2
      exit 1
    fi
    js=0
    if [[ "$base" == dribbblish ]]; then
      js=1
    fi
    dest="$(dest_dir)"
    if [[ "${STILLWATER_DRY_RUN:-0}" != 1 ]]; then
      mkdir -p "$dest"
      cp -a "$ROOT/spicetify/color.ini" "$ROOT/spicetify/$base/user.css" "$dest/"
      if [[ "$js" == 1 ]]; then
        cp -a "$ROOT/spicetify/$base/theme.js" "$dest/"
      else
        rm -f "$dest/theme.js"
      fi
    fi
    if stillwater_has_cmd spicetify; then
      stillwater_run spicetify config current_theme stillwater color_scheme stillwater || true
      stillwater_run spicetify config inject_css 1 replace_colors 1 overwrite_assets 1 inject_theme_js "$js" || true
      stillwater_run spicetify apply || true
    fi
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
