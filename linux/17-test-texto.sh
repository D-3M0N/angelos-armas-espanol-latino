#!/bin/bash
# SPDX-License-Identifier: MIT
# Prueba la sustitucion hash->texto de aafix con un exe sintetico con la misma firma que FUN_0042c7d0. Requiere build.sh.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)"; . "$R/linux/lib-wine.sh"
C="$BUILD_CACHE"; W="$C/texttest"; mkdir -p "$W"; cd "$W"; rm -f log tabla.tsv
i686-w64-mingw32-gcc -O0 "$R/linux/tests/msg_t.c" -o t.exe; cp "$C/build/aafix.dll" "$C/build/aalauncher.exe" .
start_xvfb; trap stop_xvfb EXIT
ADDR=$(wine t.exe x | tr -d '\r' | sed -n 's/^addr=0x\?//p')
echo "direccion de msg: $ADDR"
H=$(python3 -I -c 'h=0xcbf29ce484222325  # igual que extract-text.py
for b in bytes([0x82,0xA0,0x82,0xA2]): h=((h^b)*1099511628211)&(2**64-1)
print("%016x"%h)')
printf '%s\tHello \xc2\xbfQu\xc3\xa9? \xc3\xb1\n' "$H" > tabla.tsv
echo "sin tabla:"; AAFIX_LOG="Z:${W//\//\\}\\log" AAFIX_MSG_ADDR=$ADDR AAFIX_TRACE_TEXT=1 timeout 60 wine aalauncher.exe t.exe aafix.dll | tee o0.txt
printf '%s\tAUTO\n' "$H" > auto.tsv
echo "con tabla:"; AAFIX_LOG="Z:${W//\//\\}\\log" AAFIX_MSG_ADDR=$ADDR AAFIX_TEXT_TSV="Z:${W//\//\\}\\tabla.tsv" timeout 60 wine aalauncher.exe t.exe aafix.dll | tee o1.txt
echo "precedencia (manual;auto):"; AAFIX_LOG="Z:${W//\//\\}\\log" AAFIX_MSG_ADDR=$ADDR AAFIX_TEXT_TSV="Z:${W//\//\\}\\tabla.tsv;Z:${W//\//\\}\\auto.tsv" timeout 60 wine aalauncher.exe t.exe aafix.dll | tee o2.txt
echo "precedencia (auto;manual):"; AAFIX_LOG="Z:${W//\//\\}\\log" AAFIX_MSG_ADDR=$ADDR AAFIX_TEXT_TSV="Z:${W//\//\\}\\auto.tsv;Z:${W//\//\\}\\tabla.tsv" timeout 60 wine aalauncher.exe t.exe aafix.dll | tee o3.txt
grep -q '^a=48656C6C6F20F04E' o2.txt && grep -q '^a=4155544F' o3.txt || { echo "FALLO precedencia"; exit 1; }
grep -q '^a=82A082A2' o0.txt && grep -q '^a=48656C6C6F20F04E5175F0483F20F04D' o1.txt && grep -q '^b=sin traduccion' o1.txt && echo "OK: sustitucion por hash" || { echo FALLO; exit 1; }
