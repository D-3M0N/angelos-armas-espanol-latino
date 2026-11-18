#!/bin/bash
# SPDX-License-Identifier: MIT
# F17: barrido con aafix inyectado (AAFIX_SM_IDX/VAL, AAFIX_LOG) del raton sobre START (hover) con openbox; imprime md5 de captura por (x,y).
. "$(dirname "$0")/lib-wine.sh"
OUT="$BUILD_CACHE/f17/hook"; mkdir -p "$OUT"; export WINEDEBUG="${WINEDEBUG:-err}"
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$BUILD_CACHE/run" || exit 1
openbox >"$OUT/wm.log" 2>&1 & WMPID=$!; sleep 2
[ -n "${PRE0:-}" ] && xdotool mousemove 50 50
cp "$BUILD_CACHE/build/aafix.dll" "$BUILD_CACHE/build/aalauncher.exe" . && wine ${DESKTOP:+explorer /desktop=aa,${DESKTOP}} aalauncher.exe Z:\\home\\chimi\\aa_rebirth\\cache\\run\\nps.exe aafix.dll >"$OUT/wine.log" 2>&1 & WP=$!
sleep "${WAIT:-30}"
for w in $(xdotool search ${MAINONLY:+--onlyvisible} --name . 2>/dev/null); do [ -n "${MAINONLY:-}" ] && { g=$(xdotool getwindowgeometry "$w" | grep -c "800x600"); [ "$g" = 0 ] && continue; }; xdotool windowactivate "$w" 2>/dev/null; done
if [ -n "${PRE:-}" ]; then for i in 1 2 3 4 5; do xdotool mousemove $((400+i*20)) $((300+i*10)); sleep 0.3; done; fi
for x in ${XS:-300 330}; do for y in ${YS:-560 580 600 614 630 650 670}; do
  xdotool mousemove "$x" "$y"; sleep 0.2; xdotool mousemove_relative 1 1; sleep 1.2
  import -window root "$OUT/s.png"; cp "$OUT/s.png" "$OUT/s-$x-$y.png"; echo "$x $y $(md5sum < "$OUT/s.png" | cut -c1-8)"
done; done
[ -n "${CLICK:-}" ] && { xdotool mousemove ${CLICK% *} ${CLICK#* }; sleep 1; xdotool click 1; sleep 8; import -window root "$OUT/click.png"; echo "click $(md5sum < "$OUT/click.png" | cut -c1-8)"; }
kill "$WMPID"; kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
