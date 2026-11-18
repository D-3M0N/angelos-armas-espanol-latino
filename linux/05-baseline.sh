#!/bin/bash
# SPDX-License-Identifier: MIT
# Fase 0 C: baseline en Wine sobre copia desechable (symlinks) en cache/run. Uso: 05-baseline.sh ja_JP.UTF-8|C.UTF-8
# Capturas t=5/15/30 s y, tras pulsar START, +10 s y +25 s (OP). Todo en cache/baseline/<locale>/ (no se commitea).
. "$(dirname "$0")/lib-wine.sh"
LOC="${1:?locale}"; export LC_ALL="$LOC" LANG="$LOC"
export WINEDEBUG=err+all,+loaddll
OUT="$BUILD_CACHE/baseline/$LOC"; mkdir -p "$OUT" "$BUILD_CACHE/run"
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$BUILD_CACHE/run" || exit 1; for f in "$INSTALL_DIR"/*; do ln -sf "$f" .; done
wine nps.exe > "$OUT/wine.log" 2>&1 & WP=$!
shot() { import -window root "$OUT/$1.png" 2>/dev/null; }
sleep 5; shot t05; sleep 10; shot t15; sleep 15; shot t30
for w in $(xdotool search --name . 2>/dev/null); do echo "$w | $(xdotool getwindowname "$w") | $(xdotool getwindowgeometry "$w" | tr '\n' ' ')"; done > "$OUT/windows.txt"
# START (≈300,614 en pantalla): el clic NO llegó al juego en 2 intentos (ver fase-0-C-baseline.md); queda como intento
xdotool mousemove 300 614; sleep 1; xdotool click 1
sleep 10; shot s10; sleep 25; shot s35
kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
echo "log: $(wc -l < "$OUT/wine.log") líneas; err: $(grep -c 'err:' "$OUT/wine.log")"
