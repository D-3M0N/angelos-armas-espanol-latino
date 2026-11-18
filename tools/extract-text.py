#!/usr/bin/env python3
"""Fase 2: indexa el texto visible (atributo SRC de <BOX>/<CHOICE>) de script.npp por hash FNV-1a 64 (D3/D10).
Uso: extract-text.py script.npp salida_dir     (salida_dir va en cache/, NUNCA al repo)
Escribe index.tsv (hash, entrada, línea, bytes) y plantilla.tsv (hash<TAB>) sin texto JP. Imprime solo conteos."""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import sys, os, re, collections, importlib.util
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('npp', os.path.join(here, 'inspect-npp.py'))
npp = importlib.util.module_from_spec(spec); spec.loader.exec_module(npp)

def fnv1a64(b):
    h = 0xcbf29ce484222325
    for c in b: h = ((h ^ c) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF
    return h

def box_texts(line):
    """Textos visibles de una línea: atributo SRC de <BOX> y SRC1..3 de <CHOICE> (el texto va en el atributo)."""
    s = line.strip(b'\t \r')
    if not s.startswith((b'<BOX', b'<CHOICE', b'<TEXT ')): return []  # <TEXT>: prólogo 1-0cut01_11 (traza s723)
    return [m for m in re.findall(rb'\bSRC\d?="([^"]*)"', s)]

def speaker(line):
    """Hablante aproximado: prefijo alfabetico de TARGET sin 'v_' (sin verificar)."""
    m = re.search(rb'TARGET="(?:v_)?([A-Za-z]+)', line)
    return m.group(1).decode() if m else ''

def main():
    path, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    size, count, ds, ents, _ = npp.parse(path)
    seen = collections.defaultdict(set); rows = []; total = 0; jl = {}
    with open(path, 'rb') as f:
        for ei, (off, st, orig, fl, j, d, n) in enumerate(ents):
            f.seek(off); raw = f.read(st)
            data = npp.lzss(raw, orig) if fl == 1 else raw
            for li, ln in enumerate(data.replace(b'\r\n', b'\n').split(b'\n')):
                for t in box_texts(ln):
                    if not any(c >= 0x80 for c in t): continue
                    total += 1; h = fnv1a64(t); jl.setdefault(h, (n, speaker(ln), t)); seen[h].add(t); rows.append((h, ei, li, len(t)))
    import json
    with open(os.path.join(out, 'lines.jsonl'), 'w', encoding='utf-8') as o:   # entrada de fase 4; NUNCA a git
        for h, (sc, sp, t) in jl.items():
            o.write(json.dumps({'id': '%016x' % h, 'scene': sc.decode('ascii', 'replace') if isinstance(sc, bytes) else str(sc), 'speaker': sp, 'text': t.decode('cp932', 'replace')}, ensure_ascii=False) + '\n')
    coll = sum(1 for v in seen.values() if len(v) > 1)
    with open(os.path.join(out, 'index.tsv'), 'w', encoding='utf-8', newline='\n') as o:
        for h, ei, li, n in rows: o.write('%016x\t%d\t%d\t%d\n' % (h, ei, li, n))
    with open(os.path.join(out, 'plantilla.tsv'), 'w', encoding='utf-8', newline='\n') as o:
        for h in sorted(seen): o.write('%016x\t\n' % h)
    print('líneas BOX con JP', total, 'hashes únicos', len(seen), 'colisiones (mismo hash, texto distinto)', coll)
    print('bytes únicos', sum(len(next(iter(v))) for v in seen.values()))
main()
