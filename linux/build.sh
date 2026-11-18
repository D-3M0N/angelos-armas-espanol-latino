#!/bin/bash
# SPDX-License-Identifier: MIT
# Compila aafix.dll y aalauncher.exe (i686-w64-mingw32) en cache/build.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"
cmake -S "$R" -B "$R/../cache/build" -G Ninja -DCMAKE_SYSTEM_NAME=Windows \
  -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc -DCMAKE_RC_COMPILER=i686-w64-mingw32-windres -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$R/../cache/build"
