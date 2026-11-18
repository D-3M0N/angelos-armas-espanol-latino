#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Valida una tabla hash<TAB>texto (D3) como la carga aafix (tab_load): hash de 16 hex, existente en index.tsv,
# texto mapeable a cp932 (+ letras latinas -> zona de usuario, D11), <= 511 B. Uso: validate-table.py tabla.tsv [index.tsv]
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import sys, re
LATIN = ("ÁÉÍÓÚÜÑáéíóúüñ¿¡«»ÀÈÌÒÙàèìòùÂÊÎÔÛâêîôûÇçÄËÏÖäëïöß")  # igual que LATIN en aafix.c
def enc(t):
    t = "".join(chr(0xE000 + LATIN.index(c)) if c in LATIN else c for c in t)
    return t.encode("cp932")
def main(tab, idx):
    known = {l.split("\t")[0] for l in open(idx, encoding="ascii")} if idx else None
    err = 0; seen = set(); n = 0
    for no, l in enumerate(open(tab, encoding="utf-8"), 1):
        l = l.rstrip("\r\n")
        if not l or l.startswith("#"): continue
        h, _, t = l.partition("\t")
        if not re.fullmatch(r"[0-9a-f]{16}", h) or not t:
            print(f"{no}: formato (hash de 16 hex + TAB + texto)"); err += 1; continue
        if h in seen: print(f"{no}: hash duplicado {h}"); err += 1
        seen.add(h); n += 1
        if known is not None and h not in known: print(f"{no}: hash {h} no esta en el indice"); err += 1
        try: b = enc(t)
        except UnicodeEncodeError as e: print(f"{no}: caracter no mapeable {t[e.start]!r}"); err += 1; continue
        if len(b) > 511: print(f"{no}: {len(b)} B > 511"); err += 1
    print(f"{n} entradas, {err} errores"); return 1 if err else 0
if __name__ == "__main__": sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
