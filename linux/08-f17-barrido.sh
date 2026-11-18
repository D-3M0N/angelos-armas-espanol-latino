#!/bin/bash
# SPDX-License-Identifier: MIT
# F17: barrido de posiciones del raton sobre START (hover) con openbox; imprime md5 de captura por (x,y).
. "$(dirname "$0")/lib-wine.sh"
OUT="$BUILD_CACHE/f17/barrido"; mkdir -p "$OUT"; export WINEDEBUG=err
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$BUILD_CACHE/run" || exit 1
openbox >"$OUT/wm.log" 2>&1 & WMPID=$!; sleep 2
wine nps.exe >"$OUT/wine.log" 2>&1 & WP=$!
sleep 30
for w in $(xdotool search --name . 2>/dev/null); do xdotool windowactivate "$w" 2>/dev/null; done
for x in ${XS:-300 330}; do for y in ${YS:-560 580 600 614 630 650 670}; do
  xdotool mousemove "$x" "$y"; sleep 0.2; xdotool mousemove_relative 1 1; sleep 1.2
  import -window root "$OUT/s.png"; echo "$x $y $(md5sum < "$OUT/s.png" | cut -c1-8)"
done; done
[ -n "${CLICK:-}" ] && { xdotool mousemove ${CLICK% *} ${CLICK#* }; sleep 1; xdotool click 1; sleep 8; import -window root "$OUT/click.png"; echo "click $(md5sum < "$OUT/click.png" | cut -c1-8)"; }
kill "$WMPID"; kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
