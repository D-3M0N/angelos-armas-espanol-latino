#!/bin/bash
# SPDX-License-Identifier: MIT
# Arranca el juego sin aafix desde una copia desechable (symlinks) en cache/run, con el Game Disc como D:.
# Comprueba: NPMM.dll cargada y que ninguna ventana sea el diálogo «inserte disco». Sin captura de pantalla
# no demuestra que se vea el título: solo "arrancó y no pidió el disco".
. "$(dirname "$0")/lib-wine.sh"
export WINEDEBUG=err+all,+loaddll
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
mkdir -p "$BUILD_CACHE/run"; cd "$BUILD_CACHE/run" || exit 1
for f in "$INSTALL_DIR"/*; do ln -sf "$f" .; done
wine nps.exe > ../run.log 2>&1 & WP=$!
sleep 25
echo "ventanas (clase | nombre | geometría); #32770 = diálogo estándar (MessageBox):"
for w in $(xdotool search --name "." 2>/dev/null); do
  echo "$(xdotool getwindowclassname "$w" 2>/dev/null) | $(xdotool getwindowname "$w") | $(xdotool getwindowgeometry "$w" | tr '\n' ' ')"
done
grep -qi 'npmm' ../run.log && echo "OK: NPMM.dll cargada" || echo "FALLO: sin NPMM.dll en el log"
grep -c 'err:' ../run.log
import -window root "$BUILD_CACHE/run-check.png" 2>/dev/null
kill "$WP" 2>/dev/null; wineserver -k
