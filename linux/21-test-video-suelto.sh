#!/bin/bash
# SPDX-License-Identifier: MIT
# Comprueba si npmm.dll abre un op.mpg SUELTO junto a nps.exe (copia desechable en cache/run-vid, sin aafix).
# Requiere cache/video/op.mpg. Traza +file de Wine filtrada a «op.mpg» y «mpeg.npp».
. "$(dirname "$0")/lib-wine.sh"
export WINEDEBUG=+file
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
R="$BUILD_CACHE/run-vid"; rm -rf "$R"; mkdir -p "$R"; cd "$R" || exit 1
for f in "$INSTALL_DIR"/*; do ln -sf "$f" .; done
ln -sf "$BUILD_CACHE/video/op.mpg" op.mpg
wine nps.exe > ../run-vid.full 2>&1 & WP=$!
sleep "${1:-60}"
wineserver -k; sleep 2; kill "$WP" 2>/dev/null
grep -aiE "op\.mpg|mpeg\.npp|npmm" ../run-vid.full | cut -c1-200 | head -30 > ../run-vid.log; wc -l ../run-vid.full; echo "== op.mpg / mpeg.npp / npmm:"; cat ../run-vid.log
