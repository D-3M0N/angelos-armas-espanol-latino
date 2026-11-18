#!/bin/bash
# SPDX-License-Identifier: MIT
# H2: traza de texto sin usuario. Xvfb+openbox, clic START (F17), avanza N pasos; log en cache/test/traza.log (solo len+hash).
. "$(dirname "$0")/lib-wine.sh"
OUT="$BUILD_CACHE/test"; mkdir -p "$OUT"; N="${N:-25}"; TAG="${TAG:-}"
export AAFIX_LOG="$OUT/traza.log" AAFIX_TRACE_TEXT="${AAFIX_TRACE_TEXT:-1}"; rm -f "$AAFIX_LOG"  # TAG=xx: al final copia evidencia a cierre-h2/ (no se sobrescribe)
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$BUILD_CACHE/run" || exit 1
openbox >"$OUT/wm.log" 2>&1 & WMPID=$!; sleep 2
wine nps.exe >"$OUT/traza-wine.log" 2>&1 & WP=$!
sleep 30
for w in $(xdotool search --name . 2>/dev/null); do xdotool windowactivate "$w" 2>/dev/null; done
for y in ${YS:-614 600}; do
  xdotool mousemove 300 "$y"; sleep 0.5; xdotool mousemove_relative 1 1; sleep 1; echo "y=$y $(xdotool getmouselocation) act=$(xdotool getactivewindow getwindowname 2>&1)"; xdotool click 1; sleep 10
  grep -q '^MSG' "$AAFIX_LOG" 2>/dev/null && { echo "START ok y=$y"; import -window root "$OUT/traza-start.png"; break; }
done
for _ in $(seq "$N"); do xdotool key Return; sleep 1.5; done
sleep "${WAIT_END:-8}"; import -window root "$OUT/traza.png"
kill "$WMPID"; kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
echo "MSG: $(grep -c '^MSG' "$AAFIX_LOG" 2>/dev/null)"
[ -n "$TAG" ] && { mkdir -p "$OUT/cierre-h2"; cp "$AAFIX_LOG" "$OUT/cierre-h2/traza-$TAG.log"; cp "$OUT/traza-wine.log" "$OUT/cierre-h2/traza-wine-$TAG.log"; cp "$OUT/traza.png" "$OUT/cierre-h2/traza-$TAG.png"; }
