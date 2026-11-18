#!/bin/bash
# SPDX-License-Identifier: MIT
# Fase 1: entrada por teclado en el titulo (aafix inyectado). KEYS="Return Down ..." se envian cada STEP s; captura tras cada tecla.
. "$(dirname "$0")/lib-wine.sh"
OUT="$BUILD_CACHE/f17/keys"; mkdir -p "$OUT"; rm -f "$OUT"/k-*.png; export WINEDEBUG="${WINEDEBUG:-err}"
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$BUILD_CACHE/run" || exit 1
openbox >"$OUT/wm.log" 2>&1 & WMPID=$!; sleep 2
cp "$BUILD_CACHE/build/aafix.dll" "$BUILD_CACHE/build/aalauncher.exe" . && wine aalauncher.exe Z:\\home\\chimi\\aa_rebirth\\cache\\run\\nps.exe aafix.dll >"$OUT/wine.log" 2>&1 & WP=$!
sleep "${WAIT:-30}"
w=$(for w in $(xdotool search --onlyvisible --name .); do xdotool getwindowgeometry "$w" | grep -q 800x600 && echo "$w"; done | head -1)
echo "ventana=$w"; xdotool windowactivate "$w"; xdotool windowfocus "$w"; sleep 1
import -window root "$OUT/k-00.png"; echo "00 $(md5sum < "$OUT/k-00.png" | cut -c1-8)"
n=0; for k in ${KEYS:-Return}; do n=$((n+1)); xdotool key ${SENDEV:+--window "$w"} "$k"; sleep "${STEP:-5}"
  f=$(printf "$OUT/k-%02d.png" $n); import -window root "$f"; echo "$n $k $(md5sum < "$f" | cut -c1-8)"; done
kill "$WMPID"; kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
