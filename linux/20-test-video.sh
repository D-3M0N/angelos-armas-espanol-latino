#!/bin/bash
# SPDX-License-Identifier: MIT
# D8 peldaño 1: la copia con subtitulos quemados (video-sub.sh) se reproduce por DirectShow en Wine hasta EC_COMPLETE.
# Requiere cache/video/op.mpg (extraido del juego del usuario).
set -eo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)"; . "$R/linux/lib-wine.sh"
C="$BUILD_CACHE"; W="$C/vidtest"; mkdir -p "$W"; cd "$W"; rm -f s.srt sub.mpg orig6.mpg
printf '1\n00:00:01,000 --> 00:00:04,000\nHola ¿qué? ñ\n' > s.srt
"$R/linux/video-sub.sh" "$C/video/op.mpg" s.srt sub.mpg 6
ffmpeg -v error -y -i "$C/video/op.mpg" -t 6 -c copy -f mpeg orig6.mpg
i686-w64-mingw32-gcc -O0 "$R/linux/tests/ds_t.c" -o t.exe -lole32 -lstrmiids -luuid
start_xvfb; trap stop_xvfb EXIT
for f in orig6.mpg sub.mpg; do echo "== $f"; timeout 90 wine t.exe "Z:${W//\//\\}\\$f" 20000 | tr -d '\r' | tee "o-$f.txt"; done
grep -q '^COMPLETE' o-orig6.mpg.txt && grep -q '^COMPLETE' o-sub.mpg.txt && echo "OK: video con subtitulos reproduce por DirectShow" || { echo FALLO; exit 1; }
