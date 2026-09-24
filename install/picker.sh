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
  SW_BAR_ON="█"
  SW_BAR_BUSY="▒"
  SW_BAR_OFF="░"
  SW_SPIN_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  SW_SPIN_I=0
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

stillwater_job_verb() {
  local theme="$1"
  local state="$2"
  case "$state" in
    skip) printf 'missing' ;;
    fail) printf 'failed' ;;
    pending) printf 'queued' ;;
    busy)
      case "$theme" in
        current) printf 'refreshing' ;;
        update) printf 'updating' ;;
        *) printf 'installing' ;;
      esac
      ;;
    ok)
      case "$theme" in
        current) printf 'refreshed' ;;
        update) printf 'updated' ;;
        *) printf 'installed' ;;
      esac
      ;;
    *) printf '%s' "$state" ;;
  esac
}

stillwater_job_verb_color() {
  local theme="$1"
  local state="$2"
  case "$state" in
    skip | pending) printf '%s' "$SW_MUTED" ;;
    fail) printf '%s' "$SW_ERROR" ;;
    busy)
      case "$theme" in
        update) printf '%s' "$SW_WARN" ;;
        *) printf '%s' "$SW_ACCENT_HOVER" ;;
      esac
      ;;
    ok) printf '%s' "$SW_ACCENT" ;;
    *) printf '%s' "$SW_TEXT" ;;
  esac
}

stillwater_spin_frame() {
  local n="${#SW_SPIN_FRAMES[@]}"
  if [[ "$n" -eq 0 ]]; then
    printf '%s' "$SW_OFF"
    return
  fi
  printf '%s' "${SW_SPIN_FRAMES[SW_SPIN_I % n]}"
}

stillwater_progress_bar() {
  local done="$1"
  local total="$2"
  local width="${3:-20}"
  local busy="${4:-0}"
  local i filled=0
  if [[ "$width" -lt 4 ]]; then
    width=4
  fi
  if [[ "$total" -gt 0 ]]; then
    filled=$((done * width / total))
  fi
  if [[ "$filled" -gt "$width" ]]; then
    filled="$width"
  fi
  if [[ "$busy" == 1 && "$filled" -ge "$width" ]]; then
    filled=$((width - 1))
  fi
  for ((i = 0; i < width; i++)); do
    if [[ "$i" -lt "$filled" ]]; then
      printf '%s' "$SW_BAR_ON"
    elif [[ "$busy" == 1 && "$i" -eq "$filled" ]]; then
      printf '%s' "$SW_BAR_BUSY"
    else
      printf '%s' "$SW_BAR_OFF"
    fi
  done
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
  cols="${SW_COLS:-$(stillwater_term_cols)}"
  max=$((cols - used))
  if [[ "$max" -lt 8 ]]; then
    return 0
  fi
  stillwater_fit_left "$(stillwater_display_path "$dest")" "$max"
}

stillwater_picker_cache() {
  local i cols max
  SW_OS_LABEL="$(stillwater_os_label)"
  SW_VERSION="$(stillwater_version)"
  SW_COLS="$(stillwater_term_cols)"
  cols="$SW_COLS"
  max=$((cols - 60))
  SW_ROW_LABEL=()
  SW_ROW_ACTION=()
  SW_ROW_NOTE=()
  SW_ROW_PATH=()
  SW_ROW_COLOR=()
  for i in "${!SW_IDS[@]}"; do
    SW_ROW_LABEL+=("$(printf '%-22s' "${SW_LABELS[$i]}")")
    SW_ROW_ACTION+=("$(printf '%-10s' "$(stillwater_picker_action "${SW_APPS[$i]}" "${SW_THEMES[$i]}")")")
    SW_ROW_NOTE+=("$(printf '%-16s' "${SW_NOTES[$i]}")")
    if [[ "$max" -lt 8 ]]; then
      SW_ROW_PATH+=("")
    else
      SW_ROW_PATH+=("$(stillwater_fit_left "$(stillwater_display_path "${SW_DESTS[$i]}")" "$max")")
    fi
    SW_ROW_COLOR+=("$(stillwater_picker_action_color "${SW_APPS[$i]}" "${SW_THEMES[$i]}")")
  done
  SW_KEYMAP_PLAIN="$(stillwater_keymap_plain)"
  if [[ ${#SW_KEYMAP_PLAIN} -ge cols ]]; then
    SW_FOOTER_LINES=2
  else
    SW_FOOTER_LINES=1
  fi
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
  echo $((${#SW_IDS[@]} + 2 + ${SW_FOOTER_LINES:-1}))
}

stillwater_hint_pair() {
  printf '%s%s%s %s%s%s' "$SW_ACCENT" "$1" "$SW_RESET" "$SW_MUTED" "$2" "$SW_RESET"
}

stillwater_hint_sep() {
  printf '  %s·%s  ' "$SW_MUTED" "$SW_RESET"
}

stillwater_keymap_plain() {
  printf '└  ↑↓ jk nav  ·  space toggle  ·  a all  ·  n none  ·  enter apply  ·  q abort'
}

stillwater_keymap_select() {
  local cols="${SW_COLS:-$(stillwater_term_cols)}"
  local plain wrap=0
  plain="${SW_KEYMAP_PLAIN:-$(stillwater_keymap_plain)}"
  if [[ "${SW_FOOTER_LINES:-0}" -eq 2 || ${#plain} -ge cols ]]; then
    wrap=1
  fi
  printf '%s%s%s  ' "$SW_CLEAR" "$SW_MUTED" "$SW_CORNER"
  stillwater_hint_pair '↑↓ jk' nav
  stillwater_hint_sep
  stillwater_hint_pair space toggle
  stillwater_hint_sep
  stillwater_hint_pair a all
  if [[ "$wrap" == 1 ]]; then
    printf '%s\n' "$SW_RESET"
    printf '%s%s   ' "$SW_CLEAR" "$SW_MUTED"
  else
    stillwater_hint_sep
  fi
  stillwater_hint_pair n none
  stillwater_hint_sep
  stillwater_hint_pair enter apply
  stillwater_hint_sep
  stillwater_hint_pair q abort
  printf '%s\n' "$SW_RESET"
}

stillwater_picker_print_row() {
  local i="$1"
  local check labelfg
  if ! stillwater_picker_selectable "${SW_APPS[$i]}"; then
    printf '%s%s%s     %s  %s  %s  %s%s\n' \
      "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" \
      "${SW_ROW_LABEL[$i]}" "${SW_ROW_ACTION[$i]}" "${SW_ROW_NOTE[$i]}" "${SW_ROW_PATH[$i]}" "$SW_RESET" >&2
    return
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
    "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" "$SW_RESET" "$check" "$labelfg" "${SW_ROW_LABEL[$i]}" \
    "${SW_ROW_COLOR[$i]}" "${SW_ROW_ACTION[$i]}" "$SW_MUTED" "${SW_ROW_NOTE[$i]}" "${SW_ROW_PATH[$i]}" "$SW_RESET" >&2
}

stillwater_picker_draw() {
  local i
  printf '%s%s%s  %sStillwater%s  %s%s  %s%s\n' \
    "$SW_CLEAR" "$SW_MUTED" "$SW_START" "$SW_ACCENT" "$SW_RESET" "$SW_WARM" "$SW_OS_LABEL" "$SW_VERSION" "$SW_RESET" >&2
  printf '%s%s%s  %sselect%s\n' \
    "$SW_CLEAR" "$SW_ACCENT" "$SW_DIAMOND" "$SW_TEXT" "$SW_RESET" >&2
  for i in "${!SW_IDS[@]}"; do
    stillwater_picker_print_row "$i"
  done
  stillwater_keymap_select >&2
}

stillwater_picker_redraw() {
  printf '\033[%dA' "$1" >&2
  stillwater_picker_draw
}

stillwater_picker_repaint_rows() {
  local n="${#SW_IDS[@]}"
  local footer="${SW_FOOTER_LINES:-1}"
  local i up down
  for i in "$@"; do
    [[ -n "$i" ]] || continue
    up=$((footer + n - i))
    printf '\033[%dA' "$up" >&2
    stillwater_picker_print_row "$i"
    down=$((n - i - 1 + footer))
    if [[ "$down" -gt 0 ]]; then
      printf '\033[%dB' "$down" >&2
    fi
  done
}

stillwater_picker_erase() {
  printf '\033[%dA' "$1" >&2
}

stillwater_jobs_rows() {
  echo $((${#SW_JOB_LABELS[@]} + 3))
}

stillwater_jobs_mark() {
  local theme="$1"
  local state="$2"
  local color
  color="$(stillwater_job_verb_color "$theme" "$state")"
  case "$state" in
    ok) printf '%s%s%s' "$color" "$SW_ON" "$SW_RESET" ;;
    fail) printf '%s%s%s' "$color" "$SW_CANCEL" "$SW_RESET" ;;
    busy) printf '%s%s%s' "$color" "$(stillwater_spin_frame)" "$SW_RESET" ;;
    *) printf '%s%s%s' "$color" "$SW_OFF" "$SW_RESET" ;;
  esac
}

stillwater_jobs_footer() {
  local done="$1"
  local total="$2"
  local running="$3"
  local busy="$4"
  local summary="$5"
  if [[ "$running" == 1 ]]; then
    printf '%s%s%s  %s%s/%s%s  %s%s%s%s\n' \
      "$SW_CLEAR" "$SW_MUTED" "$SW_CORNER" \
      "$SW_TEXT" "$done" "$total" "$SW_RESET" \
      "$SW_ACCENT" "$(stillwater_progress_bar "$done" "$total" 24 "$busy")" "$SW_RESET"
  else
    printf '%s%s%s  %s%s%s\n' "$SW_CLEAR" "$SW_MUTED" "$SW_CORNER" "$SW_TEXT" "$summary" "$SW_RESET"
  fi
}

stillwater_jobs_next() {
  local text="$1"
  local cols max
  [[ -n "$text" ]] || return 0
  cols="${SW_COLS:-$(stillwater_term_cols)}"
  max=$((cols - 42))
  if [[ "$max" -lt 12 ]]; then
    printf '%s' "$text"
    return 0
  fi
  stillwater_fit_left "$text" "$max"
}

stillwater_jobs_draw() {
  local summary="${1:-}"
  local i label verb next mark vcolor labelfg done=0 total=0 busy=0 running=0
  total="${#SW_JOB_LABELS[@]}"
  for i in "${!SW_JOB_LABELS[@]}"; do
    case "${SW_JOB_STATES[$i]}" in
      busy) busy=1 ; running=1 ;;
      pending) running=1 ;;
      *) done=$((done + 1)) ;;
    esac
  done
  printf '%s%s%s  %sStillwater%s  %s%s  %s%s\n' \
    "$SW_CLEAR" "$SW_MUTED" "$SW_START" "$SW_ACCENT" "$SW_RESET" "$SW_WARM" "$(stillwater_os_label)" "$(stillwater_version)" "$SW_RESET" >&2
  if [[ "$running" == 1 ]]; then
    printf '%s%s%s  %sinstall%s\n' \
      "$SW_CLEAR" "$SW_ACCENT" "$SW_DIAMOND" "$SW_TEXT" "$SW_RESET" >&2
  else
    printf '%s%s%s  %sinstall%s\n' \
      "$SW_CLEAR" "$SW_ACCENT_HOVER" "$SW_DONE" "$SW_TEXT" "$SW_RESET" >&2
  fi
  for i in "${!SW_JOB_LABELS[@]}"; do
    label="$(printf '%-22s' "${SW_JOB_LABELS[$i]}")"
    verb="$(printf '%-11s' "$(stillwater_job_verb "${SW_JOB_THEMES[$i]}" "${SW_JOB_STATES[$i]}")")"
    vcolor="$(stillwater_job_verb_color "${SW_JOB_THEMES[$i]}" "${SW_JOB_STATES[$i]}")"
    mark="$(stillwater_jobs_mark "${SW_JOB_THEMES[$i]}" "${SW_JOB_STATES[$i]}")"
    if [[ "${SW_JOB_STATES[$i]}" == ok ]]; then
      labelfg="$SW_TEXT"
      next="$(stillwater_jobs_next "${SW_JOB_NEXTS[$i]}")"
    elif [[ "${SW_JOB_STATES[$i]}" == fail ]]; then
      labelfg="$SW_TEXT"
      next=""
    else
      labelfg="$SW_MUTED"
      next=""
    fi
    printf '%s%s%s%s  %s  %s%s%s  %s%s%s  %s%s%s\n' \
      "$SW_CLEAR" "$SW_MUTED" "$SW_PIPE" "$SW_RESET" "$mark" \
      "$labelfg" "$label" "$SW_RESET" \
      "$vcolor" "$verb" "$SW_RESET" \
      "$SW_MUTED" "$next" "$SW_RESET" >&2
  done
  stillwater_jobs_footer "$done" "$total" "$running" "$busy" "$summary" >&2
  printf '\033[J' >&2
}

stillwater_jobs_redraw() {
  printf '\033[%dA' "$(stillwater_jobs_rows)" >&2
  stillwater_jobs_draw "$1"
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
# Leaves the cursor hidden on confirm so install.sh can reuse the box.
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
  stillwater_picker_cache
  stillwater_picker_draw
  local rows key prev
  rows="$(stillwater_picker_rows)"
  SW_PICKER_ROWS="$rows"
  while true; do
    key="$(stillwater_picker_read_key || true)"
    case "$key" in
      up)
        prev="$SW_CURSOR"
        stillwater_picker_move -1
        if [[ "$prev" != "$SW_CURSOR" ]]; then
          stillwater_picker_repaint_rows "$prev" "$SW_CURSOR"
        fi
        ;;
      down)
        prev="$SW_CURSOR"
        stillwater_picker_move 1
        if [[ "$prev" != "$SW_CURSOR" ]]; then
          stillwater_picker_repaint_rows "$prev" "$SW_CURSOR"
        fi
        ;;
      space)
        if stillwater_picker_selectable "${SW_APPS[$SW_CURSOR]}"; then
          if [[ "${SW_SELECTED[$SW_CURSOR]}" == 1 ]]; then
            SW_SELECTED[$SW_CURSOR]=0
          else
            SW_SELECTED[$SW_CURSOR]=1
          fi
          stillwater_picker_repaint_rows "$SW_CURSOR"
        fi
        ;;
      all)
        stillwater_picker_toggle_all
        stillwater_picker_redraw "$rows"
        ;;
      none)
        stillwater_picker_none
        stillwater_picker_redraw "$rows"
        ;;
      enter)
        local i
        for i in "${!SW_IDS[@]}"; do
          if [[ "${SW_SELECTED[$i]}" == 1 ]]; then
            STILLWATER_PICKED+=("${SW_IDS[$i]}")
          fi
        done
        trap - EXIT
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
  done
}

stillwater_clack() {
  [[ -t 1 ]]
}
