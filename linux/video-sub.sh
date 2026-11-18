#!/usr/bin/env bash
# D8 peldaño 1: copia local del video MPEG-1/MP2 con subtítulos quemados, mismo códec y contenedor.
# Uso: video-sub.sh entrada.mpg subs.(srt|ass) salida.mpg [segundos]   (salida en cache/, nunca en el repo)
set -euo pipefail
[ $# -ge 3 ] || { echo "uso: $0 entrada.mpg subs salida.mpg [segundos]" >&2; exit 2; }
in=$1 subs=$2 out=$3 dur=${4:-}
t=(); [ -n "$dur" ] && t=(-t "$dur")
# el filtro subtitles exige escapar \ : ' en la ruta
esc=${subs//\\/\\\\}; esc=${esc//:/\\:}; esc=${esc//\'/\\\'}
fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$in"); fps=${fps%,}
ffmpeg -v error -y -i "$in" "${t[@]}" -vf "subtitles='$esc'" \
  -c:v mpeg1video -r "$fps" -b:v 4000k -maxrate 6000k -bufsize 1835k -pix_fmt yuv420p \
  -c:a copy -f mpeg "$out"
