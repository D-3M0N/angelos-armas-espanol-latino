#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Angelos Armas - Rebirth · traducción por capas (resumible). Datos en AA_ROOT/cache/text (nunca en git).
  translate.py draft        borrador local JA→EN→ES con los modelos de modelos.json (incluye explicit: solo local)
  translate.py check        comprobaciones sin IA (códigos de control, kana, idioma, longitud)
  translate.py audit        Haiku compara JA con EN/ES por escena (NUNCA explicit) → severidad 0-3
  translate.py fix          Sonnet reescribe solo sev ≥ 2 o fallos de check (NUNCA explicit)
  translate.py sample [%]   muestra (2 % + toda sev 3) para la revisión final de Opus
  translate.py export       translations.jsonl: manual > fix > draft
  translate.py status
Entradas: lines.jsonl {id, scene, speaker, text}, local-clasif.jsonl, local-resumenes.jsonl, glosario.tsv|local-glosario.tsv,
excluded-scenes.txt (una escena por línea; no se traduce), manual.jsonl (D12, {id,en,es}). Clases sin borrador: lyrics, excluir."""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import shutil, urllib.error, collections, datetime as dt, json, os, random, re, subprocess, sys, time, urllib.request

ROOT = os.environ.get("AA_ROOT", os.path.expanduser("~/angelos-armas"))
T, TR = f"{ROOT}/cache/text", f"{ROOT}/cache/text/tr"
HOST = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
if not HOST.startswith("http"):
    HOST = "http://" + HOST
CTX = int(os.environ.get("AA_LOCAL_CTX", "8192"))
LIMIT_RE = re.compile(r"usage_limit_reached|hit your .*limit|usage limit|limit reached|out of extra usage|limit will reset", re.I)
NOSPK = ("", "-", None, "ナレーション")


# ── Ollama ───────────────────────────────────────────────
def _post(path, body, timeout=900):
    req = urllib.request.Request(HOST + path, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read()[:200]!r}")


def installed():
    try:
        return [m["name"] for m in json.load(urllib.request.urlopen(HOST + "/api/tags", timeout=10)).get("models", [])]
    except OSError:
        return []


def resolve(hint, names=None):
    names = installed() if names is None else names
    if hint in names or hint + ":latest" in names:
        return hint
    h = hint.split(":")[0].lower()
    return next((n for n in names if h in n.lower()), None)


def gen_chat(spec, system, user, temp=0.2):
    body = {"model": spec["name"], "stream": False, "keep_alive": "10m", "options": {"temperature": temp, "num_ctx": CTX},
            "messages": [{"role": "system", "content": system}, {"role": "user", "content": user}]}
    if spec.get("think") is not None:
        body["think"] = spec["think"]
    return re.sub(r"<think>.*?</think>", "", _post("/api/chat", body)["message"]["content"], flags=re.S).strip()


def gen_raw(spec, prompt):   # VNTL: formato Llama 3 con cabeceras propias; temperatura 0; si Ollama aborta por repetición, reintenta con penalización y al final deja vacío (lo recoge check)
    for rp, temp in ((1.0, 0), (1.15, 0.3), (1.3, 0.7)):
        try:
            return _post("/api/generate", {"model": spec["name"], "raw": True, "stream": False, "keep_alive": "10m", "prompt": prompt,
                                           "options": {"temperature": temp, "repeat_penalty": rp, "num_ctx": CTX, "num_predict": 300,
                                                       "stop": ["<|eot_id|>"]}})["response"]
        except RuntimeError as e:
            print("⚠ gen_raw:", e, file=sys.stderr)
    return ""


def clean_line(s):
    s = re.sub(r"<\|[^>]*\|>", "", s).strip()
    s = re.sub(r"^\[[^\]\n]{1,40}\]:\s*", "", s)
    s = re.sub(r"^(Translation|Traducción|English|Spanish|Español)\s*:\s*", "", s, flags=re.I)
    if len(s) >= 2 and s[0] in "\"“«「" and s[-1] in "\"”»」":
        s = s[1:-1].strip()
    return s


# ── ficha / prompts ──────────────────────────────────────
def load_ficha():
    for n in ("glosario.tsv", "local-glosario.tsv"):
        p = f"{T}/{n}"
        if os.path.exists(p):
            out = []
            for l in list(open(p, encoding="utf-8"))[1:]:
                c = l.rstrip("\n").split("\t")
                if len(c) >= 5:
                    out.append({"ja": c[0], "tipo": c[2], "en": c[3], "es": c[4], "genero": c[7] if len(c) > 7 else "",
                                "f": int(c[5]) if len(c) > 5 and c[5].isdigit() else 0})
            return sorted(out, key=lambda x: -x["f"])[:40]
    return []


def ficha_block(ficha, lang):
    return "\n".join(f"- {f['ja']} → {f.get(lang) or f['en']}" + (f" ({f['genero']})" if f.get("genero") else "")
                     + (f" — {f['nota']}" if f.get("nota") else "") for f in ficha) or "(no sheet)"


def en_name(ficha, sp):
    if sp in NOSPK:
        return ""
    for f in ficha:
        if f.get("tipo") == "persona" and (sp == f["ja"] or sp in f["ja"].split() or f["ja"].replace(" ", "").startswith(sp)):
            return f["en"].split()[0]
    return sp


H = lambda role: f"<|start_header_id|>{role}<|end_header_id|>\n\n"


def vntl_prompt(ficha, prev, sp, ja):
    meta = [(f"[character] Name: {f['en']} ({f['ja']}) | Gender: {f.get('genero') or 'Unknown'}" if f.get("tipo") == "persona"
             else f"[element] Name: {f['en']} ({f['ja']}) | Type: {f.get('tipo', 'term')}") for f in ficha[:30]]
    tag = lambda n: f"[{n}]: " if n else ""
    p = H("Metadata") + "\n".join(meta) + "<|eot_id|>"
    for s, j, e in prev:
        s = "" if s in NOSPK else s
        p += H("Japanese") + tag(s) + j + "<|eot_id|>" + H("English") + tag(en_name(ficha, s)) + (f'"{e}"' if j.startswith("「") else e) + "<|eot_id|>"
    return p + H("Japanese") + tag("" if sp in NOSPK else sp) + ja + "<|eot_id|>" + H("English")


SYS_JA_EN = ("You are a professional Japanese→English translator of visual novels. Translate ONLY the given line, faithfully: meaning, "
             "register, tone, speaker gender and who is addressed (infer omitted subjects from context). Use the character sheet for "
             "names and gender. Keep control codes (\\n, %s, {..}, <..>) exactly. Output only the English line: no notes, no quotes.")
SYS_EN_ES = ("You translate visual-novel lines from English to neutral Spanish (Latin America). The Japanese original is only to "
             "disambiguate (gender, who is addressed, register). Be faithful and natural for the character. Keep control codes "
             "(\\n, %s, {..}, <..>) exactly. Output only the Spanish line: no notes, no quotes.")


def ja_en(spec, ficha, summ, prev, sp, ja):
    prev = prev[-5:]
    if spec["style"] == "vntl":
        return clean_line(gen_raw(spec, vntl_prompt(ficha, prev, sp, ja)))
    hist = "\n".join(f"[{'' if s in NOSPK else s}] {j}\n  → {e}" for s, j, e in prev) or "(start of scene)"
    user = (f"Character sheet:\n{ficha_block(ficha, 'en')}\nScene: {summ}\nPrevious lines:\n{hist}\n\n"
            f"Translate this line:\n[{'narration' if sp in NOSPK else sp}] {ja}")
    return clean_line(gen_chat(spec, SYS_JA_EN, user))


def en_es(spec, ficha, summ, prev, sp, ja, en):
    hist = "\n".join(f"[{'' if s in NOSPK else s}] {e}\n  → {x}" for s, e, x in prev[-5:]) or "(start of scene)"
    user = (f"Character sheet (JA → ES):\n{ficha_block(ficha, 'es')}\nScene: {summ}\nPrevious lines (EN → ES):\n{hist}\n\n"
            f"Speaker: {'narration' if sp in NOSPK else sp}\nJapanese: {ja}\nEnglish: {en}\n\nSpanish:")
    return clean_line(gen_chat(spec, SYS_EN_ES, user))


# ── comprobaciones sin IA ────────────────────────────────
CODE_RE = re.compile(r"\\n|%[sd]|\{[^}]*\}|<[^>]*>")
KANA_RE = re.compile(r"[\u3040-\u30ff\u4e00-\u9fff]")
EN_STOP = set("the and you to is of that it in was for with this not are have".split())
ES_STOP = set("el la los las de que y en un una es no se con por para lo".split())


def checks(ja, out, lang):
    if not out.strip():
        return ["vacio"]
    iss = []
    if sorted(CODE_RE.findall(ja)) != sorted(CODE_RE.findall(out)):
        iss.append("codigos")
    if KANA_RE.search(out):
        iss.append("japones")
    w = re.findall(r"[a-záéíóúñü]+", out.lower())
    if len(w) >= 5:
        en, es = sum(x in EN_STOP for x in w), sum(x in ES_STOP for x in w)
        if (lang == "es" and en > es + 1) or (lang == "en" and es > en + 1):
            iss.append("idioma")
    r = len(out) / max(len(ja), 1)
    if r > 8 or (len(ja) > 6 and r < 0.15):
        iss.append("longitud")
    return iss


# ── Claude (solo capas 4-6; nunca explicit) ──────────────
def reset_secs(text):
    m = re.search(r"resets?(?: at)?\s+(?:(mon|tue|wed|thu|fri|sat|sun)\w*\s+)?(\d{1,2})(?::(\d{2}))?\s*([ap]m)(?:\s*\(([^)]+)\))?", text, re.I)
    if not m:
        return None
    from zoneinfo import ZoneInfo
    day, h, mi, ap, tz = m.groups()
    h = int(h) % 12 + (12 if ap.lower() == "pm" else 0)
    try:
        z = ZoneInfo(tz) if tz else None
    except Exception:
        z = None
    now = dt.datetime.now(z) if z else dt.datetime.now().astimezone()
    c = now.replace(hour=h, minute=int(mi or 0), second=0, microsecond=0)
    if day:
        c += dt.timedelta(days=(["mon", "tue", "wed", "thu", "fri", "sat", "sun"].index(day[:3].lower()) - c.weekday()) % 7)
    while c <= now:
        c += dt.timedelta(days=7 if day else 1)
    return int((c - now).total_seconds()) + 120


def claude(prompt, model, effort="medium"):
    d = f"{ROOT}/cache/tr-run"          # directorio vacío: no carga CLAUDE.md del repo
    os.makedirs(d, exist_ok=True)
    opts = ["--effort", effort]
    for _ in range(300):
        r = subprocess.run([shutil.which("claude") or "claude", "-p", prompt, "--model", model, "--tools", "", "--output-format", "json", *opts],
                           cwd=d, capture_output=True, text=True, timeout=1800)
        out = (r.stdout or "") + (r.stderr or "")
        if r.returncode != 0 and opts and re.search(r"unknown option|unrecognized|invalid (option|value)", out, re.I):
            opts = []
            continue
        try:
            data = json.loads(r.stdout)
        except ValueError:
            data = {}
        bad = r.returncode != 0 or data.get("is_error")
        if bad and LIMIT_RE.search(out):
            secs = reset_secs(out) or 900
            print(f"\n  cuota agotada: espero {secs // 60} min", file=sys.stderr, flush=True)
            time.sleep(secs)
            continue
        if bad:
            raise RuntimeError(out[-300:])
        return data.get("result", "")
    raise RuntimeError("demasiados reintentos")


def claude_json(prompt, model):
    for k in range(2):
        txt = claude(prompt, model)
        m = re.search(r"\{.*\}", txt, re.S)
        try:
            return json.loads(m.group(0))
        except (AttributeError, ValueError):
            prompt += "\n\nRESPONDE SOLO CON EL JSON pedido."
    raise RuntimeError("sin JSON válido")


# ── E/S ──────────────────────────────────────────────────
def load(path):
    return [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()] if os.path.exists(path) else []


def append(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(obj, ensure_ascii=False) + "\n")


def by_scene(rows):
    d = collections.OrderedDict()
    for r in rows:
        d.setdefault(r.get("scene", "?"), []).append(r)
    return d


def progress(i, n, t0, what):
    el = time.time() - t0
    print(f"\r{what}: {i}/{n} · {el / 60:.0f} min · faltan ~{el / max(i, 1) * (n - i) / 60:.0f} min ", end="", file=sys.stderr, flush=True)


def models():
    p = f"{T}/modelos.json"
    if not os.path.exists(p):
        return (os.environ.get("AA_MODEL_JA_EN", "qwen3:8b"), os.environ.get("AA_MODEL_EN_ES", "qwen3:8b"))
    m = json.load(open(p, encoding="utf-8"))
    return m["ja_en"], m["en_es"]


def current():
    """draft con las correcciones de fix encima."""
    fx = {r["id"]: r for r in load(f"{TR}/fix.jsonl")}
    return [dict(r, en=fx[r["id"]]["en"], es=fx[r["id"]]["es"], src="sonnet") if r["id"] in fx else r for r in load(f"{TR}/draft.jsonl")]


# ── capas ────────────────────────────────────────────────
def cmd_draft():
    """Dos pasadas (un solo modelo en la VRAM de 8 GB cada vez): A = JA→EN, B = EN→ES. Reanudable."""
    s_en, s_es = models()
    rows = load(f"{T}/lines.jsonl")
    cls = {r["id"]: r["cat"] for r in load(f"{T}/local-clasif.jsonl")}
    if not cls:
        sys.exit("✖ falta local-clasif.jsonl (local-llm.py clasificar)")
    excl = set(open(f"{T}/excluded-scenes.txt", encoding="utf-8").read().split()) if os.path.exists(f"{T}/excluded-scenes.txt") else set()
    summ = {r["scene"]: r["resumen"] for r in load(f"{T}/local-resumenes.jsonl")}
    ficha = load_ficha()
    sc = lambda r: r.get("scene", "?")
    want = [r for r in rows if cls.get(r["id"]) in ("traducible", "explicit") and sc(r) not in excl]
    pa, pb = f"{TR}/draft-en.jsonl", f"{TR}/draft.jsonl"
    en = {r["id"]: r["en"] for r in load(pa)}
    hist = collections.defaultdict(list)
    for r in want:
        if r["id"] in en:
            hist[sc(r)].append((r.get("speaker"), r["text"], en[r["id"]]))
    todo = [r for r in want if r["id"] not in en]
    t0, n = time.time(), 0
    for scene, srows in by_scene(todo).items():
        h = hist[scene]
        for r in srows:
            e = ja_en(s_en, ficha, summ.get(scene, "(no summary)"), h, r.get("speaker"), r["text"])
            append(pa, {"id": r["id"], "en": e})
            en[r["id"]] = e
            h.append((r.get("speaker"), r["text"], e))
            n += 1
            progress(n, len(todo), t0, "JA→EN")
    print(file=sys.stderr)
    done = {r["id"]: r for r in load(pb)}
    hist = collections.defaultdict(list)
    for r in want:
        if r["id"] in done:
            hist[sc(r)].append((r.get("speaker"), done[r["id"]]["en"], done[r["id"]]["es"]))
    todo = [r for r in want if r["id"] in en and r["id"] not in done]
    t0, n = time.time(), 0
    for scene, srows in by_scene(todo).items():
        h = hist[scene]
        for r in srows:
            es = en_es(s_es, ficha, summ.get(scene, "(no summary)"), h, r.get("speaker"), r["text"], en[r["id"]])
            append(pb, {"id": r["id"], "scene": scene, "explicit": cls[r["id"]] == "explicit", "en": en[r["id"]], "es": es,
                        "src": f"draft:{s_en['key']}+{s_es['key']}"})
            h.append((r.get("speaker"), en[r["id"]], es))
            n += 1
            progress(n, len(todo), t0, "EN→ES")
    print(file=sys.stderr)

def cmd_check():
    ja = {r["id"]: r["text"] for r in load(f"{T}/lines.jsonl")}
    bad, cnt = [], collections.Counter()
    for r in current():
        iss = [f"en:{x}" for x in checks(ja[r["id"]], r["en"], "en")] + [f"es:{x}" for x in checks(ja[r["id"]], r["es"], "es")]
        if iss:
            bad.append({"id": r["id"], "explicit": r.get("explicit", False), "issues": iss})
            cnt.update(iss)
    os.makedirs(TR, exist_ok=True)
    open(f"{TR}/checks.jsonl", "w", encoding="utf-8").write("".join(json.dumps(b, ensure_ascii=False) + "\n" for b in bad))
    print(f"check: {len(bad)} líneas con avisos · {dict(cnt)}")


def scene_chunks(rows, n=40):
    for scene, srows in by_scene(rows).items():
        for i in range(0, len(srows), n):
            yield scene, srows[i:i + n]


def cmd_audit():
    model = os.environ.get("AA_AUDIT_MODEL_TR", "haiku")
    ja = {r["id"]: r for r in load(f"{T}/lines.jsonl")}
    summ = {r["scene"]: r["resumen"] for r in load(f"{T}/local-resumenes.jsonl")}
    ficha, out = load_ficha(), f"{TR}/audit.jsonl"
    done = {r["id"] for r in load(out)}
    rows = [r for r in current() if not r.get("explicit")]
    chunks = [(s, c) for s, c in scene_chunks(rows) if any(r["id"] not in done for r in c)]
    chunks = chunks[: int(os.environ.get("AA_AUDIT_MAX", "100000"))]
    t0 = time.time()
    for k, (scene, c) in enumerate(chunks):
        body = "\n".join(f"{i + 1} | {ja[r['id']].get('speaker') or '-'} | {ja[r['id']]['text']}\n  EN: {r['en']}\n  ES: {r['es']}" for i, r in enumerate(c))
        try:
            res = claude_json(
            "Eres revisor de traducciones de una novela visual japonesa. Compara el japonés con EN y ES. Marca SOLO las líneas con problemas: "
            "omisión o adición de contenido, error de sentido, sujeto/género/honorífico/tuteo incorrecto, nombre distinto de la ficha, tono muy distinto. "
            "sev: 1 leve, 2 medio (cambia el matiz), 3 grave (sentido incorrecto u omisión). Ignora preferencias de estilo. "
            'Responde SOLO JSON: {"items":[{"n":<número>,"sev":1-3,"tipo":"omision|adicion|sentido|genero|registro|nombre|tono","nota":"≤12 palabras","lang":"en|es|ambos"}]}. '
            'Si todo está bien: {"items":[]}.\n\nFicha:\n' + ficha_block(ficha, "es") + f"\n\nEscena: {summ.get(scene, '')}\n\nLíneas:\n{body}", model)
        except RuntimeError as e:
            print(f"\n  trozo {scene} omitido: {str(e)[:80]}", file=sys.stderr)
            _omit = globals().get("_omit_audit", 0) + 1; globals()["_omit_audit"] = _omit
            with open(f"{TR}/omitidos-audit.txt", "a", encoding="utf-8") as _f:
                _f.write(scene + "\t" + ",".join(r["id"] for r in c) + "\n")
            continue
        flag = {int(i["n"]): i for i in res.get("items", []) if str(i.get("n", "")).isdigit()}
        for i, r in enumerate(c):
            f = flag.get(i + 1, {})
            append(out, {"id": r["id"], "sev": int(f.get("sev", 0)), "tipo": f.get("tipo", ""), "nota": f.get("nota", ""), "lang": f.get("lang", "")})
        progress(k + 1, len(chunks), t0, "audit")
    print(file=sys.stderr)
    print(f"  audit: {globals().get('_omit_audit', 0)} trozos omitidos de {len(chunks)}", file=sys.stderr)


def cmd_fix():
    model = os.environ.get("AA_FIX_MODEL", "sonnet")
    ja = {r["id"]: r for r in load(f"{T}/lines.jsonl")}
    summ = {r["scene"]: r["resumen"] for r in load(f"{T}/local-resumenes.jsonl")}
    ficha, out = load_ficha(), f"{TR}/fix.jsonl"
    sev = {r["id"]: r for r in load(f"{TR}/audit.jsonl")}
    chk = {r["id"]: r["issues"] for r in load(f"{TR}/checks.jsonl")}
    done = {r["id"] for r in load(out)}
    cur = [r for r in current() if not r.get("explicit") and r["id"] not in done]
    om = set()  # ids de trozos omitidos en audit: sin sev, se corrigen igual
    try:
        for l in open(f"{TR}/omitidos-audit.txt", encoding="utf-8"):
            om.update(l.rstrip("\n").split("\t")[-1].split(","))
    except FileNotFoundError: pass
    if om: print(f"  aviso: {len(om)} líneas de trozos omitidos en audit (se incluyen en fix)", file=sys.stderr)
    targets = [r for r in cur if sev.get(r["id"], {}).get("sev", 0) >= 2 or r["id"] in chk or r["id"] in om]
    if os.environ.get("AA_FIX_SEV"):  # solo sev>=2 del audit (ignora avisos de check)
        targets = [r for r in cur if sev.get(r["id"], {}).get("sev", 0) >= 2 or r["id"] in om]
        if os.environ.get("AA_FIX_DRY"):
            print(f"fix dry sev>=2: {len(targets)} líneas"); return
    only = os.environ.get("AA_FIX_ONLY")  # subcadena de issue (p.ej. "japones"): solo esas líneas
    if only:
        targets = [r for r in targets if any(only in x for x in chk.get(r["id"], []))]
        if os.environ.get("AA_FIX_DRY"):
            print(f"fix dry: {len(targets)} líneas"); return
    chunks = list(scene_chunks(targets, 25))
    chunks = chunks[: int(os.environ.get("AA_FIX_MAX", "100000"))]
    t0 = time.time()
    for k, (scene, c) in enumerate(chunks):
        body = []
        for i, r in enumerate(c):
            a, why = sev.get(r["id"], {}), chk.get(r["id"], [])
            body.append(f"{i + 1} | {ja[r['id']].get('speaker') or '-'} | {ja[r['id']]['text']}\n  EN actual: {r['en']}\n  ES actual: {r['es']}\n"
                        f"  Problema: {a.get('tipo', '')} {a.get('nota', '')} {' '.join(why)} (lang {a.get('lang', 'ambos')})")
        try:
          res = claude_json(
            "Corriges traducciones de una novela visual japonesa. Para cada línea devuelve EN y ES corregidos: fieles al japonés, naturales para el personaje, "
            "ES neutro. Mantén exactamente los códigos de control (\\n, %s, {..}, <..>). Si una de las dos ya está bien, repítela igual. "
            'Responde SOLO JSON: {"items":[{"n":<número>,"en":"...","es":"..."}]}.\n\nFicha:\n' + ficha_block(ficha, "es")
            + f"\n\nEscena: {summ.get(scene, '')}\n\nLíneas:\n" + "\n".join(body), model)
        except RuntimeError as e:
            print(f"\n  trozo {scene} omitido: {str(e)[:80]}", file=sys.stderr)
            _omit = globals().get("_omit_fix", 0) + 1; globals()["_omit_fix"] = _omit
            with open(f"{TR}/omitidos-fix.txt", "a", encoding="utf-8") as _f:
                _f.write(scene + "\t" + ",".join(r["id"] for r in c) + "\n")
            continue
        got = {int(i["n"]): i for i in res.get("items", []) if str(i.get("n", "")).isdigit()}
        for i, r in enumerate(c):
            if i + 1 in got:
                append(out, {"id": r["id"], "en": got[i + 1]["en"], "es": got[i + 1]["es"], "src": f"fix:{model}"})
        progress(k + 1, len(chunks), t0, "fix")
    print(file=sys.stderr)
    print(f"  fix: {globals().get('_omit_fix', 0)} trozos omitidos de {len(chunks)}", file=sys.stderr)


def cmd_sample(pct=2.0):
    sev3 = {r["id"] for r in load(f"{TR}/audit.jsonl") if r["sev"] >= 3}
    cur = [r for r in current() if not r.get("explicit")]
    pick = {r["id"] for r in random.Random(1).sample(cur, min(len(cur), max(1, int(len(cur) * pct / 100))))} if cur else set()
    ja = {r["id"]: r for r in load(f"{T}/lines.jsonl")}
    rows = [{"id": r["id"], "ja": ja[r["id"]]["text"], "en": r["en"], "es": r["es"]} for r in cur if r["id"] in pick | sev3]
    open(f"{TR}/muestra.jsonl", "w", encoding="utf-8").write("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows))
    print(f"muestra.jsonl: {len(rows)} líneas ({len(sev3)} sev 3)")


def repair(ja, t):
    """Determinista: corta colas alucinadas (salto de linea ajeno) y repone <BR> del original en el punto proporcional."""
    if "\n" in t and "\n" not in ja:
        t = t.split("\n")[0].strip()
    for a, b in (("\u201c", '"'), ("\u201d", '"'), ("\u2018", "'"), ("\u2019", "'"), ("\u2014", "-"), ("\u2013", "-"), ("\u2026", "..."), ("\u00a0", " ")):
        t = t.replace(a, b)  # cp932 no los tiene: aafix los descartaba en silencio
    if "*" in t and "*" not in ja and "\uff0a" not in ja:
        t = t.replace("*", "")  # markdown espurio del LLM
    t = t.translate(str.maketrans("\u0101\u0113\u012b\u014d\u016b\u0100\u0112\u012a\u014c\u016a", "aeiouAEIOU"))  # macrones: no estan en cp932 ni en LATIN
    k = ja.count("<BR>")
    t = t.replace("<BR>", " ")
    while sum(2 if (ord(c) > 127) else 1 for c in t) > 440 and " " in t:  # tab_load descarta > 511 B (con <BR> del wrap)
        t = t.rsplit(" ", 1)[0]
    t = re.sub(r" {2,}", " ", t).strip()
    if k:
        parts = ja.split("<BR>")
        tot = sum(len(x) for x in parts) or 1
        acc = 0
        for x in parts[:-1]:
            acc += len(x)
            pos = int(len(t) * acc / tot)
            i = t.rfind(" ", 0, pos + 1)
            if i <= 0:
                i = t.find(" ", pos)
            if i <= 0:
                continue
            t = t[:i] + "<BR>" + t[i + 1:]
    lim = max(k, 3)  # caja: JA llega a 4 <BR>; mas lineas colgo el juego (s745)
    for mx in (WRAP_MAX, 48, 54, 60, 72):
        w = wrap(t, mx)
        if w.count("<BR>") <= lim:
            return w
    parts = w.split("<BR>")  # ultimo recurso: fusiona el exceso en la ultima linea
    return "<BR>".join(parts[:lim] + [" ".join(parts[lim:])]) if len(parts) > lim + 1 else w


WRAP_MAX = 42  # chars/linea ES (caja mas ancha medida: ~48 en s726; conservador). H3


def wrap(t, mx=WRAP_MAX):
    """Parte en espacios los segmentos (entre <BR>) mas largos que mx, sin cortar palabras ni tocar <tags>."""
    out = []
    for seg in t.split("<BR>"):
        while len(re.sub(r"<[^>]*>", "", seg)) > mx:
            i = seg.rfind(" ", 0, mx + 1)
            if i <= 0:
                break
            out.append(seg[:i]); seg = seg[i + 1:]
        out.append(seg)
    return "<BR>".join(out)


def cmd_export():
    jas = {r["id"]: r["text"] for r in load(f"{T}/lines.jsonl")}
    man = {r["id"]: r for r in load(f"{T}/manual.jsonl")}
    n = collections.Counter()
    with open(f"{T}/translations.jsonl", "w", encoding="utf-8") as f:
        for r in current():
            m = man.get(r["id"])
            row = {"id": r["id"], "en": m["en"], "es": m["es"], "src": "manual"} if m else {"id": r["id"], "en": r["en"], "es": r["es"], "src": r["src"]}
            if row["src"] != "manual" and r["id"] in jas:
                row["es"] = repair(jas[r["id"]], row["es"])
            row["explicit"] = r.get("explicit", False)
            n[row["src"].split(":")[0]] += 1
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"translations.jsonl: {dict(n)}")


def cmd_status():
    c = lambda p: len(load(f"{TR}/{p}"))
    print(f"draft {c('draft.jsonl')} · check avisos {c('checks.jsonl')} · audit {c('audit.jsonl')} (sev≥2: "
          f"{sum(r['sev'] >= 2 for r in load(f'{TR}/audit.jsonl'))}) · fix {c('fix.jsonl')}")


def main(a):
    if not a or a[0] in ("-h", "--help"):
        print(__doc__)
    elif a[0] == "sample":
        cmd_sample(float(a[1]) if len(a) > 1 else 2.0)
    elif a[0] in ("draft", "check", "audit", "fix", "export", "status"):
        globals()["cmd_" + a[0]]()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
