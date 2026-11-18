#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Uso: make-manifest.sh DIR SALIDA.json  — sha256+tamaño por archivo (solo lectura sobre DIR).
set -euo pipefail
[ "${1:-}" = "--help" ] || [ $# -ne 2 ] && { echo "Uso: $0 DIR SALIDA.json"; exit 0; }
cd "$1"
find . -type f -print0 | sort -z | while IFS= read -r -d '' f; do
  printf '%s\t%s\t%s\n' "${f#./}" "$(stat -c %s "$f")" "$(sha256sum "$f" | cut -d' ' -f1)"
done | jq -Rn '[inputs|split("\t")|{(.[0]):{size:(.[1]|tonumber),sha256:.[2]}}]|add' >"$2"
