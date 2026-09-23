#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="vencord"
LABEL="Vencord / Vesktop"
SRC="$ROOT/vencord/Stillwater.theme.css"

target_roots() {
  printf '%s\n' \
    "$XDG_CONFIG_HOME/Vencord" \
    "$XDG_CONFIG_HOME/vesktop" \
    "$XDG_CONFIG_HOME/Vesktop" \
    "$XDG_CONFIG_HOME/equicord" \
    "$XDG_CONFIG_HOME/Equicord" \
    "$STILLWATER_SUPPORT/Vencord" \
    "$STILLWATER_SUPPORT/vesktop" \
    "$STILLWATER_SUPPORT/Vesktop" \
    "$STILLWATER_SUPPORT/equicord" \
    "$STILLWATER_SUPPORT/Equicord" \
    "$APPDATA/Vencord" \
    "$APPDATA/vesktop" \
    "$APPDATA/Vesktop" \
    "$APPDATA/equicord" \
    "$APPDATA/Equicord"
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
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
