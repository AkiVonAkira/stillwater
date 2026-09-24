# Clack-style multi-select for install.sh. Colors come from palette.json.

stillwater_picker_color() {
  [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-}" != dumb ]]
}

stillwater_picker_init_style() {
  stillwater_load_theme_ansi
  if ! stillwater_picker_color; then
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
  SW_HIDE=$'\033[?25l'
  SW_SHOW=$'\033[?25h'
  SW_CLEAR=$'\033[2K'
  SW_START="┌"
  SW_DIAMOND="◆"
  SW_DONE="◇"
  SW_CANCEL="■"
  SW_PIPE="│"
  SW_CORNER="└"
  SW_ON="●"
  SW_OFF="○"
}

stillwater_picker_selectable() {
  [[ "$1" == found ]]
}

stillwater_picker_action() {
  local app="$1"
  local theme="$2"
  case "$app" in
    skip) printf 'Not found' ;;
    n/a) printf 'Linux only' ;;
    *)
      case "$theme" in
        none) printf 'Install' ;;
        current) printf 'Up to date' ;;
        update) printf 'Update' ;;
        *) printf '%s' "$theme" ;;
      esac
      ;;
  esac
}

stillwater_picker_summary_name() {
  local label="$1"
  local theme="$2"
  case "$theme" in
    none) printf '%s to install' "$label" ;;
    update) printf '%s to update' "$label" ;;
    current) printf '%s, already current' "$label" ;;
    *) printf '%s' "$label" ;;
  esac
}

stillwater_picker_action_color() {
  local app="$1"
  local theme="$2"
  if ! stillwater_picker_selectable "$app"; then
    printf '%s' "$SW_MUTED"
    return
  fi
  case "$theme" in
    none) printf '%s' "$SW_ACCENT" ;;
    current) printf '%s' "$SW_ACCENT_DEEP" ;;
    update) printf '%s' "$SW_WARN" ;;
    *) printf '%s' "$SW_TEXT" ;;
  esac
}

stillwater_picker_parse() {
  local blob="$1"
  SW_IDS=()
  SW_LABELS=()
  SW_APPS=()
  SW_THEMES=()
  SW_NOTES=()
  SW_DESTS=()
  SW_SELECTED=()
  local id label app theme note dest
  while IFS='|' read -r id label app theme note dest; do
    [[ -n "$id" ]] || continue
    SW_IDS+=("$id")
    SW_LABELS+=("$label")
    SW_APPS+=("$app")
    SW_THEMES+=("$theme")
    SW_NOTES+=("$note")
    SW_DESTS+=("$dest")
    if stillwater_picker_selectable "$app" && [[ "$theme" != current ]]; then
      SW_SELECTED+=(1)
    else
      SW_SELECTED+=(0)
    fi
  done <<<"$blob"
}

stillwater_picker_path() {
  local dest="$1"
  local used="${2:-60}"
  local cols max
  cols="$(stillwater_term_cols)"
  max=$((cols - used))
  if [[ "$max" -lt 8 ]]; then
    return 0
  fi
  stillwater_fit_left "$(stillwater_display_path "$dest")" "$max"
}

stillwater_picker_first() {
  local i
  for i in "${!SW_IDS[@]}"; do
    if stillwater_picker_selectable "${SW_APPS[$i]}"; then
      echo "$i"
      return
    fi
  done
  echo 0
}

stillwater_picker_move() {
  local dir="$1"
  local n="${#SW_IDS[@]}"
  local i="$SW_CURSOR"
  local start="$SW_CURSOR"
  [[ "$n" -gt 0 ]] || return 0
  while true; do
    i=$(((i + dir + n) % n))
    if stillwater_picker_selectable "${SW_APPS[$i]}"; then
      SW_CURSOR="$i"
      return
    fi
    if [[ "$i" -eq "$start" ]]; then
      return
    fi
  done
}

stillwater_picker_toggle_all() {
  local i on=1
  for i in "${!SW_IDS[@]}"; do
    if stillwater_picker_selectable "${SW_APPS[$i]}" && [[ "${SW_SELECTED[$i]}" != 1 ]]; then
      on=0
      break
    fi
  done
  for i in "${!SW_IDS[@]}"; do
    if stillwater_picker_selectable "${SW_APPS[$i]}"; then
      if [[ "$on" == 1 ]]; then
        SW_SELECTED[$i]=0
      else
        SW_SELECTED[$i]=1
      fi
    fi
  done
}

stillwater_picker_none() {
  local i
  for i in "${!SW_IDS[@]}"; do
    SW_SELECTED[$i]=0
  done
}

stillwater_picker_rows() {
  echo $((${#SW_IDS[@]} + 3))
}

stillwater_picker_draw() {
  local i check label action note path color labelfg
  printf '%s%s%s  %sStillwater%s  %s%s  %s%s\n' \
    "$SW_CLEAR" "$SW_MUTED" "$SW_START" "$SW_ACCENT" "$SW_RESET" "$SW_WARM" "$(stillwater_os_label)" "$(stillwater_version)" "$SW_RESET" >&2
  printf '%s%s%s  %sWhich apps should get Stillwater?%s\n' \
    "$SW_CLEAR" "$SW_ACCENT" "$SW_DIAMOND" "$SW_TEXT" "$SW_RESET" >&2
  for i in "${!SW_IDS[@]}"; do
    label="$(printf '%-22s' "${SW_LABELS[$i]}")"
    action="$(printf '%-10s' "$(stillwater_picker_action "${SW_APPS[$i]}" "${SW_THEMES[$i]}")")"
    note="$(printf '%-16s' "${SW_NOTES[$i]}")"
    path="$(stillwater_picker_path "${SW_DESTS[$i]}")"
    color="$(stillwater_picker_action_color "${SW_APPS[$i]}" "${SW_THEMES[$i]}")"
    if ! stillwater_picker_selectable "${SW_APPS[$i]}"; then
      printf '%s%s%s     %s  %s  %s  %s%s\n' \
        "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" "$label" "$action" "$note" "$path" "$SW_RESET" >&2
      continue
    fi
    if [[ "${SW_SELECTED[$i]}" == 1 ]]; then
      check="${SW_ACCENT}${SW_ON}${SW_RESET}"
    elif [[ "$i" -eq "$SW_CURSOR" ]]; then
      check="${SW_ACCENT_HOVER}${SW_OFF}${SW_RESET}"
    else
      check="${SW_MUTED}${SW_OFF}${SW_RESET}"
    fi
    if [[ "$i" -eq "$SW_CURSOR" ]]; then
      labelfg="$SW_TEXT"
    else
      labelfg="$SW_MUTED"
    fi
    printf '%s%s%s%s  %s  %s%s  %s%s  %s%s  %s%s%s\n' \
      "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" "$SW_RESET" "$check" "$labelfg" "$label" "$color" "$action" "$SW_MUTED" "$note" "$path" "$SW_RESET" >&2
  done
  printf '%s%s%s  Space selects, a selects all found, Enter installs%s\n' "$SW_CLEAR" "$SW_MUTED" "$SW_CORNER" "$SW_RESET" >&2
}

stillwater_picker_redraw() {
  printf '\033[%dA' "$1" >&2
  stillwater_picker_draw
}

stillwater_picker_erase() {
  printf '\033[%dA' "$1" >&2
}

stillwater_picker_summary() {
  local i names=()
  for i in "${!SW_IDS[@]}"; do
    if [[ "${SW_SELECTED[$i]}" == 1 ]]; then
      names+=("$(stillwater_picker_summary_name "${SW_LABELS[$i]}" "${SW_THEMES[$i]}")")
    fi
  done
  printf '%s%s%s  %sStillwater%s  %s%s  %s%s\n' \
    "$SW_CLEAR" "$SW_MUTED" "$SW_START" "$SW_ACCENT" "$SW_RESET" "$SW_WARM" "$(stillwater_os_label)" "$(stillwater_version)" "$SW_RESET" >&2
  printf '%s%s%s  %sWhich apps should get Stillwater?%s\n' \
    "$SW_CLEAR" "$SW_ACCENT_HOVER" "$SW_DONE" "$SW_TEXT" "$SW_RESET" >&2
  if [[ ${#names[@]} -eq 0 ]]; then
    printf '%s%s%s  Nothing selected.%s\n' "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" "$SW_RESET" >&2
  else
    local joined
    joined="$(printf '%s, ' "${names[@]}")"
    joined="${joined%, }"
    printf '%s%s%s  %s%s%s\n' "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" "$SW_TEXT" "$joined" "$SW_RESET" >&2
  fi
  printf '\033[J' >&2
}

stillwater_picker_read_key() {
  local k1 k2 k3
  IFS= read -rsn1 k1 || return 1
  case "$k1" in
    $'\x03') printf 'quit\n' ;;
    $'\n' | $'\r' | "") printf 'enter\n' ;;
    " ") printf 'space\n' ;;
    q | Q) printf 'quit\n' ;;
    a | A) printf 'all\n' ;;
    n | N) printf 'none\n' ;;
    j) printf 'down\n' ;;
    k) printf 'up\n' ;;
    $'\x1b')
      IFS= read -rsn1 k2 || { printf 'quit\n'; return 0; }
      if [[ "$k2" != '[' ]]; then
        printf 'quit\n'
        return 0
      fi
      IFS= read -rsn1 k3 || { printf 'quit\n'; return 0; }
      case "$k3" in
        A) printf 'up\n' ;;
        B) printf 'down\n' ;;
        *) printf 'other\n' ;;
      esac
      ;;
    *) printf 'other\n' ;;
  esac
}

stillwater_picker_restore() {
  printf '%s' "$SW_SHOW" >&2
  if [[ -n "${SW_STTY:-}" ]]; then
    stty "$SW_STTY" 2>/dev/null || true
  fi
}

# Sets STILLWATER_PICKED to selected adapter ids. Exit 0 on confirm, 1 on cancel.
stillwater_picker() {
  local blob="$1"
  STILLWATER_PICKED=()
  stillwater_picker_init_style
  stillwater_picker_parse "$blob"
  if [[ ${#SW_IDS[@]} -eq 0 ]]; then
    echo "No adapters found." >&2
    return 1
  fi
  SW_CURSOR="$(stillwater_picker_first)"
  SW_STTY="$(stty -g 2>/dev/null || true)"
  printf '%s' "$SW_HIDE" >&2
  trap 'stillwater_picker_restore; trap - EXIT INT TERM; exit 130' INT TERM
  trap 'stillwater_picker_restore' EXIT
  stillwater_picker_draw
  local rows key
  rows="$(stillwater_picker_rows)"
  while true; do
    key="$(stillwater_picker_read_key || true)"
    case "$key" in
      up) stillwater_picker_move -1 ;;
      down) stillwater_picker_move 1 ;;
      space)
        if stillwater_picker_selectable "${SW_APPS[$SW_CURSOR]}"; then
          if [[ "${SW_SELECTED[$SW_CURSOR]}" == 1 ]]; then
            SW_SELECTED[$SW_CURSOR]=0
          else
            SW_SELECTED[$SW_CURSOR]=1
          fi
        fi
        ;;
      all) stillwater_picker_toggle_all ;;
      none) stillwater_picker_none ;;
      enter)
        stillwater_picker_erase "$rows"
        stillwater_picker_summary
        local i
        for i in "${!SW_IDS[@]}"; do
          if [[ "${SW_SELECTED[$i]}" == 1 ]]; then
            STILLWATER_PICKED+=("${SW_IDS[$i]}")
          fi
        done
        stillwater_picker_restore
        trap - EXIT INT TERM
        return 0
        ;;
      quit)
        stillwater_picker_erase "$rows"
        printf '%s%s%s  Cancelled.%s\n' "$SW_CLEAR" "$SW_ERROR" "$SW_CANCEL" "$SW_RESET" >&2
        printf '\033[J' >&2
        stillwater_picker_restore
        trap - EXIT INT TERM
        return 1
        ;;
    esac
        stillwater_picker_redraw "$rows"
  done
}

stillwater_clack() {
  [[ -t 1 ]]
}

stillwater_clack_header() {
  printf '%s%s%s  %sStillwater%s  %s%s  %s%s\n' \
    "$SW_CLEAR" "$SW_MUTED" "$SW_START" "$SW_ACCENT" "$SW_RESET" "$SW_WARM" "$(stillwater_os_label)" "$(stillwater_version)" "$SW_RESET" >&2
}

stillwater_clack_step() {
  local color="${1:-$SW_ACCENT}"
  local mark="${2:-$SW_DIAMOND}"
  local text="$3"
  printf '%s%s%s  %s%s%s\n' "$SW_CLEAR" "$color" "$mark" "$SW_TEXT" "$text" "$SW_RESET" >&2
}

stillwater_clack_row() {
  local state="$1"
  local label="$2"
  local hint="${3:-}"
  local mark color labelfg hintfg
  labelfg="$SW_TEXT"
  hintfg="$SW_MUTED"
  case "$state" in
    ok)
      mark="$SW_ON"
      color="$SW_ACCENT"
      ;;
    fail)
      mark="$SW_CANCEL"
      color="$SW_ERROR"
      hintfg="$SW_ERROR"
      ;;
    skip)
      mark="$SW_OFF"
      color="$SW_MUTED"
      labelfg="$SW_MUTED"
      ;;
    busy)
      mark="$SW_OFF"
      color="$SW_ACCENT_HOVER"
      ;;
    next)
      printf '%s%s%s  %s%-22s%s  %s%s%s\n' \
        "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" "$SW_TEXT" "$label" "$SW_RESET" "$SW_MUTED" "$hint" "$SW_RESET" >&2
      return 0
      ;;
    *)
      mark="$SW_OFF"
      color="$SW_MUTED"
      labelfg="$SW_MUTED"
      ;;
  esac
  printf '%s%s%s  %s%s%s  %s%-22s%s  %s%s%s\n' \
    "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" "$color" "$mark" "$SW_RESET" \
    "$labelfg" "$label" "$SW_RESET" "$hintfg" "$hint" "$SW_RESET" >&2
}

stillwater_clack_end() {
  local text="$1"
  printf '%s%s%s  %s%s%s\n' "$SW_CLEAR" "$SW_MUTED" "$SW_CORNER" "$text" "$SW_RESET" >&2
}

stillwater_clack_up() {
  printf '\033[%dA' "$1" >&2
}
