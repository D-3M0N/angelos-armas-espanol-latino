#!/usr/bin/env python3
"""Inspección PE de solo lectura (stdlib). Uso: python3 -I inspect-pe.py archivo..."""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import os, struct, sys, re, hashlib

PROT = [b"SafeDisc", b"SECUROM", b"SecuROM", b"StarForce", b"protect.dll", b"Macrovision",
        b"LaserLok", b"UPX0", b"UPX!", b"ASPack", b"Themida", b"VMProtect", b"Armadillo",
        b"ExeCryptor", b"PECompact", b".vmp", b"Enigma", b"CDCheck", b"GetDriveTypeA",
        b"GetDriveTypeW", b"GetVolumeInformation"]

def rva2off(secs, rva):
    for n, vs, va, rs, ro in secs:
        if va <= rva < va + max(vs, rs):
            return rva - va + ro
    return None

def cstr(d, o):
    e = d.index(b"\0", o)
    return d[o:e].decode("latin1")

def main(p):
    d = open(p, "rb").read()
    print(f"## {os.path.basename(p)}  ({len(d)} B, sha256 {hashlib.sha256(d).hexdigest()[:16]}…)")
    pe = struct.unpack_from("<I", d, 0x3c)[0]
    assert d[pe:pe+4] == b"PE\0\0"
    mach, nsec, ts, _, _, osz, chars = struct.unpack_from("<HHIIIHH", d, pe+4)
    oh = pe + 24
    magic = struct.unpack_from("<H", d, oh)[0]
    pe32p = magic == 0x20b
    maj, mnr = d[oh+2], d[oh+3]
    ep = struct.unpack_from("<I", d, oh+16)[0]
    ib = struct.unpack_from("<Q" if pe32p else "<I", d, oh+24 if pe32p else oh+28)[0]
    subsys = struct.unpack_from("<H", d, oh+68)[0]
    dd = oh + (112 if pe32p else 96)
    dirs = [struct.unpack_from("<II", d, dd+8*i) for i in range(16)]
    import datetime
    print(f"- formato: {'PE32+' if pe32p else 'PE32'}, machine 0x{mach:x}, linker {maj}.{mnr}, "
          f"timestamp {datetime.datetime.fromtimestamp(ts, datetime.UTC):%Y-%m-%d}, DLL={bool(chars&0x2000)}, "
          f"subsystem {subsys}, entry RVA 0x{ep:x}, imagebase 0x{ib:x}")
    so = oh + osz
    secs = []
    print("- secciones (nombre, vsize, rsize, entropía):")
    import math
    for i in range(nsec):
        n, vs, va, rs, ro = struct.unpack_from("<8sIIII", d, so+40*i)
        n = n.rstrip(b"\0").decode("latin1")
        blk = d[ro:ro+rs]
        ent = 0.0
        if blk:
            c = [0]*256
            for b in blk: c[b] += 1
            ent = -sum(x/len(blk)*math.log2(x/len(blk)) for x in c if x)
        secs.append((n, vs, va, rs, ro))
        print(f"  - {n}: v={vs} r={rs} H={ent:.2f}")
    # imports
    ro_ = dirs[1][0]
    imps = {}
    if ro_:
        o = rva2off(secs, ro_)
        while True:
            oft, _, _, nm, ft = struct.unpack_from("<IIIII", d, o)
            if not nm: break
            dll = cstr(d, rva2off(secs, nm))
            t = rva2off(secs, oft or ft); fn = []
            while True:
                v = struct.unpack_from("<I", d, t)[0]
                if not v: break
                fn.append(f"#{v&0xffff}" if v & 0x80000000 else cstr(d, rva2off(secs, v)+2))
                t += 4
            imps[dll] = fn; o += 20
    print("- imports por DLL:")
    for k, v in imps.items():
        print(f"  - {k} ({len(v)})" + (": " + ", ".join(v) if len(v) <= 12 else ""))
    keys = ("timeGetTime","timeBeginPeriod","GetTickCount","QueryPerformanceCounter","Sleep",
            "RegOpenKeyExA","RegQueryValueExA","RegCreateKeyExA","RegSetValueExA","RegOpenKeyA",
            "RegQueryValueA","GetDriveTypeA","GetVolumeInformationA","TextOutA","ExtTextOutA",
            "GetGlyphOutlineA","DrawTextA","CreateFontA","CreateFontIndirectA","DirectDrawCreate",
            "DirectDrawCreateEx","Direct3DCreate8","Direct3DCreate9","DirectSoundCreate","DirectInputCreateA",
            "mciSendCommandA","mciSendStringA","CoCreateInstance","SHGetFolderPathA","GetModuleFileNameA")
    allf = {f for v in imps.values() for f in v}
    print("- imports relevantes presentes:", ", ".join(k for k in keys if k in allf) or "ninguno")
    # recursos / versión
    rr = dirs[2][0]
    if rr:
        base = rva2off(secs, rr)
        def ents(o):
            nn, ni = struct.unpack_from("<HH", d, o+12)
            return [struct.unpack_from("<II", d, o+16+8*i) for i in range(nn+ni)]
        types = {}
        for tid, off in ents(base):
            sub = ents(base + (off & 0x7fffffff))
            types[tid] = len(sub)
        names = {1:"CURSOR",2:"BITMAP",3:"ICON",4:"MENU",5:"DIALOG",6:"STRING",9:"ACCEL",10:"RCDATA",
                 12:"GROUP_CURSOR",14:"GROUP_ICON",16:"VERSION",24:"MANIFEST"}
        print("- recursos:", ", ".join(f"{names.get(k,k)}×{v}" for k, v in types.items() if isinstance(k,int)) or "—")
        m = re.search(rb"F\0i\0l\0e\0V\0e\0r\0s\0i\0o\0n\0\0\0(?:\0\0)?((?:[^\0]\0)+)", d)
        if m: print("- FileVersion:", m.group(1).decode("utf-16le"))
    # protección
    print("- indicadores de protección/packer (aparición en el archivo):")
    hit = {k.decode(): len(re.findall(re.escape(k), d)) for k in PROT}
    print("  " + (", ".join(f"{k}×{v}" for k, v in hit.items() if v) or "ninguno"))
    # claves de registro
    print("- cadenas de registro/INI:")
    seen = set()
    for m in re.finditer(rb"(?i:software)\\[\x20-\x7e]{3,120}|HKEY_[A-Z_]+[\x20-\x7e]{0,80}|[\w.]+\.ini", d):
        s = m.group().decode("latin1")
        if s not in seen: seen.add(s); print("  -", s)
    print()

for a in sys.argv[1:]:
    main(a)
