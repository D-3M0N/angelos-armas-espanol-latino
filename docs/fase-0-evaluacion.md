# Fase 0 — evaluación + bootstrap
> Los ajustes de `CLAUDE.md` («Orden de trabajo», punto 3) mandan sobre este documento. `CLAUDE.md` ya existe: no lo sobrescribas en A.1.

# Contexto
Proyecto «Angelos Armas - Rebirth»: fix de compatibilidad y traducción EN/ES aplicados en runtime para 天使ノ二挺拳銃 -Angelos Armas- (Nitroplus, 28-01-2005, novela visual para Windows, solo binario). Destino: Windows 10/11 x64 y Linux con Wine. Host de trabajo: openSUSE con Claude Code.
- `GAME_DIR` = imágenes de disco del usuario. **Solo lectura.** `INSTALL_DIR` = juego instalado en el prefijo. `WORK_DIR` = este repo. `BUILD_CACHE` = extracciones, capturas y assets generados, fuera del repo.
- Motor propietario de Nitroplus anterior a N2System (por confirmar). Se reporta un script en un único `.npp`. Existe un parche oficial v1.1.200 y una versión china (Seikuu Network): la reinserción de texto es viable.
- Arquitectura objetivo: `AALauncher.exe` (ajustes → proceso suspendido → inyección temprana de `aafix.dll` → resume) + `aafix.dll` (MinHook).

# Decisiones vigentes (no contradecir)
D1-D16 en `docs/decisiones.md`. Resumen: runtime con inyección temprana sin tocar GAME_DIR (D1); i686-w64-mingw32 + CMake + MinHook (D2); `hash → texto` (D3); assets derivados solo en local (D4); repo privado + pre-commit (D5); no eludir DRM (D6); política de contenido por línea (D7, fase 4); escalera de video (D8); avisos legales (D9); sustitución por hash (D10); mapeo SJIS (D11); hoja manual (D12, fase 4: aquí solo reservar `translations/manual/` en .gitignore y anotar en el inventario si el script vincula cada línea con su voz); wrapper gráfico sin reescribir el motor (D13); host en WoW64 nuevo (D14); imágenes de disco → instalación en el prefijo (D15); agente autónomo (D16).

# Tarea: Fase 0, evaluación + bootstrap

## A. Bootstrap del repo y del host
1. `CLAUDE.md`: ya existe (no sobrescribir).
2. Archivos legales (D9):
   - `README.md` con un disclaimer en EN y ES: proyecto de fans no oficial; sin afiliación, patrocinio ni respaldo de Nitroplus Co., Ltd.; «天使ノ二挺拳銃 -Angelos Armas-» y sus marcas, personajes y contenidos © Nitroplus / sus titulares; el repo no contiene ni distribuye archivos del juego; requiere una copia obtenida legalmente; no comercial (sin ventas ni donaciones vinculadas); no se responden peticiones de archivos del juego; aviso de contenido +18.
   - `LICENSE`: MIT para el código propio. Autor: por defecto el usuario de GitHub de `gh api user` o `git config user.name` (anótalo en PREGUNTAS).
   - `translations/LICENSE`: CC BY-NC-SA 4.0 limitado a la aportación propia, con la nota de que los derechos sobre la obra original pertenecen a sus titulares.
   - `THIRD_PARTY_NOTICES.md`: cada dependencia con su licencia (MinHook BSD-2, fuentes OFL, wrappers, libavcodec LGPL si se usa). LAV Filters (GPL) no se incluye: se descarga por script.
   - `TAKEDOWN.md`: los titulares pueden pedir la retirada abriendo un Issue; se atiende retirando el contenido sin discusión. **No publiques ningún email.**
   - Cabecera `SPDX-License-Identifier` en cada fuente propia.
3. Scripts bash idempotentes en `scripts/` (`set -euo pipefail`, detección de apt/dnf/pacman/zypper, `--help`):
   - `00-host-setup.sh`: wine, winetricks, mingw-w64 i686, cmake, ninja, python3, ffmpeg/ffprobe, xvfb, imagemagick, gh, gitleaks, p7zip, shellcheck y plugins GStreamer (64 bits en WoW64 nuevo; 32 bits en clásico: `:i386` en Debian/Ubuntu, `lib32-gst-*` en Arch, `.i686` en Fedora, `-32bit` en openSUSE). Necesita sudo: **no lo ejecutes** (en este host ya está todo).
   - `01-github-auth.sh`: `gh auth login` + `gh auth status`. Nunca guarda tokens dentro del repo.
   - `02-config.sh`: pide y valida `GAME_DIR`, `INSTALL_DIR`, `WINEPREFIX` y `BUILD_CACHE` → `.env.local` (gitignored).
   - `03-wineprefix.sh`: crea el prefijo (64 bits), instala fuentes CJK y sustituciones de fuentes japonesas, CD virtual con las imágenes (D15) y ofrece escritorio virtual (útil en Wayland).
   - `check-no-game-data.sh`: compara los sha256 de todo el historial con los manifiestos de `GAME_DIR` e `INSTALL_DIR` y pasa gitleaks. Sale con código ≠ 0 si encuentra algo.
4. `.gitignore` + `scripts/hooks/pre-commit` (con `core.hooksPath`): bloquea archivos > 1 MB fuera de una allowlist, extensiones de assets detectadas en B, coincidencias de hash con los manifiestos y secretos.
5. `gh repo create aa-rebirth --private` y `git remote add origin …` (el commit y el push los hace run-agent.sh tras la revisión de Opus). Si `gh` no está autenticado: git local, anótalo en PREGUNTAS y sigue con B.

## B. Inventario (solo lectura sobre GAME_DIR e INSTALL_DIR). Cada punto cubre un fallo previsto (F#)
1. `docs/manifest.json`: ruta, tamaño y sha256 (sin contenido). Versión instalada (¿1.1.200 aplicado?) (F14).
2. Nombres de archivo: ¿válidos en UTF-8 o hay mojibake? (F2)
3. Exe: PE32/PE32+, compilador, secciones, imports (ddraw/d3d8/d3d9/dsound/dinput/winmm/quartz/msvfw32/gdi32/imm32/advapi32), recursos y versión.
4. Protección: indicadores de SafeDisc/SecuROM/StarForce, comprobación de CD, packer. Sí/no con evidencia. **No la quites ni la esquives** (F3, D6).
5. Registro: claves que lee el exe (strings `Software\…`, uso de RegQueryValue). ¿Depende del instalador? (F3)
6. Gráficos: API, resolución y profundidad de color, pantalla completa exclusiva o ventana; qué wrapper encaja (cnc-ddraw, dgVoodoo2, DXVK) y su licencia (F4, D13).
6b. Timing: timers importados (timeGetTime, GetTickCount, QueryPerformanceCounter, Sleep, timeBeginPeriod) y si la lógica avanza por frame o por tiempo. Prueba en Wine con cnc-ddraw cargado por `WINEDLLOVERRIDES` desde `BUILD_CACHE`: mide la duración de un mismo fundido con `maxfps=60` y `maxfps=144`. Si cambia más de un 2 % → atado a frames (F13) y anota si `maxgameticks` lo corrige.
7. Formatos: magic bytes y estructura por tipo. Prueba herramientas existentes (GARbro, arc_unpacker, galgamereverse, tools de Saya no Uta y Demonbane) y documenta cuál lee qué. Como mucho, una lectura mínima del índice.
8. Script: ubicación, cifrado o compresión, codificación, líneas y escenas estimadas, códigos de control. **Candidatos a función de texto** para D10: xrefs a TextOutA, ExtTextOutA, GetGlyphOutlineA, DrawTextA y rutinas que recorren bytes SJIS (F9).
9. Render de texto: GDI o fuente bitmap; nombre de la fuente pedida y charset; cómo calcula el avance y el corte de línea (F6, F7, F8).
10. Video: ubicación, contenedor y códec (ffprobe sobre una copia en `BUILD_CACHE`); vía de reproducción (DirectShow RenderFile, VFW o propia); ¿hay voz o diálogo sin texto en el script? ¿cuáles son canciones? (F5, F15, D8)
11. Saves y configuración: ruta. Si escriben en la carpeta del juego o en Program Files, anótalo (F10).

## C. Baseline en Wine (sobre una copia desechable en `cache/run/`)
1. Xvfb + `LANG=ja_JP.UTF-8`, capturas a t = 5, 15 y 30 s en `BUILD_CACHE/baseline/`, log con `WINEDEBUG=err+all,+loaddll`. Llega hasta la OP si se puede (pulsaciones con xdotool).
2. Repite con `LANG=C.UTF-8` para documentar el mojibake.
3. Clasifica cada fallo observado con su F# y la línea del log que lo evidencia (busca `winegstreamer`, `quartz:autoplug`, `ddraw`, `Could not find`, `page fault`).
4. Anota la versión de Wine, el modo WoW64 y si la sesión es X11 o Wayland.

## D. Plan y playbook
1. `docs/playbook-fallos.md`: la tabla F1-F16 del brief con cada fila marcada como **confirmado / descartado / sin evidencia**, con la prueba. Añade los fallos nuevos.
2. `docs/plan-fases.md`: estimación de las fases 1-6, peldaño de D8 recomendado con evidencia, los 5 riesgos principales actualizados y las herramientas de terceros con su licencia.

# Criterio de terminado
- Repo creado (privado en GitHub o local); `check-no-game-data.sh` pasa sobre todo el historial; archivos legales de A.2 presentes.
- `docs/fase0-inventario.md` cubre B.1-B.11 con evidencia, o «no determinado» + el porqué.
- Baseline de Wine documentado en los dos locales, con fallos mapeados a F#.
- `docs/playbook-fallos.md` con el estado de F1-F16.
- Manifiestos de `GAME_DIR` e `INSTALL_DIR` idénticos antes y después (sha256).
- Scripts 00-03 pasan `shellcheck` y `bash -n`.

# Antes de proponer
Busca el estado actual de: herramientas para formatos de Nitroplus 2003-2006 (GARbro, arc_unpacker, parches de fans de Saya no Uta y Demonbane), cómo reinsertó el texto la versión china, Wine estable actual (WoW64 y reproducción de video: GStreamer en quartz, winedmo/FFmpeg en Media Foundation), cnc-ddraw/dgVoodoo2/DXVK para la API detectada, e inyección por imports con mingw (Detours `withdll` o equivalente). Referencias de patrón: thcrap, SenPatcher, YuriSizuku/galgamereverse. Cita cada fuente en una línea.

# Verificación
Ejecuta y reporta evidencia: «verifiqué X con Y». Lo que no puedas verificar (p. ej., Windows 11 real), dilo y deja un checklist para el usuario en `docs/fase-0-informe.md`.

# Límites
- No escribas, muevas ni borres nada en `GAME_DIR` ni en `INSTALL_DIR`.
- No subas al repo assets, script original, capturas del juego, extracciones ni texto japonés del juego. Todo eso va a `BUILD_CACHE`.
- No ejecutes sudo: genera el script y anótalo.
- Si detectas DRM o protección de disco: `docs/BLOQUEADO.md` y termina.
- No escribas el launcher, la DLL ni traducciones en esta fase.
- Sin abstracciones ni archivos que la tarea no necesite.
- Si un enfoque falla 2 veces, detente, replantea la hipótesis y busca cómo lo resolvieron otros.

# Entrega (en `docs/fase-0-informe.md`)
Resumen del inventario (≤ 15 líneas) + estado de F1-F16 en una línea cada uno + hecho / verificado / pendiente + scripts que debe ejecutar el usuario, en orden + máx. 3 riesgos no pedidos. Sin pausa: sigue con la fase 1.
