#!/usr/bin/env python3
"""Lectura mínima (solo lectura) del índice de contenedores .npp (magic 'nitP').
Uso: inspect-npp.py archivo.npp...   Solo imprime estadísticas, nunca nombres ni contenido."""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import struct, sys, os, zlib, collections

def lzss(src, n):
    """LZSS Okumura: anillo 4096, posición inicial 0xFEE, relleno 0, bit=1 literal, par (lo, hi): pos=lo|(hi&0xF0)<<4, long=(hi&15)+3."""
    ring = bytearray(4096); r = 0xFEE; out = bytearray(); i = 0
    while len(out) < n and i < len(src):
        fl = src[i]; i += 1
        for b in range(8):
            if len(out) >= n or i >= len(src): break
            if fl >> b & 1:
                c = src[i]; i += 1; out.append(c); ring[r] = c; r = (r + 1) & 4095
            else:
                if i + 1 >= len(src): break
                lo, hi = src[i], src[i+1]; i += 2
                pos = lo | ((hi & 0xF0) << 4)
                for k in range((hi & 15) + 3):
                    c = ring[(pos + k) & 4095]; out.append(c); ring[r] = c; r = (r + 1) & 4095
    return bytes(out[:n])

def check_lzss(path, ents):
    """Descomprime las entradas flag=1 en memoria; solo cuenta (no imprime contenido)."""
    full = img = imgok = 0
    with open(path, 'rb') as f:
        for (off, stored, orig, flag, junk, d, n) in ents:
            if flag != 1: continue
            f.seek(off); o = lzss(f.read(stored), orig)
            full += len(o) == orig
            e = n.lower()
            if e.endswith(b'.png') or e.endswith(b'.jpg'):
                img += 1
                imgok += o[:4] == b'\x89PNG' or o[:2] == b'\xff\xd8'
    return full, img, imgok

def parse(path):
    size = os.path.getsize(path)
    with open(path, 'rb') as f:
        magic, count = struct.unpack('<4sI', f.read(8))
        assert magic == b'nitP', magic
        ents = []
        for _ in range(count):
            b = f.read(0x90)
            off, stored, orig, flag, junk = struct.unpack('<IIIHH', b[:16])
            # b[12:14]=flag, b[14:16]=u16 antes del nombre de directorio (ver informe)
            d = b[16:16+0x40].split(b'\0')[0]
            n = b[16+0x40:].split(b'\0')[0]
            ents.append((off, stored, orig, flag, junk, d, n))
        data_start = 8 + count * 0x90
        # primer offset == data_start ?
        probes = {}
        for (off, stored, orig, flag, junk, d, n) in ents:
            if stored == 0: continue
            f.seek(off); h = f.read(4)
            probes.setdefault(flag, collections.Counter())[h[:2].hex() if flag else h.hex()] += 1
    return size, count, data_start, ents, probes

def main():
    for p in sys.argv[1:]:
        size, count, ds, ents, probes = parse(p)
        print(f'== {os.path.basename(p)}  {size} B  entradas={count}  fin_indice=0x{ds:x}')
        print('  primer offset == fin_indice:', ents[0][0] == ds if ents else None)
        end = max((e[0] + e[1] for e in ents), default=0)
        print('  max(off+tam) == tamaño archivo:', end == size, f'({end} vs {size})')
        contig = all(ents[i][0] + ents[i][1] == ents[i+1][0] for i in range(len(ents)-1))
        print('  entradas contiguas en orden:', contig)
        print('  flags:', dict(collections.Counter(e[3] for e in ents)))
        print('  tam==orig:', sum(1 for e in ents if e[1] == e[2]), ' tam!=orig:', sum(1 for e in ents if e[1] != e[2]))
        ext = collections.Counter(os.path.splitext(e[6].decode('cp932', 'replace'))[1].lower() for e in ents)
        print('  extensiones:', dict(ext.most_common(8)))
        dirs = collections.Counter(e[5].decode('cp932', 'replace') for e in ents)
        print('  directorios distintos:', len(dirs))
        if any(e[3] == 1 for e in ents):
            full, img, imgok = check_lzss(p, ents)
            print(f'  LZSS: {full}/{sum(1 for e in ents if e[3]==1)} al tamaño orig; imágenes con magic válido {imgok}/{img}')
        for fl, c in probes.items():
            print(f'  cabecera de datos (flag={fl}):', dict(c.most_common(6)))

if __name__ == "__main__":
    main()
