# Fase 0 · C Baseline en Wine

Entorno: Wine 11.21, WoW64 nuevo, sesión X11 del host (el juego corre bajo Xvfb propio 1024×768×24, renderizado por llvmpipe/wined3d). Script: `scripts/05-baseline.sh <locale>` (copia desechable con symlinks en `cache/run/`, D: = Game Disc, `WINEDEBUG=err+all,+loaddll`). Capturas y logs en `cache/baseline/<locale>/` (no se commitean).

## Resultados (ejecutado en `ja_JP.UTF-8` y `C.UTF-8`)
| | ja_JP.UTF-8 | C.UTF-8 |
|---|---|---|
| Arranca sin pedir disco | sí | sí |
| `err:` en el log (242 líneas) | 0 | 0 |
| t=5 s | aviso «18 años» (clasificación) | ídem |
| t=15 s y t=30 s | pantalla de título completa | ídem |
| Título de ventana (xdotool) | `天使ノ二挺拳銃　-Angelos Armas-` | `??????? -Angelos Armas-` |
| Ventanas | 800×600 en (112,97) + barra 460×30 | ídem |

- **Mojibake (F-locale):** el único efecto observado con `C.UTF-8` es el título de ventana (`CreateWindowA` con cp932 convertido con ACP 1252/UTF-8 → `?`). El título del juego y el menú son imágenes, no texto. No se ha comprobado el texto del script porque no se llegó a la OP.
- Diferencia entre logs fuera del tema de rutas: solo el idioma del mensaje de «cookie» (permiso denegado). 
- Cargas relevantes (`+loaddll`): `NPMM.dll` nativa (copia local), `DDRAW`, `WINMM`, `dsound`, `QUARTZ` builtin. No aparece `winegstreamer` ni `quartz:autoplug` hasta el título (el vídeo no se ha reproducido aún) → F5 **sin evidencia** en este tramo.
- Otros avisos: `fixme:d3d:wined3d_guess_card` (llvmpipe, esperable en Xvfb), `fixme:wineusb` (ruido). Ningún `page fault` ni `Could not find`.

## No conseguido (sin verificar)
- **Pulsar START:** `xdotool` (mousemove + click, y mousedown/up con pausas, y Return) no hizo avanzar el título en 2 intentos distintos (capturas a +8 s idénticas). No sé si es por foco/XTEST, por DirectInput o porque la región es otra. Por la regla de «2 fallos», no insisto: siguiente hipótesis a probar (a) `xdotool` con `--window` o `xdotool windowfocus` previo, (b) mover el ratón dentro de la ventana en pasos pequeños antes, (c) teclas distintas de Return (el menú puede usar flechas/espacio). Por tanto **no se llegó a la OP ni a la primera escena**: no se ha probado el vídeo (F5), el texto del script (F6-F9) ni el guardado (F10).
- No se ha probado sobre Win10/11 real.

## Clasificación F#
- F-locale/ACP (L-1 del playbook): confirmado solo para el título de ventana con locale distinto de ja_JP.
- F5 (vídeo), F6-F9 (texto), F10 (saves), F13 (timing): **sin evidencia**, pendientes de llegar a la escena de referencia.
