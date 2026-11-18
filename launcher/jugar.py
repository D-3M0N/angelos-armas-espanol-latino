#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Lanzador para Windows: abre Angelos Armas con la capa de corrección/traducción (aafix.dll).

Uso:
  python launcher/jugar.py --juego "C:\\Juegos\\AngelosArmas" [--dll build\\aafix.dll] [--texto tabla.tsv]

Necesita: tu copia legal del juego (con nps.exe), aalauncher.exe y aafix.dll compilados (ver README.md).
No incluye ni descarga ningún archivo del juego.
"""
import argparse, os, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def buscar(nombre, candidatos):
    for c in candidatos:
        if c and os.path.isfile(c):
            return os.path.abspath(c)
    sys.exit(f"No encuentro {nombre}. Compílalo (README.md) o indica su ruta.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--juego", default=os.environ.get("AA_GAME_DIR"), help="carpeta con nps.exe (o AA_GAME_DIR)")
    ap.add_argument("--dll", help="ruta a aafix.dll")
    ap.add_argument("--launcher", help="ruta a aalauncher.exe")
    ap.add_argument("--texto", default=os.environ.get("AAFIX_TEXT_TSV"), help="tabla hash<TAB>español del texto del juego (la generas tú)")
    ap.add_argument("--ui", default=os.path.join(REPO, "translations", "ui-es.tsv"), help="tabla de la interfaz Win32")
    a = ap.parse_args()
    if not a.juego or not os.path.isfile(os.path.join(a.juego, "nps.exe")):
        sys.exit("Indica --juego con la carpeta que contiene nps.exe.")
    build = [os.path.join(REPO, "build"), os.path.join(REPO, "build", "Release"), REPO]
    dll = buscar("aafix.dll", [a.dll] + [os.path.join(b, "aafix.dll") for b in build])
    lau = buscar("aalauncher.exe", [a.launcher] + [os.path.join(b, "aalauncher.exe") for b in build])
    env = dict(os.environ, AAFIX_UI_TSV=a.ui)
    if a.texto:
        env["AAFIX_TEXT_TSV"] = os.path.abspath(a.texto)
    sys.exit(subprocess.call([lau, os.path.join(os.path.abspath(a.juego), "nps.exe"), dll], cwd=a.juego, env=env))


if __name__ == "__main__":
    main()
