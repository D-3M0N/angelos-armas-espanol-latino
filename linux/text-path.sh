#!/bin/bash
# SPDX-License-Identifier: MIT
# Imprime el valor de AAFIX_TEXT_TSV para un idioma: "manual;automatica" (rutas Wine Z:\...), solo las que existen.
# Uso: AAFIX_TEXT_TSV="$(linux/text-path.sh es)" wine aalauncher.exe ...
set -e
L="$1"; [[ "$L" =~ ^(en|es)$ ]] || { echo "uso: $0 en|es" >&2; exit 2; }
R="$(cd "$(dirname "$0")/.." && pwd)"; . "$R/linux/lib-wine.sh" 2>/dev/null || true
C="${BUILD_CACHE:-$R/../cache}"
out=""
for f in "$R/translations/manual/$L.tsv" "$C/translations/$L.tsv" "$R/translations/$L.tsv"; do
  [ -f "$f" ] || continue
  w="Z:$(realpath "$f" | tr / '\\')"
  out="${out:+$out;}$w"
done
printf '%s\n' "$out"
