#!/bin/bash
# SPDX-License-Identifier: MIT
# Parche oficial 1.1.200. Modos:
#   03-patch.sh --verify   solo compara sha256 de INSTALL_DIR con lo extraído del parche (cache/patchx/, 7z x).
#   03-patch.sh            ejecuta el parche (GUI) — aborta si ya existe cache/manifest-install.json (INSTALL_DIR es a-w).
# ESTADO: el paso GUI se hizo a mano apuntando a la carpeta de instalación; el Enter ciego no está probado.
. "$(dirname "$0")/lib-wine.sh"
verify() {
  local f a b rc=0
  for f in nps.exe NPMM.dll script.npp update.npp; do
    if [ ! -f "$BUILD_CACHE/patchx/$f" ] || [ ! -f "$INSTALL_DIR/${f,,}" ]; then echo "FALTA $f"; rc=1; continue; fi
    a=$(sha256sum "$BUILD_CACHE/patchx/$f" | cut -d' ' -f1); b=$(sha256sum "$INSTALL_DIR/${f,,}" | cut -d' ' -f1)
    if [ -n "$a" ] && [ "$a" = "$b" ]; then echo "OK $f"; else echo "DIFIERE $f"; rc=1; fi
  done
  return $rc
}
[ "${1:-}" = "--verify" ] && { verify; exit; }
[ -e "$BUILD_CACHE/manifest-install.json" ] && { echo "INSTALL_DIR ya tiene manifiesto (solo lectura): usa --verify" >&2; exit 1; }
start_xvfb || exit 1; trap stop_xvfb EXIT
cd "$BUILD_CACHE" || exit 1
wine "$GAME_DIR/tenshi_1.1.200.exe" > patch.log 2>&1 & WP=$!
sleep 20; xdotool key Return; sleep 5   # primer diálogo; la ruta de destino debe ser $INSTALL_DIR en notación Windows
wait "$WP"; wineserver -w
verify
