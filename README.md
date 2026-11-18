# Angelos Armas — Español Latino

Proyecto de fans, **no oficial y sin fines de lucro**: corrección de compatibilidad (Windows 10/11 y Wine) y capa de traducción al español en tiempo de ejecución para *天使ノ二挺拳銃 -Angelos Armas-* (Nitroplus, 2005). Contenido para **mayores de 18 años**.

> **Aviso legal.** Este repositorio **no contiene** archivos, texto ni recursos del juego, ni parches que los incluyan. Necesitas tu propia copia legal. Sin afiliación, patrocinio ni respaldo de Nitroplus Co., Ltd.; el juego, sus marcas, personajes y contenidos son © Nitroplus / sus titulares. Si eres titular de derechos y quieres que se retire algo, mira [`TAKEDOWN.md`](TAKEDOWN.md).
> **Disclaimer (EN).** Unofficial, non-commercial fan project. No game files or game text are included; you must own a legal copy. No affiliation with Nitroplus Co., Ltd.

## Qué incluye

| Carpeta | Contenido |
|---|---|
| `src/aafix/`, `src/launcher/` | Código en C: DLL de corrección/traducción (`aafix.dll`, o `npmm.dll` como proxy) y lanzador (`aalauncher.exe`). |
| `translations/ui-es.tsv` | Traducción original al español de la interfaz Win32 del juego (menús, diálogos), indexada por hash (sin texto japonés). |
| `tools/` | Herramientas en **Python** (solo biblioteca estándar) que corren en Windows, Linux y macOS. |
| `launcher/jugar.py` | Lanzador en Python para Windows. |
| `linux/` | Scripts bash para el flujo con Wine (opcional, solo Linux). |
| `docs/` | Documentación generada por IA (Claude) en español: decisiones, informes y fallos conocidos. |

El texto de la historia **no** se publica: lo extraes tú de tu copia con `tools/extract-text.py` y se queda en tu equipo.

## Requisitos en Windows
- Python 3.9 o superior (`python --version`).
- Tu copia legal del juego, ya instalada y parcheada a la versión 1.1.200 oficial.
- Para compilar el hook: CMake ≥ 3.20, MinGW-w64 (32 bits, `i686`) o equivalente, y [MinHook](https://github.com/TsudaKageyu/minhook) en `third_party/minhook` (no se incluye).

## Compilar (32 bits)
```bat
cmake -S . -B build -G "MinGW Makefiles" -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc
cmake --build build
```
Genera `build\aafix.dll`, `build\npmm.dll` y `build\aalauncher.exe`.

## Jugar
```bat
python launcher\jugar.py --juego "C:\Juegos\AngelosArmas"
```
Opcional: `--texto mi_tabla.tsv` con tu tabla `hash<TAB>texto` para el texto de la historia (formato en `docs/decisiones.md`, D3). La interfaz usa `translations\ui-es.tsv`.

## Herramientas (`tools/`)
```bat
python tools\extract-text.py "C:\...\script.npp" salida\      :: indexa el texto por hash (no publiques la salida)
python tools\validate-table.py mi_tabla.tsv salida\index.tsv  :: valida tu tabla
python tools\translate.py --help                              :: borrador por capas (Ollama; opcional Claude)
python tools\check.py --tree                                  :: revisa que el repo no tenga datos del juego
```
Variables: `AA_ROOT` (carpeta de trabajo, por defecto `~/angelos-armas`), `AA_GAME_DIR`, `OLLAMA_HOST`, `AA_LOCAL_MODEL`.
Sin `cache/text/modelos.json` se usan `AA_MODEL_JA_EN` / `AA_MODEL_EN_ES` (por defecto `qwen3:8b`).

## Estado y limitaciones
- Desarrollado y probado sobre Linux con Wine; **las herramientas Python y el lanzador de Windows no se han probado en un Windows real**. Hay un checklist en `docs/checklist-win-real.md`. Reporta fallos en *Issues*.
- Los documentos y buena parte del código los escribió una IA bajo supervisión del autor; revísalos antes de confiar en ellos.

## Licencias
Código: MIT ([`LICENSE`](LICENSE)). Traducciones propias en `translations/`: CC BY-NC-SA 4.0 ([`translations/LICENSE`](translations/LICENSE)). Terceros: [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
