#!/bin/bash
# SPDX-License-Identifier: MIT
# Vigila AAFIX_LOG y captura SOLO la ventana del juego cuando aparece un SUBST de un hash «seguro»
# (traducible, escena no sexual, no excluida, fuera de 1-6cut). Máx. AA_CAP_MAX (5). Nombre: es-<hash>.png.
# Uso: captura-es.sh LOG DIR_SALIDA   (lo lanza jugar.sh en segundo plano)
log="$1"; out="$2"; max="${AA_CAP_MAX:-5}"; cls="${AA_CAP_CLS:-$BUILD_CACHE/text/lines.cls.jsonl}"
safe="$out/captura-safe.txt"; mkdir -p "$out"
python3 - "$cls" "$BUILD_CACHE/text/excluded-scenes.txt" > "$safe" <<'P' || exit 0
import json, sys, os
exc = set()
if os.path.exists(sys.argv[2]): exc = {l.strip() for l in open(sys.argv[2]) if l.strip()}
for l in open(sys.argv[1]):
    r = json.loads(l); sc = r.get("scene") or ""
    if r.get("cat") == "traducible" and r.get("escena_sexual") is False and sc not in exc and "1-6cut" not in sc:
        print(r["id"])
P
n=0; last=0
tail -F -n0 "$log" 2>/dev/null | while read -r a b _; do
  [ "$a" = SUBST ] || continue
  h="${b#hash=}"; [ -f "$out/es-$h.png" ] && continue
  grep -qx "$h" "$safe" || continue
  now=$(date +%s); [ $((now - last)) -ge "${AA_CAP_GAP:-60}" ] || continue
  sleep 1  # deja que el texto se dibuje
  w=$(xdotool search --onlyvisible --name 'Angelos Armas' 2>/dev/null | head -1)
  [ -z "$w" ] && w=$(xdotool search --onlyvisible --name '天使ノ二挺拳銃' 2>/dev/null | head -1)
  [ -z "$w" ] && continue
  import -window "$w" "$out/es-$h.png" 2>/dev/null && { n=$((n+1)); last=$now; echo "captura $n/$max: es-$h.png"; }
  [ "$n" -ge "$max" ] && break
done
