# Shared helpers for Stillwater install scripts. Sourced by install.sh and */install.sh.

stillwater_platform() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) echo darwin ;;
    Linux) echo linux ;;
    MINGW* | MSYS* | CYGWIN*) echo windows ;;
    *) echo linux ;;
  esac
}

stillwater_os_label() {
  case "$(stillwater_platform)" in
    darwin) echo macos ;;
    windows) echo windows ;;
    *)
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "linux/${ID:-linux}"
      else
        echo linux
      fi
      ;;
  esac
}

stillwater_init_paths() {
  if [[ -n "${STILLWATER_HOME:-}" ]]; then
    HOME="$STILLWATER_HOME"
    export HOME
    XDG_CONFIG_HOME="$HOME/.config"
    XDG_DATA_HOME="$HOME/.local/share"
    APPDATA="$HOME/AppData/Roaming"
    LOCALAPPDATA="$HOME/AppData/Local"
  fi
  : "${XDG_CONFIG_HOME:=$HOME/.config}"
  : "${XDG_DATA_HOME:=$HOME/.local/share}"
  : "${APPDATA:=$HOME/AppData/Roaming}"
  : "${LOCALAPPDATA:=$HOME/AppData/Local}"
  export XDG_CONFIG_HOME XDG_DATA_HOME APPDATA LOCALAPPDATA
  STILLWATER_SUPPORT="$HOME/Library/Application Support"
}

stillwater_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

stillwater_any_cmd() {
  local name
  for name in "$@"; do
    if stillwater_has_cmd "$name"; then
      return 0
    fi
  done
  return 1
}

stillwater_any_dir() {
  local dir
  for dir in "$@"; do
    if [[ -d "$dir" ]]; then
      return 0
    fi
  done
  return 1
}

stillwater_copy_tree() {
  local src="$1"
  local dest="$2"
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    echo "would copy $src -> $dest" >&2
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp -a "$src"/. "$dest"/
}

stillwater_copy_file() {
  local src="$1"
  local dest="$2"
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    echo "would copy $src -> $dest" >&2
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
}

stillwater_set_vscode_theme() {
  local settings="$1"
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    echo "would set workbench.colorTheme in $settings" >&2
    return 0
  fi
  mkdir -p "$(dirname "$settings")"
  if [[ ! -f "$settings" ]]; then
    printf '%s\n' '{
  "workbench.colorTheme": "Stillwater"
}' >"$settings"
    return 0
  fi
  if grep -q '"workbench.colorTheme"' "$settings"; then
    local tmp
    tmp="$(mktemp)"
    sed 's/"workbench.colorTheme"[[:space:]]*:[[:space:]]*"[^"]*"/"workbench.colorTheme": "Stillwater"/' "$settings" >"$tmp"
    mv "$tmp" "$settings"
  fi
}

stillwater_run() {
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    echo "would run: $*" >&2
    return 0
  fi
  "$@"
}

stillwater_id_wanted() {
  local id="$1"
  shift
  if [[ $# -eq 0 ]]; then
    return 0
  fi
  local item
  for item in "$@"; do
    if [[ "$item" == "$id" ]]; then
      return 0
    fi
  done
  return 1
}
