cmake_minimum_required(VERSION 3.31)

# ---- App config (single source of truth) ----
set(APP_NAME    "MyApp")
set(APP_VERSION "0.0.1")
set(APP_ICON    "${CMAKE_SOURCE_DIR}/icon.ico")  # "" = no icon
set(APP_WINDOW_MODE "CONSOLE")  # CONSOLE | WINDOW | AUTO (console in Debug, window otherwise)
set(APP_USE_ASSETS    ON)  # ship assets/ next to the exe
set(APP_USE_RESOURCES OFF)  # ship resources/ next to the exe
set(APP_PLATFORMS Windows Linux macOS)  # where the app builds and releases: Windows Linux macOS
set(APP_COMPILER "")  # "" = platform default (MSVC on Windows) | clang-cl | clang++ | g++
# ---------------------------------------------

# Personal overrides for this machine only (gitignored, see README.md and local.cmake.example)
include("${CMAKE_SOURCE_DIR}/local.cmake" OPTIONAL RESULT_VARIABLE APP_LOCAL_CONFIG)
if(APP_LOCAL_CONFIG)
  message(STATUS "Using local overrides from local.cmake")
endif()

# The compiler is locked in when a build folder is first configured, so a change needs a
# fresh folder. scripts/build.sh sees this error and recreates the folder automatically.
if(DEFINED CACHE{APP_COMPILER_USED})
  set(_previous_compiler "$CACHE{APP_COMPILER_USED}")
elseif(DEFINED CACHE{CMAKE_CXX_COMPILER})
  set(_previous_compiler "")  # folder configured before APP_COMPILER existed: default compiler
else()
  set(_previous_compiler "${APP_COMPILER}")  # fresh folder
endif()
if(NOT "${_previous_compiler}" STREQUAL "${APP_COMPILER}")
  message(FATAL_ERROR "APP_COMPILER changed ('${_previous_compiler}' -> '${APP_COMPILER}'), "
                      "delete ${CMAKE_BINARY_DIR} and configure again")
endif()
if(APP_COMPILER)
  set(CMAKE_CXX_COMPILER "${APP_COMPILER}")
endif()
set(APP_COMPILER_USED "${APP_COMPILER}" CACHE INTERNAL "")

if(NOT DEFINED CMAKE_TOOLCHAIN_FILE AND DEFINED ENV{VCPKG_ROOT})
  set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE STRING "")
endif()



project(${APP_NAME} VERSION ${APP_VERSION} LANGUAGES CXX)
message(STATUS "${APP_NAME}: compiler ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")

if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
  set(APP_PLATFORM "macOS")
else()
  set(APP_PLATFORM "${CMAKE_SYSTEM_NAME}")
endif()
if(NOT APP_PLATFORM IN_LIST APP_PLATFORMS)
  message(FATAL_ERROR "${APP_NAME} is not enabled for ${APP_PLATFORM} (APP_PLATFORMS: ${APP_PLATFORMS})")
endif()

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")


file(GLOB_RECURSE SOURCES
  CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/src/*.cpp"
  "${CMAKE_SOURCE_DIR}/src/*.cxx"
  "${CMAKE_SOURCE_DIR}/src/*.h"
  "${CMAKE_SOURCE_DIR}/src/*.hpp"
)



add_executable(${APP_NAME} ${SOURCES})

# Console vs window app (AUTO = console in Debug, window otherwise)
if(APP_WINDOW_MODE STREQUAL "WINDOW")
  set(APP_WINDOWED ON)
elseif(APP_WINDOW_MODE STREQUAL "CONSOLE")
  set(APP_WINDOWED OFF)
elseif(APP_WINDOW_MODE STREQUAL "AUTO")
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(APP_WINDOWED OFF)
  else()
    set(APP_WINDOWED ON)
  endif()
else()
  message(FATAL_ERROR "APP_WINDOW_MODE must be CONSOLE, WINDOW or AUTO (got '${APP_WINDOW_MODE}')")
endif()

if(WIN32 AND APP_WINDOWED)
  set_target_properties(${APP_NAME} PROPERTIES WIN32_EXECUTABLE ON)
  # Keep int main() as the entry point instead of requiring WinMain
  if(MSVC)
    target_link_options(${APP_NAME} PRIVATE "/ENTRY:mainCRTStartup")
  endif()
endif()
message(STATUS "${APP_NAME}: ${CMAKE_BUILD_TYPE} build, windowed = ${APP_WINDOWED}")

# Generated files: AppConfig.h (name/version for C++) and app.rc (icon + version info)
set(APP_GENERATED_DIR "${CMAKE_BINARY_DIR}/generated")
configure_file("${CMAKE_SOURCE_DIR}/cmake/AppConfig.h.in" "${APP_GENERATED_DIR}/AppConfig.h" @ONLY)

if(WIN32)
  if(APP_ICON)
    if(NOT EXISTS "${APP_ICON}")
      message(FATAL_ERROR "APP_ICON is set but ${APP_ICON} does not exist")
    endif()
    set(APP_ICON_LINE "IDI_ICON1 ICON \"${APP_ICON}\"")
  else()
    set(APP_ICON_LINE "")
  endif()
  configure_file("${CMAKE_SOURCE_DIR}/cmake/app.rc.in" "${APP_GENERATED_DIR}/app.rc" @ONLY)
  target_sources(${APP_NAME} PRIVATE "${APP_GENERATED_DIR}/app.rc")
endif()

target_include_directories(${APP_NAME} PRIVATE
  "${CMAKE_SOURCE_DIR}/src"
  "${CMAKE_SOURCE_DIR}/include"
  "${APP_GENERATED_DIR}"
)


# External libraries: see cmake/LIBRARIES.md for copy-paste templates


# Data folders: mirrored next to the exe on every build, copied on install
foreach(_dir IN ITEMS assets resources)
  string(TOUPPER "${_dir}" _dir_upper)
  set(_src "${CMAKE_SOURCE_DIR}/${_dir}")

  if(NOT APP_USE_${_dir_upper})
    continue()
  endif()
  if(NOT IS_DIRECTORY "${_src}")
    message(FATAL_ERROR "APP_USE_${_dir_upper} is ON but ${_src} does not exist")
  endif()

  # Custom targets always run, so edits (and deletions) always reach the build
  add_custom_target(copy_${_dir}
    COMMAND ${CMAKE_COMMAND} -E rm -rf "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${_dir}"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${_src}" "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${_dir}"
  )
  add_dependencies(${APP_NAME} copy_${_dir})

  install(DIRECTORY "${_src}" DESTINATION ${APP_NAME})
endforeach()


install(TARGETS ${APP_NAME}
  RUNTIME DESTINATION ${APP_NAME}
)

# Release zip (made by scripts/release.sh), e.g. MyApp-0.0.1-Windows.zip
set(CPACK_GENERATOR ZIP)
set(CPACK_PACKAGE_FILE_NAME "${APP_NAME}-${APP_VERSION}-${APP_PLATFORM}")
set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY OFF)  # install() already puts everything in ${APP_NAME}/
include(CPack)


# `cmake --build --preset <preset> --target run` builds and runs the app
add_custom_target(run
  COMMAND $<TARGET_FILE:${APP_NAME}>
  DEPENDS ${APP_NAME}
  WORKING_DIRECTORY "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}"
  USES_TERMINAL
)
