#!/bin/bash
# SPDX-License-Identifier: MIT
# Prueba el hook de glifo: GetGlyphOutlineA(0xF04E) debe dar las metricas de U+00BF. Requiere build.sh.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"; . "$R/linux/lib-wine.sh"
C="$BUILD_CACHE"; W="$C/glyphtest"; mkdir -p "$W"; cd "$W"; rm -f log tabla.tsv
i686-w64-mingw32-gcc -O0 "$R/linux/tests/glyph_t.c" -o t.exe -lgdi32; cp "$C/build/aafix.dll" "$C/build/aalauncher.exe" .
printf '0000000000000000\tx\n' > tabla.tsv
start_xvfb; trap stop_xvfb EXIT
echo "sin aafix:"; timeout 60 wine t.exe | tr -d '\r' | tee o0.txt
echo "con aafix:"; AAFIX_LOG="Z:${W//\//\\}\\log" AAFIX_TEXT_TSV="Z:${W//\//\\}\\tabla.tsv" timeout 60 wine aalauncher.exe t.exe aafix.dll | tr -d '\r' | tee o1.txt
grep -q '^same=0' o0.txt && grep -q '^same=1' o1.txt && grep -q 'glifo latino: MH_OK' log && echo "OK: hook de glifo" || { echo FALLO; exit 1; }
