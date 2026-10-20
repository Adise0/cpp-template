# Linking external libraries

Copy one of these into `CMakeLists.txt` (after `target_include_directories`) and adapt the names and paths.
Each option ends with `target_link_libraries()`, which also gives the app the library's include dirs, so you don't add them separately.

Suggested layout for libraries you drop into the repo:

```
external/<lib>/include/   headers
external/<lib>/lib/       .lib files (static libs, or import libs for DLLs)
external/<lib>/bin/       .dll files
```

| Option | When to use | Ship anything with the .exe? |
|---|---|---|
| A) `find_package` | Library installed via vcpkg, or provides its own CMake config | Depends on the library |
| B) `FetchContent` | Download from git and build with the project | Usually no (static) |
| C) Prebuilt static | You have a `.lib` + headers | No, code is baked into the .exe |
| D) Prebuilt dynamic | You have a `.dll` + `.lib` + headers | Yes, the `.dll` |
| E) Windows system lib | `user32`, `gdi32`, ... | No, Windows already has them |

## A) Installed package

```cmake
find_package(fmt CONFIG REQUIRED)
target_link_libraries(${APP_NAME} PRIVATE fmt::fmt)
```

## B) Download and build from source

Works for libraries that use CMake themselves.

```cmake
include(FetchContent)
FetchContent_Declare(fmt
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  GIT_TAG        11.0.2              # always pin a tag or commit
)
FetchContent_MakeAvailable(fmt)
target_link_libraries(${APP_NAME} PRIVATE fmt::fmt)
```

## C) Prebuilt static library

```cmake
add_library(mylib STATIC IMPORTED)
set_target_properties(mylib PROPERTIES
  IMPORTED_LOCATION             "${CMAKE_SOURCE_DIR}/external/mylib/lib/mylib.lib"
  IMPORTED_LOCATION_DEBUG       "${CMAKE_SOURCE_DIR}/external/mylib/lib/mylibd.lib"  # optional
  INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/external/mylib/include"
)
target_link_libraries(${APP_NAME} PRIVATE mylib)
```

On MSVC, linking a release-built `.lib` into a Debug build often fails with runtime-library mismatch errors (`LNK2038`). That's what the `_DEBUG` line is for.

## D) Prebuilt dynamic library (DLL)

```cmake
add_library(mydll SHARED IMPORTED)
set_target_properties(mydll PROPERTIES
  IMPORTED_LOCATION             "${CMAKE_SOURCE_DIR}/external/mydll/bin/mydll.dll"  # loaded at runtime
  IMPORTED_IMPLIB               "${CMAKE_SOURCE_DIR}/external/mydll/lib/mydll.lib"  # linked at build time
  INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/external/mydll/include"
)
target_link_libraries(${APP_NAME} PRIVATE mydll)

# Copy the DLL next to the exe after each build (so dev/run works)...
add_custom_command(TARGET ${APP_NAME} POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:mydll> $<TARGET_FILE_DIR:${APP_NAME}>
)
# ...and ship it with the release
install(IMPORTED_RUNTIME_ARTIFACTS mydll RUNTIME DESTINATION ${APP_NAME})
```

## E) Windows system library

```cmake
target_link_libraries(${APP_NAME} PRIVATE user32 gdi32)
```
