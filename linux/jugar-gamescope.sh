#!/bin/bash
# SPDX-License-Identifier: MIT
# Lanza la copia desechable (cache/run) dentro de gamescope: el juego sigue en 800x600 y gamescope lo escala a tu monitor
# conservando 4:3 (el escalado de pantalla completa de Wine no existe: WineHQ bug 39768).
# Uso: jugar-gamescope.sh            (pantalla completa, escalado "fit", filtro lineal)
#      GS_SCALER=integer GS_FILTER=nearest jugar-gamescope.sh   (píxel perfecto: 800x600 x2 o x3, con bordes negros)
#      GS_FILTER=fsr jugar-gamescope.sh                          (más nítido que lineal)
#      GS_WINDOW=1 jugar-gamescope.sh                            (ventana en vez de pantalla completa)
# Dentro del juego NO uses la tecla F (pantalla completa de Wine): gamescope ya hace el trabajo.
# Sin probar en pantalla real (pendiente del usuario).
. "$(dirname "$0")/lib-wine.sh"
command -v gamescope >/dev/null || { echo "falta gamescope (zypper in gamescope)" >&2; exit 1; }
# Resolución del monitor: GS_W/GS_H, o la del modo activo de xrandr.
W="${GS_W:-}"; H="${GS_H:-}"
if [ -z "$W" ] || [ -z "$H" ]; then
  read -r W H < <(xrandr 2>/dev/null | awk '/\*/ {split($1,a,"x"); print a[1], a[2]; exit}')
fi
W="${W:-1920}"; H="${H:-1080}"
# Misma tabla de texto e interfaz que jugar.sh
if [ -z "${AAFIX_TEXT_TSV:-}" ] && [ -f "$BUILD_CACHE/test/real-es.tsv" ]; then
  AAFIX_TEXT_TSV="Z:$(realpath "$BUILD_CACHE/test/real-es.tsv" | tr / '\\')"
fi
# shellcheck disable=SC2154  # _here lo define lib-wine.sh
if [ -z "${AAFIX_UI_TSV:-}" ] && [ -f "$_here/translations/ui-es.tsv" ]; then
  AAFIX_UI_TSV="Z:$(realpath "$_here/translations/ui-es.tsv" | tr / '\\')"
fi
export AAFIX_TEXT_TSV AAFIX_UI_TSV AAFIX_LOG="$BUILD_CACHE/test/jugar-aafix.log"
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
mkdir -p "$BUILD_CACHE/test"; cd "$BUILD_CACHE/run" || exit 1
mode=(-f); [ -n "${GS_WINDOW:-}" ] && mode=()
be=(); [ -n "${GS_BACKEND:-}" ] && be=(--backend "$GS_BACKEND")   # pruebas: GS_BACKEND=headless
exec gamescope "${be[@]}" -w 800 -h 600 -W "$W" -H "$H" "${mode[@]}" \
  -S "${GS_SCALER:-fit}" -F "${GS_FILTER:-linear}" -- wine nps.exe
