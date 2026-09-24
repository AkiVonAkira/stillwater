#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="t3"
LABEL="T3 Code"
SRC="$ROOT/t3/stillwater.json"

found() {
  if stillwater_has_cmd t3; then
    return 0
  fi
  stillwater_any_dir "$XDG_CONFIG_HOME/t3" "$HOME/.t3" "$APPDATA/t3" "$LOCALAPPDATA/t3"
}

theme_dest() {
  if [[ -n "${T3CODE_HOME:-}" ]]; then
    printf '%s\n' "$T3CODE_HOME/userdata/themes/stillwater.json"
    return
  fi
  printf '%s\n' "$HOME/.t3/userdata/themes/stillwater.json"
}

theme_candidates() {
  printf '%s\n' "$(theme_dest)"
  printf '%s\n' \
    "$HOME/.t3/themes/stillwater.json" \
    "$XDG_CONFIG_HOME/t3/userdata/themes/stillwater.json" \
    "$XDG_CONFIG_HOME/t3/themes/stillwater.json" \
    "$APPDATA/t3/userdata/themes/stillwater.json" \
    "$APPDATA/t3/themes/stillwater.json" \
    "$LOCALAPPDATA/t3/userdata/themes/stillwater.json" \
    "$LOCALAPPDATA/t3/themes/stillwater.json"
}

theme_state() {
  local file states=()
  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      states+=("$(stillwater_copy_state "$SRC" "$file")")
    fi
  done < <(theme_candidates)
  if [[ ${#states[@]} -eq 0 ]]; then
    echo none
    return
  fi
  stillwater_merge_theme_state "${states[@]}"
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    dests=("$(theme_dest)")
    while IFS= read -r file; do
      if [[ -f "$file" ]]; then
        dests+=("$file")
      fi
    done < <(theme_candidates)
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$(theme_state)" "${dests[@]}"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dest="$(theme_dest)"
    if stillwater_has_cmd t3; then
      stillwater_run t3 theme set --id stillwater "$SRC" || true
    fi
    stillwater_copy_file "$SRC" "$dest"
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
