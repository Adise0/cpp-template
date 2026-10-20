#!/usr/bin/env bash
# Prints the GitHub Actions build matrix for the platforms in APP_PLATFORMS (CMakeLists.txt),
# e.g. [{"platform":"Windows","os":"windows-latest"}]. Used by the workflows in .github/workflows.
set -euo pipefail

platforms=$(sed -n 's/^set(APP_PLATFORMS[[:space:]]*\([^)]*\)).*/\1/p' CMakeLists.txt)
echo "APP_PLATFORMS: $platforms" >&2

entries=()
for p in $platforms; do
  case "$p" in
  Windows) os=windows-latest ;;
  Linux) os=ubuntu-latest ;;
  macOS) os=macos-latest ;;
  *)
    echo "::error::Unknown platform '$p' in APP_PLATFORMS" >&2
    exit 1
    ;;
  esac
  entries+=("{\"platform\":\"$p\",\"os\":\"$os\"}")
done
(IFS=,; echo "[${entries[*]}]")
