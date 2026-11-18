#!/bin/bash
# SPDX-License-Identifier: MIT
# Fase 1: cursor falso de aafix (hover determinista) + clic real XTEST de xdotool. CX,CY = cliente; WAIT espera inicial.
. "$(dirname "$0")/lib-wine.sh"
OUT="$BUILD_CACHE/f17/clic"; mkdir -p "$OUT"; rm -f "$OUT"/c-*.png; export WINEDEBUG="${WINEDEBUG:-err}"
CX="${CX:-188}"; CY="${CY:-517}"
start_xvfb || exit 1; trap stop_xvfb EXIT
set_cd "$BUILD_CACHE/disc/game/x" TENSHI_GAME
cd "$BUILD_CACHE/run" || exit 1
openbox >"$OUT/wm.log" 2>&1 & WMPID=$!; sleep 2
cp "$BUILD_CACHE/build/aafix.dll" "$BUILD_CACHE/build/aalauncher.exe" . 
env ${TRACE:+AAFIX_TRACE=1} AAFIX_FAKE="$CX,$CY,${FAKE_SEG:-99999}" AAFIX_LOG="$OUT/aafix.log" wine aalauncher.exe Z:\\home\\chimi\\aa_rebirth\\cache\\run\\nps.exe aafix.dll >"$OUT/wine.log" 2>&1 & WP=$!
sleep "${WAIT:-30}"
w=$(for w in $(xdotool search --onlyvisible --name .); do xdotool getwindowgeometry "$w" | grep -q 800x600 && echo "$w"; done | head -1)
[ -n "$w" ] || { echo "sin ventana 800x600" >&2; kill "$WMPID" "$WP" 2>/dev/null; wineserver -k; exit 1; }
echo "ventana=$w"; xdotool windowactivate "$w"; sleep 1
eval "$(xdotool getwindowgeometry --shell "$w")"; echo "X=$X Y=$Y"
# ESTABLE=1: esperar a que la pantalla cambie al menos 1 vez y luego quede igual 3 capturas (título cargado)
if [ -n "${ESTABLE:-}" ]; then
  prev=""; same=0; seen=""
  for i in $(seq 40); do
    import -window root "$OUT/c-st.png"; t=$(md5sum < "$OUT/c-st.png" | cut -c1-8)
    case " $seen " in *" $t "*) ;; *) seen="$seen $t";; esac
    if [ "$t" = "$prev" ]; then same=$((same+1)); else same=0; fi; prev=$t
    echo "estable $i $t same=$same distintos=$(echo $seen | wc -w)"
    [ "$same" -ge 3 ] && break
    sleep 3
  done
fi
import -window root "$OUT/c-00.png"; echo "00 reposo $(md5sum < "$OUT/c-00.png" | cut -c1-8)"
xdotool mousemove $((X+CX)) $((Y+CY)); sleep 2
import -window root "$OUT/c-01.png"; echo "01 hover $(md5sum < "$OUT/c-01.png" | cut -c1-8)"
for n in $(seq "${CLICKS:-1}"); do
  xdotool mousemove $((X+CX+n)) $((Y+CY)); sleep 0.3; xdotool mousemove $((X+CX)) $((Y+CY)); sleep 0.5
  xdotool mousedown 1; sleep "${HOLD:-0.3}"; xdotool mouseup 1; sleep 1.5
  # REINTENTA=1: parar en cuanto la captura difiera del hover
  if [ -n "${REINTENTA:-}" ]; then
    import -window root "$OUT/c-try.png"; t=$(md5sum < "$OUT/c-try.png" | cut -c1-8)
    echo "clic $n -> $t"; [ "$t" != "$(md5sum < "$OUT/c-01.png" | cut -c1-8)" ] && break
  fi
done; sleep "${STEP:-8}"
import -window root "$OUT/c-02.png"; echo "02 clic $(md5sum < "$OUT/c-02.png" | cut -c1-8)"
# CONT=n: si START activó, avanzar texto con n clics (cada CONT_SEG s) y capturar c-a<k>.png
if [ -n "${CONT:-}" ] && [ "$(md5sum < "$OUT/c-02.png" | cut -c1-8)" != "$(md5sum < "$OUT/c-00.png" | cut -c1-8)" ]; then
  rm -f "$OUT"/c-a*.png
  for k in $(seq "$CONT"); do
    xdotool mousemove $((X+400)) $((Y+300)); sleep 0.3; xdotool mousedown 1; sleep 0.15; xdotool mouseup 1; sleep "${CONT_SEG:-4}"
    import -window root "$OUT/c-a$k.png"; m=$(md5sum < "$OUT/c-a$k.png" | cut -c1-8); echo "a$k $m"
    # ESPACIO=1: si el clic no cambió la pantalla, pulsar Espacio (una vez) y recapturar
    if [ -n "${ESPACIO:-}" ] && [ "$m" = "${pm:-}" ]; then
      xdotool key space; sleep "${CONT_SEG:-4}"; import -window root "$OUT/c-a$k.png"; m=$(md5sum < "$OUT/c-a$k.png" | cut -c1-8); echo "a$k espacio $m (antes $pm)"
    fi
    # SERIE=1: tras 4 capturas iguales, 12 capturas cada ~0,3 s (¿el fundido se mueve?) y otra a los 30 s (una vez)
    if [ -n "${SERIE:-}" ] && [ "$m" = "${pm:-}" ] && [ "$((ig+1))" -ge 4 ] && [ -z "${serie_hecha:-}" ]; then
      serie_hecha=1; sr=""
      for j in $(seq 12); do import -window root "$OUT/c-s$j.png"; sr="$sr $(md5sum < "$OUT/c-s$j.png" | cut -c1-8)"; sleep 0.3; done
      echo "SERIE$sr"; sleep 30; import -window root "$OUT/c-s30.png"; echo "SERIE tras30s $(md5sum < "$OUT/c-s30.png" | cut -c1-8)"
    fi
    # SONDA=1: tras 6 capturas iguales, comprobar CPU del juego y probar teclas (una vez)
    if [ "$m" = "${pm:-}" ]; then ig=$((ig+1)); else ig=0; fi; pm=$m
    if [ -n "${SONDA:-}" ] && [ "$ig" -ge 6 ] && [ -z "${sonda_hecha:-}" ]; then
      sonda_hecha=1
      for q in /proc/[0-9]*; do [ "$(cat $q/comm 2>/dev/null)" = "nps.exe" ] && pid=${q#/proc/}; done
      t0=$(awk '{print $14+$15}' /proc/$pid/stat); sleep 5; t1=$(awk '{print $14+$15}' /proc/$pid/stat)
      echo "SONDA pid=${pid:-?} estado=$(ps -o stat= -p "$pid") hilos=$(ls /proc/$pid/task | wc -l) ticks_cpu_5s=$((t1-t0))"
      echo "SONDA foco=$(xdotool getwindowfocus 2>&1) ventana=$w raton=$(xdotool getmouselocation 2>&1)"
      for key in Return space ctrl; do
        [ "$key" = ctrl ] && { xdotool keydown ctrl; sleep 2; xdotool keyup ctrl; } || xdotool key "$key"
        sleep 3; import -window root "$OUT/c-k-$key.png"; echo "SONDA tecla $key $(md5sum < "$OUT/c-k-$key.png" | cut -c1-8) (antes $m)"
      done
    fi
  done
fi
kill "$WMPID"; kill "$WP" 2>/dev/null; wineserver -k; wait "$WP" 2>/dev/null
