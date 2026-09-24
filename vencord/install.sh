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
  printf '%s\n' "$XDG_CONFIG_HOME" "$STILLWATER_SUPPORT" "$APPDATA"
}

target_roots() {
  local base name
  while IFS= read -r base; do
    for name in Vencord vesktop Vesktop equicord Equicord equibop Equibop; do
      printf '%s\n' "$base/$name"
    done
  done < <(bases)
}

client_present() {
  local name base
  for name in "$@"; do
    while IFS= read -r base; do
      if [[ -d "$base/$name" ]]; then
        return 0
      fi
    done < <(bases)
  done
  return 1
}

label_of() {
  local parts="Vencord"
  if client_present vesktop Vesktop; then
    parts="$parts / Vesktop"
  fi
  if client_present equicord Equicord; then
    parts="$parts / Equicord"
  fi
  if client_present equibop Equibop; then
    parts="$parts / Equibop"
  fi
  printf '%s\n' "$parts"
}

found() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      return 0
    fi
  done < <(target_roots)
  return 1
}

dest_file() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
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
      if [[ -d "$local_dir" ]]; then
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
      if [[ -d "$local_dir" ]]; then
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
