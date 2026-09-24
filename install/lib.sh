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

stillwater_version() {
  local file="${STILLWATER_ROOT}/palette.json"
  if stillwater_has_cmd node; then
    node --input-type=commonjs -e "process.stdout.write(String(JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')).version||''))" "$file"
    return
  fi
  sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n 1
}

stillwater_vscode_ext_id() {
  printf 'kayzel.stillwater-theme-%s\n' "$(stillwater_version)"
}

stillwater_retire_vscode_extensions() {
  local parent="$1"
  local keep="$2"
  local dir
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    echo "would retire old Stillwater folders in $parent" >&2
    return 0
  fi
  [[ -d "$parent" ]] || return 0
  for dir in "$parent"/kayzel.stillwater-theme-*; do
    [[ -e "$dir" ]] || continue
    if [[ "$(basename "$dir")" != "$keep" ]]; then
      rm -rf "$dir"
    fi
  done
}

stillwater_register_vscode_extension() {
  local dest="$1"
  local version
  version="$(stillwater_version)"
  local id="kayzel.stillwater-theme"
  local script="${STILLWATER_ROOT}/install/vscode-ext.cjs"
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
    echo "would register $id $version -> $dest" >&2
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if stillwater_has_cmd node && [[ -f "$script" ]]; then
    node "$script" register "$dest" "$id" "$version"
    return
  fi
  stillwater_register_vscode_extension_bash "$dest" "$id" "$version"
}

stillwater_register_vscode_extension_bash() {
  local dest="$1"
  local id="$2"
  local version="$3"
  local folder root json obsolete tmp path
  folder="$(basename "$dest")"
  root="$(dirname "$dest")"
  json="$root/extensions.json"
  obsolete="$root/.obsolete"
  mkdir -p "$root"
  if [[ -f "$obsolete" ]]; then
    tmp="$(mktemp)"
    sed -E 's/"kayzel\.stillwater-theme-[^"]+":true,?//g' "$obsolete" >"$tmp"
    mv "$tmp" "$obsolete"
  fi
  path="$dest"
  path="${path//\\//}"
  if [[ "$path" =~ ^([A-Za-z]):/(.*)$ ]]; then
    path="/$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]'):/${BASH_REMATCH[2]}"
  elif [[ "$path" =~ ^/([A-Za-z])/(.*)$ ]]; then
    path="/$(printf '%s' "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]'):/${BASH_REMATCH[2]}"
  fi
  tmp="$(mktemp)"
  printf '[{"identifier":{"id":"%s"},"version":"%s","location":{"$mid":1,"path":"%s","scheme":"file"},"relativeLocation":"%s","metadata":{"installedTimestamp":%s000,"pinned":true,"source":"vsix","isPreReleaseVersion":false,"hasPreReleaseVersion":false}}]\n' \
    "$id" "$version" "$path" "$folder" "$(date +%s)" >"$tmp"
  if [[ ! -f "$json" ]] || grep -q '^[[:space:]]*\[\][[:space:]]*$' "$json"; then
    mv "$tmp" "$json"
    return 0
  fi
  if grep -q "\"id\":\"$id\"" "$json"; then
    rm -f "$tmp"
    return 0
  fi
  sed '$s/]$/,/' "$json" | sed '$d' >"${tmp}.head"
  {
    cat "${tmp}.head"
    tail -c +2 "$tmp"
  } >"$json"
  rm -f "$tmp" "${tmp}.head"
}

stillwater_set_vscode_theme() {
  local settings="$1"
  local tmp
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
  tmp="$(mktemp)"
  if grep -q '"workbench.colorTheme"' "$settings"; then
    sed 's/"workbench.colorTheme"[[:space:]]*:[[:space:]]*"[^"]*"/"workbench.colorTheme": "Stillwater"/' "$settings" >"$tmp"
  else
    awk 'BEGIN { done=0 }
      /{/ && done==0 { print; print "  \"workbench.colorTheme\": \"Stillwater\","; done=1; next }
      { print }' "$settings" >"$tmp"
  fi
  mv "$tmp" "$settings"
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
