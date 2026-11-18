#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Compara el sha256 de todos los blobs del historial con los manifiestos de GAME_DIR e INSTALL_DIR
# y pasa gitleaks. Salida ≠ 0 si encuentra algo. Uso: check-no-game-data.sh [--staged]
set -euo pipefail
[ "${1:-}" = "--help" ] && { echo "Uso: $0 [--staged]  (--staged: solo el índice, para el hook)"; exit 0; }
cd "$(dirname "${BASH_SOURCE[0]}")/.."
[ -f .env.local ] && { set -a; . ./.env.local; set +a; }
BUILD_CACHE="${BUILD_CACHE:?falta BUILD_CACHE (.env.local)}"
bad=0
hashes=$(jq -r '.[].sha256' "$BUILD_CACHE"/manifest-game.json "$BUILD_CACHE"/manifest-install.json | sort -u)
[ -n "$hashes" ] || { echo "manifiestos vacíos o ausentes" >&2; exit 2; }
if [ "${1:-}" = "--staged" ]; then
  list=$(git diff --cached --name-only --diff-filter=AM -z | xargs -0 -r -I{} git rev-parse ":{}" 2>/dev/null || true)
else
  list=$(git rev-list --objects --all 2>/dev/null | cut -d' ' -f1 | git cat-file --batch-check='%(objecttype) %(objectname)' | awk '$1=="blob"{print $2}')
fi
for b in $list; do
  h=$(git cat-file blob "$b" | sha256sum | cut -d' ' -f1)
  if grep -qx "$h" <<<"$hashes"; then echo "COINCIDE con archivo del juego: blob $b" >&2; bad=1; fi
done
if command -v gitleaks >/dev/null; then
  if [ "${1:-}" = "--staged" ]; then gitleaks git --staged --no-banner --log-level error || bad=1
  else gitleaks git --no-banner --log-level error . || bad=1; fi
else echo "gitleaks no instalado" >&2; bad=1; fi
[ $bad -eq 0 ] && echo "OK: sin datos del juego ni secretos"
exit $bad
