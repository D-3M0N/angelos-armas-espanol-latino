#!/bin/bash
# SPDX-License-Identifier: MIT
# Prueba la redirección de saves de aafix.dll con un exe sintético (no usa el juego). Requiere linux/build.sh hecho.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"; . "$R/linux/lib-wine.sh"
C="$BUILD_CACHE"; W="$C/savetest/work"; mkdir -p "$W"; cd "$W"; rm -rf data "$C/savetest/sd" "$C/savetest/log"
i686-w64-mingw32-gcc "$R/linux/tests/saves_t.c" -o t.exe; cp "$C/build/aafix.dll" "$C/build/aalauncher.exe" .
start_xvfb; trap stop_xvfb EXIT
AAFIX_SAVE_DIR="Z:${C//\//\\}\\savetest\\sd" AAFIX_LOG="Z:${C//\//\\}\\savetest\\log" timeout 60 wine aalauncher.exe t.exe aafix.dll
[ "$(cat "$C/savetest/sd/s01.dat")" = hola ] && [ ! -e data/save/s01.dat ] && [ -e data/other.txt ] && echo "OK: save redirigido, resto intacto"
