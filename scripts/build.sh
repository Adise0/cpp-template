#!/usr/bin/env bash
set -euo pipefail

preset=$1

source "$(dirname "$0")/env.sh"

printf "[Build] Configuring preset: %s\n" "$preset"
configure_log="$(mktemp)"
if ! cmake --preset "$preset" 2>&1 | tee "$configure_log"; then
  # Switching APP_COMPILER needs a fresh build folder: recreate it once and retry
  if grep -q "APP_COMPILER changed" "$configure_log"; then
    printf "[Build] Compiler changed, recreating build/%s\n" "$preset"
    rm -rf "build/$preset"
    cmake --preset "$preset"
  else
    rm -f "$configure_log"
    exit 1
  fi
fi
rm -f "$configure_log"

printf "[Build] Building preset: %s\n" "$preset"
cmake --build --preset "$preset"

printf "[Build] Done!\n"
