#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export STILLWATER_ROOT="$ROOT"
# shellcheck source=install/lib.sh
source "$ROOT/install/lib.sh"
# shellcheck source=install/picker.sh
source "$ROOT/install/picker.sh"
stillwater_init_paths

usage() {
  cat <<'EOF'
Install Stillwater into apps found on this OS. Missing apps are dimmed.

  bash install.sh                 interactive picker, default
  bash install.sh --all           every found adapter, for agents
  bash install.sh --list
  bash install.sh --dry-run --all
  bash install.sh cursor t3
  bash install.sh vencord:comfy   pick a base theme
EOF
}

LIST=0
INTERACTIVE=0
ALL=0
ONLY=()
STILLWATER_DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      LIST=1
      shift
      ;;
    --dry-run)
      STILLWATER_DRY_RUN=1
      shift
      ;;
    --interactive)
      INTERACTIVE=1
      shift
      ;;
    --all)
      ALL=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown flag: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      ONLY+=("$1")
      shift
      ;;
  esac
done

export STILLWATER_DRY_RUN

if [[ "$ALL" == 1 && ${#ONLY[@]} -gt 0 ]]; then
  echo "Use --all or adapter ids, not both." >&2
  exit 1
fi

BASH_EXE="${BASH:-bash}"

adapter_scripts() {
  local script
  for script in "$ROOT"/*/install.sh; do
    if [[ -f "$script" ]]; then
      printf '%s\n' "$script"
    fi
  done | sort
}

# Runs every adapter's status at once and keeps the result, with the adapter
# that printed each id, so nothing asks the adapters twice. Call it in the main
# shell; `skeleton` draws the picker frame while the adapters answer.
STATUS_LOADED=0
STATUS_ROWS=""
STATUS_OWNERS=""
load_status() {
  local dir i line rows="" owners="" scripts=()
  [[ "$STATUS_LOADED" == 1 ]] && return 0
  dir="$(mktemp -d)"
  while IFS= read -r line; do
    scripts+=("$line")
  done < <(adapter_scripts)
  for i in "${!scripts[@]}"; do
    {
      "$BASH_EXE" "${scripts[$i]}" status >"$dir/$i.rows" 2>"$dir/$i.err" || true
      : >"$dir/$i.done"
    } &
  done
  if [[ "${1:-}" == skeleton ]]; then
    stillwater_loading "$dir" "${scripts[@]}"
  fi
  wait
  for i in "${!scripts[@]}"; do
    if [[ "${1:-}" != skeleton && -s "$dir/$i.err" ]]; then
      cat "$dir/$i.err" >&2
    fi
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      rows+="$line"$'\n'
      owners+="${line%%|*}"$'\t'"${scripts[$i]}"$'\n'
    done <"$dir/$i.rows"
  done
  rm -rf "$dir"
  STATUS_ROWS="$(printf '%s' "$rows" | stillwater_sort_status)"
  STATUS_OWNERS="$owners"
  STATUS_LOADED=1
}

collect_status() {
  printf '%s\n' "$STATUS_ROWS"
}

print_list() {
  local paint id label app theme note dest bases base path
  stillwater_load_theme_ansi
  if [[ ! -t 1 ]]; then
    SW_RESET=""
    SW_ACCENT=""
    SW_ACCENT_DEEP=""
    SW_WARN=""
    SW_MUTED=""
    SW_TEXT=""
    SW_WARM=""
  fi
  printf '%sStillwater%s  %s%s  %s%s\n' "$SW_ACCENT" "$SW_RESET" "$SW_WARM" "$(stillwater_os_label)" "$(stillwater_version)" "$SW_RESET"
  while IFS='|' read -r id label app theme note dest bases base; do
    paint="$SW_MUTED"
    if [[ "$app" == found ]]; then
      case "$theme" in
        current) paint="$SW_ACCENT_DEEP" ;;
        update) paint="$SW_WARN" ;;
        *) paint="$SW_ACCENT" ;;
      esac
    fi
    path="$(stillwater_display_path "$dest")"
    printf '  %s%-22s%s  %-8s  %s%-10s%s  %-16s  %-10s  %s%-16s%s  %s%s%s\n' \
      "$paint" "$label" "$SW_RESET" "$app" "$paint" "$theme" "$SW_RESET" "${note:-}" "${base:-}" \
      "$SW_MUTED" "$id" "$SW_RESET" "$SW_MUTED" "$path" "$SW_RESET"
  done < <(collect_status)
}

adapter_for_id() {
  local id="$1" owner script
  while IFS=$'\t' read -r owner script; do
    if [[ "$owner" == "$id" ]]; then
      printf '%s\n' "$script"
      return 0
    fi
  done <<<"$STATUS_OWNERS"
  return 1
}

# Adapter ids may carry a base theme, as vencord:comfy.
unknown_ids() {
  local item id base status known row bases
  if [[ ${#ONLY[@]} -eq 0 ]]; then
    return 0
  fi
  status="$(collect_status)"
  known="$(printf '%s\n' "$status" | cut -d'|' -f1)"
  for item in "${ONLY[@]}"; do
    id="${item%%:*}"
    if ! printf '%s\n' "$known" | grep -qx "$id"; then
      echo "Unknown adapter: $id" >&2
      echo "Known: $(printf '%s' "$known" | tr '\n' ' ')" >&2
      return 1
    fi
    if [[ "$item" == *:* ]]; then
      base="${item#*:}"
      row="$(printf '%s\n' "$status" | grep "^$id|" | head -n 1)"
      bases="$(printf '%s' "$row" | cut -d'|' -f7)"
      if ! stillwater_base_valid "$bases" "$base"; then
        echo "Unknown base for $id: $base" >&2
        if [[ -n "$bases" ]]; then
          echo "Bases: $(stillwater_base_keys "$bases" | tr '\n' ' ')" >&2
        else
          echo "$id has no base themes." >&2
        fi
        return 1
      fi
    fi
  done
  return 0
}

check_ids() {
  local errs
  if ! errs="$(unknown_ids 2>&1)"; then
    stillwater_inline_end erase
    printf '%s\n' "$errs" >&2
    exit 1
  fi
}

# Prints the base asked for with id, and fails when id was not asked for.
wanted_base() {
  local id="$1" item
  for item in "${ONLY[@]}"; do
    if [[ "$item" == "$id" ]]; then
      return 0
    fi
    if [[ "$item" == "$id":* ]]; then
      printf '%s' "${item#*:}"
      return 0
    fi
  done
  return 1
}

prompt_interactive() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "install.sh needs a terminal, or pass --all or adapter ids." >&2
    exit 1
  fi
  stillwater_picker_init_style
  load_status skeleton
  if ! stillwater_picker "$(collect_status)"; then
    exit 0
  fi
  ONLY=("${STILLWATER_PICKED[@]+"${STILLWATER_PICKED[@]}"}")
}

if [[ "$LIST" == 1 ]]; then
  load_status
  print_list
  exit 0
fi

# Named installs and --all draw inline on the normal screen, so the progress you
# watch is the output that stays.
if [[ "$ALL" == 1 || ${#ONLY[@]} -gt 0 ]]; then
  if [[ ( "$ALL" == 1 || "$INTERACTIVE" != 1 ) && -t 1 && -t 2 ]]; then
    stillwater_picker_init_style
    stillwater_inline_begin
    load_status skeleton
  else
    load_status
  fi
fi
check_ids

FILTER=0
if [[ "$ALL" == 1 ]]; then
  ONLY=()
  FILTER=0
elif [[ ${#ONLY[@]} -gt 0 && "$INTERACTIVE" != 1 ]]; then
  FILTER=1
else
  prompt_interactive
  FILTER=1
fi

check_ids

installed=0
skipped=0
failed=0
jobs_id=()
jobs_label=()
jobs_theme=()
jobs_kind=()
jobs_state=()
jobs_next=()
jobs_base=()
jobs_base_label=()

while IFS='|' read -r id label app theme _note _dest bases base; do
  pick=""
  if [[ "$FILTER" == 1 ]]; then
    if [[ ${#ONLY[@]} -eq 0 ]]; then
      continue
    fi
    if ! pick="$(wanted_base "$id")"; then
      continue
    fi
  fi
  if [[ -n "$pick" && "$pick" != "$base" ]]; then
    if [[ "$theme" != none ]]; then
      theme=switch
    fi
    base="$pick"
  fi
  base_label=""
  if [[ -n "$base" ]]; then
    base_label="$(stillwater_base_label "$bases" "$base" || true)"
  fi
  if [[ "$app" != found ]]; then
    skipped=$((skipped + 1))
    if [[ "$FILTER" == 1 ]]; then
      jobs_id+=("$id")
      jobs_label+=("$label")
      jobs_theme+=("$theme")
      jobs_kind+=("skip")
      jobs_state+=("skip")
      jobs_next+=("")
      jobs_base+=("$base")
      jobs_base_label+=("$base_label")
    fi
    continue
  fi
  jobs_id+=("$id")
  jobs_label+=("$label")
  jobs_theme+=("$theme")
  jobs_kind+=("install")
  jobs_state+=("pending")
  jobs_next+=("$(stillwater_next_step "$id")")
  jobs_base+=("$base")
  jobs_base_label+=("$base_label")
done < <(collect_status)

stillwater_picker_init_style
CLACK=0
if stillwater_clack; then
  CLACK=1
fi

job_summary() {
  if [[ "$failed" -gt 0 ]]; then
    printf 'Installed %s, skipped %s, failed %s.' "$installed" "$skipped" "$failed"
  else
    printf 'Installed %s, skipped %s.' "$installed" "$skipped"
  fi
}

load_jobs() {
  SW_JOB_LABELS=("${jobs_label[@]+"${jobs_label[@]}"}")
  SW_JOB_THEMES=("${jobs_theme[@]+"${jobs_theme[@]}"}")
  SW_JOB_STATES=("${jobs_state[@]+"${jobs_state[@]}"}")
  SW_JOB_NEXTS=("${jobs_next[@]+"${jobs_next[@]}"}")
  SW_JOB_BASES=("${jobs_base_label[@]+"${jobs_base_label[@]}"}")
}

paint_jobs() {
  load_jobs
  stillwater_jobs_draw "$(job_summary)"
}

repaint_jobs() {
  load_jobs
  stillwater_jobs_redraw "$(job_summary)"
}

run_install() {
  local script="$1"
  local id="$2"
  local base="$3"
  local out err pid rc
  if [[ "$CLACK" != 1 ]]; then
    "$BASH_EXE" "$script" install "$id" "$base" >/dev/null
    return
  fi
  out="$(mktemp)"
  err="$(mktemp)"
  set +e
  "$BASH_EXE" "$script" install "$id" "$base" >"$out" 2>"$err" &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    SW_SPIN_I=$((SW_SPIN_I + 1))
    repaint_jobs
    sleep 0.07
  done
  wait "$pid"
  rc=$?
  set -e
  rm -f "$out" "$err"
  return "$rc"
}

if [[ "$CLACK" == 1 ]]; then
  SW_STTY="${SW_STTY:-$(stty -g 2>/dev/null || true)}"
  [[ "${SW_INLINE:-0}" == 1 ]] || stillwater_screen_enter
  trap 'stillwater_picker_restore; trap - EXIT INT TERM; exit 130' INT TERM
  trap 'stillwater_picker_restore' EXIT
  trap 'SW_RESIZED=1' WINCH
  paint_jobs
fi

for i in "${!jobs_id[@]}"; do
  if [[ "${jobs_kind[$i]}" != install ]]; then
    if [[ "$CLACK" != 1 ]]; then
      echo "Skipped ${jobs_label[$i]}. Not found."
    fi
    continue
  fi
  if [[ "$CLACK" == 1 ]]; then
    jobs_state[$i]="busy"
    repaint_jobs
  fi
  script="$(adapter_for_id "${jobs_id[$i]}" || true)"
  if [[ -z "$script" ]]; then
    jobs_state[$i]="fail"
    jobs_next[$i]=""
    failed=$((failed + 1))
    if [[ "$CLACK" != 1 ]]; then
      echo "Skipped ${jobs_label[$i]}. No installer."
    fi
  elif run_install "$script" "${jobs_id[$i]}" "${jobs_base[$i]}"; then
    jobs_state[$i]="ok"
    installed=$((installed + 1))
    if [[ "$CLACK" != 1 ]]; then
      name="${jobs_label[$i]}"
      if [[ -n "${jobs_base_label[$i]}" ]]; then
        name="$name on ${jobs_base_label[$i]}"
      fi
      if [[ "$STILLWATER_DRY_RUN" == 1 ]]; then
        echo "Would install $name."
      else
        echo "Installed $name."
      fi
    fi
  else
    jobs_state[$i]="fail"
    jobs_next[$i]=""
    failed=$((failed + 1))
    if [[ "$CLACK" != 1 ]]; then
      echo "Failed ${jobs_label[$i]}."
    fi
  fi
  if [[ "$CLACK" == 1 ]]; then
    repaint_jobs
  fi
done

next_any=0
for i in "${!jobs_id[@]}"; do
  if [[ "${jobs_state[$i]}" == ok && -n "${jobs_next[$i]}" ]]; then
    next_any=1
    break
  fi
done

summary="Installed ${installed}, skipped ${skipped}."
if [[ "$failed" -gt 0 ]]; then
  summary="Installed ${installed}, skipped ${skipped}, failed ${failed}."
fi
if [[ "$CLACK" == 1 && "${SW_INLINE:-0}" == 1 ]]; then
  # The last frame is the output, unless the list did not fit and was cut short.
  repaint_jobs
  if [[ "${SW_INLINE_COMPACT:-0}" == 1 ]]; then
    stillwater_inline_end erase
    stillwater_jobs_print "$(job_summary)"
  else
    stillwater_inline_end
  fi
  trap - EXIT INT TERM
elif [[ "$CLACK" == 1 ]]; then
  stillwater_picker_restore
  trap - EXIT INT TERM
  load_jobs
  stillwater_jobs_print "$(job_summary)"
else
  if [[ "$next_any" == 1 ]]; then
    echo "Do this next."
    for i in "${!jobs_id[@]}"; do
      if [[ "${jobs_state[$i]}" == ok && -n "${jobs_next[$i]}" ]]; then
        printf '  %-22s  %s\n' "${jobs_label[$i]}" "${jobs_next[$i]}"
      fi
    done
  fi
  echo "$summary"
fi
