#!/bin/bash
# SPDX-License-Identifier: MIT
# Prueba el registro virtual de aafix con un exe sintético: sin aafix se lee la clave del instalador; con aafix se abre desde HKCU\Software\AngelosArmasRebirth.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"; . "$R/linux/lib-wine.sh"
C="$BUILD_CACHE"; W="$C/regtest"; mkdir -p "$W"; cd "$W"; rm -f log
i686-w64-mingw32-gcc "$R/linux/tests/reg_t.c" -o t.exe; cp "$C/build/aafix.dll" "$C/build/aalauncher.exe" .
start_xvfb; trap stop_xvfb EXIT
echo "sin aafix:"; timeout 60 wine t.exe
# estado limpio: sin claves previas, el hook debe sembrar execute y escribir vol en esta ejecucion
wine reg delete 'HKCU\Software\AngelosArmasRebirth' /f >/dev/null 2>&1 || true
wine reg delete 'HKCU\Software\NitroPlus' /f >/dev/null 2>&1 || true
echo "con aafix:"; AAFIX_LOG="Z:${W//\//\\}\\log" timeout 60 wine aalauncher.exe t.exe aafix.dll | tee out.txt
grep -q 'execute=Z:.*regtest\\nps.exe' out.txt || { echo "FALLO: execute no sembrado"; exit 1; }
wine reg query 'HKCU\Software\AngelosArmasRebirth\NitroPlus\AngelosArmas' /v vol 2>&1 | tee vol.txt
! wine reg query 'HKCU\Software\NitroPlus\AngelosArmas' /v vol >/dev/null 2>&1 || { echo "FALLO: vol escrito en la clave real"; exit 1; }
grep -qE 'vol +REG_SZ +7' vol.txt || { echo "FALLO: vol=7 no esta en la clave virtual"; exit 1; }
echo "OK: registro virtual"
