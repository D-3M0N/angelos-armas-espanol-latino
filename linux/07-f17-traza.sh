#!/bin/bash
# SPDX-License-Identifier: MIT
# F17 (ACT=1 activa ventanas con windowactivate; WM=openbox para probar con gestor de ventanas): traza +ddraw/+cursor y clic tras espera larga. Uso: 07-f17-traza.sh [desktop]  (desktop = explorer /desktop=)
. "$(dirname "$0")/lib-wine.sh"
MODE="${1:-plain}"; OUT="$BUILD_CACHE/f17/$MODE"; mkdir -p "$OUT"
export WINEDEBUG=${WD:-err+all,+ddraw,+cursor}
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$BUILD_CACHE/run" || exit 1
if [ -n "${WM:-}" ]; then "$WM" >"$OUT/wm.log" 2>&1 & WMPID=$!; sleep 2; fi
if [ "$MODE" = desktop ]; then wine explorer /desktop=aa,800x600 "Z:${BUILD_CACHE////\\}\\run\\nps.exe" > "$OUT/wine.log" 2>&1 & WP=$!
else wine nps.exe > "$OUT/wine.log" 2>&1 & WP=$!; fi
shot() { import -window root "$OUT/$1.png" 2>/dev/null; md5sum "$OUT/$1.png"; }
sleep ${PRE:-70}; shot a70
echo MARK_CLICK >> "$OUT/wine.log"
if [ -n "${ACT:-}" ]; then for w in $(xdotool search --name . 2>/dev/null); do xdotool windowactivate "$w" 2>/dev/null; done; sleep 2; shot act; fi
xdotool mousemove ${CX:-300} ${CY:-614}; sleep 1; xdotool click 1; sleep 5; shot b5; sleep 20; shot b25
for w in $(xdotool search --name . 2>/dev/null); do import -window "$w" "$OUT/w$w.png" 2>/dev/null; echo "$w $(xdotool getwindowname "$w") $(md5sum < "$OUT/w$w.png")"; done
ps -o pid,pcpu,nlwp,stat,comm -C nps.exe,wine64-preloader,wine 2>/dev/null | head
[ -n "${WMPID:-}" ] && kill "$WMPID"
kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
grep -n MARK_CLICK "$OUT/wine.log"
echo "total: $(wc -l < "$OUT/wine.log")"; sed 's/^[0-9a-f]*:[0-9a-f]*:trace:\([a-z]*\):\([A-Za-z_0-9]*\).*/\1 \2/' "$OUT/wine.log" | sort | uniq -c | sort -rn | head -25
