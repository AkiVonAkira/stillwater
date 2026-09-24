#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="obsidian"
LABEL="Obsidian"
SRC_DIR="$ROOT/obsidian"

config_jsons() {
  printf '%s\n' \
    "$XDG_CONFIG_HOME/obsidian/obsidian.json" \
    "$STILLWATER_SUPPORT/obsidian/obsidian.json" \
    "$APPDATA/obsidian/obsidian.json"
}

config_dirs() {
  printf '%s\n' \
    "$XDG_CONFIG_HOME/obsidian" \
    "$STILLWATER_SUPPORT/obsidian" \
    "$APPDATA/obsidian"
}

vault_paths() {
  local file
  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      grep -oE '"path"[[:space:]]*:[[:space:]]*"[^"]+"' "$file" 2>/dev/null \
        | sed 's/.*"path"[[:space:]]*:[[:space:]]*"//;s/"$//'
    fi
  done < <(config_jsons)
}

theme_dest_for() {
  printf '%s\n' "$1/.obsidian/themes/Stillwater"
}

found() {
  local dir
  if stillwater_any_cmd obsidian; then
    return 0
  fi
  while IFS= read -r dir; do
    if [[ -d "$dir" ]]; then
      return 0
    fi
  done < <(config_dirs)
  return 1
}

first_dest() {
  local vault
  while IFS= read -r vault; do
    if [[ -n "$vault" ]]; then
      theme_dest_for "$vault"
      return 0
    fi
  done < <(vault_paths)
  printf '%s\n' "$XDG_CONFIG_HOME/obsidian/themes/Stillwater"
}

set_css_theme() {
  local appearance="$1/.obsidian/appearance.json"
  local tmp
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$appearance")"
  if [[ ! -f "$appearance" ]]; then
    printf '%s\n' '{
  "cssTheme": "Stillwater"
}' >"$appearance"
    return 0
  fi
  tmp="$(mktemp)"
  if grep -q '"cssTheme"' "$appearance"; then
    sed 's/"cssTheme"[[:space:]]*:[[:space:]]*"[^"]*"/"cssTheme": "Stillwater"/' "$appearance" >"$tmp"
  else
    awk 'BEGIN { done=0 }
      /{/ && done==0 { print; print "  \"cssTheme\": \"Stillwater\","; done=1; next }
      { print }' "$appearance" >"$tmp"
  fi
  mv "$tmp" "$appearance"
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    pairs=()
    dests=("$(first_dest)")
    while IFS= read -r vault; do
      [[ -n "$vault" ]] || continue
      dest="$(theme_dest_for "$vault")"
      pairs+=("$SRC_DIR/manifest.json" "$dest/manifest.json" "$SRC_DIR/theme.css" "$dest/theme.css")
      dests+=("$dest")
    done < <(vault_paths)
    theme="none"
    if [[ ${#pairs[@]} -gt 0 ]]; then
      theme="$(stillwater_payload_state "${pairs[@]}")"
    fi
    stillwater_print_copy_status "$ID" "$LABEL" "$app" "$theme" "${dests[@]}"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    dests=""
    while IFS= read -r vault; do
      [[ -n "$vault" ]] || continue
      dest="$(theme_dest_for "$vault")"
      stillwater_copy_file "$SRC_DIR/manifest.json" "$dest/manifest.json"
      stillwater_copy_file "$SRC_DIR/theme.css" "$dest/theme.css"
      set_css_theme "$vault"
      if [[ -n "$dests" ]]; then
        dests="$dests, $dest"
      else
        dests="$dest"
      fi
    done < <(vault_paths)
    printf '%s\n' "$dests"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
