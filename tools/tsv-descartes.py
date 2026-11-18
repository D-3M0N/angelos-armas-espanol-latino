#!/usr/bin/env python3
"""Replica tab_load (src/aafix/aafix.c) y lista los ids que el cargador descarta.
Uso: tsv-descartes.py TSV  -> imprime id, motivo, bytes (sin texto: puede ser JP).
OJO: más estricto que Wine: cp932 de Python no hace best-fit; Wine sí (p. ej. Ú en <RUBY text=...> carga
degradado). Lo que cuenta en Wine es el log "tabla: N textos (descartados: ...)"."""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import sys
LATIN = ("ÁÉÍÓÚÜÑáéíóúüñ¿¡«»"
         "ÀÈÌÒÙàèìòùÂÊÎÔÛâêîôû"
         "ÇçÄËÏÖäëïöß,.")
def pua(s):
    out, tag = [], False
    for c in s:
        if c == "<": tag = True
        elif c == ">": tag = False
        i = LATIN.find(c) if not tag else -1
        out.append(chr(0xE000 + i) if i >= 0 else c)
    return "".join(out)
ok = bad = 0
for n, raw in enumerate(open(sys.argv[1], "rb"), 1):
    line = raw.rstrip(b"\r\n")
    if len(line) >= 4095: print(f"L{n}\tlinea>4095B (fgets la parte)"); bad += 1; continue
    tab = line.find(b"\t")
    if tab != 16 or len(line) == 17: print(f"L{n}\tformato (tab en {tab})"); bad += 1; continue
    hid = line[:16].decode("ascii", "replace")
    try: w = line[17:].decode("utf-8")
    except UnicodeDecodeError: print(f"{hid}\tutf8-invalido"); bad += 1; continue
    if len(w) + 1 > 2048: print(f"{hid}\t>2048 WCHAR"); bad += 1; continue
    try: m = len(pua(w).encode("cp932")) + 1
    except UnicodeEncodeError as e: print(f"{hid}\tno-cp932 U+{ord(w[e.start]):04X}"); bad += 1; continue
    if m > 600: print(f"{hid}\t>600B (buffer; cuenta como no-cp932) {m}B"); bad += 1; continue
    if m > 512: print(f"{hid}\t>512B {m}B"); bad += 1; continue
    ok += 1
print(f"cargadas {ok} · descartadas {bad}", file=sys.stderr)
