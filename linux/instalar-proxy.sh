#!/bin/bash
# SPDX-License-Identifier: MIT
# H2: instala aafix como proxy npmm.dll en la copia desechable cache/run (original -> npmm_real.dll). Idempotente.
R="$(cd "$(dirname "$0")/.." && pwd)"; C="$R/../cache"
cd "$C/run" || exit 1
[ -f npmm_real.dll ] || mv npmm.dll npmm_real.dll
cp "$C/build/npmm.dll" npmm.dll && echo "proxy instalado: $(sha256sum npmm.dll | cut -c1-12)"
