#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""D12: lee la hoja (export-worksheet.py), valida y guarda SOLO lo que cambió en manual/{en,es}.tsv.
Uso: import-worksheet.py hoja_dir [manual_dir] [index.tsv]    Valida con las reglas de validate-table.py (cp932+LATIN, <=511 B, sin TAB/CR/LF),
indica archivo:línea y no escribe nada si hay algún error. Hash fuera del índice (si se da) = error."""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import sys, os, re, glob, importlib.util
here = os.path.dirname(os.path.abspath(__file__))
s = importlib.util.spec_from_file_location('vt', os.path.join(here, 'validate-table.py')); vt = importlib.util.module_from_spec(s); s.loader.exec_module(vt)
def main():
    hoja = sys.argv[1]
    man = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, '..', 'translations', 'manual')
    known = {l.split('\t')[0] for l in open(sys.argv[3], encoding='ascii')} if len(sys.argv) > 3 else None
    cur = {}
    for l in ('en', 'es'):
        cur[l] = {}; p = os.path.join(man, l + '.tsv')
        if os.path.exists(p):
            for ln in open(p, encoding='utf-8'):
                h, _, t = ln.rstrip('\r\n').partition('\t')
                if t: cur[l][h] = t
    new = {'en': {}, 'es': {}}; err = 0; h = None
    for fn in sorted(glob.glob(os.path.join(hoja, '*.txt'))):
        for no, ln in enumerate(open(fn, encoding='utf-8'), 1):
            ln = ln.rstrip('\r\n'); where = '%s:%d' % (os.path.basename(fn), no)
            m = re.match(r'@([0-9a-f]{16})(\s|$)', ln)
            if m:
                h = m.group(1)
                if known is not None and h not in known: print(where, 'hash fuera del índice'); err += 1; h = None
                continue
            m = re.match(r'(EN|ES):\s?(.*)$', ln)
            if not m: continue
            if h is None: print(where, 'campo sin @hash'); err += 1; continue
            l, t = m.group(1).lower(), m.group(2).strip()
            if not t or cur[l].get(h) == t: continue
            if '\t' in t: print(where, 'TAB en el texto'); err += 1; continue
            try: b = vt.enc(t)
            except UnicodeEncodeError as e: print(where, 'carácter no mapeable %r' % t[e.start]); err += 1; continue
            if len(b) > 511: print(where, '%d B > 511' % len(b)); err += 1; continue
            new[l][h] = t
    if err: print('%d errores: no se guardó nada' % err); return 1
    os.makedirs(man, exist_ok=True)
    for l in ('en', 'es'):
        if not new[l]: continue
        cur[l].update(new[l])
        with open(os.path.join(man, l + '.tsv'), 'w', encoding='utf-8') as o:
            for k in sorted(cur[l]): o.write('%s\t%s\n' % (k, cur[l][k]))
    print('guardado: en %d, es %d cambios' % (len(new['en']), len(new['es']))); return 0
sys.exit(main())
