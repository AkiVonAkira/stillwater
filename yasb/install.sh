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

yasb_role() {
  local name="$1" key
  name="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  key="$(sed -n "s/^${name}[[:space:]]\{1,\}//p" "$MAP" | head -n 1)"
  if [[ -z "$key" && "$name" == *-rgb ]]; then
    name="${name%-rgb}"
    key="$(sed -n "s/^${name}[[:space:]]\{1,\}//p" "$MAP" | head -n 1)"
  fi
  [[ -n "$key" ]] || return 1
  printf '%s' "$key"
}

yasb_hex() {
  local role="$1"
  stillwater_palette_hex "$role"
}

yasb_format() {
  local old="$1" hex="$2"
  local r g b alpha
  hex="$(printf '%s' "$hex" | tr '[:upper:]' '[:lower:]')"
  r=$((16#${hex:0:2}))
  g=$((16#${hex:2:2}))
  b=$((16#${hex:4:2}))
  if [[ "$old" == rgba\(* ]]; then
    alpha="${old##*,}"
    alpha="${alpha%)}"
    printf 'rgba(%d, %d, %d,%s)' "$r" "$g" "$b" "$alpha"
  elif [[ "$old" == rgb\(* ]]; then
    printf 'rgb(%d, %d, %d)' "$r" "$g" "$b"
  elif [[ "$old" =~ ^[0-9]+, ]]; then
    printf '%d, %d, %d' "$r" "$g" "$b"
  else
    printf '#%s' "$hex"
  fi
}

yasb_rewrite_line() {
  local line="$1"
  local indent name value rest role hex
  local re='^([[:space:]]*)--([A-Za-z0-9-]+)[[:space:]]*:[[:space:]]*([^;]+);(.*)$'
  if [[ ! "$line" =~ $re ]]; then
    printf '%s\n' "$line"
    return 0
  fi
  indent="${BASH_REMATCH[1]}"
  name="${BASH_REMATCH[2]}"
  value="${BASH_REMATCH[3]}"
  rest="${BASH_REMATCH[4]}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#"${value%%[![:space:]]*}"}"
  if [[ "$value" == var\(* || "$value" == transparent || "$value" == none ]]; then
    printf '%s\n' "$line"
    return 0
  fi
  role="$(yasb_role "$name" || true)"
  if [[ -z "$role" ]]; then
    printf '%s\n' "$line"
    return 0
  fi
  hex="$(yasb_hex "$role")"
  if [[ -z "$hex" ]]; then
    printf '%s\n' "$line"
    return 0
  fi
  printf '%s--%s: %s;%s\n' "$indent" "$name" "$(yasb_format "$value" "$hex")" "$rest"
}

# ponytail: one-level :root brace count. Nested blocks inside :root are not expected in YASB themes.
yasb_rewrite() {
  local dest="$1" out="$2"
  local version depth=0 in_root=0 line stamped=0 opens closes was i c
  version="$(stillwater_version)"
  : >"$out"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$line" == *"@version"* ]]; then
      line="$(printf '%s' "$line" | sed "s/@version[[:space:]]*[0-9][0-9.]*[0-9]/@version ${version}/")"
      stamped=1
    fi
    if [[ "$depth" -eq 0 && "$stamped" -eq 0 && "$line" == *":root"* ]]; then
      printf '%s\n' "/* @version ${version} */" >>"$out"
      stamped=1
    fi
    was="$depth"
    opens=0
    closes=0
    for ((i = 0; i < ${#line}; i++)); do
      c="${line:i:1}"
      if [[ "$c" == '{' ]]; then
        opens=$((opens + 1))
      elif [[ "$c" == '}' ]]; then
        closes=$((closes + 1))
      fi
    done
    if [[ "$line" == *":root"* ]]; then
      in_root=1
    fi
    if [[ "$in_root" -eq 1 ]]; then
      yasb_rewrite_line "$line" >>"$out"
    else
      printf '%s\n' "$line" >>"$out"
    fi
    depth=$((was + opens - closes))
    if [[ "$depth" -lt 0 ]]; then
      depth=0
    fi
    if [[ "$in_root" -eq 1 && "$depth" -eq 0 ]]; then
      in_root=0
    fi
  done <"$dest"
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
