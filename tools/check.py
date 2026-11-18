#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""check.py · reglas duras sin IA. La usan los hooks de git (pre-commit: --staged, pre-push: --tree).
Falla si hay: rutas prohibidas (game/, cache/, prefix/), extensiones de asset, archivos > 1 MB, volcados de texto
japonés (≥ 8 líneas con ≥ 6 kana/kanji seguidos), secretos, sintaxis rota (sh/py) o cambios en .aa-allow."""
import sys as _s
for _x in (_s.stdout, _s.stderr):
    try: _x.reconfigure(encoding='utf-8', errors='replace')
    except Exception: pass
import ast, fnmatch, os, re, shutil, subprocess, sys

mode = sys.argv[1] if len(sys.argv) > 1 else "--staged"
top = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
os.chdir(top)


def git(*a):
    return subprocess.run(["git", *a], capture_output=True, text=True).stdout


files = git("diff", "--cached", "--name-only", "--diff-filter=ACMR").split("\n") if mode == "--staged" else git("ls-files").split("\n")
files = [f for f in files if f and os.path.isfile(f) and "__pycache__" not in f]
allow = []
if os.path.exists(".aa-allow"):
    allow += [l.strip() for l in open(".aa-allow", encoding="utf-8") if l.strip() and not l.startswith("#")]
ok = lambda f: any(fnmatch.fnmatch(f, g) for g in allow)
errs = []
BAD_EXT = re.compile(r"\.(bin|cue|iso|npp|npa|pak|mpg|mpeg|wmv|avi|dat|exe|dll|bmp|png|jpe?g|wav|ogg|mp3|cab|bak|log|jsonl|sav|zip|7z|rar|ttf|otf)$", re.I)
JP = re.compile(r"[぀-ヿ一-鿿]{6,}")
SECRET = re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}|sk-ant-oat\d+|gh[pousr]_[A-Za-z0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|CLAUDE_CODE_OAUTH_TOKEN=\S{20,}")

if mode == "--staged" and ".aa-allow" in files:
    tracked = subprocess.run(["git", "cat-file", "-e", "HEAD:.aa-allow"], capture_output=True).returncode == 0
    body = [l for l in open(".aa-allow", encoding="utf-8") if l.strip() and not l.startswith("#")]
    if tracked or body:
        errs.append(".aa-allow cambió: lo aprueba el usuario, no el agente")
for f in files:
    if f.startswith(("game/", "cache/", "prefix/")):
        errs.append(f"{f}: ruta prohibida en el repo")
        continue
    if ok(f):
        continue
    if BAD_EXT.search(f):
        errs.append(f"{f}: extensión de asset/binario/log")
        continue
    if os.path.getsize(f) > 1_048_576:
        errs.append(f"{f}: > 1 MB")
        continue
    try:
        text = open(f, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        errs.append(f"{f}: binario o no UTF-8")
        continue
    n = sum(1 for l in text.splitlines() if JP.search(l))
    if n >= 8 and not f.startswith("docs/historial/"):
        errs.append(f"{f}: {n} líneas con japonés (¿texto del juego?)")
    if SECRET.search(text):
        errs.append(f"{f}: parece contener un secreto")
    if f.endswith(".py"):
        try:
            ast.parse(text)
        except SyntaxError as e:
            errs.append(f"{f}: {e}")
    elif f.endswith(".sh") and shutil.which("bash"):
        if subprocess.run(["bash", "-n", f], capture_output=True).returncode:
            errs.append(f"{f}: bash -n falla")
        elif shutil.which("shellcheck"):
            r = subprocess.run(["shellcheck", "-S", "warning", "-f", "gcc", f], capture_output=True, text=True)
            if r.returncode:
                errs.append(f"{f}: shellcheck: " + (r.stdout.strip().splitlines() or ["?"])[0][:160])
if errs:
    print("check.py ✖ (reglas duras; corrige y vuelve a intentar):")
    print("\n".join("  " + e for e in errs[:15]))
    sys.exit(1)
print(f"check.py ✔ {len(files)} archivos")
