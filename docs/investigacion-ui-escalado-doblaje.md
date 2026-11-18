# Interfaz, escalado y doblaje · investigación y estado (2026-11-17)
Alcance: D22. Estado de cada punto: **hecho y verificado**, **hecho sin verificar en pantalla real**, o **investigado**.

## 1. Interfaz en japonés (menú del clic derecho, ajustes) · HECHO
**Causa (verificada):** son recursos Win32 de `nps.exe` (5 menús, 10 diálogos, 2 tablas de cadenas; `wrestool --raw` + parser propio). `translations/ui-es.tsv` ya traía 105 textos, pero ningún código los leía: aafix solo traducía el texto del motor (`0x42c7d0`, por hash).
**Solución:** `src/aafix/ui.c`, cargado por `aafix.c` (`ui_init`). Tabla `AAFIX_UI_TSV` (o `ui-es.tsv` junto a la DLL), hash FNV-1a64 del texto cp932 original → texto UTF-16. **El español nunca pasa por cp932** (á é í ó ú ñ ¿ ¡ no existen allí; el truco D11 solo vale para el rasterizador del motor): todo se aplica con APIs W.
| Elemento | Hook | Verificación |
|---|---|---|
| Menú emergente (109/110), menú del registro (140), deslizador (134) | `LoadMenuA` → recorre el menú y `SetMenuItemInfoW` | captura aislada del menú 109 en español, acentos OK; estático en `nps.exe`: `0x422d4c` `push 6Dh`+`LoadMenuA` → `GetSubMenu(m,0)` (global) → `TrackPopupMenu` en `0x422e84`; 2.º camino en `0x401784`. **No visto aún dentro de una escena** |
| Diálogos de ajustes (135-139) y marco (106) | `DialogBoxParamA`/`CreateDialogParamA` instalan `WH_CALLWNDPROCRET`; en `WM_INITDIALOG` traduce el título y los hijos | 5 páginas aisladas + ajustes reales en el juego; lectura de vuelta: 0 «LOSSY» |
| Pestañas | `SendMessageA` `TCM_INSERTITEMA` → `TCM_INSERTITEMW` | juego real: Básico/Texto/Sonido/Versión/Atajos |
| Avisos | `MessageBoxA` → `MessageBoxW` | solo aislado |
| Comentario de guardado (130) | mismo mecanismo | captura aislada OK («Editar comentario», Aceptar/Cancelar) |
| Título y textos dinámicos (nombres de personaje, info del sistema) | `CreateWindowExA` (solo nivel superior), `SetWindowTextA`, `SetDlgItemTextA` + fragmentos | juego real: «Angelos Armas», lista de personajes, «Resolución de pantalla… Libre/Total» |
**Maquetación:** el español es 1,5-2× más largo y los controles tienen ancho fijo → `fit_ctl`: ensancha hasta el vecino de la derecha y, si no cabe, reduce la fuente (mín. 70 %). Margen del 12 % porque la fuente de dibujo puede diferir de la medida.
**Trampa encontrada:** traducir en `CreateWindowExA` también cambiaba los controles hijos (Wine crea así los controles de diálogos ANSI) *antes* de `WM_INITDIALOG`, y el ajuste de tamaño nunca corría (texto cortado). Por eso ese hook se limita a ventanas sin `WS_CHILD`.
**Pendiente:** el menú del clic derecho dentro de una escena real (solo probado aislado; el clic del arnés Xvfb falla ~1 de 3, F17). Texto dentro de imágenes (logo, botones START/LOAD/CONFIG del título, en `cg.npp`): sigue en japonés/inglés, fuera de este cambio.
**Reversión:** `AAFIX_NO_UI=1` desactiva todo; o restaurar `cache/run/npmm.dll.pre-ui`. Si lanzas `wine nps.exe` a mano (sin `jugar.sh`), la DLL usa `ui-es.tsv` junto a ella (copiado en `cache/run/`).
**Ampliar la tabla:** `AAFIX_UI_TRACE=1` + `AAFIX_LOG=...` escribe `UIMISS` con hash y bytes cp932 de lo no traducido (solo para local, nunca al repo).

### Precedentes en otras novelas de Nitroplus
- **Kishin Hishou Demonbane (Nitroplus 2006), parche EN de Starry Wisdom, abril 2026** ([página del parche](https://starrywisdomtranslation.blogspot.com/p/kishin-hishou-demonbane.html), [noticia](https://www.timeextension.com/news/2026/04/the-wait-is-finally-over-japanese-visual-novel-kishin-hishou-demonbane-has-been-translated-into-english)): exige instalar el juego japonés y poner el *locale* del sistema en Japón; no traduce los menús; avisa de que los menús emergentes (guardar, cargar, ajustes) **cuelgan el juego** y hay que usar las teclas S, L y C; solo admite caracteres japoneses, chinos e ingleses («Iä» pasa a «Ia»); deja los nombres sin traducir para que casen con los archivos de voz. Lo que hicimos: `LC_ALL=ja_JP.UTF-8` (equivalente al *locale* Japón), caracteres latinos por D11, menús traducidos. **Riesgo a vigilar:** si el menú emergente cuelga también aquí (no se ha visto), las teclas S/L/C y la pantalla completa son la salida.
- **Otros motores de Nitroplus:** `nipa`/`libnpa` ([nipa](https://github.com/FGRE/nipa), [libnpa](https://github.com/FGRE/libnpa)) extraen `.npa` del motor N2System (6 juegos de Nitro+/Nitro+CHiRAL). No es este motor (aquí `.npp`), no aplica.
- **Técnica parecida a la nuestra:** [VNTranslationTools](https://github.com/arcusmaximus/VNTranslationTools) usa una DLL proxy (`d2d1.dll`, o `version.dll` como alternativa) que dibuja caracteres no-SJIS con una tabla de mapeo → mismo patrón que `npmm.dll` + D11. [LiViNo](https://adriancourreges.com/projects/livino-reader/) engancha `GetGlyphOutlineW`; nosotros `GetGlyphOutlineA`.
- *Locale* japonés en Wine: [bug 57540](https://list.winehq.org/archives/list/wine-bugs@list.winehq.org/thread/YAENKOB5LO64OHOSVMAVNADFX7KY473V) (discusión sobre `ja_JP.SJIS` frente a `ja_JP.UTF-8`; un desarrollador pide ejemplos que fallen con UTF-8). Aquí `ja_JP.UTF-8` funciona.
No encontré ninguna fuente sobre cómo tradujo Starry Wisdom (u otro equipo) los recursos del `.exe`; el hook por API es solución propia.

## 2. Ventana completa mal escalada · REPRODUCIDO, SOLUCIÓN SIN VERIFICAR EN PANTALLA REAL
**Reproducción (Xvfb 1920×1080, tecla F del juego):** el juego pasa a «pantalla completa» pero pinta su superficie de 800×600 sin escalar, pegada a la esquina, con restos duplicados del fotograma anterior en el escritorio. Wine no escala por sí mismo ([bug 39768](https://list.winehq.org/hyperkitty/list/wine-bugs@list.winehq.org/thread/LOVFWSBXRV47B3LBBEB76EZTH2FCARRR/), abierto): hay que escalar fuera del juego.
**Opciones:**
1. **gamescope** (instalado; Vulkan NVIDIA disponible): `scripts/jugar-gamescope.sh` → el juego queda en 800×600 y gamescope lo lleva al monitor (`-S fit` conserva 4:3; `GS_SCALER=integer GS_FILTER=nearest` = píxel perfecto; `GS_FILTER=fsr` más nítido). Es la receta habitual para juegos de 800×600 en Linux ([guía de escalado entero](https://www.gamingonlinux.com/2020/11/testing-integer-scaling-with-valves-gamescope-micro-compositor-for-linux/page=2)). **No usar la tecla F dentro del juego.**
2. **cnc-ddraw** ([repo](https://github.com/vogonsorg/CnCNet-cnc-ddraw)): escala dentro del proceso (`renderer=opengl`, `maintas=true`; receta de [CodeWeavers](https://www.codeweavers.com/compatibility/crossover/tips/pharaoh-cleopatra/fixes-to-get-cleopatra-running-without-a-black-screen) con DLL nativa). En este proyecto dio blanco (gdi) / negro (opengl) **solo bajo Xvfb** (sin GL real), nunca se probó en el X11 real; además reescribe coordenadas del ratón y chocaría con la corrección F17 (`g_f17_dy=34`, medida bajo openbox).
3. Escritorio virtual de Wine: no escala el contenido. dgVoodoo2 no aplica (el juego usa DirectDraw 1.x, sin D3D).
**Verificado:** con `GS_BACKEND=headless`, Wine arranca dentro de gamescope y aafix carga (log). **Sin ver:** cómo se ve en pantalla.
**Probar:** `scripts/jugar-gamescope.sh` en tu sesión. Mira (a) que el juego llene la pantalla con barras negras, (b) que START/CONFIG respondan donde clicas (la corrección F17 podría necesitar `AAFIX_NO_F17=1` o ajustar `AAFIX_F17_DY` dentro de gamescope, que no pone barra de título), (c) que el cursor no se escape en monitores múltiples.

## 3. «Doblaje» del contenido erótico · INVESTIGADO (hace falta una aclaración)
Dos lecturas posibles; el estado de cada una:
**A. Traducción (texto) de las líneas `explicit`:** ya existe el borrador local completo (2226 líneas `explicit` en 246 escenas; sin ninguna `excluir`; 86 `lyrics` quedan en el original). Por D7/D20 solo lo ve el modelo local, no Claude. Para mejorar su calidad sin cuota: modelos locales entrenados para novelas visuales (ya se usa `vntl-llama3-8b-v2`; hay una [tabla de VNTL](https://www.huggingface.co/datasets/lmg-anon/vntl-leaderboard/blob/57b8f36811f2dbdd2564e3e64c75e6dfc2f6e7d8/README.md), pero solo 256 pares y sin ES) y repasar con un segundo modelo local (JA→EN→ES ya es la ruta). La revisión humana (D12, `import-worksheet.py`) sigue siendo lo único que da calidad final. No encontré fuente fiable que compare modelos locales para contenido adulto JA→ES: hay que medir con `scripts/bakeoff.py` sobre una muestra que el usuario lea.
**B. Voz (doblar al español):** hoy las voces están en `voice.npp` en japonés. Brief (`docs/brief.md:88`) lo deja fuera; sería una fase nueva.
| Modelo (fuentes: blogs, no verificado) | Licencia | Español | Notas |
|---|---|---|---|
| [Chatterbox Multilingual](https://archy.net/from-qwen3-tts-to-chatterbox-finally-getting-voice-cloning-right/) | MIT | sí (23 idiomas) | clonado con 7-10 s; usar referencia en el mismo idioma para no arrastrar acento |
| Qwen3-TTS ([comparativa](https://pinggy.io/blog/best_open_source_self_hosted_text_to_speech_models/)) | Apache-2.0 | sí | clona con ~3 s; un usuario necesitó fijar semilla y recortar audio |
| CosyVoice 3 (mismas fuentes) | Apache-2.0 | sí | control de pronunciación |
| Fish Audio S2 / Fish Speech | No comercial (fuentes discrepan) | sin dato | solo uso personal |
| XTTS-v2 | Coqui Public Model License | sí | restricciones comerciales |
| Piper / Kokoro ([comparativa](https://www.codesota.com/text-to-speech/piper-vs-kokoro)) | MIT (repo original) / Apache-2.0 | Piper: voces es-ES y es-MX; Kokoro: no confirmado | no clonan; calidad menor |
Ninguna fuente trata política de contenido adulto: hay que leer la tarjeta de cada modelo y generar **solo en local**. GPU: RTX 4060 Ti de 8 GB; los modelos de ~0,5-2 B caben, pero compartiría VRAM con Ollama (pausar uno).
**Cómo encajaría (esbozo, no hecho):** (1) analizar `voice.npp` y cómo el guion referencia cada voz (no hay análisis aún: bloqueo principal); (2) contar líneas con voz en las 246 escenas `explicit`; (3) TTS local por línea con una voz por personaje; (4) paquete de reemplazo servido por la redirección de archivos de aafix (ya existe para saves) o por un proxy de lectura en `npmm.dll`; (5) los nombres en pantalla ya van en español y la voz sería ES, pero el sincronismo de la caja de texto no cambia.
**Límites (míos y del proyecto):** no clonar las voces de las actrices/los actores originales sin su consentimiento (usar voces sintéticas diseñadas o una referencia propia con permiso); solo líneas `explicit` entre personajes claramente adultos (D7/D20), nunca `excluir`; no distribuir audio generado (D8: nada derivado se publica, todo se genera en local).

## 4. Pendientes y preguntas
- ¿«Doblaje» es A (texto) o B (voz)? Si es B, ¿para todo el juego o solo las escenas `explicit`?
- ¿También el texto dentro de imágenes (logo, START/LOAD/CONFIG, pantallas de guardado en `cg.npp`)? Es otra fase (regenerar imágenes).
- Probar `scripts/jugar.sh` (menú e interfaz) y `scripts/jugar-gamescope.sh` (escalado) en pantalla real y anotar fallos en `docs/BUGS-USUARIO.md`.
