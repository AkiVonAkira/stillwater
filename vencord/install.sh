#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
SRC="$ROOT/vencord/Stillwater.theme.css"

product_ids() {
  printf '%s\n' vencord equicord
}

owns() {
  case "$1" in
    vencord | equicord) return 0 ;;
    *) return 1 ;;
  esac
}

label_of() {
  case "$1" in
    vencord) echo "Vencord / Vesktop" ;;
    equicord) echo "Equicord / Equibop" ;;
  esac
}

target_roots() {
  case "$1" in
    vencord)
      printf '%s\n' \
        "$XDG_CONFIG_HOME/Vencord" \
        "$XDG_CONFIG_HOME/vesktop" \
        "$XDG_CONFIG_HOME/Vesktop" \
        "$STILLWATER_SUPPORT/Vencord" \
        "$STILLWATER_SUPPORT/vesktop" \
        "$STILLWATER_SUPPORT/Vesktop" \
        "$APPDATA/Vencord" \
        "$APPDATA/vesktop" \
        "$APPDATA/Vesktop"
      ;;
    equicord)
      printf '%s\n' \
        "$XDG_CONFIG_HOME/equicord" \
        "$XDG_CONFIG_HOME/Equicord" \
        "$XDG_CONFIG_HOME/equibop" \
        "$XDG_CONFIG_HOME/Equibop" \
        "$STILLWATER_SUPPORT/equicord" \
        "$STILLWATER_SUPPORT/Equicord" \
        "$STILLWATER_SUPPORT/equibop" \
        "$STILLWATER_SUPPORT/Equibop" \
        "$APPDATA/equicord" \
        "$APPDATA/Equicord" \
        "$APPDATA/equibop" \
        "$APPDATA/Equibop"
      ;;
  esac
}

product_found() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      return 0
    fi
  done < <(target_roots "$1")
  return 1
}

dest_file() {
  local id="$1" dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir/themes/Stillwater.theme.css"
      return 0
    fi
  done < <(target_roots "$id")
  if [[ "$id" == equicord ]]; then
    if [[ "$(stillwater_platform)" == windows ]]; then
      printf '%s\n' "$APPDATA/equibop/themes/Stillwater.theme.css"
    elif [[ "$(stillwater_platform)" == darwin ]]; then
      printf '%s\n' "$STILLWATER_SUPPORT/equibop/themes/Stillwater.theme.css"
    else
      printf '%s\n' "$XDG_CONFIG_HOME/equibop/themes/Stillwater.theme.css"
    fi
    return 0
  fi
  if [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/vesktop/themes/Stillwater.theme.css"
  elif [[ "$(stillwater_platform)" == darwin ]]; then
    printf '%s\n' "$STILLWATER_SUPPORT/vesktop/themes/Stillwater.theme.css"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/vesktop/themes/Stillwater.theme.css"
  fi
}

print_product_status() {
  local id="$1" app="skip" theme="none"
  local pairs=() dests=() dest local_dir
  if product_found "$id"; then
    app="found"
  fi
  dests+=("$(dest_file "$id")")
  while IFS= read -r local_dir; do
    if [[ -d "$local_dir" ]]; then
      dest="$local_dir/themes/Stillwater.theme.css"
      pairs+=("$SRC" "$dest")
      dests+=("$dest")
    fi
  done < <(target_roots "$id")
  if [[ ${#pairs[@]} -gt 0 ]]; then
    theme="$(stillwater_payload_state "${pairs[@]}")"
  fi
  stillwater_print_copy_status "$id" "$(label_of "$id")" "$app" "$theme" "${dests[@]}"
}

install_product() {
  local id="$1" dests="" local_dir dest
  while IFS= read -r local_dir; do
    if [[ -d "$local_dir" ]]; then
      dest="$local_dir/themes/Stillwater.theme.css"
      stillwater_copy_file "$SRC" "$dest"
      if [[ -n "$dests" ]]; then
        dests="$dests, $dest"
      else
        dests="$dest"
      fi
    fi
  done < <(target_roots "$id")
  printf '%s\n' "$dests"
}

case "$ACTION" in
  status)
    while IFS= read -r id; do
      print_product_status "$id"
    done < <(product_ids)
    ;;
  owns)
    owns "${1:-}"
    ;;
  install)
    owns "${1:-}"
    install_product "${1:-}"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
