# shellcheck shell=bash
# Entorno común. Uso: source linux/lib-wine.sh  (requiere .env.local en la raíz del repo)
# SPDX-License-Identifier: MIT
# F-locale: LC_ALL (no solo LANG) o un LC_CTYPE heredado (p. ej. es_ES) fija ACP=1252.
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
set -a; . "$_here/.env.local"; set +a
export LC_ALL=ja_JP.UTF-8 LANG=ja_JP.UTF-8 WINEDEBUG="${WINEDEBUG:--all}" WINEDLLOVERRIDES=mscoree,mshtml=d
# Xvfb propio (xvfb-run no existe en este host); se limpia por PID, nunca con pkill.
start_xvfb() {
  # Elige un display libre; comprueba que Xvfb sigue vivo y que el socket es suyo.
  local n
  for n in $(seq 77 99); do
    [ -e "/tmp/.X11-unix/X$n" ] || [ -e "/tmp/.X$n-lock" ] && continue
    Xvfb ":$n" -screen 0 1024x768x24 >"$BUILD_CACHE/xvfb.log" 2>&1 & XVFB_PID=$!
    for _ in $(seq 20); do [ -e "/tmp/.X11-unix/X$n" ] && break; sleep 0.25; done
    if kill -0 "$XVFB_PID" 2>/dev/null && [ -e "/tmp/.X11-unix/X$n" ]; then export DISPLAY=":$n"; return 0; fi
  done
  echo "no se pudo arrancar Xvfb" >&2; return 1
}
stop_xvfb()  { [ -n "${XVFB_PID:-}" ] && kill "$XVFB_PID" 2>/dev/null; }
# CD virtual: D: -> directorio extraído del Game Disc + etiqueta (el juego pide TENSHI_GAME).
# set_cd DIR [ETIQUETA]: la etiqueta se escribe en DIR/.windows-label si DIR es escribible.
set_cd() {
  ln -sfn "$1" "$WINEPREFIX/dosdevices/d:"
  [ -n "${2:-}" ] && { printf '%s' "$2" > "$1/.windows-label" 2>/dev/null || echo "aviso: no pude escribir la etiqueta en $1" >&2; }
  return 0
}
