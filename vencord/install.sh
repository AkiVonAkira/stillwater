#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
SRC="$ROOT/vencord/Stillwater.theme.css"

bases() {
  case "$(stillwater_platform)" in
    windows) printf '%s\n' "$APPDATA" ;;
    darwin) printf '%s\n' "$STILLWATER_SUPPORT" "$XDG_CONFIG_HOME" ;;
    *) printf '%s\n' "$XDG_CONFIG_HOME" ;;
  esac
}

# Empty leftovers (often only themes/ from us) are not a client.
client_live() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -f "$dir/settings.json" || -d "$dir/settings" || -d "$dir/sessionData" ]]
}

product_ids() {
  printf '%s\n' vencord equicord
}

product_names() {
  case "$1" in
    vencord) printf '%s\n' Vencord vesktop Vesktop ;;
    equicord) printf '%s\n' equicord Equicord equibop Equibop ;;
  esac
}

target_roots() {
  local base name
  while IFS= read -r base; do
    [[ -n "$base" ]] || continue
    while IFS= read -r name; do
      printf '%s\n' "$base/$name"
    done < <(product_names "$1")
  done < <(bases)
}

client_present() {
  local name base
  for name in "$@"; do
    while IFS= read -r base; do
      [[ -n "$base" ]] || continue
      if client_live "$base/$name"; then
        return 0
      fi
    done < <(bases)
  done
  return 1
}

label_of() {
  local out=""
  case "$1" in
    vencord)
      if client_present Vencord; then out="Vencord"; fi
      if client_present vesktop Vesktop; then
        if [[ -n "$out" ]]; then out="$out / Vesktop"; else out="Vesktop"; fi
      fi
      printf '%s\n' "${out:-Vencord}"
      ;;
    equicord)
      if client_present equicord Equicord; then out="Equicord"; fi
      if client_present equibop Equibop; then
        if [[ -n "$out" ]]; then out="$out / Equibop"; else out="Equibop"; fi
      fi
      printf '%s\n' "${out:-Equicord}"
      ;;
  esac
}

product_found() {
  local dir
  while IFS= read -r dir; do
    if client_live "$dir"; then
      return 0
    fi
  done < <(target_roots "$1")
  return 1
}

dest_file() {
  local dir
  while IFS= read -r dir; do
    if client_live "$dir"; then
      printf '%s\n' "$dir/themes/Stillwater.theme.css"
      return 0
    fi
  done < <(target_roots "$1")
  case "$1" in
    equicord)
      if [[ "$(stillwater_platform)" == windows ]]; then
        printf '%s\n' "$APPDATA/Equicord/themes/Stillwater.theme.css"
      elif [[ "$(stillwater_platform)" == darwin ]]; then
        printf '%s\n' "$STILLWATER_SUPPORT/Equicord/themes/Stillwater.theme.css"
      else
        printf '%s\n' "$XDG_CONFIG_HOME/equicord/themes/Stillwater.theme.css"
      fi
      ;;
    *)
      if [[ "$(stillwater_platform)" == windows ]]; then
        printf '%s\n' "$APPDATA/Vencord/themes/Stillwater.theme.css"
      elif [[ "$(stillwater_platform)" == darwin ]]; then
        printf '%s\n' "$STILLWATER_SUPPORT/Vencord/themes/Stillwater.theme.css"
      else
        printf '%s\n' "$XDG_CONFIG_HOME/Vencord/themes/Stillwater.theme.css"
      fi
      ;;
  esac
}

print_product_status() {
  local id="$1" app="skip" theme="none"
  local pairs=() dests=() dest local_dir
  if product_found "$id"; then
    app="found"
  fi
  dests+=("$(dest_file "$id")")
  while IFS= read -r local_dir; do
    if client_live "$local_dir"; then
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
    if client_live "$local_dir"; then
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

owns() {
  case "$1" in
    vencord | equicord) return 0 ;;
    *) return 1 ;;
  esac
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
