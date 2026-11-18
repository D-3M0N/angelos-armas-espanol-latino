#!/bin/bash
# SPDX-License-Identifier: MIT
# Instala el juego con D:\Setup.exe bajo Xvfb. D: -> $BUILD_CACHE/disc/merged (symlinks de ambos discos).
# Pasos de xdotool reconstruidos de la sesión manual (Enter x4, «No» al acceso directo, desmarcar casilla final).
# ESTADO: NO re-ejecutado de punta a punta (ver docs/PROGRESO.md); los títulos de ventana son japoneses.
. "$(dirname "$0")/lib-wine.sh"
start_xvfb || exit 1; trap stop_xvfb EXIT
cd "$BUILD_CACHE" || exit 1
# merged/ = symlinks de ambos discos (data1/2 del Install Disc y data3.cab/voice.npp del Game Disc)
mkdir -p "$BUILD_CACHE/disc/merged"
for d in inst game; do for f in "$BUILD_CACHE/disc/$d/x"/*; do ln -sfn "$f" "$BUILD_CACHE/disc/merged/"; done; done
set_cd "$BUILD_CACHE/disc/merged" TENSHI_INST
wine 'D:\Setup.exe' > setup.log 2>&1 & WP=$!
sleep 30
for _ in 1 2 3 4; do xdotool key Return; sleep 4; done   # bienvenida, licencia, carpeta, copia
sleep 120                                                   # copia de archivos (data1-3.cab)
xdotool key Tab Return; sleep 3                             # «No» al acceso directo (ajustar con captura si falla)
xdotool key space Tab Return; sleep 3                       # desmarcar casilla final y terminar
wait "$WP"; wineserver -w
# DEUDA (no automatizado): renombrar la carpeta a AngelosArmas, corregir system.reg (App Paths, Uninstall,
# Wow6432Node\NitroPlus), generar cache/manifest-install.json y chmod -R a-w. Se hizo a mano; ver PROGRESO.
echo "Revisar: la carpeta se crea con el nombre japonés si LC_ALL=ja_JP.UTF-8; si no, renombrar a AngelosArmas y corregir el registro."
