#!/usr/bin/env python3
"""B.8: estructura estadística del script (script.npp). Solo lectura; imprime solo conteos y
tokens ASCII, nunca texto japonés. Uso: inspect-script.py script.npp"""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import sys, collections, importlib.util, os
spec = importlib.util.spec_from_file_location('npp', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'inspect-npp.py'))
npp = importlib.util.module_from_spec(spec); spec.loader.exec_module(npp)

path = sys.argv[1]
size, count, ds, ents, _ = npp.parse(path)
first = collections.Counter(); lens = []; nl = 0; tot = 0; jp_lines = 0; asc_lines = 0
sjis_lead = collections.Counter(); ctrl = collections.Counter(); tokens = collections.Counter()
crlf = lf = 0; maxlen = 0; mixed = 0
with open(path, 'rb') as f:
    for (off, stored, orig, flag, junk, d, n) in ents:
        f.seek(off); raw = f.read(stored)
        data = npp.lzss(raw, orig) if flag == 1 else raw
        crlf += data.count(b'\r\n'); lf += data.count(b'\n') - data.count(b'\r\n')
        for line in data.replace(b'\r\n', b'\n').split(b'\n'):
            if not line: continue
            nl += 1; tot += len(line); maxlen = max(maxlen, len(line))
            hi = any(c >= 0x80 for c in line)
            if hi: jp_lines += 1
            else: asc_lines += 1
            first[chr(line[0]) if line[0] < 0x80 and line[0] >= 0x20 else ('JP' if line[0] >= 0x80 else 'ctl%02x' % line[0])] += 1
            if not hi and line.split():
                tokens[line.split()[0][:12].decode('ascii', 'replace')] += 1
            for c in line:
                if c < 0x20 and c != 9: ctrl[c] += 1
print('entradas', count, 'líneas no vacías', nl, 'bytes', tot, 'máx línea', maxlen, 'CRLF', crlf, 'LF solos', lf)
print('líneas con bytes altos', jp_lines, 'solo ASCII', asc_lines)
print('primer carácter (top 25):', first.most_common(25))
print('primer token ASCII (top 40):', tokens.most_common(40))
print('bytes de control:', dict(ctrl))

# Dónde está el texto: prefijo ASCII (hasta el primer byte alto) de las líneas con JP, sin el JP.
import re
pre = collections.Counter(); attrs = collections.Counter(); unterminated = 0
with open(path, 'rb') as f:
    for (off, stored, orig, flag, junk, d, n) in ents:
        f.seek(off); raw = f.read(stored)
        data = npp.lzss(raw, orig) if flag == 1 else raw
        for line in data.replace(b'\r\n', b'\n').split(b'\n'):
            if not any(c >= 0x80 for c in line): continue
            s = line.strip(b'\t ')
            k = next(i for i, c in enumerate(s) if c >= 0x80)
            p = s[:k].decode('ascii', 'replace')
            pre[re.sub(r'"[^"]*"', '"…"', p)[:50]] += 1
            for m in re.findall(rb'(\w+)=', s): attrs[m.decode()] += 1
print('prefijos ASCII de líneas con JP (top 25):', pre.most_common(25))
print('atributos (top 30):', attrs.most_common(30))

# Muestras enmascaradas (cada racha de bytes altos -> «J{n}»), sin texto original.
if len(sys.argv) > 2:
    shown = collections.Counter(); k = int(sys.argv[2])
    with open(path, 'rb') as f:
        for (off, stored, orig, flag, junk, d, n) in ents[:40]:
            f.seek(off); raw = f.read(stored)
            data = npp.lzss(raw, orig) if flag == 1 else raw
            for line in data.replace(b'\r\n', b'\n').split(b'\n'):
                if not any(c >= 0x80 for c in line): continue
                m = re.sub(rb'[\x80-\xff]+', lambda x: b'J%d' % len(x.group()), line.strip(b'\t '))
                m = re.sub(rb'(SRC\d?|HREF)="[^"]*"', rb'\1="-"', m).decode('ascii', 'replace')
                key = m.split()[0]
                if shown[key] < k and ('BOX' in key or 'TEXT' in key): shown[key] += 1; print(m[:200])
