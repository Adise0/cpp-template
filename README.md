# C++ App Template

A small starter for C++23 desktop apps built with CMake and Ninja. You configure the app in one place, rebuild and run it automatically while you code, and get one release zip per OS from GitHub Actions.

- **One config block** at the top of `CMakeLists.txt`: name, version, icon, console or window app, data folders, target platforms, compiler.
- **Personal overrides** in a gitignored `local.cmake`, so everyone on a team can use their own setup without editing shared files.
- **Watch mode**: rebuilds and reruns the app in the same terminal whenever code, config or assets change.
- **Release zips** for every enabled platform, built locally or by CI.

---

## Requirements

|                       | Windows                                                                              | Linux / macOS                                            |
| --------------------- | ------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| Compiler              | Visual Studio 2022 or Build Tools with the **Desktop development with C++** workload | GCC or Clang (Xcode Command Line Tools on macOS)         |
| CMake                 | 3.31 or newer                                                                        | 3.31 or newer                                            |
| Ninja                 | Included with the VS C++ workload                                                    | `apt install ninja-build` / `brew install ninja`         |
| Shell                 | **Git Bash** (run every script from it)                                              | Any bash                                                 |
| Watch mode (optional) | `choco install watchexec`                                                            | `brew install watchexec` / `cargo install watchexec-cli` |

On Windows you **don't** need a Developer Command Prompt: the scripts find Visual Studio and load the compiler environment themselves (see `scripts/env.sh`).

---

## Quick start

```bash
# 1. Name your app: edit the config block at the top of CMakeLists.txt
# 2. Build and run
bash scripts/dev.sh

# Or rebuild and rerun automatically on every change
bash scripts/watch.sh
```

Run all scripts from the repository root.

---

## Project layout

```
CMakeLists.txt        Build definition; the config block at the top is the only part you normally edit
CMakePresets.json     The two build modes: dev (Debug) and release (RelWithDebInfo)
local.cmake.example   Template for your personal overrides (copy it to local.cmake)
icon.ico              App icon (Windows)
src/                  Your .cpp files (picked up automatically, no need to list them)
include/              Your headers
assets/               Data files shipped next to the executable (optional)
resources/            A second data folder, same rules (optional)
cmake/                Templates CMake fills in (AppConfig.h.in, app.rc.in) and LIBRARIES.md
scripts/              dev.sh, watch.sh, build.sh, release.sh, env.sh, ci-matrix.sh
.github/workflows/    CI checks (ci.yml) and releases (release.yml)
build/                Generated build folders, one per preset (gitignored)
out/                  Release output (gitignored)
```

Include headers either from `include/` (`#include "Foo.h"`) or by their path under `src/` (`#include "bar/Foo.h"`).

---

## Configuration

Everything about the app is set in the block at the top of `CMakeLists.txt`:

```cmake
set(APP_NAME    "MyApp")
set(APP_VERSION "0.0.1")
set(APP_ICON    "${CMAKE_SOURCE_DIR}/icon.ico")  # "" = no icon
set(APP_WINDOW_MODE "CONSOLE")  # CONSOLE | WINDOW | AUTO (console in Debug, window otherwise)
set(APP_USE_ASSETS    ON)  # ship assets/ next to the exe
set(APP_USE_RESOURCES OFF)  # ship resources/ next to the exe
set(APP_PLATFORMS Windows Linux macOS)  # where the app builds and releases: Windows Linux macOS
set(APP_COMPILER "")  # "" = platform default (MSVC on Windows) | clang-cl | clang++ | g++
```

| Setting                                | What it does                                                                                                                                                          |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `APP_NAME`                             | Executable name, release folder and zip name, and `APP_NAME` in C++.                                                                                                  |
| `APP_VERSION`                          | `major.minor.patch`. Shown in the .exe's Properties → Details on Windows, available in C++, used in the zip name.                                                     |
| `APP_ICON`                             | `.ico` file embedded in the Windows executable. Configure fails if the file is missing.                                                                               |
| `APP_WINDOW_MODE`                      | `CONSOLE` = terminal app. `WINDOW` = no console window (Windows). `AUTO` = console in dev builds, window in release. `int main()` works in every mode.                |
| `APP_USE_ASSETS` / `APP_USE_RESOURCES` | Copies `assets/` or `resources/` next to the executable on every build and includes them in releases. Configure fails if the setting is ON and the folder is missing. |
| `APP_PLATFORMS`                        | Which OSes the app supports. Configuring on any other OS fails, and CI only builds these.                                                                             |
| `APP_COMPILER`                         | The **project's** compiler. Leave it `""` unless the code really needs a specific one; see below for personal choices.                                                |

The block is plain `set()` calls, so edits apply on the next build. You never have to delete `build/` after changing it.

### Using the config in C++

CMake generates `AppConfig.h` from `cmake/AppConfig.h.in`:

```cpp
#include "AppConfig.h"

printf("%s v%s\n", APP_NAME, APP_VERSION);   // "MyApp v0.0.1"
// Also: APP_VERSION_MAJOR, APP_VERSION_MINOR, APP_VERSION_PATCH, APP_WINDOWED (1/0)
```

To pass another value to C++, `set()` it in the config block and add a `#define` line using `@YOUR_VAR@` to `cmake/AppConfig.h.in`.

---

## Personal settings: `local.cmake`

`CMakeLists.txt` is shared by everyone on the project, but people work on different machines: one teammate uses MSVC, another prefers clang-cl, someone else is on Linux with GCC. Putting a personal choice in the config block would change everyone's build.

`local.cmake` is for those settings. It's an optional file in the repository root that is **gitignored**, so it only affects your machine:

```bash
cp local.cmake.example local.cmake
```

```cmake
# local.cmake
set(APP_COMPILER "clang-cl")
```

How it works:

- CMake loads it **right after** the config block, so anything you set there overrides the project value. If the file doesn't exist, nothing changes.
- When it's active, the configure output says `Using local overrides from local.cmake`, followed by the compiler actually used, e.g. `compiler Clang 23.1.3`.
- **CI never sees it.** Official releases always use the project's settings, whatever compiler people use locally.
- Local `release.sh` runs **do** use it. A zip you build yourself is built with your compiler.

**What belongs there:** anything that depends on your machine, mainly `APP_COMPILER`.
**What doesn't:** anything that changes the app itself (name, version, platforms, data folders). Those are project decisions and go in the config block, or teammates and CI will build something different from you.

### Changing compilers

A build folder stays tied to the compiler it was first configured with. When `APP_COMPILER` changes (in the config block or in `local.cmake`), CMake stops with `APP_COMPILER changed`. `build.sh` sees that, deletes `build/<preset>`, and configures again, so all you do is edit the line and rebuild.

| Compiler   | Platforms | Notes                                                                                            |
| ---------- | --------- | ------------------------------------------------------------------------------------------------ |
| `""`       | All       | MSVC on Windows, GCC on Linux, Apple Clang on macOS                                              |
| `clang-cl` | Windows   | Clang with MSVC-style flags and MSVC's libraries. Good for catching code that only MSVC accepts. |
| `clang++`  | All       |                                                                                                  |
| `g++`      | All       | On Windows this means MinGW, whose libraries aren't compatible with MSVC-built ones              |

Install LLVM for the clang options (`winget install LLVM.LLVM` on Windows, then add `C:\Program Files\LLVM\bin` to your PATH).

---

## Scripts

| Script                                 | What it does                                                                                                                                                                                                   |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bash scripts/dev.sh`                  | Debug build, then runs the app                                                                                                                                                                                 |
| `bash scripts/watch.sh`                | Runs `dev.sh` again whenever `src`, `include`, `cmake`, `assets`, `resources`, `CMakeLists.txt`, `CMakePresets.json` or `local.cmake` changes. Output stays in the same terminal. `-n` builds without running. |
| `bash scripts/build.sh <dev\|release>` | Configure and build one preset                                                                                                                                                                                 |
| `bash scripts/release.sh`              | Release build, then `out/<APP_NAME>/` and `out/<APP_NAME>-<version>-<platform>.zip`                                                                                                                            |
| `bash scripts/ci-matrix.sh`            | Prints the GitHub Actions build matrix for `APP_PLATFORMS`. Used by both workflows; you don't run it yourself                                                                                                  |

`watch.sh` only watches paths that exist when it starts. Restart it after creating `local.cmake` or a data folder.

You can also run the app through CMake directly: `cmake --build --preset dev --target run`.

---

## Data folders (`assets/`, `resources/`)

- **Dev:** each build replaces `build/<preset>/bin/assets` with a fresh copy, so edits, new files and deleted files always show up, even when no code changed.
- **Release:** copied into `out/<APP_NAME>/assets`.

Load files with paths relative to the executable's folder, e.g. `"./assets/example.txt"`. The `run` target and the release layout both start the app from that folder.

---

## External libraries

See [`cmake/LIBRARIES.md`](cmake/LIBRARIES.md) for copy-paste templates: installed packages, downloading from git, prebuilt static `.lib`, prebuilt `.dll` (including copying it next to the executable and into releases), and Windows system libraries.

---

## Releases and CI

Two workflows in `.github/workflows/`. Both read `APP_PLATFORMS` from `CMakeLists.txt` (through `scripts/ci-matrix.sh`) and run one clean GitHub virtual machine per listed OS.

### CI checks (`ci.yml`)

Runs on **every push to any branch** and builds the `dev` and `release` presets. Nothing is uploaded or published; the only result is a ✅ or ❌ next to the commit on GitHub. If you push again before a run finishes, the older run for that branch is cancelled.

### Releases (`release.yml`)

Runs `scripts/release.sh` and keeps the zips. It **never runs on a normal push**:

| Trigger                                                   | Where the zips end up                                                                                 |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| **Actions** tab → _Release_ → _Run workflow_              | The **Artifacts** section of that run (login required, deleted after 90 days). Use it to test builds. |
| Pushing a tag: `git tag v0.1.0 && git push origin v0.1.0` | The same artifacts **plus** a **draft GitHub Release** with all zips attached.                        |

A tag push never publishes anything by itself. The release is created as a **draft**, visible only to people with write access, and its notes are pre-filled from the commits and pull requests since the previous tag. To ship it, open the repository's **Releases** page, edit the draft (title, notes, extra files such as a signed installer), and click **Publish release**. Once published it's public and permanent.

Keep the tag matching `APP_VERSION`. The release is named after the tag, but the zips are named after `APP_VERSION`.

The _Run workflow_ button only appears once a workflow file is on the default branch (`master`/`main`). Until then, push-triggered workflows like CI still run on your branch.

Actions is free for public repositories. Private repositories get a monthly minute allowance, and Windows minutes count double and macOS minutes ten times.

To support another OS, your code has to compile with that OS's compiler. Building locally with `clang-cl` or `clang++` catches most MSVC-only code before CI does.

---

## Troubleshooting

**`No MSVC found` / `No CMAKE_CXX_COMPILER could be found` (Windows).** Install Visual Studio or Build Tools with the _Desktop development with C++_ workload. You don't need a Developer Command Prompt.

**Build fails right after copying the project from another PC.** `build/` stores absolute paths for the machine that created it. Delete `build/` and build again. Fresh clones are never affected.

**`<App> is not enabled for <OS>`.** Add the OS to `APP_PLATFORMS`.

**`APP_USE_ASSETS is ON but .../assets does not exist`.** Create the folder or turn the setting off.

**The new icon doesn't show after a rebuild (Windows).** The executable is fine; Windows Explorer is showing a cached icon. Run `ie4uinit.exe -show`, or rename the executable to confirm. Pinned taskbar shortcuts keep their own copy, so unpin and pin again.

**Typing `bash` in PowerShell starts WSL instead of Git Bash.** Run the scripts from a Git Bash terminal. VS Code can make it the default terminal (_Terminal: Select Default Profile_).
