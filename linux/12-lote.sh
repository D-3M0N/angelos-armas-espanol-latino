#!/bin/bash
# SPDX-License-Identifier: MIT
# Fase 1: repite 11-clic-real.sh (juego reiniciado) hasta que la captura tras el clic difiera del reposo. MAX = intentos.
d="$(dirname "$0")"; LOG="${BUILD_CACHE:-$d/../../cache}/f17/lote.log"; mkdir -p "$(dirname "$LOG")"; : >"$LOG"
for i in $(seq "${MAX:-8}"); do
  CONT="${CONT:-}" ESTABLE=1 CLICKS=2 HOLD=0.15 WAIT=30 "$d/11-clic-real.sh" >"$LOG.$i" 2>&1
  r=$(sed -n 's/^00 reposo //p' "$LOG.$i"); c=$(sed -n 's/^02 clic //p' "$LOG.$i")
  echo "intento $i reposo=$r clic=$c" | tee -a "$LOG"
  [ -n "$c" ] && [ "$r" != "$c" ] && { echo "ÉXITO en intento $i (captura en f17/clic/c-02.png)"; exit 0; }
done; echo "sin éxito"; exit 1
