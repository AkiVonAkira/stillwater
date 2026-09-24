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

  bash install.sh                 interactive picker (default)
  bash install.sh --all           every found adapter (for agents)
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
      echo "unknown flag: $1" >&2
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
  echo "use --all or adapter ids, not both" >&2
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
  local paint id label app theme note
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
  while IFS='|' read -r id label app theme note; do
    paint="$SW_MUTED"
    if [[ "$app" == found ]]; then
      case "$theme" in
        current) paint="$SW_ACCENT_DEEP" ;;
        update) paint="$SW_WARN" ;;
        *) paint="$SW_ACCENT" ;;
      esac
    fi
    printf '  %s%-22s%s  %-8s  %s%-10s%s  %-16s  %s\n' \
      "$paint" "$label" "$SW_RESET" "$app" "$paint" "$theme" "$SW_RESET" "${note:-}" "$id"
  done < <(collect_status)
}

unknown_ids() {
  local id known
  if [[ ${#ONLY[@]} -eq 0 ]]; then
    return 0
  fi
  known="$(collect_status | cut -d'|' -f1)"
  for id in "${ONLY[@]}"; do
    if ! printf '%s\n' "$known" | grep -qx "$id"; then
      echo "unknown adapter: $id" >&2
      echo "known: $(printf '%s' "$known" | tr '\n' ' ')" >&2
      return 1
    fi
  done
  return 0
}

prompt_interactive() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "install.sh needs a terminal, or pass --all / adapter ids" >&2
    exit 1
  fi
  if ! stillwater_picker "$(collect_status)"; then
    exit 0
  fi
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
while IFS='|' read -r id label app _theme _note; do
  if [[ "$FILTER" == 1 ]]; then
    if [[ ${#ONLY[@]} -eq 0 ]]; then
      continue
    fi
    if ! stillwater_id_wanted "$id" "${ONLY[@]}"; then
      continue
    fi
  fi
  if [[ "$app" != found ]]; then
    echo "skip  $label ($id) - not found"
    skipped=$((skipped + 1))
    continue
  fi
  script=""
  while IFS= read -r candidate; do
    if "$BASH_EXE" "$candidate" owns "$id"; then
      script="$candidate"
      break
    fi
  done < <(adapter_scripts)
  if [[ -z "$script" ]]; then
    echo "skip  $label ($id) - no installer"
    skipped=$((skipped + 1))
    continue
  fi
  dest="$("$BASH_EXE" "$script" install "$id")"
  if [[ "$STILLWATER_DRY_RUN" == 1 ]]; then
    echo "would install  $label -> $dest"
  else
    echo "install  $label -> $dest"
  fi
  installed=$((installed + 1))
done < <(collect_status)

echo "$installed installed, $skipped skipped"
