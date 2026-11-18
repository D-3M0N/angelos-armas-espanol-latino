# Brief — Angelos Armas · fix de compatibilidad + traducción EN/ES

Proyecto: «Angelos Armas - Rebirth» · Slug: `angelos-armas` · Repo: `aa-rebirth` (privado; antes `angelos-armas-fix`) · Creado: 2026-11-15 · Rev. 3: 2026-11-15

## Codebase
- Juego: 天使ノ二挺拳銃 -Angelos Armas- (Tenshi no Nichou Kenjuu), Nitroplus, 28-01-2005, novela visual para Windows, contenido adulto, voces JP, 10-30 h.
- Motor: propietario de Nitroplus anterior a N2System (N2System/.npa es de 2008+). Se reporta el script en un único `.npp`. **Confirmar en fase 0.**
- Solo binario. Exe presumiblemente PE32 (x86), Shift-JIS, DirectDraw/D3D + DirectShow de 2005 (por confirmar).
- Copia del usuario: imágenes BIN/CUE del disco de instalación y del disco de juego + parche oficial v1.1.200 (D15).
- Antecedentes: versión china (Seikuu Network) → la reinserción de texto es viable. Parche EN de 2025 hecho con MT sin revisión y con el render de texto roto, retirado → el anti-ejemplo.

## Origen → destino
Windows 2005 x86 → Windows 10/11 x64 (WOW64) y Linux vía Wine/Proton. Sin recompilar ni parchear el exe en disco: corrección en runtime.

## Objetivo de fondo
1. Jugable de principio a fin en Win11 y Wine sin cambiar el locale del sistema.
2. Idioma seleccionable JA / EN / ES: diálogos, menús, nombres, elecciones, backlog y subtítulos de cinemáticas. Texto en imágenes: fase opcional.
3. Cero modificaciones en la instalación original y cero assets del juego en el repo.
4. Pipeline reproducible (extraer → traducir → QA → empaquetar).
5. Presentación moderna (D13): pantalla completa sin bordes, escalado de calidad, monitores de 60-240 Hz y VRR sin cambiar la velocidad del juego, y mando.

## Opciones de video modernas (D13), configurables en el launcher
- Modo: ventana redimensionable / pantalla completa sin bordes / exclusiva; Alt+Enter; elección de monitor; compatible con HiDPI.
- Escalado: entero, ajustado a 4:3 o estirado. Filtros: nearest, bilinear, sharp-bilinear, lanczos, xBRZ (shaders de libretro).
- Pantallas 16:9/21:9: barras negras por defecto; fondo desenfocado como opción posterior.
- Hz: la presentación va a la tasa del monitor o tiene límite; la lógica del juego sigue a su ritmo original (en cnc-ddraw, `maxfps` separado de `maxgameticks`). VRR en pantalla completa sin bordes.
- Animaciones a más de 60 fps reales: solo si la fase 0 demuestra que el motor anima por tiempo y no por frames. Si anima por frames, no se pueden inventar frames intermedios sin reescribir el motor.
- Mando XInput → acciones (avanzar, saltar, auto, backlog, menú, ocultar ventana).
- Texto en alta resolución (fase 7, opcional): la DLL dibuja el texto de diálogo a la resolución de salida en lugar de escalarlo desde 800×600. Es la mejora visual más grande que se puede lograr sin reescribir el motor.
- Reimplementar el motor (intérprete propio del script + render en SDL3, estilo ScummVM u ONScripter; nativo en Linux, cualquier Hz, todo en alta resolución): **proyecto aparte**. Se decide al final de la fase 2, cuando se conozca el bytecode. Costo muy alto: hay que cubrir el 100 % de los opcodes, efectos y video.

## Arquitectura (ver decisiones.md)
- `AALauncher.exe` (Win32): ventana de ajustes (idioma, ventana/pantalla completa, escala, fixes on/off, cómo mostrar las líneas excluidas) → crea el proceso del exe original suspendido → **inyección temprana** de `aafix.dll` (añadiéndola a la tabla de imports en memoria, estilo Detours `withdll`) para cargar antes de que se resuelvan ddraw/d3d → resume. En Wine: alternativa con `WINEDLLOVERRIDES`/`WINEDLLPATH`.
- `aafix.dll` (MinHook): redirección de lecturas y escrituras (overlay y saves), registro virtual, locale/codepage 932, sustitución de texto en runtime por hash, fuente y glifos latinos, wrapper gráfico, video.
- Overlay = datos de traducción del repo + assets generados **localmente** desde la copia del usuario (`BUILD_CACHE`, nunca en git).

## Carpetas
`GAME_DIR` (imágenes de disco, solo lectura) · `INSTALL_DIR` (juego instalado en el prefijo, solo lectura tras su manifiesto) · `WORK_DIR` (repo) · `BUILD_CACHE` (extracciones, capturas, videos generados; fuera del repo).

## Targets medibles (PC del usuario; Win11 x64 y Linux con Wine estable actual)
- Llega a la pantalla de título en < 5 s, sin locale japonés del sistema.
- Ruta completa sin crash (validación por capítulo).
- QA: 100 % de cobertura de las líneas traducibles, 0 códigos de control rotos, 0 desbordes de la caja de texto, 0 líneas excluidas sin motivo registrado.
- Cinemáticas reproducen en Win11 y Wine; subtítulos ±150 ms.
- Presentación sin tirones a 60, 144 y 240 Hz: frametime de presentación p99 ≤ 1,5 × el periodo de refresco en la escena de referencia.
- La velocidad del juego no depende de los Hz: la duración de un fundido de referencia a 144/240 Hz es igual a la de 60 Hz ±2 %.
- Release < 50 MB, sin assets del juego. Saves compatibles con el original.

## Restricciones
- No escribir en `GAME_DIR` ni en `INSTALL_DIR`. No redistribuir nada derivado byte a byte de los assets.
- Traducciones como `hash → texto`. El japonés original no se versiona.
- Sin secretos. Repo privado. GitHub vía `gh auth login`.
- No eludir DRM ni protección anticopia.
- Política de contenido de la traducción (D7):
  - Escenas sexuales entre personajes claramente adultos: se traduce todo lo narrativo, emocional, de trama y diálogo no explícito. Solo las **líneas** sexualmente explícitas o de violencia sexual quedan en el original (`excluded:explicit`).
  - Escenas sexuales en las que participe un personaje que no sea claramente adulto: escena completa en el original (`excluded:scene`).
  - Violencia y abuso no sexual de la trama: se traducen (es narrativa).
  - Letras de canciones: `excluded:lyrics`, subtítulo «♪».
  - Granularidad por línea, no por palabra: una línea con huecos sigue siendo explícita y además se lee rota.
- Pasos con sudo o interactivos → scripts bash generados por el agente que ejecuta el usuario.

## Hoja de traducción manual (D12)
- `scripts/export-worksheet.sh <en|es|all>` genera en `BUILD_CACHE/worksheet/` (nunca en git) un `.txt` por capítulo con **todo** el texto en orden: líneas traducidas y editables, y líneas `excluded:explicit` con el japonés comentado y los campos vacíos:
  ```
  @scene 012 · Cap. 3 · <resumen de una línea>
  @a1b2c3d4 Wim
  EN: Translated line.
  ES: Línea traducida.

  @e5f6a7b8 Komaki   # Explicit
  # JA: 「……」
  # voz: v_kom_0123
  EN:
  ES:
  ```
- Cada línea excluida lleva contexto (2 líneas antes y 2 después ya traducidas) y la referencia de voz si el script la vincula. `scripts/play-line.sh <id>` la reproduce desde la copia del usuario.
- `scripts/import-worksheet.sh` lee la hoja, toma solo lo que cambió y lo guarda en `translations/manual/{en,es}.tsv` (`hash → texto`). Antes valida: códigos de control, caracteres mapeables (D11) y desborde de la caja de texto, e indica la línea exacta que falla.
- Precedencia en runtime: manual > automática > original.
- `translations/manual/` va en .gitignore por defecto (así el repo se puede hacer público después). Para versionarlo, se quita de .gitignore.
- Recarga en caliente: con el modo desarrollo del launcher activo, F5 en el juego recarga `manual/` sin reiniciar.
- La misma hoja sirve para la revisión humana del resto de la traducción (riesgo 3): cualquier línea editada pasa a `manual/`.
- Las escenas `excluded:scene` no entran en la hoja y el importador rechaza sus IDs.

## Avisos legales en el repo (D9)
`README` con disclaimer (proyecto no oficial, sin afiliación con Nitroplus, marcas y obra de sus titulares, requiere copia legítima, sin archivos del juego, no comercial), `LICENSE` MIT para el código propio, `translations/LICENSE` (CC BY-NC-SA 4.0 solo sobre la aportación propia; los derechos de la obra original son de Nitroplus), `THIRD_PARTY_NOTICES.md`, `TAKEDOWN.md` (retirada inmediata a petición del titular; contacto por GitHub Issues), cabeceras SPDX. Esto reduce el riesgo, no lo elimina, y no es asesoría legal.

## No objetivos
Remaster o reescalado con IA, doblaje, recompilación o port nativo, macOS, móvil.

## Fallos previstos → respuesta
| # | Síntoma | Causa probable | Respuesta |
|---|---|---|---|
| F1 | Mojibake o crash al abrir archivos | ACP ≠ 932; nombres de archivo en SJIS | Hooks de GetACP/GetOEMCP, MultiByteToWideChar(CP_ACP) y CreateFileA → conversión 932 → W. En Wine, además `LANG=ja_JP.UTF-8` |
| F2 | Nombres de archivo corruptos | Copia descomprimida/copiada con la codificación incorrecta | Detectarlo en la fase 0; vista con enlaces simbólicos (sin renombrar el original) |
| F3 | «Insert disc», «not installed» o ruta no encontrada | Claves de registro del instalador o comprobación de CD | Registro virtual por hook de RegOpenKey/RegQueryValue; CD virtual con la imagen del usuario (D15). Si es protección → D6: parar |
| F4 | Pantalla negra, colores rotos, lentitud a 16 bpp, crash al hacer alt-tab | DirectDraw/D3D antiguo en pantalla completa exclusiva | Wrapper gráfico cargado por inyección temprana (cnc-ddraw o dgVoodoo2 según la API; DXVK si es d3d8/9). Modo ventana y escalado por defecto |
| F5 | Video negro o el juego se cuelga en la OP | En Wine faltan plugins GStreamer (64 bits en WoW64 nuevo, 32 bits en clásico); códec legacy | Plugins base/good/bad/ugly/libav. Si no basta, escalera D8 |
| F6 | Tofu o fuente incorrecta | La fuente japonesa pedida («ＭＳ ゴシック») no existe en Wine | Sustitución de fuentes en el prefijo + fuente OFL incluida y cargada con AddFontMemResourceEx |
| F7 | Acentos y ñ rompen el texto o se comen el carácter siguiente | Bytes Latin-1 (p. ej. á = 0xE1) son bytes iniciales de SJIS | D11: mapear no-ASCII a códigos de la zona de usuario de SJIS (0xF040-0xF9FC) y renderizarlos con el hook de fuente |
| F8 | Texto latino espaciado como si fuera de ancho completo, cortes a mitad de palabra | Avance fijo y wrap por carácter del motor | Hook de medida/avance de glifos + word-wrap propio en la sustitución |
| F9 | Saltos y offsets rotos tras reinsertar el script | Bytecode con offsets absolutos | D10: sustitución en runtime por hash en la función de texto; reconstruir el script solo como plan B |
| F10 | Partidas guardadas en Program Files (virtualizadas) o en la carpeta del juego | Diseño de 2005 | Redirigir las escrituras a `%APPDATA%\AngelosArmasFix` |
| F11 | Defender/SmartScreen marca el launcher | Inyección de DLL sin firmar | Sin packers, build reproducible, hashes publicados, inyección por imports en lugar de CreateRemoteThread. Documentarlo en el README |
| F12 | Ventana diminuta o estirada en Wayland | No hay cambio de modo de pantalla | Modo ventana + escalado en el wrapper; opción de escritorio virtual de Wine en el script |
| F13 | Animaciones aceleradas a 120/144 Hz | Lógica atada al vsync | Separar presentación y lógica: `maxfps=-1` + `maxgameticks=60` (cnc-ddraw) o hook de timers |
| F14 | Hooks que fallan según la versión | 1.0 vs 1.1.200 | Firmas por patrón (no direcciones fijas) + verificación de versión con el manifiesto de hashes |
| F15 | Cinemáticas con voz sin texto en el script | Diálogo solo en el audio | ASR local (whisper.cpp) sobre la copia del usuario para obtener tiempos y texto JP; nada de eso se versiona |
| F16 | Traducción inconsistente (nombres, términos) | Texto por lotes sin memoria | Glosario versionado, resumen por escena como contexto, QA automática de términos |

## Riesgos conocidos
1. Formato de script desconocido o cifrado.
2. Protección de disco → bloqueante; decide el usuario.
3. Calidad de la traducción automática → glosario, contexto y revisión humana por muestreo (≥ 5 % por capítulo).
4. Costo en tokens de traducir 10-30 h de texto → procesar por lotes con caché por hash; no re-traducir lo ya aprobado.
5. Contenido adulto en GitHub → repo privado.
6. Texto incrustado en imágenes → fase opcional, generado localmente.

## Escena de referencia
Partida nueva → OP (primera cinemática) → primera escena con texto hasta la primera elección. Misma resolución, mismo prefijo de Wine y mismo build.

## Fases
0. Evaluación + bootstrap (repo, avisos legales, scripts del host, playbook de fallos). Antes: conversión de discos e instalación en el prefijo (D15).
1. Compatibilidad: launcher, inyección temprana, locale, registro, gráficos, saves.
2. Pipeline de texto: localizar la función de texto, hash, sustitución en runtime, prueba de ida y vuelta.
3. Render latino: fuente, mapeo SJIS, avance proporcional, word-wrap.
4. Traducción EN → ES: glosario, clasificación de contenido (D7), QA y revisión.
5. Cinemáticas: escalera D8 + subtítulos.
6. UI de ajustes completa (incluidas las opciones de video D13), release y validación en Win11 y Wine (WoW64 nuevo y clásico).
7. (Opcional) Texto de diálogo en alta resolución.
