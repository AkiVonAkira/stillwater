#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="yasb"
LABEL="YASB"
MAP="$ROOT/yasb/vars.map"
HEXMAP="$ROOT/yasb/hex.map"
SEED="$ROOT/yasb/root.css"

detect_dirs() {
  if [[ -n "${YASB_CONFIG_HOME:-}" ]]; then
    printf '%s\n' "$YASB_CONFIG_HOME"
  fi
  printf '%s\n' "$HOME/.config/yasb" "$XDG_CONFIG_HOME/yasb"
}

found() {
  if stillwater_any_cmd yasb yasbc; then
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

dest_file() {
  local dir
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir/styles.css"
      return 0
    fi
  done < <(detect_dirs)
  printf '%s\n' "$HOME/.config/yasb/styles.css"
}

# One awk pass. A loop of sed and tr per line took seconds on Git Bash.
yasb_rewrite() {
  local dest="$1" out="$2"
  awk -v version="$(stillwater_version)" -f "$ROOT/yasb/rewrite.awk" \
    "$ROOT/palette.json" "$MAP" "$HEXMAP" "$dest" >"$out"
}

yasb_apply() {
  local dest="$1" tmp
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    return 0
  fi
  if [[ ! -f "$dest" ]]; then
    stillwater_copy_file "$SEED" "$dest"
    return 0
  fi
  if ! grep -q ':root' "$dest"; then
    tmp="$(mktemp)"
    cat "$SEED" "$dest" >"$tmp"
    mv "$tmp" "$dest"
    return 0
  fi
  tmp="$(mktemp)"
  yasb_rewrite "$dest" "$tmp"
  mv "$tmp" "$dest"
}

yasb_state() {
  local dest="$1" tmp
  if [[ ! -f "$dest" ]] || ! grep -q ':root' "$dest"; then
    printf 'none\n'
    return 0
  fi
  tmp="$(mktemp)"
  yasb_rewrite "$dest" "$tmp"
  if stillwater_same_file "$dest" "$tmp"; then
    printf 'current\n'
  elif grep -q '@version' "$dest"; then
    printf 'update\n'
  else
    printf 'none\n'
  fi
  rm -f "$tmp"
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    dest="$(dest_file)"
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(yasb_state "$dest")" "$dest"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$(dest_file)"
    yasb_apply "$dest"
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
