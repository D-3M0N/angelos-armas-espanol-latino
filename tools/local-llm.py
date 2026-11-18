#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Angelos Armas - Rebirth · ayudante local (Ollama) para ahorrar cuota de Claude.

  local-llm.py resumir ARCHIVO [--pregunta "..."]      resume logs/decompilados largos (≤ 30 líneas)
  local-llm.py clasificar IN.jsonl OUT.jsonl            D7 por línea: traducible | explicit | lyrics
  local-llm.py resumir-escenas IN.jsonl OUT.jsonl       resumen de 2-3 líneas por escena (contexto F16)
  local-llm.py glosario IN.jsonl OUT.tsv                nombres y términos candidatos con frecuencia
  local-llm.py traducir IN.jsonl OUT.jsonl [--glosario G.tsv] [--resumenes R.jsonl]
                                                        borrador local EN+ES (precedencia más baja)
  local-llm.py selftest                                 comprueba Ollama, el modelo, JSON y velocidad

IN.jsonl: un objeto por línea del juego: {"id": hash, "scene": "...", "speaker": "...", "text": "JP"}.
Las salidas son incrementales (caché por id/escena): se puede cortar y reanudar.
Variables: AA_LOCAL_MODEL (qwen3:8b), OLLAMA_HOST (http://127.0.0.1:11434), AA_LOCAL_CTX (8192).
"""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import collections, json, os, re, sys, time, urllib.request

MODEL = os.environ.get("AA_LOCAL_MODEL", "qwen3:8b")
HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
if not HOST.startswith("http"):
    HOST = "http://" + HOST
CTX = int(os.environ.get("AA_LOCAL_CTX", "8192"))
BATCH = 25
STATS = {"calls": 0, "out_tokens": 0, "secs": 0.0}


def chat(system, user, schema=None, think=False, temp=0.2):
    body = {"model": MODEL, "stream": False, "think": think, "keep_alive": "10m",
            "options": {"temperature": temp, "num_ctx": CTX, "num_predict": int(os.environ.get("AA_LOCAL_NUM_PREDICT", "3000"))},
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}
    if schema:
        body["format"] = schema
    req = urllib.request.Request(HOST + "/api/chat", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    for intento in range(4):
        try:
            with urllib.request.urlopen(req, timeout=400) as r:
                res = json.load(r)
            break
        except (TimeoutError, urllib.error.URLError, ConnectionError):
            if intento == 3:
                raise
            time.sleep(5 * (intento + 1))
    STATS["calls"] += 1
    STATS["out_tokens"] += res.get("eval_count", 0)
    STATS["secs"] += res.get("eval_duration", 0) / 1e9
    return re.sub(r"<think>.*?</think>", "", res["message"]["content"], flags=re.S).strip()


def chat_json(system, user, schema):
    """JSON validado; si sin razonamiento no respeta el esquema, reintenta con razonamiento."""
    last = None
    for think in (False, True):
        try:
            return json.loads(chat(system, user, schema, think))
        except (ValueError, KeyError) as e:
            last = e
    raise RuntimeError(f"el modelo no devolvió JSON válido: {last}")


def load_jsonl(path):
    with open(path, encoding="utf-8") as f:
        return [json.loads(l) for l in f if l.strip()]


def done_keys(path, key):
    if not os.path.exists(path):
        return set()
    return {json.loads(l)[key] for l in open(path, encoding="utf-8") if l.strip()}


def append(path, obj):
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(obj, ensure_ascii=False) + "\n")


def by_scene(rows):
    scenes = collections.OrderedDict()
    for r in rows:
        scenes.setdefault(r.get("scene", "?"), []).append(r)
    return scenes


def batches(rows, n=BATCH):
    for i in range(0, len(rows), n):
        yield rows[i:i + n]


def fmt_lines(rows):
    return "\n".join(f'{r["id"]}\t{r.get("speaker") or "-"}\t{r["text"]}' for r in rows)


def progress(i, total, t0, what):
    el = time.time() - t0
    eta = el / max(i, 1) * (total - i)
    print(f"\r{what}: {i}/{total} · {el/60:.0f} min · faltan ~{eta/60:.0f} min ", end="", file=sys.stderr, flush=True)


def cmd_resumir(path, pregunta=""):
    text = open(path, encoding="utf-8", errors="replace").read()
    nlines = text.count("\n")
    if len(text) > 150000:   # logs enormes: el principio y, sobre todo, el final
        text = text[:30000] + "\n[…recortado…]\n" + text[-120000:]
    focus = f"Céntrate en: {pregunta}\n" if pregunta else ""
    sysm = ("Resumes salidas técnicas (logs de Wine, decompilados de Ghidra, trazas) para un programador. "
            "Conserva literalmente: errores, direcciones, nombres de funciones/archivos/DLL, códigos de error y números clave. "
            "Sin introducciones. Español, viñetas cortas.")
    chunks = [text[i:i + 12000] for i in range(0, len(text), 12000)] or [""]
    parts = [chat(sysm, f"{focus}Fragmento {k+1}/{len(chunks)}:\n{c}") for k, c in enumerate(chunks)]
    final = parts[0] if len(parts) == 1 else chat(sysm, f"{focus}Une estos resúmenes en máximo 30 viñetas:\n\n" + "\n\n".join(parts))
    lines = final.splitlines()[:30]
    print(f"[resumen local de {path}: {nlines} líneas → {len(lines)}; puede omitir detalles: confirma con grep]")
    print("\n".join(lines))


CLS_SCHEMA = {"type": "object", "required": ["items"], "properties": {"items": {"type": "array", "items": {
    "type": "object", "required": ["id", "cat", "motivo"], "properties": {
        "id": {"type": "string"}, "cat": {"type": "string", "enum": ["traducible", "explicit", "lyrics"]},
        "motivo": {"type": "string"}}}}, "escena_sexual": {"type": "boolean"}}}
CLS_SYS = ("Clasificas líneas de una novela visual japonesa para una política de traducción. Por cada línea devuelve cat:\n"
           "- explicit: descripción o diálogo sexualmente explícito, o violencia sexual.\n"
           "- lyrics: letra de canción.\n"
           "- traducible: todo lo demás (incluye romance, insinuación no explícita, violencia no sexual, trama).\n"
           "Ante la duda entre explicit y traducible, elige explicit. motivo: 2-6 palabras. "
           "escena_sexual: true si el lote contiene contenido sexual. Responde solo JSON.")


def cmd_clasificar(inp, out):
    rows = load_jsonl(inp)
    done = done_keys(out, "id")
    todo = [r for r in rows if r["id"] not in done]
    t0 = time.time()
    for k, b in enumerate(batches(todo)):
        res = chat_json(CLS_SYS, fmt_lines(b), CLS_SCHEMA)
        got = {i["id"]: i for i in res.get("items", [])}
        for r in b:
            i = got.get(r["id"]) or {"cat": "explicit", "motivo": "sin respuesta: revisar"}   # a prueba de fallos
            append(out, {"id": r["id"], "scene": r.get("scene"), "cat": i["cat"], "motivo": i["motivo"],
                         "escena_sexual": bool(res.get("escena_sexual")), "src": f"local:{MODEL}"})
        progress(min((k + 1) * BATCH, len(todo)), len(todo), t0, "clasificar")
    print(file=sys.stderr)


SUM_SCHEMA = {"type": "object", "required": ["resumen", "personajes"], "properties": {
    "resumen": {"type": "string"}, "personajes": {"type": "array", "items": {"type": "string"}}}}


def cmd_resumir_escenas(inp, out):
    scenes = by_scene(load_jsonl(inp))
    done = done_keys(out, "scene")
    todo = [s for s in scenes if s not in done]
    t0 = time.time()
    for k, s in enumerate(todo):
        text = fmt_lines(scenes[s])[:20000]
        res = chat_json("Resume una escena de novela visual en español, 2-3 frases: quién, qué pasa, tono. "
                        "Sin detalles sexuales explícitos. Lista los personajes que hablan. Solo JSON.", text, SUM_SCHEMA)
        append(out, {"scene": s, "resumen": res["resumen"], "personajes": res["personajes"], "src": f"local:{MODEL}"})
        progress(k + 1, len(todo), t0, "resumir-escenas")
    print(file=sys.stderr)


GLO_SCHEMA = {"type": "object", "required": ["terms"], "properties": {"terms": {"type": "array", "items": {
    "type": "object", "required": ["ja", "tipo", "en", "es"], "properties": {
        "ja": {"type": "string"}, "lectura": {"type": "string"},
        "tipo": {"type": "string", "enum": ["persona", "lugar", "organizacion", "objeto", "termino"]},
        "en": {"type": "string"}, "es": {"type": "string"}}}}}}


def cmd_glosario(inp, out):
    rows = load_jsonl(inp)
    cnt, info = collections.Counter(), {}
    t0 = time.time()
    total = (len(rows) + 59) // 60
    for k, b in enumerate(batches(rows, 60)):
        try:
            res = chat_json("Extrae nombres propios y términos recurrentes (personas, lugares, organizaciones, armas, "
                            "jerga) de estas líneas japonesas. Da lectura en romaji y una propuesta EN y ES. "
                            "No incluyas palabras comunes. Solo JSON.", fmt_lines(b), GLO_SCHEMA)
        except RuntimeError:
            progress(k + 1, total, t0, "glosario(lote omitido)")
            continue
        for t in res.get("terms", []):
            ja = t["ja"].strip()
            if ja:
                cnt[ja] += sum(r["text"].count(ja) for r in b) or 1
                info.setdefault(ja, t)
        progress(k + 1, total, t0, "glosario")
    print(file=sys.stderr)
    with open(out, "w", encoding="utf-8") as f:
        f.write("ja\tlectura\ttipo\ten\tes\tfrecuencia\tfuente\n")
        for ja, n in cnt.most_common():
            t = info[ja]
            f.write(f'{ja}\t{t.get("lectura","")}\t{t["tipo"]}\t{t["en"]}\t{t["es"]}\t{n}\tlocal:{MODEL}\n')
    print(f"{len(cnt)} términos → {out} (candidatos: revísalos antes de fijarlos)")


TR_SCHEMA = {"type": "object", "required": ["items"], "properties": {"items": {"type": "array", "items": {
    "type": "object", "required": ["id", "en", "es"], "properties": {
        "id": {"type": "string"}, "en": {"type": "string"}, "es": {"type": "string"}}}}}}


def cmd_traducir(inp, out, glosario=None, resumenes=None, clasificacion=None, adultas=None):
    """Solo traduce cat=traducible (D7/D12). Escenas con escena_sexual en algún lote: excluded:scene
    salvo que figuren en el archivo --escenas-adultas (una por línea; revisión humana: todos claramente adultos)."""
    if not clasificacion or not os.path.exists(clasificacion):
        sys.exit("✖ traducir exige --clasificacion CLS.jsonl (salida de clasificar)")
    cls = {r["id"]: r for r in load_jsonl(clasificacion)}
    ok_scenes = set(open(adultas, encoding="utf-8").read().split("\n")) if adultas and os.path.exists(adultas) else set()
    sexual = {r["scene"] for r in cls.values() if r.get("escena_sexual")} - ok_scenes
    rows = [r for r in load_jsonl(inp)
            if r["id"] in cls and cls[r["id"]]["cat"] == "traducible" and r["scene"] not in sexual]
    print(f"traducir: {len(rows)} líneas elegibles; {len(sexual)} escenas excluded:scene", file=sys.stderr)
    done = done_keys(out, "id")
    gl = ""
    if glosario and os.path.exists(glosario):
        lines = open(glosario, encoding="utf-8").read().splitlines()[1:200]
        gl = "Glosario (ja → en / es):\n" + "\n".join(
            f"{c[0]} → {c[3]} / {c[4]}" for c in (l.split("\t") for l in lines) if len(c) >= 5)
    summ = {}
    if resumenes and os.path.exists(resumenes):
        summ = {r["scene"]: r["resumen"] for r in load_jsonl(resumenes)}
    sysm = ("Traductor literario de novelas visuales japonesas. Traduce cada línea al inglés (en) y al español neutro (es), "
            "naturales y fieles al tono del personaje. Conserva exactamente códigos de control, etiquetas y secuencias "
            "como \\n, %s, {..}, <..>. No añadas notas. Responde solo JSON con el mismo id.\n" + gl)
    todo = [r for r in rows if r["id"] not in done]
    t0 = time.time()
    n = 0
    for scene, srows in by_scene(todo).items():
        ctx = f"Escena: {scene}. Contexto: {summ.get(scene, '(sin resumen)')}\n\n"
        for b in batches(srows):
            res = chat_json(sysm, ctx + fmt_lines(b), TR_SCHEMA)
            got = {i["id"]: i for i in res.get("items", [])}
            for r in b:
                if r["id"] in got:
                    append(out, {"id": r["id"], "en": got[r["id"]]["en"], "es": got[r["id"]]["es"], "src": f"local:{MODEL}"})
            n += len(b)
            progress(n, len(todo), t0, "traducir")
    print(file=sys.stderr)


def cmd_selftest():
    try:
        tags = json.load(urllib.request.urlopen(HOST + "/api/tags", timeout=10))
    except OSError as e:
        sys.exit(f"✖ Ollama no responde en {HOST}: {e}")
    names = {m["name"] for m in tags.get("models", [])}
    if MODEL not in names and MODEL + ":latest" not in names:
        sys.exit(f"✖ falta el modelo {MODEL}: ollama pull {MODEL}")
    print(f"✔ Ollama en {HOST} con {MODEL}")
    demo = [{"id": "t1", "scene": "demo", "speaker": "ウィム", "text": "「行くぞ。弾はまだ残ってる」"},
            {"id": "t2", "scene": "demo", "speaker": "-", "text": "雨が街を濡らしていた。"}]
    t0 = time.time()
    c = chat_json(CLS_SYS, fmt_lines(demo), CLS_SCHEMA)
    ids = {i["id"] for i in c["items"]}
    mark = "✔" if ids == {"t1", "t2"} else "⚠ (faltan ids: esas líneas se marcan explicit por seguridad)"
    print(f"{mark} clasificar: {[(i['id'], i['cat']) for i in c['items']]}")
    t = chat_json("Traduce cada línea al inglés (en) y al español (es). Solo JSON con el mismo id.", fmt_lines(demo), TR_SCHEMA)
    for i in t["items"]:
        print(f"✔ traducir {i['id']}: EN «{i['en']}» · ES «{i['es']}»")
    s = chat("Resume en una viñeta.", "err:module:import_dll Library d3d8.dll not found\nerr:module:loader_init failed\n" * 50)
    print(f"✔ resumir: {s.splitlines()[0][:100] if s else '(vacío)'}")
    tps = STATS["out_tokens"] / STATS["secs"] if STATS["secs"] else 0
    print(f"✔ {STATS['calls']} llamadas en {time.time()-t0:.0f} s · {tps:.0f} tokens/s de salida")
    if tps and tps < 15:
        print("⚠ muy lento: probablemente el modelo no cabe entero en la GPU (mira `ollama ps`: debe decir 100% GPU)")


def main(a):
    if len(a) < 1 or a[0] in ("-h", "--help"):
        print(__doc__); return
    cmd, rest = a[0], a[1:]
    opt = lambda k: rest[rest.index(k) + 1] if k in rest else None
    pos = [x for i, x in enumerate(rest) if not x.startswith("--") and (i == 0 or not rest[i - 1].startswith("--"))]
    try:
        if cmd == "resumir": cmd_resumir(pos[0], opt("--pregunta") or "")
        elif cmd == "clasificar": cmd_clasificar(pos[0], pos[1])
        elif cmd == "resumir-escenas": cmd_resumir_escenas(pos[0], pos[1])
        elif cmd == "glosario": cmd_glosario(pos[0], pos[1])
        elif cmd == "traducir": cmd_traducir(pos[0], pos[1], opt("--glosario"), opt("--resumenes"), opt("--clasificacion"), opt("--escenas-adultas"))
        elif cmd == "selftest": cmd_selftest()
        else: sys.exit(f"comando desconocido: {cmd}\n{__doc__}")
    except IndexError:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
