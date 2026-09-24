#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="vencord"
SRC="$ROOT/vencord/Stillwater.theme.css"

bases() {
  case "$(stillwater_platform)" in
    windows) printf '%s\n' "$APPDATA" ;;
    darwin) printf '%s\n' "$STILLWATER_SUPPORT" "$XDG_CONFIG_HOME" ;;
    *) printf '%s\n' "$XDG_CONFIG_HOME" ;;
  esac
}

target_roots() {
  local base name
  while IFS= read -r base; do
    [[ -n "$base" ]] || continue
    for name in Vencord vesktop Vesktop equicord Equicord equibop Equibop; do
      printf '%s\n' "$base/$name"
    done
  done < <(bases)
}

# Empty leftovers (often only themes/ from us) are not a client.
client_live() {
  local dir="$1"
  [[ -d "$dir" ]] || return 1
  [[ -f "$dir/settings.json" || -d "$dir/settings" || -d "$dir/sessionData" ]]
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
  if client_present Vencord; then
    out="Vencord"
  fi
  if client_present vesktop Vesktop; then
    if [[ -n "$out" ]]; then out="$out / Vesktop"; else out="Vesktop"; fi
  fi
  if client_present equicord Equicord equibop Equibop; then
    if [[ -n "$out" ]]; then out="$out / Equicord"; else out="Equicord"; fi
  fi
  printf '%s\n' "${out:-Vencord}"
}

found() {
  local dir
  while IFS= read -r dir; do
    if client_live "$dir"; then
      return 0
    fi
  done < <(target_roots)
  return 1
}

dest_file() {
  local dir
  while IFS= read -r dir; do
    if client_live "$dir"; then
      printf '%s\n' "$dir/themes/Stillwater.theme.css"
      return 0
    fi
  done < <(target_roots)
  if [[ "$(stillwater_platform)" == windows ]]; then
    printf '%s\n' "$APPDATA/Vencord/themes/Stillwater.theme.css"
  elif [[ "$(stillwater_platform)" == darwin ]]; then
    printf '%s\n' "$STILLWATER_SUPPORT/Vencord/themes/Stillwater.theme.css"
  else
    printf '%s\n' "$XDG_CONFIG_HOME/Vencord/themes/Stillwater.theme.css"
  fi
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    pairs=()
    dests=("$(dest_file)")
    while IFS= read -r local_dir; do
      if client_live "$local_dir"; then
        dest="$local_dir/themes/Stillwater.theme.css"
        pairs+=("$SRC" "$dest")
        dests+=("$dest")
      fi
    done < <(target_roots)
    theme="none"
    if [[ ${#pairs[@]} -gt 0 ]]; then
      theme="$(stillwater_payload_state "${pairs[@]}")"
    fi
    stillwater_print_copy_status "$ID" "$(label_of)" "$app" "$theme" "${dests[@]}"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dests=""
    local_dir=""
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
    done < <(target_roots)
    printf '%s\n' "$dests"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
