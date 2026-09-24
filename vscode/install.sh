#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

EXT_ID="$(stillwater_vscode_ext_id)"
SRC="$ROOT/vscode"
ACTION="${1:-install}"
shift || true

platform="$(stillwater_platform)"

product_ids() {
  printf '%s\n' cursor vscode vscode-insiders vscodium code-oss windsurf
}

owns() {
  local id="$1"
  case "$id" in
    cursor | vscode | vscode-insiders | vscodium | code-oss | windsurf) return 0 ;;
    *) return 1 ;;
  esac
}

detect_dirs() {
  local id="$1"
  case "$platform:$id" in
    linux:cursor) printf '%s\n' "$HOME/.cursor" "$XDG_CONFIG_HOME/Cursor" ;;
    darwin:cursor) printf '%s\n' "$HOME/.cursor" "$STILLWATER_SUPPORT/Cursor" ;;
    windows:cursor) printf '%s\n' "$HOME/.cursor" "$APPDATA/Cursor" ;;
    linux:vscode) printf '%s\n' "$HOME/.vscode" "$XDG_CONFIG_HOME/Code" ;;
    darwin:vscode) printf '%s\n' "$HOME/.vscode" "$STILLWATER_SUPPORT/Code" ;;
    windows:vscode) printf '%s\n' "$HOME/.vscode" "$APPDATA/Code" ;;
    linux:vscode-insiders) printf '%s\n' "$HOME/.vscode-insiders" "$XDG_CONFIG_HOME/Code - Insiders" ;;
    darwin:vscode-insiders) printf '%s\n' "$HOME/.vscode-insiders" "$STILLWATER_SUPPORT/Code - Insiders" ;;
    windows:vscode-insiders) printf '%s\n' "$HOME/.vscode-insiders" "$APPDATA/Code - Insiders" ;;
    linux:vscodium) printf '%s\n' "$HOME/.vscode-oss" "$XDG_CONFIG_HOME/VSCodium" ;;
    darwin:vscodium) printf '%s\n' "$HOME/.vscode-oss" "$STILLWATER_SUPPORT/VSCodium" ;;
    windows:vscodium) printf '%s\n' "$HOME/.vscode-oss" "$APPDATA/VSCodium" ;;
    linux:code-oss) printf '%s\n' "$XDG_CONFIG_HOME/Code - OSS" ;;
    darwin:code-oss) printf '%s\n' "$STILLWATER_SUPPORT/Code - OSS" ;;
    windows:code-oss) printf '%s\n' "$APPDATA/Code - OSS" ;;
    linux:windsurf) printf '%s\n' "$HOME/.windsurf" "$XDG_CONFIG_HOME/Windsurf" "$HOME/.codeium/windsurf" ;;
    darwin:windsurf) printf '%s\n' "$HOME/.windsurf" "$STILLWATER_SUPPORT/Windsurf" ;;
    windows:windsurf) printf '%s\n' "$HOME/.windsurf" "$APPDATA/Windsurf" ;;
  esac
}

detect_cmds() {
  case "$1" in
    cursor) printf '%s\n' cursor ;;
    vscode) printf '%s\n' code ;;
    vscode-insiders) printf '%s\n' code-insiders ;;
    vscodium) printf '%s\n' codium ;;
    code-oss) printf '%s\n' code-oss ;;
    windsurf) printf '%s\n' windsurf ;;
  esac
}

ext_dir() {
  case "$1" in
    cursor) echo "$HOME/.cursor/extensions/$EXT_ID" ;;
    vscode) echo "$HOME/.vscode/extensions/$EXT_ID" ;;
    vscode-insiders) echo "$HOME/.vscode-insiders/extensions/$EXT_ID" ;;
    vscodium | code-oss) echo "$HOME/.vscode-oss/extensions/$EXT_ID" ;;
    windsurf) echo "$HOME/.windsurf/extensions/$EXT_ID" ;;
  esac
}

settings_path() {
  local id="$1"
  case "$platform:$id" in
    linux:cursor) echo "$XDG_CONFIG_HOME/Cursor/User/settings.json" ;;
    darwin:cursor) echo "$STILLWATER_SUPPORT/Cursor/User/settings.json" ;;
    windows:cursor) echo "$APPDATA/Cursor/User/settings.json" ;;
    linux:vscode) echo "$XDG_CONFIG_HOME/Code/User/settings.json" ;;
    darwin:vscode) echo "$STILLWATER_SUPPORT/Code/User/settings.json" ;;
    windows:vscode) echo "$APPDATA/Code/User/settings.json" ;;
    linux:vscode-insiders) echo "$XDG_CONFIG_HOME/Code - Insiders/User/settings.json" ;;
    darwin:vscode-insiders) echo "$STILLWATER_SUPPORT/Code - Insiders/User/settings.json" ;;
    windows:vscode-insiders) echo "$APPDATA/Code - Insiders/User/settings.json" ;;
    linux:vscodium) echo "$XDG_CONFIG_HOME/VSCodium/User/settings.json" ;;
    darwin:vscodium) echo "$STILLWATER_SUPPORT/VSCodium/User/settings.json" ;;
    windows:vscodium) echo "$APPDATA/VSCodium/User/settings.json" ;;
    linux:code-oss) echo "$XDG_CONFIG_HOME/Code - OSS/User/settings.json" ;;
    darwin:code-oss) echo "$STILLWATER_SUPPORT/Code - OSS/User/settings.json" ;;
    windows:code-oss) echo "$APPDATA/Code - OSS/User/settings.json" ;;
    linux:windsurf) echo "$XDG_CONFIG_HOME/Windsurf/User/settings.json" ;;
    darwin:windsurf) echo "$STILLWATER_SUPPORT/Windsurf/User/settings.json" ;;
    windows:windsurf) echo "$APPDATA/Windsurf/User/settings.json" ;;
  esac
}

label_of() {
  case "$1" in
    cursor) echo Cursor ;;
    vscode) echo "Visual Studio Code" ;;
    vscode-insiders) echo "VS Code Insiders" ;;
    vscodium) echo VSCodium ;;
    code-oss) echo "Code - OSS" ;;
    windsurf) echo Windsurf ;;
  esac
}

product_found() {
  local id="$1"
  local dir cmd
  while IFS= read -r dir; do
    [[ -n "$dir" ]] || continue
    if [[ -d "$dir" ]]; then
      return 0
    fi
  done < <(detect_dirs "$id")
  while IFS= read -r cmd; do
    [[ -n "$cmd" ]] || continue
    if stillwater_has_cmd "$cmd"; then
      return 0
    fi
  done < <(detect_cmds "$id")
  return 1
}

case "$ACTION" in
  status)
    while IFS= read -r id; do
      app="skip"
      if product_found "$id"; then
        app="found"
      fi
      dest="$(ext_dir "$id")"
      payload="$(stillwater_vscode_payload_state "$SRC" "$dest")"
      theme="${payload%%|*}"
      note="${payload#*|}"
      stillwater_print_status "$id" "$(label_of "$id")" "$app" "$theme" "$note" "$dest"
    done < <(product_ids)
    ;;
  owns)
    owns "${1:-}"
    ;;
  install)
    id="${1:-}"
    owns "$id"
    dest="$(ext_dir "$id")"
    stillwater_retire_vscode_extensions "$(dirname "$dest")" "$(basename "$dest")"
    stillwater_copy_file "$SRC/package.json" "$dest/package.json"
    stillwater_copy_tree "$SRC/themes" "$dest/themes"
    stillwater_register_vscode_extension "$dest"
    stillwater_set_vscode_theme "$(settings_path "$id")"
    printf '%s\n' "$dest"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
