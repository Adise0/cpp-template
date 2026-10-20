#!/usr/bin/env bash
set -euo pipefail

# Load the compiler env once here, so every rebuild inherits it
source "$(dirname "$0")/env.sh"

printf "Starting watcher...\n"

run_after=1
while getopts "n" opt; do
  case "$opt" in
  n) run_after=0 ;;
  esac
done
shift $((OPTIND - 1))

# Watch code, build config and data folders (only the ones that exist)
watch_args=()
for path in src include cmake assets resources CMakeLists.txt CMakePresets.json local.cmake; do
  [[ -e "$path" ]] && watch_args+=(-w "$path")
done

# Run dev.sh with this same bash, by absolute path. A bare "bash" makes Windows
# pick System32\bash.exe (WSL) over Git Bash, and dev.sh never runs.
bash_exe="$(cygpath -w "$BASH" 2>/dev/null || echo "$BASH")"

watchexec "${watch_args[@]}" -r --shell=none \
  -E RUN_AFTER="$run_after" \
  -- "$bash_exe" ./scripts/dev.sh
