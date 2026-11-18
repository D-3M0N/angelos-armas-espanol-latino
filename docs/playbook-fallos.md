# Playbook de fallos (registrar los nuevos aquí)

## L-1 · ACP=1252 / mojibake en el instalador (2026-11-14)
Síntoma: textos y carpeta de instalación en Shift-JIS mostrados como cp1252; `reg` y `chcp` salen con `????`.
Causa: el entorno del usuario trae `LC_CTYPE=es_ES.UTF-8`, que gana a `LANG=ja_JP.UTF-8`; Wine fija ACP 1252.
Verificado: con `LC_ALL=ja_JP.UTF-8` el registro devuelve `ACP=932` en el mismo prefijo; con el entorno anterior, 1252.
Arreglo: exportar `LC_ALL=ja_JP.UTF-8` (hecho en `scripts/lib-wine.sh`). Aún sin reinstalar con 932 (ver PROGRESO).

## L-2 · Cuelgue en wineboot por wine-mono/gecko
Causa: diálogo de instalación bajo Xvfb. Arreglo: `WINEDLLOVERRIDES=mscoree,mshtml=d`.

## Estado F1-F16 (2026-11-15, Wine 11.21 WoW64 nuevo, Xvfb 1024×768; sin Win10/11 real)
Estados: **confirmado** / **descartado** / **sin evidencia** (no probado en ejecución). Evidencia en `docs/fase-0-B-inventario.md` (B) y `docs/fase-0-C-baseline.md` (C).
| # | Estado | Prueba |
|---|---|---|
| F1 | confirmado (parcial) | Con `C.UTF-8` el título de ventana sale `???????` (C); L-1 para el instalador. Texto del script no probado |
| F2 | descartado para los archivos del juego | INSTALL_DIR 10/10 nombres ASCII (B.2). La carpeta mojibake salió del instalador con ACP 1252 (L-1), ya renombrada |
| F3 | descartado como bloqueo con CD virtual | `GetDriveTypeA`/`GetVolumeInformationA` (B.4); con `D:`→Game Disc y etiqueta TENSHI_GAME arranca (C). Sin probar sin CD ni sin la clave de registro |
| F4 | sin evidencia | Arranca en ventana 800×600, 0 `err:` (C); modo/profundidad de DirectDraw no medidos; Win real no probado |
| F5 | sin evidencia | No se llegó a la OP; no se cargó `winegstreamer`/quartz (C). OP: MPEG-1 800×608 + MP2 (B.10) |
| F6 | confirmado (solo diálogos del sistema) | El cuadro «¿salir?» de Windows muestra cuadrados (tofu) en Xvfb con ja_JP; el texto propio del juego sin probar |
| F7 | sin evidencia | B.9 estático: `GetGlyphOutlineA` con código DBCS; sin traza en ejecución |
| F8 | sin evidencia | B.9: métricas gmCellIncX/BlackBox, sin comprobar cuál se usa |
| F9 | sin evidencia | Script = cp932 con etiquetas (B.8); no se ha localizado la función de texto en ejecución |
| F10 | sin evidencia | Cadenas `./data/save/…` en el binario (B.11); escritura real no observada |
| F11 | sin evidencia | Aún no hay launcher |
| F12 | sin evidencia | Solo X11 |
| F13 | sin evidencia | Importa `timeGetTime`, `QueryPerformanceCounter`, `GetTickCount`, `Sleep` (B.6b); no medido |
| F14 | sin evidencia | Solo existe 1.1.200 (manifiesto); sin versión 1.0 para comparar |
| F15 | sin evidencia | Sin audio analizado |
| F16 | sin evidencia | Aún no hay traducción |

## F17 · RESUELTO (2026-11-15): el clic cae ~14 px por encima del botón visual
Causa (evidencia): el juego calcula el ratón en `FUN_004212e0` (nps.exe) como `GetCursorPos − GetWindowRect − SM_CXFRAME`, y en Y resta `SM_CYCAPTION + SM_CYMENU + SM_CYFRAME` (Ghidra); no hay menú, así que la zona activa queda desplazada. Barrido `scripts/08-f17-barrido.sh` (openbox + windowactivate): con la ventana en (109,68) el hover de START cambia la captura a y=600 (no a y=614, donde se ve el botón) y un clic en (300,600) entra en la partida (primera escena visible). Los intentos anteriores clicaban sobre el botón visual, por eso «no determinista».
Para aafix: hook de `GetSystemMetrics` (SM_CYMENU→0 y revisar SM_CXFRAME/SM_CYFRAME) o `AdjustWindowRect`; sin verificar si el offset es el mismo en Windows real.

### Historial F17 (diagnóstico previo)
Síntoma: en el título, ni clics (START/LOAD/CONFIG) ni teclas avanzan; la pantalla queda idéntica byte a byte.
Observado: los mensajes llegan (`+message`: WM_MOUSEMOVE con coordenadas de cliente correctas, WM_LBUTTONDOWN/UP, WM_KEYDOWN Return/Escape); `windowfocus` da WM_SETFOCUS; el hilo principal está en `poll` (vivo, ~10 % CPU). Escape **sí** abrió el cuadro de salida en una ejecución; en otra, una tecla Derecha resaltó START y nada más; en una tercera, nada. Resultado no determinista.
Descartado: no importa dinput (B.3), así que no es DirectInput; foco y movimiento gradual del ratón no cambian nada.
Intento cnc-ddraw 2026-11-15: gdi→blanco, opengl/auto→negro (ver PROGRESO); sin resolver.
Descartado 2026-11-15 (`scripts/07-f17-traza.sh`): (a) el juego SÍ ve el ratón: `GetCursorPos` (hilos sondeando sin parar) pasa de (512,384) a (300,614) tras mover; (b) no es captura: con espera de 70 s sigue idéntico; (c) no es la espera; sin gestor de ventanas, con openbox y con `explorer /desktop=aa,800x600` (ventana en 0,0) el clic no cambia nada. En desktop, WM_LBUTTONUP llega a la ventana principal con lParam correcto (190,517 cliente) y devuelve 0. nps.exe NO importa GetAsyncKeyState/GetKeyState/GetForegroundWindow/SetCapture; sí GetActiveWindow (×2), PeekMessageA, GetMessageA.
Hipótesis pendientes: el menú del título está condicionado por GetActiveWindow o por un estado interno (p. ej. espera de un evento/hilo) y no por la entrada; (d) cnc-ddraw con `renderer=direct3d9`/software; (e) desensamblar con Ghidra el wndproc (WM_LBUTTONUP) y las 2 llamadas a GetActiveWindow; (f) `+relay` en el hilo principal tras el clic para ver qué llama.
