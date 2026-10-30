# Clack-style multi-select for install.sh. Colors come from palette.json.
# The picker and the install progress repaint whole frames on the alternate
# screen, so scrollback and resizes cannot tear them. The result prints once to
# the normal screen. Frame code avoids $(...) because forks are slow in Git Bash.
# Functions named *_into write their result to the variable named by $1, so
# leaf helpers keep their locals _-prefixed and cannot shadow the caller.

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
  SW_HOME=$'\033[H'
  SW_EOS=$'\033[J'
  SW_WIPE=$'\033[2J'
  # 1049 is the alternate screen. 1007 turns the mouse wheel into arrow keys there.
  SW_ALT_ON=$'\033[?1049h\033[?1007h'
  SW_ALT_OFF=$'\033[?1007l\033[?1049l'
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
  if [[ "${BASH_VERSINFO[0]:-3}" -ge 4 ]]; then
    SW_READ_T=0.2
    SW_ESC_T=0.05
  else
    SW_READ_T=1
    SW_ESC_T=1
  fi
}

stillwater_screen_enter() {
  if [[ "${SW_ALT:-0}" != 1 ]]; then
    printf '%s%s%s' "$SW_ALT_ON" "$SW_HIDE" "$SW_WIPE" >&2
    SW_ALT=1
  fi
}

stillwater_screen_leave() {
  if [[ "${SW_ALT:-0}" == 1 ]]; then
    printf '%s' "$SW_ALT_OFF" >&2
    SW_ALT=0
  fi
}

stillwater_picker_selectable() {
  [[ "$1" == found ]]
}

stillwater_picker_action_into() {
  local _o
  case "$2" in
    skip) _o='Not found' ;;
    n/a) _o='Linux only' ;;
    *)
      case "$3" in
        none) _o='Install' ;;
        current) _o='Up to date' ;;
        update) _o='Update' ;;
        switch) _o='Switch' ;;
        *) _o="$3" ;;
      esac
      ;;
  esac
  printf -v "$1" '%s' "$_o"
}

stillwater_picker_action_color_into() {
  local _o
  if ! stillwater_picker_selectable "$2"; then
    _o="$SW_MUTED"
  else
    case "$3" in
      none) _o="$SW_ACCENT" ;;
      current) _o="$SW_ACCENT_DEEP" ;;
      update | switch) _o="$SW_WARN" ;;
      *) _o="$SW_TEXT" ;;
    esac
  fi
  printf -v "$1" '%s' "$_o"
}

stillwater_job_verb_into() {
  local _o
  case "$3" in
    skip) _o='missing' ;;
    fail) _o='failed' ;;
    pending) _o='queued' ;;
    busy)
      case "$2" in
        current) _o='refreshing' ;;
        update) _o='updating' ;;
        switch) _o='switching' ;;
        *) _o='installing' ;;
      esac
      ;;
    ok)
      case "$2" in
        current) _o='refreshed' ;;
        update) _o='updated' ;;
        switch) _o='switched' ;;
        *) _o='installed' ;;
      esac
      ;;
    *) _o="$3" ;;
  esac
  printf -v "$1" '%s' "$_o"
}

stillwater_job_verb_color_into() {
  local _o
  case "$3" in
    skip | pending) _o="$SW_MUTED" ;;
    fail) _o="$SW_ERROR" ;;
    busy)
      case "$2" in
        update | switch) _o="$SW_WARN" ;;
        *) _o="$SW_ACCENT_HOVER" ;;
      esac
      ;;
    ok) _o="$SW_ACCENT" ;;
    *) _o="$SW_TEXT" ;;
  esac
  printf -v "$1" '%s' "$_o"
}

stillwater_spin_frame_into() {
  local _n="${#SW_SPIN_FRAMES[@]}"
  if [[ "$_n" -eq 0 ]]; then
    printf -v "$1" '%s' "$SW_OFF"
    return
  fi
  printf -v "$1" '%s' "${SW_SPIN_FRAMES[SW_SPIN_I % _n]}"
}

stillwater_progress_bar_into() {
  local _done="$2"
  local _total="$3"
  local _width="${4:-20}"
  local _busy="${5:-0}"
  local _i _filled=0 _o=""
  if [[ "$_width" -lt 4 ]]; then
    _width=4
  fi
  if [[ "$_total" -gt 0 ]]; then
    _filled=$((_done * _width / _total))
  fi
  if [[ "$_filled" -gt "$_width" ]]; then
    _filled="$_width"
  fi
  if [[ "$_busy" == 1 && "$_filled" -ge "$_width" ]]; then
    _filled=$((_width - 1))
  fi
  for ((_i = 0; _i < _width; _i++)); do
    if [[ "$_i" -lt "$_filled" ]]; then
      _o+="$SW_BAR_ON"
    elif [[ "$_busy" == 1 && "$_i" -eq "$_filled" ]]; then
      _o+="$SW_BAR_BUSY"
    else
      _o+="$SW_BAR_OFF"
    fi
  done
  printf -v "$1" '%s' "$_o"
}

stillwater_progress_bar() {
  local _r
  stillwater_progress_bar_into _r "$@"
  printf '%s' "$_r"
}

# Pads text to width, or cuts it with an ellipsis.
stillwater_pad_into() {
  local _s="$2"
  local _w="$3"
  local _pad
  if [[ "$_w" -le 0 ]]; then
    _s=""
  elif [[ ${#_s} -gt "$_w" ]]; then
    if [[ "$_w" -le 1 ]]; then
      _s='…'
    else
      _s="${_s:0:$((_w - 1))}…"
    fi
  else
    printf -v _pad '%*s' $((_w - ${#_s})) ''
    _s+="$_pad"
  fi
  printf -v "$1" '%s' "$_s"
}

# Keeps the end of a path, which is the part that tells paths apart.
stillwater_fit_left_into() {
  local _s="$2"
  local _w="$3"
  local _len=${#_s}
  if [[ -z "$_s" || "$_w" -le 0 ]]; then
    _s=""
  elif [[ "$_len" -gt "$_w" ]]; then
    if [[ "$_w" -le 1 ]]; then
      _s='…'
    else
      _s="…${_s:$((_len - _w + 1))}"
    fi
  fi
  printf -v "$1" '%s' "$_s"
}

stillwater_picker_parse() {
  local blob="$1"
  local prev_ids=("${SW_IDS[@]+"${SW_IDS[@]}"}")
  local prev_paths=("${SW_PATHS[@]+"${SW_PATHS[@]}"}")
  SW_IDS=()
  SW_LABELS=()
  SW_APPS=()
  SW_THEMES=()
  SW_NOTES=()
  SW_DESTS=()
  SW_PATHS=()
  SW_SELECTED=()
  SW_DEFAULT=()
  SW_B_START=()
  SW_B_COUNT=()
  SW_B_SEL=()
  SW_B_INIT=()
  SW_B_KEY=()
  SW_B_LABEL=()
  SW_HAS_BASES=0
  local id label app theme note dest bases base part k idx on path
  local parts=()
  while IFS='|' read -r id label app theme note dest bases base; do
    [[ -n "$id" ]] || continue
    SW_IDS+=("$id")
    SW_LABELS+=("$label")
    SW_APPS+=("$app")
    SW_THEMES+=("$theme")
    SW_NOTES+=("$note")
    SW_DESTS+=("$dest")
    path=""
    for k in "${!prev_ids[@]}"; do
      if [[ "${prev_ids[$k]}" == "$id" ]]; then
        path="${prev_paths[$k]}"
        break
      fi
    done
    if [[ -z "$path" ]]; then
      path="$(stillwater_display_path "$dest")"
    fi
    SW_PATHS+=("$path")
    on=0
    if stillwater_picker_selectable "$app" && [[ "$theme" != current ]]; then
      on=1
    fi
    SW_SELECTED+=("$on")
    SW_DEFAULT+=("$on")
    SW_B_START+=("${#SW_B_KEY[@]}")
    k=0
    idx=0
    if [[ -n "$bases" ]]; then
      IFS=',' read -ra parts <<<"$bases"
      for part in "${parts[@]}"; do
        [[ -n "$part" ]] || continue
        SW_B_KEY+=("${part%%=*}")
        SW_B_LABEL+=("${part#*=}")
        if [[ "${part%%=*}" == "$base" ]]; then
          idx="$k"
        fi
        k=$((k + 1))
      done
    fi
    if [[ "$k" -gt 0 ]]; then
      SW_HAS_BASES=1
    fi
    SW_B_COUNT+=("$k")
    SW_B_SEL+=("$idx")
    SW_B_INIT+=("$idx")
  done <<<"$blob"
}

# Re-reads the rows from a newer status list and keeps what the user changed,
# matched by id, so rows can arrive while the picker is open. The cursor stays
# on its app once the user has moved it, else on the first app found.
stillwater_picker_merge() {
  local blob="$1" i j cursor_id=""
  local old_ids=("${SW_IDS[@]+"${SW_IDS[@]}"}")
  local old_sel=("${SW_SELECTED[@]+"${SW_SELECTED[@]}"}")
  local old_bsel=("${SW_B_SEL[@]+"${SW_B_SEL[@]}"}")
  if [[ "${SW_MOVED:-0}" == 1 && ${#old_ids[@]} -gt 0 ]]; then
    cursor_id="${old_ids[$SW_CURSOR]:-}"
  fi
  stillwater_picker_parse "$blob"
  SW_CURSOR=-1
  for i in "${!SW_IDS[@]}"; do
    for j in "${!old_ids[@]}"; do
      if [[ "${old_ids[$j]}" == "${SW_IDS[$i]}" ]]; then
        SW_SELECTED[$i]="${old_sel[$j]}"
        SW_B_SEL[$i]="${old_bsel[$j]}"
        break
      fi
    done
    if [[ -n "$cursor_id" && "${SW_IDS[$i]}" == "$cursor_id" ]]; then
      SW_CURSOR="$i"
    fi
  done
  if [[ "$SW_CURSOR" -lt 0 ]]; then
    SW_CURSOR="$(stillwater_picker_first)"
  fi
}

stillwater_picker_base_key() {
  local i="$1"
  if [[ "${SW_B_COUNT[$i]}" -gt 0 ]]; then
    printf '%s' "${SW_B_KEY[$((SW_B_START[i] + SW_B_SEL[i]))]}"
  fi
}

# A row whose base moved off the installed one is a switch, unless nothing is installed yet.
stillwater_picker_theme_into() {
  local _t="${SW_THEMES[$2]}"
  if [[ "${SW_B_SEL[$2]}" != "${SW_B_INIT[$2]}" && "$_t" != none ]]; then
    _t=switch
  fi
  printf -v "$1" '%s' "$_t"
}

stillwater_picker_cycle_base() {
  local i="$1"
  local dir="$2"
  local n="${SW_B_COUNT[$i]}"
  [[ "$n" -gt 1 ]] || return 1
  SW_B_SEL[$i]=$(((SW_B_SEL[i] + dir + n) % n))
  if [[ "${SW_B_SEL[$i]}" != "${SW_B_INIT[$i]}" ]]; then
    SW_SELECTED[$i]=1
  else
    SW_SELECTED[$i]="${SW_DEFAULT[$i]}"
  fi
  return 0
}

stillwater_keymap_pairs() {
  SW_KM_KEYS=('↑↓ jk')
  SW_KM_VERBS=(nav)
  if [[ "${SW_HAS_BASES:-0}" == 1 ]]; then
    SW_KM_KEYS+=('←→ hl')
    SW_KM_VERBS+=(base)
  fi
  SW_KM_KEYS+=(space a n enter q)
  SW_KM_VERBS+=(toggle all none apply abort)
}

# Wraps the key hints into SW_KM_LINES so no line reaches the last column.
stillwater_keymap_build() {
  local cols="${SW_COLS:-80}"
  local i w used line pair
  stillwater_keymap_pairs
  SW_KM_LINES=()
  line="${SW_MUTED}${SW_CORNER}${SW_RESET}  "
  used=3
  for i in "${!SW_KM_KEYS[@]}"; do
    w=$((${#SW_KM_KEYS[$i]} + 1 + ${#SW_KM_VERBS[$i]}))
    printf -v pair '%s%s%s %s%s%s' "$SW_ACCENT" "${SW_KM_KEYS[$i]}" "$SW_RESET" "$SW_MUTED" "${SW_KM_VERBS[$i]}" "$SW_RESET"
    if [[ "$used" -gt 3 && $((used + 5 + w)) -ge "$cols" ]]; then
      SW_KM_LINES+=("$line")
      line="   "
      used=3
    fi
    if [[ "$used" -gt 3 ]]; then
      line+="  ${SW_MUTED}·${SW_RESET}  "
      used=$((used + 5))
    fi
    line+="$pair"
    used=$((used + w))
  done
  SW_KM_LINES+=("$line")
  SW_FOOTER_LINES="${#SW_KM_LINES[@]}"
}

stillwater_keymap_select() {
  local line
  stillwater_keymap_build
  for line in "${SW_KM_LINES[@]}"; do
    printf '%s%s%s\n' "$SW_CLEAR" "$line" "$SW_RESET"
  done
}

# Fits the columns to the terminal. Path goes first, then the note column,
# then the base strip shrinks to the chosen base, then labels shrink.
stillwater_picker_layout() {
  local i j n len strip tag wl=0 wn=0 ws=0 wt=0 wa=10 avail used mode=none
  stillwater_term_size
  n="${#SW_IDS[@]}"
  for ((i = 0; i < n; i++)); do
    len=${#SW_LABELS[$i]}
    [[ "$len" -gt "$wl" ]] && wl="$len"
    len=${#SW_NOTES[$i]}
    [[ "$len" -gt "$wn" ]] && wn="$len"
    if [[ "${SW_B_COUNT[$i]}" -gt 0 ]]; then
      strip=$((4 + 3 * (SW_B_COUNT[i] - 1)))
      for ((j = SW_B_START[i]; j < SW_B_START[i] + SW_B_COUNT[i]; j++)); do
        len=${#SW_B_LABEL[$j]}
        strip=$((strip + len))
        tag=$((len + 4))
        [[ "$tag" -gt "$wt" ]] && wt="$tag"
      done
      [[ "$strip" -gt "$ws" ]] && ws="$strip"
    fi
  done
  [[ "$wl" -gt 22 ]] && wl=22
  avail=$((SW_COLS - 1))
  used=$((6 + wl + 2 + wa))
  if [[ "$ws" -gt 0 ]]; then
    if [[ $((used + 2 + wn + 2 + ws)) -le "$avail" ]]; then
      mode=full
    elif [[ $((used + 2 + ws)) -le "$avail" ]]; then
      mode=full
      wn=0
    elif [[ $((used + 2 + wn + 2 + wt)) -le "$avail" ]]; then
      mode=tag
    else
      mode=tag
      wn=0
    fi
  fi
  if [[ "$wn" -gt 0 ]]; then
    used=$((used + 2 + wn))
  fi
  case "$mode" in
    full) used=$((used + 2 + ws)) ;;
    tag) used=$((used + 2 + wt)) ;;
  esac
  if [[ "$used" -gt "$avail" ]]; then
    used=$((used - wl))
    wl=$((avail - used))
    [[ "$wl" -lt 6 ]] && wl=6
    used=$((used + wl))
  fi
  # Tiny terminals: drop the strip, then narrow the label and action columns.
  if [[ "$used" -gt "$avail" && "$mode" != none ]]; then
    if [[ "$mode" == full ]]; then
      used=$((used - 2 - ws))
    else
      used=$((used - 2 - wt))
    fi
    mode=none
  fi
  if [[ "$used" -gt "$avail" ]]; then
    used=$((used - wl))
    wl=$((avail - used))
    [[ "$wl" -lt 4 ]] && wl=4
    used=$((used + wl))
  fi
  if [[ "$used" -gt "$avail" ]]; then
    wa=$((wa - (used - avail)))
    [[ "$wa" -lt 1 ]] && wa=1
    used=$((6 + wl + 2 + wa))
  fi
  SW_W_LABEL="$wl"
  SW_W_ACTION="$wa"
  SW_W_NOTE="$wn"
  SW_STRIP_MODE="$mode"
  case "$mode" in
    full) SW_W_STRIP="$ws" ;;
    tag) SW_W_STRIP="$wt" ;;
    *) SW_W_STRIP=0 ;;
  esac
  SW_W_PATH=$((avail - used - 2))
  [[ "$SW_W_PATH" -lt 8 ]] && SW_W_PATH=0
  SW_ROW_LABEL=()
  SW_ROW_NOTE=()
  SW_ROW_PATH=()
  local cell
  for ((i = 0; i < n; i++)); do
    stillwater_pad_into cell "${SW_LABELS[$i]}" "$wl"
    SW_ROW_LABEL+=("$cell")
    stillwater_pad_into cell "${SW_NOTES[$i]}" "$wn"
    SW_ROW_NOTE+=("$cell")
    stillwater_fit_left_into cell "${SW_PATHS[$i]}" "$SW_W_PATH"
    SW_ROW_PATH+=("$cell")
  done
  stillwater_keymap_build
  SW_HEAD_LINES=2
  SW_LIST_H=$((SW_LINES - SW_HEAD_LINES - SW_FOOTER_LINES))
  while [[ "$SW_LIST_H" -lt 3 && "$SW_HEAD_LINES" -gt 0 ]]; do
    SW_HEAD_LINES=$((SW_HEAD_LINES - 1))
    SW_LIST_H=$((SW_LIST_H + 1))
  done
  [[ "$SW_LIST_H" -lt 1 ]] && SW_LIST_H=1
  return 0
}

stillwater_picker_strip_into() {
  local _i="$2"
  local _start="${SW_B_START[$2]}"
  local _count="${SW_B_COUNT[$2]}"
  local _sel="${SW_B_SEL[$2]}"
  local _init=-1
  local _o="" _plain=0 _j _lab _pad _pick="$SW_MUTED"
  if [[ "$3" == 1 ]]; then
    _pick="$SW_ACCENT"
    # On a switch, the installed base keeps the Up to date color.
    if [[ "$_sel" != "${SW_B_INIT[$2]}" && "${SW_THEMES[$2]}" != none ]]; then
      _init="${SW_B_INIT[$2]}"
    fi
  fi
  if [[ "$_count" -gt 0 ]]; then
    if [[ "$SW_STRIP_MODE" == full ]]; then
      _o="${SW_MUTED}[ "
      _plain=2
      for ((_j = 0; _j < _count; _j++)); do
        _lab="${SW_B_LABEL[$((_start + _j))]}"
        if [[ "$_j" -gt 0 ]]; then
          _o+="${SW_MUTED} / "
          _plain=$((_plain + 3))
        fi
        if [[ "$_j" -eq "$_sel" ]]; then
          _o+="${_pick}${_lab}"
        elif [[ "$_j" -eq "$_init" ]]; then
          _o+="${SW_ACCENT_DEEP}${_lab}"
        else
          _o+="${SW_MUTED}${_lab}"
        fi
        _plain=$((_plain + ${#_lab}))
      done
      _o+="${SW_MUTED} ]"
      _plain=$((_plain + 2))
    else
      _lab="${SW_B_LABEL[$((_start + _sel))]}"
      _o="${SW_MUTED}‹ ${_pick}${_lab}${SW_MUTED} ›"
      _plain=$((${#_lab} + 4))
    fi
  fi
  if [[ "$_plain" -lt "$SW_W_STRIP" ]]; then
    printf -v _pad '%*s' $((SW_W_STRIP - _plain)) ''
    _o+="$_pad"
  fi
  printf -v "$1" '%s' "$_o"
}

stillwater_picker_row_into() {
  local i="$2"
  local theme action color check labelfg strip tail="" live=0
  stillwater_picker_theme_into theme "$i"
  stillwater_picker_action_into action "${SW_APPS[$i]}" "$theme"
  stillwater_pad_into action "$action" "$SW_W_ACTION"
  if stillwater_picker_selectable "${SW_APPS[$i]}"; then
    live=1
  fi
  if [[ "$SW_W_NOTE" -gt 0 ]]; then
    tail+="  ${SW_MUTED}${SW_ROW_NOTE[$i]}"
  fi
  if [[ "$SW_STRIP_MODE" != none ]]; then
    stillwater_picker_strip_into strip "$i" "$live"
    tail+="  ${strip}"
  fi
  if [[ -n "${SW_ROW_PATH[$i]}" ]]; then
    tail+="  ${SW_MUTED}${SW_ROW_PATH[$i]}"
  fi
  if [[ "$live" != 1 ]]; then
    printf -v "$1" '%s%s     %s  %s%s%s' "$SW_MUTED" "$SW_PIPE" "${SW_ROW_LABEL[$i]}" "$action" "$tail" "$SW_RESET"
    return
  fi
  if [[ "${SW_SELECTED[$i]}" == 1 ]]; then
    check="${SW_ACCENT}${SW_ON}"
  elif [[ "$i" -eq "$SW_CURSOR" ]]; then
    check="${SW_ACCENT_HOVER}${SW_OFF}"
  else
    check="${SW_MUTED}${SW_OFF}"
  fi
  if [[ "$i" -eq "$SW_CURSOR" ]]; then
    labelfg="$SW_TEXT"
  else
    labelfg="$SW_MUTED"
  fi
  stillwater_picker_action_color_into color "${SW_APPS[$i]}" "$theme"
  printf -v "$1" '%s%s%s  %s%s  %s%s  %s%s%s%s' \
    "$SW_MUTED" "$SW_PIPE" "$SW_RESET" "$check" "$SW_RESET" "$labelfg" "${SW_ROW_LABEL[$i]}" \
    "$color" "$action" "$tail" "$SW_RESET"
}

stillwater_frame_reset() {
  SW_FRAME=""
  SW_FRAME_N=0
}

stillwater_frame_add() {
  if [[ "$SW_FRAME_N" -gt 0 ]]; then
    SW_FRAME+=$'\n'
  fi
  SW_FRAME+="${SW_CLEAR}$1${SW_RESET}"
  SW_FRAME_N=$((SW_FRAME_N + 1))
}

# One write per frame, from the top, with no newline after the last line so the
# alternate screen never scrolls. Inline frames (named installs) redraw in place
# on the normal screen, from the first line of the last frame.
stillwater_frame_flush() {
  local up=""
  if [[ "${SW_INLINE:-0}" == 1 ]]; then
    if [[ "${SW_INLINE_N:-0}" -gt 1 ]]; then
      printf -v up '\033[%dA' $((SW_INLINE_N - 1))
    fi
    printf '\r%s%s%s' "$up" "$SW_FRAME" "$SW_EOS" >&2
    SW_INLINE_N="$SW_FRAME_N"
    return
  fi
  printf '%s%s%s' "$SW_HOME" "$SW_FRAME" "$SW_EOS" >&2
}

# Starts drawing frames inline on the normal screen.
stillwater_inline_begin() {
  SW_INLINE=1
  SW_INLINE_N=0
  SW_STTY="${SW_STTY:-$(stty -g 2>/dev/null || true)}"
  stty -echo 2>/dev/null || true
  printf '%s' "$SW_HIDE" >&2
}

# Ends inline drawing. "erase" removes the last frame, otherwise it stays as output.
stillwater_inline_end() {
  local up=""
  [[ "${SW_INLINE:-0}" == 1 ]] || return 0
  if [[ "${1:-}" == erase && "${SW_INLINE_N:-0}" -gt 0 ]]; then
    if [[ "$SW_INLINE_N" -gt 1 ]]; then
      printf -v up '\033[%dA' $((SW_INLINE_N - 1))
    fi
    printf '\r%s%s' "$up" "$SW_EOS" >&2
  elif [[ "${SW_INLINE_N:-0}" -gt 0 ]]; then
    printf '\n' >&2
  fi
  SW_INLINE=0
  SW_INLINE_N=0
  stillwater_picker_restore
}

stillwater_frame_head() {
  local step="$1"
  local mark="$2"
  local tail="${3:-}"
  local line
  if [[ "${SW_HEAD_LINES:-2}" -ge 2 ]]; then
    printf -v line '%s%s%s  %sStillwater%s  %s%s  %s' \
      "$SW_MUTED" "$SW_START" "$SW_RESET" "$SW_ACCENT" "$SW_RESET" "$SW_WARM" "$SW_OS_LABEL" "$SW_VERSION"
    stillwater_frame_add "$line"
  fi
  if [[ "${SW_HEAD_LINES:-2}" -ge 1 ]]; then
    stillwater_frame_add "${mark}  ${SW_TEXT}${step}${tail}"
  fi
}

# Picks the first visible row so the focus row stays on screen. Sets SW_VIEW_FIRST
# and SW_VIEW_LAST, and SW_VIEW_MORE=1 when the list needs the more lines.
stillwater_view_window() {
  local n="$1"
  local focus="$2"
  local h="$SW_LIST_H"
  SW_TOP="${SW_TOP:-0}"
  SW_VIEW_MORE=0
  if [[ "$n" -le "$h" ]]; then
    SW_TOP=0
    SW_VIEW_FIRST=0
    SW_VIEW_LAST=$((n - 1))
    return
  fi
  if [[ "$h" -ge 3 ]]; then
    SW_VIEW_MORE=1
    h=$((h - 2))
  fi
  if [[ "${SW_FOLLOW:-1}" == 1 && "$focus" -ge 0 ]]; then
    if [[ "$focus" -lt "$SW_TOP" ]]; then
      SW_TOP="$focus"
    elif [[ "$focus" -ge $((SW_TOP + h)) ]]; then
      SW_TOP=$((focus - h + 1))
    fi
  fi
  [[ "$SW_TOP" -gt $((n - h)) ]] && SW_TOP=$((n - h))
  [[ "$SW_TOP" -lt 0 ]] && SW_TOP=0
  SW_VIEW_FIRST="$SW_TOP"
  SW_VIEW_LAST=$((SW_TOP + h - 1))
}

stillwater_frame_more() {
  local count="$1"
  local arrow="$2"
  if [[ "$count" -gt 0 ]]; then
    stillwater_frame_add "${SW_MUTED}${SW_PIPE}     ${arrow} ${count} more"
  else
    stillwater_frame_add "${SW_MUTED}${SW_PIPE}"
  fi
}

# While adapters still answer, the step line spins and counts them.
stillwater_picker_draw() {
  local i n line spin
  n="${#SW_IDS[@]}"
  stillwater_frame_reset
  if [[ "${SW_LOADING:-0}" == 1 ]]; then
    SW_SPIN_I=$((SW_SPIN_I + 1))
    stillwater_spin_frame_into spin
    line=""
    [[ "$SW_POLL_DONE" -ge 0 ]] && line="  ${SW_MUTED}checking apps ${SW_POLL_DONE}/${SW_POLL_TOTAL}"
    stillwater_frame_head select "${SW_ACCENT_HOVER}${spin}" "$line"
  else
    stillwater_frame_head select "${SW_ACCENT}${SW_DIAMOND}"
  fi
  stillwater_view_window "$n" "$SW_CURSOR"
  if [[ "$SW_VIEW_MORE" == 1 ]]; then
    stillwater_frame_more "$SW_VIEW_FIRST" '↑'
  fi
  for ((i = SW_VIEW_FIRST; i <= SW_VIEW_LAST; i++)); do
    stillwater_picker_row_into line "$i"
    stillwater_frame_add "$line"
  done
  if [[ "$SW_VIEW_MORE" == 1 ]]; then
    stillwater_frame_more $((n - 1 - SW_VIEW_LAST)) '↓'
  fi
  for line in "${SW_KM_LINES[@]}"; do
    stillwater_frame_add "$line"
  done
  stillwater_frame_flush
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

# Moves to the next selectable row. Past the last one it scrolls the view so
# missing apps can still be read, then wraps.
stillwater_picker_move() {
  local dir="$1"
  local n="${#SW_IDS[@]}"
  local i="$SW_CURSOR"
  [[ "$n" -gt 0 ]] || return 0
  SW_FOLLOW=1
  SW_MOVED=1
  while true; do
    i=$((i + dir))
    if [[ "$i" -lt 0 || "$i" -ge "$n" ]]; then
      break
    fi
    if stillwater_picker_selectable "${SW_APPS[$i]}"; then
      SW_CURSOR="$i"
      return
    fi
  done
  if [[ "$dir" -gt 0 && "${SW_VIEW_LAST:-$((n - 1))}" -lt $((n - 1)) ]]; then
    SW_FOLLOW=0
    SW_TOP=$((SW_TOP + 1))
    return
  fi
  SW_TOP=0
  if [[ "$dir" -gt 0 ]]; then
    i=-1
  else
    i="$n"
  fi
  while true; do
    i=$((i + dir))
    if [[ "$i" -lt 0 || "$i" -ge "$n" ]]; then
      return
    fi
    if stillwater_picker_selectable "${SW_APPS[$i]}"; then
      SW_CURSOR="$i"
      return
    fi
  done
}

stillwater_picker_page() {
  local dir="$1"
  local h="${SW_LIST_H:-10}"
  local k
  for ((k = 0; k < h; k++)); do
    local before="$SW_CURSOR"
    stillwater_picker_move "$dir"
    if [[ "$dir" -gt 0 && "$SW_CURSOR" -lt "$before" ]] || [[ "$dir" -lt 0 && "$SW_CURSOR" -gt "$before" ]]; then
      SW_CURSOR="$before"
      SW_FOLLOW=1
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

# Sets SW_KEY. "idle" means the read timed out, so the caller can check for a resize.
stillwater_picker_read_key() {
  local k1="" k2="" k3="" rc=0
  SW_KEY=other
  IFS= read -rsn1 -t "$SW_READ_T" k1 || rc=$?
  if [[ "$rc" -gt 128 ]]; then
    SW_KEY=idle
    return 0
  elif [[ "$rc" -ne 0 ]]; then
    SW_KEY=quit
    return 0
  fi
  case "$k1" in
    $'\x03' | q | Q) SW_KEY=quit ;;
    $'\n' | $'\r' | "") SW_KEY=enter ;;
    " ") SW_KEY=space ;;
    a | A) SW_KEY=all ;;
    n | N) SW_KEY=none ;;
    j) SW_KEY=down ;;
    k) SW_KEY=up ;;
    h) SW_KEY=left ;;
    l) SW_KEY=right ;;
    $'\x1b')
      if ! IFS= read -rsn1 -t "$SW_ESC_T" k2; then
        SW_KEY=quit
        return 0
      fi
      if [[ "$k2" != '[' && "$k2" != O ]]; then
        return 0
      fi
      IFS= read -rsn1 -t "$SW_ESC_T" k3 || return 0
      # Modified keys and Page Up/Down carry digits before the final byte.
      while [[ "$k3" == [0-9\;] ]]; do
        k2+="$k3"
        IFS= read -rsn1 -t "$SW_ESC_T" k3 || return 0
      done
      case "$k3" in
        A) SW_KEY=up ;;
        B) SW_KEY=down ;;
        C) SW_KEY=right ;;
        D) SW_KEY=left ;;
        '~')
          case "$k2" in
            *5) SW_KEY=pgup ;;
            *6) SW_KEY=pgdn ;;
          esac
          ;;
      esac
      ;;
  esac
  return 0
}

stillwater_picker_restore() {
  trap - WINCH
  stillwater_screen_leave
  printf '%s' "$SW_SHOW" >&2
  if [[ -n "${SW_STTY:-}" ]]; then
    stty "$SW_STTY" 2>/dev/null || true
  fi
}

# Sets STILLWATER_PICKED to the chosen adapter ids, as id or id:base. Exit 0 on
# confirm, 1 on cancel. Stays on the alternate screen on confirm so install.sh
# can draw progress there.
# Takes a function that sets SW_POLL_DONE and SW_POLL_TOTAL, and SW_POLL_ROWS
# when more adapters have answered. The picker opens at once, sorts rows in as
# adapters answer, and takes enter once the last one has.
stillwater_picker() {
  local poll="$1"
  local read_t="${SW_READ_T:-1}"
  STILLWATER_PICKED=()
  stillwater_picker_init_style
  SW_IDS=()
  SW_PATHS=()
  stillwater_picker_parse ""
  SW_POLL_DONE=-1
  SW_POLL_TOTAL=1
  SW_POLL_ROWS=""
  SW_LOADING=1
  SW_OS_LABEL="$(stillwater_os_label)"
  SW_VERSION="$(stillwater_version)"
  SW_CURSOR=0
  SW_MOVED=0
  SW_TOP=0
  SW_FOLLOW=1
  SW_RESIZED=0
  SW_STTY="${SW_STTY:-$(stty -g 2>/dev/null || true)}"
  trap 'stillwater_picker_restore; trap - EXIT INT TERM; exit 130' INT TERM
  trap 'stillwater_picker_restore' EXIT
  trap 'SW_RESIZED=1' WINCH
  stillwater_screen_enter
  stillwater_picker_layout
  stillwater_picker_draw
  local i base before dirty=1
  while true; do
    if [[ "$SW_LOADING" == 1 ]]; then
      dirty=1
      before="$SW_POLL_DONE"
      "$poll"
      if [[ "$SW_POLL_DONE" != "$before" ]]; then
        stillwater_picker_merge "$SW_POLL_ROWS"
        stillwater_picker_layout
      fi
      if [[ "$SW_POLL_DONE" -ge "$SW_POLL_TOTAL" ]]; then
        SW_LOADING=0
        if [[ ${#SW_IDS[@]} -eq 0 ]]; then
          stillwater_picker_restore
          trap - EXIT INT TERM
          echo "No adapters found." >&2
          return 1
        fi
      fi
    fi
    if [[ "$dirty" == 1 ]]; then
      stillwater_picker_draw
    fi
    SW_READ_T="$read_t"
    if [[ "$SW_LOADING" == 1 && "${BASH_VERSINFO[0]:-3}" -ge 4 ]]; then
      SW_READ_T=0.05
    fi
    stillwater_picker_read_key
    SW_READ_T="$read_t"
    dirty=0
    if [[ "$SW_KEY" != idle ]]; then
      dirty=1
    fi
    if [[ "$SW_RESIZED" == 1 ]]; then
      SW_RESIZED=0
      dirty=1
      stillwater_picker_layout
      printf '%s' "$SW_WIPE" >&2
    fi
    case "$SW_KEY" in
      up) stillwater_picker_move -1 ;;
      down) stillwater_picker_move 1 ;;
      pgup) stillwater_picker_page -1 ;;
      pgdn) stillwater_picker_page 1 ;;
      left) [[ ${#SW_IDS[@]} -gt 0 ]] && stillwater_picker_cycle_base "$SW_CURSOR" -1 || true ;;
      right) [[ ${#SW_IDS[@]} -gt 0 ]] && stillwater_picker_cycle_base "$SW_CURSOR" 1 || true ;;
      space)
        if [[ ${#SW_IDS[@]} -gt 0 ]] && stillwater_picker_selectable "${SW_APPS[$SW_CURSOR]}"; then
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
        [[ "$SW_LOADING" == 1 ]] && continue
        for i in "${!SW_IDS[@]}"; do
          if [[ "${SW_SELECTED[$i]}" == 1 ]]; then
            base="$(stillwater_picker_base_key "$i")"
            if [[ -n "$base" ]]; then
              STILLWATER_PICKED+=("${SW_IDS[$i]}:${base}")
            else
              STILLWATER_PICKED+=("${SW_IDS[$i]}")
            fi
          fi
        done
        trap - EXIT WINCH
        return 0
        ;;
      quit)
        stillwater_picker_restore
        trap - EXIT INT TERM
        printf '%s%s  Cancelled.%s\n' "$SW_ERROR" "$SW_CANCEL" "$SW_RESET" >&2
        return 1
        ;;
    esac
  done
}

stillwater_jobs_layout() {
  local i n len wl=0 wb=0 avail used
  stillwater_term_size
  n="${#SW_JOB_LABELS[@]}"
  for ((i = 0; i < n; i++)); do
    len=${#SW_JOB_LABELS[$i]}
    [[ "$len" -gt "$wl" ]] && wl="$len"
    len=${#SW_JOB_BASES[$i]}
    [[ "$len" -gt "$wb" ]] && wb="$len"
  done
  [[ "$wl" -gt 22 ]] && wl=22
  avail=$((SW_COLS - 1))
  used=$((6 + wl + 2 + 11))
  if [[ "$wb" -gt 0 && $((used + 2 + wb)) -le "$avail" ]]; then
    used=$((used + 2 + wb))
  else
    wb=0
  fi
  if [[ "$used" -gt "$avail" ]]; then
    wl=$((wl - (used - avail)))
    [[ "$wl" -lt 4 ]] && wl=4
    used="$avail"
  fi
  SW_JW_LABEL="$wl"
  SW_JW_BASE="$wb"
  SW_JW_NEXT=$((avail - used - 2))
  [[ "$SW_JW_NEXT" -lt 8 ]] && SW_JW_NEXT=0
  SW_HEAD_LINES=2
  SW_FOOTER_LINES=1
  SW_LIST_H=$((SW_LINES - 3))
  while [[ "$SW_LIST_H" -lt 3 && "$SW_HEAD_LINES" -gt 0 ]]; do
    SW_HEAD_LINES=$((SW_HEAD_LINES - 1))
    SW_LIST_H=$((SW_LIST_H + 1))
  done
  [[ "$SW_LIST_H" -lt 1 ]] && SW_LIST_H=1
  return 0
}

stillwater_jobs_row_into() {
  local i="$2"
  local theme="${SW_JOB_THEMES[$i]}"
  local state="${SW_JOB_STATES[$i]}"
  local label verb vcolor mark spin labelfg="$SW_MUTED" base="" next=""
  stillwater_pad_into label "${SW_JOB_LABELS[$i]}" "$SW_JW_LABEL"
  stillwater_job_verb_into verb "$theme" "$state"
  stillwater_pad_into verb "$verb" 11
  stillwater_job_verb_color_into vcolor "$theme" "$state"
  case "$state" in
    ok) mark="${vcolor}${SW_ON}" ;;
    fail) mark="${vcolor}${SW_CANCEL}" ;;
    busy)
      stillwater_spin_frame_into spin
      mark="${vcolor}${spin}"
      ;;
    *) mark="${vcolor}${SW_OFF}" ;;
  esac
  if [[ "$state" == ok || "$state" == fail ]]; then
    labelfg="$SW_TEXT"
  fi
  if [[ "$SW_JW_BASE" -gt 0 ]]; then
    stillwater_pad_into base "${SW_JOB_BASES[$i]}" "$SW_JW_BASE"
    base="  ${SW_MUTED}${base}"
  fi
  if [[ "$state" == ok && "$SW_JW_NEXT" -gt 0 && -n "${SW_JOB_NEXTS[$i]}" ]]; then
    stillwater_pad_into next "${SW_JOB_NEXTS[$i]}" "$SW_JW_NEXT"
    next="${next%"${next##*[! ]}"}"
    next="  ${SW_MUTED}${next}"
  fi
  printf -v "$1" '%s%s%s  %s%s  %s%s  %s%s%s%s%s' \
    "$SW_MUTED" "$SW_PIPE" "$SW_RESET" "$mark" "$SW_RESET" "$labelfg" "$label" \
    "$vcolor" "$verb" "$base" "$next" "$SW_RESET"
}

# Counts jobs into SW_J_DONE, SW_J_BUSY, SW_J_RUNNING and SW_J_FOCUS (first unfinished).
stillwater_jobs_count() {
  local i
  SW_J_DONE=0
  SW_J_BUSY=0
  SW_J_RUNNING=0
  SW_J_FOCUS=-1
  for i in "${!SW_JOB_LABELS[@]}"; do
    case "${SW_JOB_STATES[$i]}" in
      busy | pending)
        [[ "${SW_JOB_STATES[$i]}" == busy ]] && SW_J_BUSY=1
        SW_J_RUNNING=1
        [[ "$SW_J_FOCUS" -lt 0 ]] && SW_J_FOCUS="$i"
        ;;
      *) SW_J_DONE=$((SW_J_DONE + 1)) ;;
    esac
  done
  return 0
}

stillwater_jobs_footer_into() {
  local summary="$2"
  local bar
  if [[ "$SW_J_RUNNING" == 1 ]]; then
    stillwater_progress_bar_into bar "$SW_J_DONE" "${#SW_JOB_LABELS[@]}" 24 "$SW_J_BUSY"
    printf -v "$1" '%s%s%s  %s%s/%s%s  %s%s' \
      "$SW_MUTED" "$SW_CORNER" "$SW_RESET" "$SW_TEXT" "$SW_J_DONE" "${#SW_JOB_LABELS[@]}" "$SW_RESET" "$SW_ACCENT" "$bar"
  else
    printf -v "$1" '%s%s%s  %s%s' "$SW_MUTED" "$SW_CORNER" "$SW_RESET" "$SW_TEXT" "$summary"
  fi
}

stillwater_jobs_draw() {
  local summary="${1:-}"
  local i n line mark
  n="${#SW_JOB_LABELS[@]}"
  [[ -n "${SW_OS_LABEL:-}" ]] || SW_OS_LABEL="$(stillwater_os_label)"
  [[ -n "${SW_VERSION:-}" ]] || SW_VERSION="$(stillwater_version)"
  if [[ "${SW_JW_LABEL:-}" == "" || "${SW_RESIZED:-0}" == 1 ]]; then
    SW_RESIZED=0
    stillwater_jobs_layout
    [[ "${SW_INLINE:-0}" == 1 ]] || printf '%s' "$SW_WIPE" >&2
  fi
  stillwater_jobs_count
  mark="${SW_ACCENT}${SW_DIAMOND}"
  [[ "$SW_J_RUNNING" == 1 ]] || mark="${SW_ACCENT_HOVER}${SW_DONE}"
  stillwater_frame_reset
  stillwater_frame_head install "$mark"
  # Inline, a list taller than the terminal shows only its progress line; the
  # full list prints once at the end. Clearing a full-screen frame would push it
  # into the scrollback.
  SW_INLINE_COMPACT=0
  if [[ "${SW_INLINE:-0}" == 1 && $((n + 3)) -ge "$SW_LINES" ]]; then
    SW_INLINE_COMPACT=1
    stillwater_jobs_footer_into line "$summary"
    if [[ "$SW_J_FOCUS" -ge 0 ]]; then
      line+="  ${SW_MUTED}${SW_JOB_LABELS[$SW_J_FOCUS]}"
    fi
    stillwater_frame_add "$line"
    stillwater_frame_flush
    return 0
  fi
  SW_FOLLOW=1
  stillwater_view_window "$n" "$SW_J_FOCUS"
  if [[ "$SW_VIEW_MORE" == 1 ]]; then
    stillwater_frame_more "$SW_VIEW_FIRST" '↑'
  fi
  for ((i = SW_VIEW_FIRST; i <= SW_VIEW_LAST; i++)); do
    stillwater_jobs_row_into line "$i"
    stillwater_frame_add "$line"
  done
  if [[ "$SW_VIEW_MORE" == 1 ]]; then
    stillwater_frame_more $((n - 1 - SW_VIEW_LAST)) '↓'
  fi
  stillwater_jobs_footer_into line "$summary"
  stillwater_frame_add "$line"
  stillwater_frame_flush
}

stillwater_jobs_redraw() {
  stillwater_jobs_draw "$1"
}

# Prints the finished install once to the normal screen, every row, no viewport.
stillwater_jobs_print() {
  local summary="$1"
  local i line
  SW_RESIZED=1
  stillwater_jobs_layout
  stillwater_jobs_count
  printf '%s%s%s  %sStillwater%s  %s%s  %s%s\n' \
    "$SW_MUTED" "$SW_START" "$SW_RESET" "$SW_ACCENT" "$SW_RESET" "$SW_WARM" "${SW_OS_LABEL:-$(stillwater_os_label)}" "${SW_VERSION:-$(stillwater_version)}" "$SW_RESET" >&2
  printf '%s%s%s  %sinstall%s\n' "$SW_ACCENT_HOVER" "$SW_DONE" "$SW_RESET" "$SW_TEXT" "$SW_RESET" >&2
  for i in "${!SW_JOB_LABELS[@]}"; do
    stillwater_jobs_row_into line "$i"
    printf '%s\n' "$line" >&2
  done
  stillwater_jobs_footer_into line "$summary"
  printf '%s%s\n' "$line" "$SW_RESET" >&2
  SW_RESIZED=0
}

# Named installs show a count while the adapters answer; the rows come with
# the progress. Takes the folder the adapters write to and how many there are;
# returns when every adapter is done.
stillwater_loading() {
  local dir="$1" n="$2" i done spin
  SW_OS_LABEL="${SW_OS_LABEL:-$(stillwater_os_label)}"
  SW_VERSION="${SW_VERSION:-$(stillwater_version)}"
  SW_STTY="${SW_STTY:-$(stty -g 2>/dev/null || true)}"
  stty -echo 2>/dev/null || true
  trap 'stillwater_picker_restore; trap - EXIT INT TERM; exit 130' INT TERM
  trap 'stillwater_picker_restore' EXIT
  SW_HEAD_LINES=2
  while true; do
    SW_SPIN_I=$((SW_SPIN_I + 1))
    stillwater_spin_frame_into spin
    done=0
    for ((i = 0; i < n; i++)); do
      [[ -e "$dir/$i.done" ]] && done=$((done + 1))
    done
    stillwater_frame_reset
    stillwater_frame_head install "${SW_ACCENT}${SW_DIAMOND}"
    stillwater_frame_add "${SW_MUTED}${SW_CORNER}  ${SW_ACCENT_HOVER}${spin}${SW_MUTED} checking apps ${done}/${n}"
    stillwater_frame_flush
    [[ "$done" -lt "$n" ]] || break
    sleep 0.05
  done
}

stillwater_clack() {
  [[ -t 1 ]]
}
