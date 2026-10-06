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
  if [[ -n "${STILLWATER_OS_LABEL:-}" ]]; then
    printf '%s' "$STILLWATER_OS_LABEL"
    return 0
  fi
  case "$(stillwater_platform)" in
    darwin) STILLWATER_OS_LABEL=macos ;;
    windows) STILLWATER_OS_LABEL=windows ;;
    *)
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        STILLWATER_OS_LABEL="linux/${ID:-linux}"
      else
        STILLWATER_OS_LABEL=linux
      fi
      ;;
  esac
  printf '%s' "$STILLWATER_OS_LABEL"
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
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
}

stillwater_version() {
  if [[ -n "${STILLWATER_VERSION:-}" ]]; then
    printf '%s' "$STILLWATER_VERSION"
    return 0
  fi
  local file="${STILLWATER_ROOT}/palette.json"
  STILLWATER_VERSION="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n 1)"
  printf '%s' "$STILLWATER_VERSION"
}

stillwater_palette_hex() {
  local key="$1"
  local file="${STILLWATER_ROOT}/palette.json"
  sed -n "s/^[[:space:]]*\"${key}\"[[:space:]]*:[[:space:]]*\"#\\([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\)\".*/\\1/p" "$file" | head -n 1
}

stillwater_fg() {
  local hex="${1#\#}"
  if [[ ${#hex} -ne 6 ]]; then
    return 0
  fi
  printf '\033[38;2;%d;%d;%dm' "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

stillwater_load_theme_ansi() {
  SW_RESET=$'\033[0m'
  SW_ACCENT="$(stillwater_fg "$(stillwater_palette_hex accent)")"
  SW_ACCENT_HOVER="$(stillwater_fg "$(stillwater_palette_hex accentHover)")"
  SW_ACCENT_DEEP="$(stillwater_fg "$(stillwater_palette_hex accentDeep)")"
  SW_TEXT="$(stillwater_fg "$(stillwater_palette_hex text)")"
  SW_MUTED="$(stillwater_fg "$(stillwater_palette_hex textMuted)")"
  SW_WARM="$(stillwater_fg "$(stillwater_palette_hex warm)")"
  SW_WARN="$(stillwater_fg "$(stillwater_palette_hex warning)")"
  SW_ERROR="$(stillwater_fg "$(stillwater_palette_hex error)")"
  if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == dumb ]]; then
    SW_RESET=""
    SW_ACCENT=""
    SW_ACCENT_HOVER=""
    SW_ACCENT_DEEP=""
    SW_TEXT=""
    SW_MUTED=""
    SW_WARM=""
    SW_WARN=""
    SW_ERROR=""
  fi
}

stillwater_vscode_ext_id() {
  printf 'kayzel.stillwater-theme-%s\n' "$(stillwater_version)"
}

stillwater_retire_vscode_extensions() {
  local parent="$1"
  local keep="$2"
  local dir
  if [[ "${STILLWATER_DRY_RUN:-0}" == 1 ]]; then
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
    return 0
  fi
  "$@" >/dev/null 2>&1
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

stillwater_print_status() {
  local id="$1"
  local label="$2"
  local app="$3"
  local theme="$4"
  local note="${5:-}"
  local dest="${6:-}"
  printf '%s|%s|%s|%s|%s|%s\n' "$id" "$label" "$app" "$theme" "$note" "$dest"
}

stillwater_display_path() {
  local path="$1"
  local home="${HOME:-}"
  local base=""
  if [[ -z "$path" ]]; then
    return 0
  fi
  path="${path//\\//}"
  path="${path%/}"
  home="${home//\\//}"
  home="${home%/}"
  if stillwater_has_cmd cygpath; then
    path="$(cygpath -u "$path" 2>/dev/null || printf '%s' "$path")"
    path="${path%/}"
    if [[ -n "$home" ]]; then
      home="$(cygpath -u "$home" 2>/dev/null || printf '%s' "$home")"
      home="${home%/}"
    fi
  fi
  base="${path##*/}"
  if [[ "$base" == *.* ]]; then
    path="${path%/*}"
  fi
  if [[ -n "$home" && ( "$path" == "$home" || "$path" == "$home"/* ) ]]; then
    printf '~%s' "${path#"$home"}"
    return 0
  fi
  printf '%s' "$path"
}

stillwater_term_cols() {
  local n="${COLUMNS:-}"
  if [[ -z "$n" ]] && stillwater_has_cmd tput; then
    n="$(tput cols 2>/dev/null || true)"
  fi
  if [[ -z "$n" || "$n" -lt 40 ]]; then
    n=80
  fi
  printf '%s' "$n"
}

stillwater_fit_left() {
  local s="$1"
  local max="$2"
  local len=${#s}
  if [[ -z "$s" || "$max" -le 0 ]]; then
    return 0
  fi
  if [[ "$len" -le "$max" ]]; then
    printf '%s' "$s"
    return 0
  fi
  if [[ "$max" -le 1 ]]; then
    printf '…'
    return 0
  fi
  printf '…%s' "${s:$((len - max + 1))}"
}

stillwater_next_step() {
  case "$1" in
    cursor | vscode | vscode-insiders | vscodium | code-oss | windsurf)
      printf 'Set Color Theme to Stillwater.'
      ;;
    zed)
      printf 'Set the theme to Stillwater.'
      ;;
    helix)
      printf 'Set theme to stillwater in config.toml.'
      ;;
    neovim)
      printf 'Run :colorscheme stillwater.'
      ;;
    sublime)
      printf 'Set Color Scheme to Stillwater.'
      ;;
    vencord)
      printf 'Enable Stillwater in Vencord themes.'
      ;;
    equicord)
      printf 'Enable Stillwater in Equicord themes.'
      ;;
    t3)
      printf 'Select Stillwater in T3 Code.'
      ;;
    spicetify)
      printf 'Restart Spotify.'
      ;;
    spotifast)
      printf 'Select Stillwater under Settings, Appearance, Theme.'
      ;;
    ryoku)
      printf 'Select Stillwater in Ryoku.'
      ;;
    obsidian)
      printf 'Set the Appearance theme to Stillwater.'
      ;;
    prism)
      printf 'Set the Widgets theme to Stillwater.'
      ;;
    yasb)
      printf 'Reload YASB to apply colors.'
      ;;
    kitty)
      printf 'Reload Kitty to apply Stillwater.'
      ;;
    ghostty)
      printf 'Set theme = Stillwater in Ghostty config.'
      ;;
    harbor)
      printf 'Import Stillwater.harborstyle under Settings, Theme & appearance.'
      ;;
    btop)
      printf 'Set color_theme to stillwater in btop.conf.'
      ;;
    windows-terminal)
      printf 'Set the color scheme to Stillwater.'
      ;;
    starship)
      printf 'Open a new PowerShell tab.'
      ;;
  esac
}

# Dest stamps where adapters keep one: JSON/TOML "1.0.0", CSS @version, ini "; version".
# Skips unquoted integers (T3 schema "version": 1) and schema_version.
stillwater_peek_version() {
  local path="$1"
  local file="" ver
  if [[ -f "$path" ]]; then
    file="$path"
  elif [[ -d "$path" ]]; then
    for cand in \
      "$path/package.json" \
      "$path/extension.toml" \
      "$path/color.ini" \
      "$path/Stillwater.theme.css" \
      "$path/meta.json" \
      "$path/manifest.json" \
      "$path/theme.json" \
      "$path/stillwater.json"; do
      if [[ -f "$cand" ]]; then
        file="$cand"
        break
      fi
    done
  fi
  [[ -n "$file" && -f "$file" ]] || return 0
  ver="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9]*\.[0-9][0-9.]*\)".*/\1/p' "$file" | head -n 1)"
  if [[ -z "$ver" ]]; then
    ver="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([0-9][0-9]*\.[0-9][0-9.]*\)".*/\1/p' "$file" | head -n 1)"
  fi
  if [[ -z "$ver" ]]; then
    ver="$(sed -n 's/.*@version[[:space:]]\{1,\}\([0-9][0-9]*\.[0-9][0-9.]*\).*/\1/p' "$file" | head -n 1)"
  fi
  if [[ -z "$ver" ]]; then
    ver="$(sed -n 's/^[[:space:]]*[;#][[:space:]]*version[[:space:]]\{1,\}\([0-9][0-9]*\.[0-9][0-9.]*\).*/\1/p' "$file" | head -n 1)"
  fi
  printf '%s' "$ver"
}

stillwater_status_note() {
  local state="$1"
  local installed="${2:-}"
  local wanted
  wanted="$(stillwater_version)"
  case "$state" in
    update)
      if [[ -n "$installed" && "$installed" != "$wanted" ]]; then
        printf '%s to %s' "$installed" "$wanted"
      else
        printf 'Modified'
      fi
      ;;
  esac
}

stillwater_print_copy_status() {
  local id="$1"
  local label="$2"
  local app="$3"
  local state="$4"
  shift 4
  local dest_show=""
  local installed="" path
  for path in "$@"; do
    [[ -n "$path" ]] || continue
    if [[ -z "$dest_show" ]]; then
      dest_show="$path"
    fi
    installed="$(stillwater_peek_version "$path")"
    if [[ -n "$installed" ]]; then
      break
    fi
  done
  stillwater_print_status "$id" "$label" "$app" "$state" "$(stillwater_status_note "$state" "$installed")" "$dest_show"
}

stillwater_sort_status() {
  local id label app theme note dest group action key
  while IFS='|' read -r id label app theme note dest; do
    [[ -n "$id" ]] || continue
    case "$app" in
      found) group=0 ;;
      skip) group=1 ;;
      *) group=2 ;;
    esac
    case "$theme" in
      update) action=0 ;;
      none) action=1 ;;
      current) action=2 ;;
      *) action=3 ;;
    esac
    key="$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]')"
    printf '%s\t%s|%s|%s|%s|%s|%s\n' "${group}${action}${key}" "$id" "$label" "$app" "$theme" "$note" "$dest"
  done | LC_ALL=C sort | cut -f2-
}

stillwater_same_file() {
  local src="$1"
  local dest="$2"
  [[ -f "$src" && -f "$dest" ]] || return 1
  if stillwater_has_cmd cmp; then
    cmp -s "$src" "$dest"
    return
  fi
  [[ "$(wc -c <"$src")" == "$(wc -c <"$dest")" ]] || return 1
  [[ "$(cksum <"$src")" == "$(cksum <"$dest")" ]]
}

stillwater_iter_files() {
  local dir="$1"
  local entry
  local saved
  saved="$(shopt -p nullglob)"
  shopt -s nullglob
  for entry in "$dir"/*; do
    if [[ -d "$entry" ]]; then
      stillwater_iter_files "$entry"
    elif [[ -f "$entry" ]]; then
      printf '%s\n' "$entry"
    fi
  done
  eval "$saved"
}

stillwater_same_tree() {
  local src="$1"
  local dest="$2"
  local file rel
  [[ -d "$src" && -d "$dest" ]] || return 1
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    rel="${file#"$src"/}"
    stillwater_same_file "$file" "$dest/$rel" || return 1
  done < <(stillwater_iter_files "$src")
  return 0
}

stillwater_copy_state() {
  local src="$1"
  local dest="$2"
  if [[ -d "$src" ]]; then
    if [[ ! -d "$dest" ]]; then
      echo none
      return
    fi
    if stillwater_same_tree "$src" "$dest"; then
      echo current
    else
      echo update
    fi
    return
  fi
  if [[ ! -f "$dest" ]]; then
    echo none
    return
  fi
  if stillwater_same_file "$src" "$dest"; then
    echo current
  else
    echo update
  fi
}

stillwater_merge_theme_state() {
  local any_current=0
  local any_update=0
  local any_none=0
  local s
  if [[ $# -eq 0 ]]; then
    echo none
    return
  fi
  for s in "$@"; do
    case "$s" in
      current) any_current=1 ;;
      update) any_update=1 ;;
      *) any_none=1 ;;
    esac
  done
  if [[ "$any_update" == 1 ]]; then
    echo update
  elif [[ "$any_current" == 1 && "$any_none" == 1 ]]; then
    echo update
  elif [[ "$any_current" == 1 ]]; then
    echo current
  else
    echo none
  fi
}

stillwater_payload_state() {
  local states=()
  while [[ $# -ge 2 ]]; do
    states+=("$(stillwater_copy_state "$1" "$2")")
    shift 2
  done
  if [[ ${#states[@]} -eq 0 ]]; then
    echo none
    return
  fi
  stillwater_merge_theme_state "${states[@]}"
}

stillwater_vscode_payload_state() {
  local src="$1"
  local dest="$2"
  local parent keep state old oldver
  parent="$(dirname "$dest")"
  keep="$(basename "$dest")"
  state="$(stillwater_payload_state "$src/package.json" "$dest/package.json" "$src/themes" "$dest/themes")"
  if [[ "$state" == current ]]; then
    printf '%s|\n' current
    return
  fi
  if [[ "$state" == update ]]; then
    printf '%s|%s\n' update "$(stillwater_status_note update "$(stillwater_peek_version "$dest/package.json")")"
    return
  fi
  for old in "$parent"/kayzel.stillwater-theme-*; do
    [[ -e "$old" ]] || continue
    if [[ "$(basename "$old")" != "$keep" ]]; then
      oldver="$(stillwater_peek_version "$old/package.json")"
      if [[ -z "$oldver" ]]; then
        oldver="$(basename "$old")"
        oldver="${oldver#kayzel.stillwater-theme-}"
      fi
      printf '%s|%s\n' update "$(stillwater_status_note update "$oldver")"
      return
    fi
  done
  printf '%s|\n' none
}
