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
EOF
}

LIST=0
INTERACTIVE=0
ALL=0
ONLY=()
STILLWATER_DRY_RUN=0
USED_PICKER=0

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

collect_status() {
  local script
  {
    while IFS= read -r script; do
      "$BASH_EXE" "$script" status
    done < <(adapter_scripts)
  } | stillwater_sort_status
}

print_list() {
  local paint id label app theme note dest path
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
  while IFS='|' read -r id label app theme note dest; do
    paint="$SW_MUTED"
    if [[ "$app" == found ]]; then
      case "$theme" in
        current) paint="$SW_ACCENT_DEEP" ;;
        update) paint="$SW_WARN" ;;
        *) paint="$SW_ACCENT" ;;
      esac
    fi
    path="$(stillwater_display_path "$dest")"
    printf '  %s%-22s%s  %-8s  %s%-10s%s  %-16s  %s%-16s%s  %s%s%s\n' \
      "$paint" "$label" "$SW_RESET" "$app" "$paint" "$theme" "$SW_RESET" "${note:-}" \
      "$SW_MUTED" "$id" "$SW_RESET" "$SW_MUTED" "$path" "$SW_RESET"
  done < <(collect_status)
}

adapter_for_id() {
  local id="$1" candidate
  while IFS= read -r candidate; do
    if "$BASH_EXE" "$candidate" owns "$id"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(adapter_scripts)
  return 1
}

unknown_ids() {
  local id known
  if [[ ${#ONLY[@]} -eq 0 ]]; then
    return 0
  fi
  known="$(collect_status | cut -d'|' -f1)"
  for id in "${ONLY[@]}"; do
    if ! printf '%s\n' "$known" | grep -qx "$id"; then
      echo "Unknown adapter: $id" >&2
      echo "Known: $(printf '%s' "$known" | tr '\n' ' ')" >&2
      return 1
    fi
  done
  return 0
}

prompt_interactive() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "install.sh needs a terminal, or pass --all or adapter ids." >&2
    exit 1
  fi
  if ! stillwater_picker "$(collect_status)"; then
    exit 0
  fi
  USED_PICKER=1
  ONLY=("${STILLWATER_PICKED[@]+"${STILLWATER_PICKED[@]}"}")
}

if [[ "$LIST" == 1 ]]; then
  print_list
  exit 0
fi

unknown_ids || exit 1

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

unknown_ids || exit 1

installed=0
skipped=0
failed=0
jobs_id=()
jobs_label=()
jobs_theme=()
jobs_kind=()
jobs_state=()
jobs_next=()

while IFS='|' read -r id label app theme _note _dest; do
  if [[ "$FILTER" == 1 ]]; then
    if [[ ${#ONLY[@]} -eq 0 ]]; then
      continue
    fi
    if ! stillwater_id_wanted "$id" "${ONLY[@]}"; then
      continue
    fi
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
    fi
    continue
  fi
  jobs_id+=("$id")
  jobs_label+=("$label")
  jobs_theme+=("$theme")
  jobs_kind+=("install")
  jobs_state+=("pending")
  jobs_next+=("$(stillwater_next_step "$id")")
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
  local out err pid rc
  if [[ "$CLACK" != 1 ]]; then
    "$BASH_EXE" "$script" install "$id" >/dev/null
    return
  fi
  out="$(mktemp)"
  err="$(mktemp)"
  set +e
  "$BASH_EXE" "$script" install "$id" >"$out" 2>"$err" &
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
  printf '%s' "$SW_HIDE" >&2
  if [[ "$USED_PICKER" == 1 ]]; then
    stillwater_picker_erase "${SW_PICKER_ROWS:-0}"
  fi
  trap 'stillwater_picker_restore; trap - EXIT INT TERM; exit 130' INT TERM
  trap 'stillwater_picker_restore' EXIT
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
  elif run_install "$script" "${jobs_id[$i]}"; then
    jobs_state[$i]="ok"
    installed=$((installed + 1))
    if [[ "$CLACK" != 1 ]]; then
      if [[ "$STILLWATER_DRY_RUN" == 1 ]]; then
        echo "Would install ${jobs_label[$i]}."
      else
        echo "Installed ${jobs_label[$i]}."
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
if [[ "$CLACK" == 1 ]]; then
  repaint_jobs
  stillwater_picker_restore
  trap - EXIT INT TERM
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
