#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
EXT_ID="kayzel.stillwater-theme-1.0.0"

install_vscode_ext() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -a "$ROOT/vscode/." "$dest/"
}

if [[ -d "$HOME/.cursor" ]] || command -v cursor >/dev/null 2>&1; then
  install_vscode_ext "$HOME/.cursor/extensions/$EXT_ID"
  echo "Cursor extension: $HOME/.cursor/extensions/$EXT_ID"
fi

if [[ -d "$HOME/.vscode" ]] || command -v code >/dev/null 2>&1; then
  install_vscode_ext "$HOME/.vscode/extensions/$EXT_ID"
  echo "VS Code extension: $HOME/.vscode/extensions/$EXT_ID"
fi

set_color_theme() {
  local settings="$1"
  mkdir -p "$(dirname "$settings")"
  if [[ ! -f "$settings" ]]; then
    printf '%s\n' '{
  "workbench.colorTheme": "Stillwater"
}' >"$settings"
    return
  fi
  python3 - "$settings" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
raw = path.read_text()
data = json.loads(raw)
data["workbench.colorTheme"] = "Stillwater"
path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

for candidate in \
  "$HOME/.config/Cursor/User/settings.json" \
  "$HOME/.config/Code/User/settings.json"
do
  if [[ -f "$candidate" ]] || [[ "$candidate" == *Cursor* && -d "$HOME/.config/Cursor" ]] || [[ "$candidate" == *Code* && -d "$HOME/.config/Code" ]]; then
    set_color_theme "$candidate"
    echo "colorTheme Stillwater -> $candidate"
  fi
done

RYOKU_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ryoku/themes/stillwater"
if command -v ryoku-shell >/dev/null 2>&1; then
  mkdir -p "$RYOKU_DIR"
  cp -a "$ROOT/ryoku/scheme.json" "$ROOT/ryoku/meta.json" "$RYOKU_DIR/"
  python3 - <<'PY'
import json, pathlib, os
p = pathlib.Path.home() / ".config" / "ryoku" / "theme.json"
p.parent.mkdir(parents=True, exist_ok=True)
data = {}
if p.exists():
    data = json.loads(p.read_text() or "{}")
data["followWallpaper"] = False
p.write_text(json.dumps(data, indent=2) + "\n")
PY
  ryoku-shell theme stillwater >/dev/null
  echo "Ryoku theme: stillwater ($RYOKU_DIR)"
fi

if command -v t3 >/dev/null 2>&1; then
  t3 theme set --id stillwater "$ROOT/t3/stillwater.json"
fi
