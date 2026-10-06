#!/usr/bin/env bash
set -euo pipefail

ROOT="${STILLWATER_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=../install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

ACTION="${1:-install}"
shift || true
ID="starship"
LABEL="Starship"
THEME_SRC="$ROOT/starship/starship.toml"
PROFILE_SRC="$ROOT/starship/Microsoft.PowerShell_profile.ps1"

theme_dest() {
  printf '%s\n' "$XDG_CONFIG_HOME/starship.toml"
}

profile_dest() {
  printf '%s\n' "$HOME/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
}

found() {
  # Profile path is Documents/PowerShell, which is Windows PowerShell 7.
  # Host pwsh on Linux (including GitHub-hosted Ubuntu) is not that install.
  if [[ "$(stillwater_platform)" == windows ]] && stillwater_any_cmd pwsh powershell; then
    return 0
  fi
  stillwater_any_dir "$HOME/Documents/PowerShell"
}

case "$ACTION" in
  status)
    app="skip"
    if found; then
      app="found"
    fi
    theme="$(theme_dest)"
    profile="$(profile_dest)"
    stillwater_print_copy_status "$ID" "$LABEL" "$app" \
      "$(stillwater_payload_state "$THEME_SRC" "$theme" "$PROFILE_SRC" "$profile")" \
      "$theme" "$profile"
    ;;
  owns)
    [[ "${1:-}" == "$ID" ]]
    ;;
  install)
    [[ "${1:-}" == "$ID" ]]
    theme="$(theme_dest)"
    profile="$(profile_dest)"
    stillwater_copy_file "$THEME_SRC" "$theme"
    stillwater_copy_file "$PROFILE_SRC" "$profile"
    printf '%s\n' "$theme"
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac
