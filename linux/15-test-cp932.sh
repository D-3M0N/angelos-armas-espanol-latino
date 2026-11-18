#!/bin/bash
# SPDX-License-Identifier: MIT
# Prueba el hook de codepage 932 con un exe sintético bajo un locale NO japonés (en_US) y con aafix. Requiere build.sh.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"; . "$R/linux/lib-wine.sh"
export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
C="$BUILD_CACHE"; W="$C/cptest"; mkdir -p "$W"; cd "$W"
i686-w64-mingw32-gcc "$R/linux/tests/cp_t.c" -o t.exe; cp "$C/build/aafix.dll" "$C/build/aalauncher.exe" .
start_xvfb; trap stop_xvfb EXIT
echo "sin aafix:"; timeout 60 wine t.exe
echo "con aafix:"; AAFIX_LOG="Z:${W//\//\\}\\log" timeout 60 wine aalauncher.exe t.exe aafix.dll
