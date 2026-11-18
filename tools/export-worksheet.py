#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""D12: genera la hoja de traducción (un .txt por entrada de script.npp) en un directorio de BUILD_CACHE (contiene japonés: NUNCA al repo).
Uso: export-worksheet.py <en|es|all> script.npp salida_dir [translations/manual]
Formato por línea:  @<hash>  /  # JA: <original>  /  EN: ...  /  ES: ...   (se precargan los valores ya guardados en manual/)."""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import sys, os, re, importlib.util
here = os.path.dirname(os.path.abspath(__file__))
def load(name, f):
    s = importlib.util.spec_from_file_location(name, os.path.join(here, f)); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
npp = load('npp', 'inspect-npp.py')
def fnv1a64(b):
    h = 0xcbf29ce484222325
    for c in b: h = ((h ^ c) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h
def box_texts(line):
    s = line.strip(b'\t \r')
    if not (s.startswith(b'<BOX') or s.startswith(b'<CHOICE')): return []
    return re.findall(rb'\bSRC\d?="([^"]*)"', s)
def readtab(p):
    d = {}
    if os.path.exists(p):
        for l in open(p, encoding='utf-8'):
            h, _, t = l.rstrip('\r\n').partition('\t')
            if t: d[h] = t
    return d
def main():
    lang, path, out = sys.argv[1], sys.argv[2], sys.argv[3]
    man = sys.argv[4] if len(sys.argv) > 4 else os.path.join(here, '..', 'translations', 'manual')
    if lang not in ('en', 'es', 'all'): sys.exit('idioma: en|es|all')
    langs = ['en', 'es'] if lang == 'all' else [lang]
    cur = {l: readtab(os.path.join(man, l + '.tsv')) for l in langs}
    os.makedirs(out, exist_ok=True)
    size, count, ds, ents, _ = npp.parse(path); seen = set(); nl = nf = 0
    with open(path, 'rb') as f:
        for ei, (off, st, orig, fl, j, d, n) in enumerate(ents):
            f.seek(off); raw = f.read(st)
            data = npp.lzss(raw, orig) if fl == 1 else raw
            blk = []
            for li, ln in enumerate(data.replace(b'\r\n', b'\n').split(b'\n')):
                for t in box_texts(ln):
                    if not any(c >= 0x80 for c in t): continue
                    h = '%016x' % fnv1a64(t)
                    if h in seen: continue
                    seen.add(h); nl += 1
                    blk.append('@%s  # línea %d\n# JA: %s\n' % (h, li, t.decode('cp932', 'replace')) +
                               ''.join('%s: %s\n' % (l.upper(), cur[l].get(h, '')) for l in langs))
            if blk:
                with open(os.path.join(out, 'e%04d.txt' % ei), 'w', encoding='utf-8') as o:
                    o.write('# entrada %d\n\n' % ei + '\n'.join(blk)); nf += 1
    print('hoja: %d líneas únicas en %d archivos' % (nl, nf))
main()
