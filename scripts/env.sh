#!/usr/bin/env bash
# Sourced by the other scripts. On Windows, loads the MSVC environment (cl, link, rc,
# INCLUDE/LIB...) if it isn't loaded yet, so builds work from a plain Git Bash.

if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]] && ! command -v cl >/dev/null 2>&1; then
  vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
  vs_path=""
  if [[ -x "$vswhere" ]]; then
    vs_path="$("$vswhere" -latest -products '*' \
      -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
      -property installationPath | tr -d '\r')"
  fi
  if [[ -z "$vs_path" ]]; then
    printf "[Env] No MSVC found. Install Visual Studio (Build Tools) with the 'Desktop development with C++' workload.\n" >&2
    return 1
  fi

  printf "[Env] Loading MSVC environment from %s\n" "$vs_path"
  env_bat="$(mktemp --suffix=.bat)"
  vcvars="$(cygpath -w "$(cygpath -u "$vs_path")/VC/Auxiliary/Build/vcvars64.bat")"
  # chcp 65001 = UTF-8 output, or non-ASCII paths (e.g. accents in the username) get mangled
  printf '@chcp 65001 >nul\r\n@call "%s" >nul\r\n@set\r\n' "$vcvars" >"$env_bat"

  while IFS='=' read -r name value; do
    value="${value%$'\r'}"
    case "$name" in
    Path | PATH)
      new_path="$(cygpath -up "$value")" || { printf "[Env] Could not convert PATH\n" >&2; return 1; }
      export PATH="$new_path"
      ;;
    INCLUDE | LIB | LIBPATH | VSINSTALLDIR | VCINSTALLDIR | VCToolsInstallDir | VSCMD_VER | \
      WindowsSdkDir | WindowsSDKVersion | UCRTVersion | UniversalCRTSdkDir)
      export "$name=$value"
      ;;
    esac
  done < <(cmd //c "$(cygpath -w "$env_bat")")
  rm -f "$env_bat"

  if ! command -v cl >/dev/null 2>&1; then
    printf "[Env] Loaded %s but cl is still not on PATH\n" "$vs_path" >&2
    return 1
  fi
fi
