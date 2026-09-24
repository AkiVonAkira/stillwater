#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
export STILLWATER_ROOT="$ROOT"
# shellcheck source=install/lib.sh
source "$ROOT/install/lib.sh"
stillwater_init_paths

usage() {
  cat <<'EOF'
Install Stillwater into apps found on this OS. Missing apps are skipped.

  bash install.sh                 interactive chooser (default)
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
  while IFS= read -r script; do
    "$BASH_EXE" "$script" status
  done < <(adapter_scripts)
}

print_list() {
  printf 'Stillwater  %s  %s\n' "$(stillwater_os_label)" "$(stillwater_version)"
  collect_status | while IFS='|' read -r id label state; do
    printf '  %-22s  %s  %s\n' "$label" "$state" "$id"
  done
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
  if [[ ! -t 0 ]]; then
    echo "install.sh needs a terminal, or pass --all / adapter ids" >&2
    exit 1
  fi
  print_list
  echo
  printf 'Install to all found apps? [Y/s/n] '
  read -r choice || exit 1
  choice="$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')"
  case "$choice" in
    n | no)
      exit 0
      ;;
    s | select)
      printf 'Ids (space separated): '
      read -r selected || exit 1
      # shellcheck disable=SC2206
      ONLY=($selected)
      ;;
    *)
      ONLY=()
      while IFS='|' read -r id _label state; do
        if [[ "$state" == found ]]; then
          ONLY+=("$id")
        fi
      done < <(collect_status)
      ;;
  esac
}

if [[ "$LIST" == 1 ]]; then
  print_list
  exit 0
fi

unknown_ids || exit 1

if [[ "$ALL" == 1 ]]; then
  ONLY=()
elif [[ ${#ONLY[@]} -gt 0 && "$INTERACTIVE" != 1 ]]; then
  :
else
  prompt_interactive
fi

unknown_ids || exit 1

installed=0
skipped=0
while IFS='|' read -r id label state; do
  if ! stillwater_id_wanted "$id" "${ONLY[@]+"${ONLY[@]}"}"; then
    continue
  fi
  if [[ "$state" != found ]]; then
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
