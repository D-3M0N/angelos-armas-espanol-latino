#!/bin/bash
# SPDX-License-Identifier: MIT
# B.6b: duración (reloj de pared) del fundido tras pulsar START según la tasa de bucle (SLOW = ms extra por PeekMessage, aafix AAFIX_SLOW).
. "$(dirname "$0")/lib-wine.sh"
OUT="$BUILD_CACHE/f17/b6b-${SLOW:-0}"; mkdir -p "$OUT"; rm -f "$OUT"/*.png; export WINEDEBUG=err
CX=188; CY=517
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$BUILD_CACHE/run" || exit 1
openbox >"$OUT/wm.log" 2>&1 & WMPID=$!; sleep 2
cp "$BUILD_CACHE/build/aafix.dll" "$BUILD_CACHE/build/aalauncher.exe" .
env AAFIX_TRACE=1 AAFIX_SLOW="${SLOW:-0}" AAFIX_FAKE="$CX,$CY,99999" AAFIX_LOG="$OUT/aafix.log" wine aalauncher.exe Z:\\home\\chimi\\aa_rebirth\\cache\\run\\nps.exe aafix.dll >"$OUT/wine.log" 2>&1 & WP=$!
sleep 30
w=$(for w in $(xdotool search --onlyvisible --name .); do xdotool getwindowgeometry "$w" | grep -q 800x600 && echo "$w"; done | head -1)
[ -n "$w" ] || { echo "sin ventana" >&2; kill "$WMPID" "$WP"; wineserver -k; exit 1; }
xdotool windowactivate "$w"; sleep 1; eval "$(xdotool getwindowgeometry --shell "$w")"
sleep 20; import -window root "$OUT/r.png"; r=$(md5sum <"$OUT/r.png"|cut -c1-8); echo "reposo $r"
xdotool mousemove $((X+CX)) $((Y+CY)); sleep 2
for n in 1 2 3 4 5 6; do
  xdotool mousemove $((X+CX+n)) $((Y+CY)); sleep 0.3; xdotool mousemove $((X+CX)) $((Y+CY)); sleep 0.5
  t0=$(date +%s.%N); xdotool mousedown 1; sleep 0.15; xdotool mouseup 1
  : >"$OUT/serie.txt"
  for _ in $(seq "${NCAP:-60}"); do import -window root "$OUT/f.png"; echo "$(date +%s.%N) $(md5sum <"$OUT/f.png"|cut -c1-8)" >>"$OUT/serie.txt"; done
  d=$(awk -v r="$r" '$2!=r' "$OUT/serie.txt" | wc -l); echo "clic $n: capturas distintas del reposo: $d"
  [ "$d" -gt 0 ] && break
done
awk -v t0="$t0" '{printf "%.2f %s\n",$1-t0,$2}' "$OUT/serie.txt" | uniq -f1 -c >"$OUT/resumen.txt"; cat "$OUT/resumen.txt"
grep -c . "$OUT/serie.txt"
kill "$WMPID"; kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
# fin de la animación: primera marca tras la cual quedan ≥8 capturas iguales hasta el final
awk '{k=$2; if(k==p){n++}else{n=1;t=$1;p=k} } END{printf "ultimo cambio en captura final: estable desde %s (md5 %s, %d capturas iguales al final)\n", t, p, n}' "$OUT/serie.txt"
