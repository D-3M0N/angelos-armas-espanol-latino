#!/bin/bash
# SPDX-License-Identifier: MIT
# Lanza la copia desechable (cache/run) en Wine. Uso: jugar.sh [--captura SEG]
#  sin args: en tu pantalla (DISPLAY actual). --captura SEG: Xvfb propio, captura tras SEG s en cache/test/.
AA_SD="$(cd "$(dirname "$0")" && pwd)"
. "$AA_SD/lib-wine.sh"
# lib-wine fija WINEDEBUG=-all por defecto; LC_ALL=ja_JP.UTF-8 ya exportado
cap=""; [ "${1:-}" = "--captura" ] && cap="${2:-40}"
if [ -n "$cap" ]; then DISPLAY= ; start_xvfb || exit 1; trap stop_xvfb EXIT; fi
# Tabla de traducción: por defecto la export real (hash→ES). Sobrescribible: AAFIX_TEXT_TSV=Z:\ruta jugar.sh
if [ -z "${AAFIX_TEXT_TSV:-}" ] && [ -f "$BUILD_CACHE/test/real-es.tsv" ]; then
  AAFIX_TEXT_TSV="Z:$(realpath "$BUILD_CACHE/test/real-es.tsv" | tr / '\\')"
fi
# Interfaz Win32 (menu del clic derecho, ajustes, avisos): tabla hash->ES del repo (src/aafix/ui.c). Sobrescribible con AAFIX_UI_TSV.
[ -z "${AAFIX_UI_TSV:-}" ] && [ -f "$(dirname "$0")/../translations/ui-es.tsv" ] && AAFIX_UI_TSV="Z:$(realpath "$(dirname "$0")/../translations/ui-es.tsv" | tr / '\\')"
export AAFIX_UI_TSV
export AAFIX_TEXT_TSV AAFIX_LOG="$BUILD_CACHE/test/jugar-aafix.log"
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
mkdir -p "$BUILD_CACHE/test"; cd "$BUILD_CACHE/run" || exit 1
if [ -z "$cap" ]; then
  # Capturas ES automáticas de la ventana del juego (máx. 5, solo hashes seguros) en cache/test/capturas-es/. AA_CAP_MAX=0 las desactiva.
  W=""; if [ "${AA_CAP_MAX:-5}" != 0 ] && command -v xdotool >/dev/null && command -v import >/dev/null; then
    touch "$AAFIX_LOG"; export BUILD_CACHE; "$AA_SD/captura-es.sh" "$AAFIX_LOG" "$BUILD_CACHE/test/capturas-es" & W=$!
  fi
  trap '[ -n "$W" ] && { pkill -P "$W"; kill "$W"; } 2>/dev/null' EXIT
  wine nps.exe; exit $?
fi
wine nps.exe > "$BUILD_CACHE/test/jugar.log" 2>&1 & WP=$!
sleep "$cap"
import -window root "$BUILD_CACHE/test/titulo.png" 2>&1 | head -3
kill "$WP" 2>/dev/null; wineserver -k
ls -la "$BUILD_CACHE/test/titulo.png"; tail -n 5 "$BUILD_CACHE/test/jugar.log"
