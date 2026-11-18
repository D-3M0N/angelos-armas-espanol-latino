#!/bin/bash
# SPDX-License-Identifier: MIT
# Fase 1: prueba de cnc-ddraw (F17) en copia desechable cache/run-cnc (symlinks + ddraw.dll/ini). Uso: 06-cncddraw-test.sh [renderer]
. "$(dirname "$0")/lib-wine.sh"
REN="${1:-gdi}"
export WINEDEBUG=err+all,+loaddll
CNC="$BUILD_CACHE/tools/cncddraw-dl/x"; R="$BUILD_CACHE/run-cnc"; OUT="$BUILD_CACHE/cnc/$REN"
rm -rf "$R"; mkdir -p "$R" "$OUT"
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$R" || exit 1; for f in "$INSTALL_DIR"/*; do ln -sf "$f" .; done
cp "$CNC/ddraw.dll" .; sed -e "s/^renderer=.*/renderer=$REN/" -e 's/^windowed=.*/windowed=true/' "$CNC/ddraw.ini" > ddraw.ini
export WINEDLLOVERRIDES="$WINEDLLOVERRIDES;ddraw=n,b"
wine nps.exe > "$OUT/wine.log" 2>&1 & WP=$!
shot() { import -window root "$OUT/$1.png" 2>/dev/null; }
sleep 10; shot t10; sleep 15; shot t25; sleep 15; shot t40
for w in $(xdotool search --name . 2>/dev/null); do echo "$w | $(xdotool getwindowname "$w") | $(xdotool getwindowgeometry "$w" | tr '\n' ' ')"; done > "$OUT/windows.txt"
cat "$OUT/windows.txt"
kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
echo "err: $(grep -c 'err:' "$OUT/wine.log")"; grep -i ddraw "$OUT/wine.log" | head -5
