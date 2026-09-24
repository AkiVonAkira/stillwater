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
HEXMAP="$ROOT/yasb/hex.map"
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

yasb_skip_hex() {
  case "$1" in
    0078d4 | 199143 | ff583b | 1db954 | ffffff | 000000) return 0 ;;
    *) return 1 ;;
  esac
}

yasb_hex_role() {
  local hex="$1"
  hex="$(printf '%s' "$hex" | tr '[:upper:]' '[:lower:]')"
  sed -n "s/^${hex}[[:space:]]\{1,\}//p" "$HEXMAP" | head -n 1
}

yasb_expand_hex() {
  local h="$1"
  h="$(printf '%s' "$h" | tr '[:upper:]' '[:lower:]')"
  if [[ ${#h} -eq 3 ]]; then
    printf '%s%s%s%s%s%s' "${h:0:1}" "${h:0:1}" "${h:1:1}" "${h:1:1}" "${h:2:1}" "${h:2:1}"
    return 0
  fi
  printf '%s' "$h"
}

yasb_map_hex() {
  local hex="$1" role
  hex="$(yasb_expand_hex "$hex")"
  if yasb_skip_hex "$hex"; then
    return 1
  fi
  role="$(yasb_hex_role "$hex")"
  [[ -n "$role" ]] || return 1
  yasb_hex "$role"
}

yasb_rewrite_colors() {
  local cursor="$1" rebuilt="" match hex mapped r g b rest pre found
  local rgb_re='rgba?\([[:space:]]*([0-9]+)[[:space:]]*,[[:space:]]*([0-9]+)[[:space:]]*,[[:space:]]*([0-9]+)[[:space:]]*(,[^)]*)?\)'
  while [[ "$cursor" =~ $rgb_re ]]; do
    match="${BASH_REMATCH[0]}"
    r="${BASH_REMATCH[1]}"
    g="${BASH_REMATCH[2]}"
    b="${BASH_REMATCH[3]}"
    rest="${BASH_REMATCH[4]}"
    hex="$(printf '%02x%02x%02x' "$r" "$g" "$b")"
    mapped="$(yasb_map_hex "$hex" || true)"
    pre="${cursor%%"$match"*}"
    rebuilt+="$pre"
    if [[ -n "$mapped" ]]; then
      r=$((16#${mapped:0:2}))
      g=$((16#${mapped:2:2}))
      b=$((16#${mapped:4:2}))
      if [[ "$match" == rgba* ]]; then
        rebuilt+="rgba(${r}, ${g}, ${b}${rest})"
      else
        rebuilt+="rgb(${r}, ${g}, ${b})"
      fi
    else
      rebuilt+="$match"
    fi
    cursor="${cursor#*"$match"}"
  done
  cursor="$rebuilt$cursor"
  rebuilt=""
  local hex_re='#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})'
  while [[ "$cursor" =~ $hex_re ]]; do
    found="${BASH_REMATCH[0]}"
    hex="$(yasb_expand_hex "${BASH_REMATCH[1]}")"
    mapped="$(yasb_map_hex "$hex" || true)"
    pre="${cursor%%"$found"*}"
    rebuilt+="$pre"
    if [[ -n "$mapped" ]]; then
      rebuilt+="#$mapped"
    else
      rebuilt+="$found"
    fi
    cursor="${cursor#*"$found"}"
  done
  printf '%s' "$rebuilt$cursor"
}

yasb_rewrite_line() {
  local line="$1"
  local indent name value rest role hex
  local re='^([[:space:]]*)--([A-Za-z0-9-]+)[[:space:]]*:[[:space:]]*([^;]+);(.*)$'
  if [[ ! "$line" =~ $re ]]; then
    yasb_rewrite_colors "$line"
    printf '\n'
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
  if [[ -n "$role" ]]; then
    hex="$(yasb_hex "$role")"
    if [[ -n "$hex" ]]; then
      printf '%s--%s: %s;%s\n' "$indent" "$name" "$(yasb_format "$value" "$hex")" "$rest"
      return 0
    fi
  fi
  yasb_rewrite_colors "$line"
  printf '\n'
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
    yasb_rewrite_line "$line" >>"$out"
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
