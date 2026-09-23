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
    if stillwater_has_cmd t3; then
      if stillwater_run t3 theme set --id stillwater "$SRC"; then
        printf '%s\n' "t3 theme set --id stillwater"
        exit 0
      fi
    fi
    printf '%s\n' "$SRC"
    ;;
  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
