# Fase 0 · B.1-B.5 — inventario de ejecutables
Generado con `scripts/inspect-pe.py` (stdlib, solo lectura) sobre INSTALL_DIR el 2026-11-14. Sin contenido del juego.

## B.1 Manifiesto y versión (F14)
- Manifiestos locales (no versionados, contienen solo ruta/tamaño/sha256): `cache/manifest-install.json` (10 archivos, 1,1 GB), `cache/manifest-game.json` (6). `docs/manifest.json` público aún no se genera (pendiente: decidir si se publica).
- Parche 1.1.200 aplicado: `scripts/03-patch.sh --verify` → OK para nps.exe, NPMM.dll, script.npp y update.npp (sha256 iguales a los extraídos del parche). nps.exe con fecha de enlace 2005-01-31.
- FileVersion interno de nps.exe = «1, 0, 0, 1» (no refleja 1.1.200; la versión real la reportan update.ini/update.npp).

## B.2 Nombres de archivo (F2)
Los 10 archivos de INSTALL_DIR son ASCII (`*.npp`, `nps.exe`, `npmm.dll`, `COPYING.txt`). Sin mojibake. Los nombres internos de los .npp se ven en B.7.

## B.3 Ejecutables
| | nps.exe | npmm.dll |
|---|---|---|
| Formato | PE32 i386, linker 7.10 (VC++ .NET 2003), GUI | PE32 i386 DLL, linker 7.10 |
| Secciones | .text .rdata .data .rsrc (sin packer; H máx 6,65) | .text .rdata .data .reloc |
| Notas | `.data` virtual 23 MB (buffers estáticos grandes), sin .reloc → base fija 0x400000 | base 0x10000000 |
| Imports clave | DDRAW (`DirectDrawCreate` únicamente), WINMM (timeGetTime/timeBeginPeriod/timeEndPeriod/timeGetDevCaps), GDI32 (17), USER32 (68), ADVAPI32 (Reg*), SHELL32 (`ShellExecuteA`), NPMM.dll (24) | WINMM (mmio*, time*), QUARTZ (`AMGetErrorTextA`), ole32 (`CoCreateInstance`), USER32 mínimo |
| Texto | `TextOutA`, `GetGlyphOutlineA`, `CreateFontIndirectA` (candidatos D10, detalle en B.8/B.9) | — |
| No importa | d3d8/d3d9, dsound, dinput, imm32, msvfw32 | dsound/dinput |
| Recursos nps.exe | 2 iconos, 5 menús, 10 diálogos, 2 tablas de cadenas, versión | — |

Lectura: el audio y el vídeo viven en NPMM.dll (mmio para WAV/OGG propios, DirectShow vía `CoCreateInstance` + quartz → F5 relevante; el reproductor es DirectShow, no VFW). La gráfica es DirectDraw 1.x puro (`DirectDrawCreate`) → encaja un wrapper tipo cnc-ddraw (D13).

## B.4 Protección (F3, D6)
**No hay protección ni packer.** Evidencia: secciones estándar y entropía ≤ 6,65 (sin sección cifrada); cero apariciones de SafeDisc, SecuROM, StarForce, Macrovision, LaserLok, UPX, ASPack, Themida, VMProtect, Armadillo, PECompact, Enigma en nps.exe y npmm.dll; sin .sys/.icd/.vxd en los discos (tarea 1).
**Comprobación de CD: sí, propia y simple** — ambos binarios importan `GetDriveTypeA` y `GetVolumeInformationA` (etiqueta del volumen). Observado en la tarea 2: sin `D:` aparece «inserte Game Disc». Se resuelve con la imagen del usuario como CD virtual (etiqueta `TENSHI_GAME`); no se toca (D6).

## B.5 Registro (F3)
- nps.exe contiene la cadena `software\NitroPlus\` (clave bajo HKLM/HKCU, el resto se compone en ejecución) e importa RegOpenKeyExA / RegQueryValueExA / RegCreateKeyExA / RegSetValueExA / RegCloseKey. No hay otras rutas literales.
- En el prefijo el instalador crea `HKLM\Software\Wow6432Node\NitroPlus\AngelosArmas` (`execute` = ruta del exe). Dependencia del instalador: **probable** (ruta de instalación, ajustes). Se confirmará en la fase 0 C trazando `+reg` con Wine; hasta entonces es hipótesis. aafix deberá virtualizar esa clave.
- Extra: nps.exe tiene URLs de soporte y una de comprobación de versión (`…/getver.php?v=`) + `ShellExecuteA` → en la fase de fixes conviene neutralizar la comprobación de red.

## B.7 Formatos (F2, F9)
**Contenedor `.npp` (magic `nitP`)**, propio de Nitroplus, little-endian. Estructura deducida y comprobada con `scripts/inspect-npp.py` (solo lee el índice; no imprime nombres ni contenido):
- `0x00` magic `nitP` · `0x04` u32 nº de entradas · desde `0x08` tabla de entradas de 0x90 B cada una: u32 offset, u32 tamaño almacenado, u32 tamaño original, u16 flag (0 = crudo, 1 = LZSS), u16 sin interpretar (varía por entrada; no afecta), 0x40 B directorio, 0x40 B nombre (cp932, relleno con 0).
- Los datos empiezan justo tras el índice (`8 + n*0x90`) y las entradas son contiguas.
- **Compresión flag=1: LZSS de Okumura** (anillo 4096, inicio 0xFEE, relleno 0, bit 1 = literal, par lo/hi: pos=lo|(hi&0xF0)<<4, long=(hi&15)+3).

| Archivo | Entradas | Contenido | Flag |
|---|---|---|---|
| script.npp | 363 | `.txt`, todos LZSS | 1 |
| data.npp | 881 | png 533, jpg 326, db 18, txt 2, vix 1, log 1 | 692 crudos / 189 LZSS |
| cg.npp | 1890 | jpg 1698, png 184, db 7, bmp 1 | 0 |
| sound.npp | 579 | `.ogg` (OggS) | 0 |
| voice.npp | 6056 | `.ogg` (OggS), 27 directorios | 0 |
| mpeg.npp | 2 | `OP.mpg` = MPEG-PS (`000001BA`, marcador MPEG-1) + Thumbs.db | 0 |
| update.npp | 21 | jpg/png/db/1 ogg (parche) | 0 |

Verificado: en los 7 archivos el primer offset == fin del índice, las entradas son contiguas y max(off+tam) == tamaño del archivo (el parseo cubre el 100 %). Descompresión LZSS: script.npp 363/363 y data.npp 189/189 dan exactamente el tamaño original; las 167 imágenes comprimidas de data.npp tienen magic PNG/JPEG válido.
**Script (anticipo de B.8):** las 363 entradas descomprimidas son texto cp932 válido, sin cifrar, sin bytes de control fuera de tab/CR/LF. Falta analizar líneas, escenas y códigos (B.8).
**Herramientas existentes:** no se probaron GARbro/arc_unpacker (no hay herramientas descargadas; el formato es trivial y ya se lee con el script propio). Pendiente: buscar en la web si GARbro lo documenta, para citar fuente.
**Vídeo:** un solo MPEG-1 de sistema en mpeg.npp (OP); reproductor = DirectShow vía NPMM.dll (B.3). Sin ffprobe aún (B.10).

## Sin verificar / siguiente
- B.5: uso real de la clave (solo cadenas, sin traza).
- Siguiente: B.6b (ver al final); B.9 hecha.

## B.8 Script y xrefs de texto

**Estructura del script** (`scripts/inspect-script.py`, solo conteos): 363 entradas, 177 324 líneas no vacías, todo CRLF, cp932, sin bytes de control salvo tabuladores. Formato tipo XML con etiquetas (`<TEXTWAIT>`, `<TRANS>`, `<COMMAND>`, `<DELETE>`, `<WAITPLAY>`, `<MOVE>`, `<SHOW>`, `<SCRIPT>`, `<CHOICE>`, `<SELECT>`, `<CASE>`, `<IF>/<ELSE>`, `<WHILE>`, `<CALL>`, `<SOUND>`…) más directivas `#base_path`. 35 646 líneas contienen bytes altos (JP). El texto visible parece vivir en `<BOX TARGET LAYER X Y WIDTH HIGHT TYPE TAIL OUTLINE INCOLOR OUTCOLOR>` (21 775 líneas con JP tras la etiqueta); el resto de JP son comentarios `//` junto a `<SOUND>`/`<BACKGROUND>`/`<FRAME>`. Las elecciones son `<CHOICE … SRC1..3 SE1..2>` (163 con JP). Pendiente: confirmar con el motor que el contenido de `<BOX>` es lo que se dibuja (B.9) y cómo se parte en líneas/ruby.

**Xrefs (Ghidra 12.2 headless, `scripts/ghidra/XrefsTexto.java`, sobre nps.exe; solo direcciones):**
| API | Funciones llamantes (dirección de la función) |
|---|---|
| `GetGlyphOutlineA` | 0x412a30, 0x412ba0, 0x412c20, 0x40f770 (6 llamadas) |
| `CreateFontIndirectA` | 0x4128b0, 0x40aff0, 0x4126a0, 0x4127b0 |
| `GetTextMetricsA` | 0x412c20, 0x40f770 |
| `TextOutA` | 1 llamada en 0x40af69 (sin función definida; junto a `lstrlenA` 0x40af58) |
| `MultiByteToWideChar` | 0x44c888, 0x44dd92, 0x44f089, 0x46a211, 0x4506d1 |
| `GetDriveTypeA` | 0x444b56, 0x423020, 0x44e50d |
| `GetVolumeInformationA` | 0x423020 |
| `GetACP`/`GetOEMCP` | 0x4479c3 |

Conclusión: el texto se rasteriza con `GetGlyphOutlineA` (4 funciones; pipeline propio, no TextOutA, que casi no se usa) → el gancho de D10 debe interceptar `GetGlyphOutlineA` y `CreateFontIndirectA`. Comprobación de CD en 0x423020 (`GetDriveTypeA`+`GetVolumeInformationA`), coherente con la tarea 2. `ERROR Invalid PNG data` de Ghidra es del marcador de datos en recursos, inofensivo.

**Cómo reproducir:** Ghidra necesita un JDK con `javac`; el JDK 21 del host (`/usr/lib64/jvm`) no lo trae, así que usé el JRE/JDK 25 del runtime de Minecraft (`java-runtime-epsilon`, solo lectura) con `JAVA_HOME`. `analyzeHeadless` exige rutas absolutas sin `..`. Log en `cache/ghidra-nps.log`.

## B.10 Vídeo (F5, F15, D8)
- Ubicación: `mpeg.npp` entrada 1 (30 396 420 B, sin comprimir, offset 296) = un único archivo OP; la entrada 2 es `Thumbs.db`.
- Verificado con `ffprobe` sobre una copia en `cache/video/op.mpg` (no se versiona): contenedor MPEG-PS, **MPEG-1 vídeo 800×608, 29,97 fps, yuv420p, 1:50**; audio **MP2 48 kHz estéreo 192 kb/s**. Vídeo a 104 857 kb/s declarado (VBV); bitrate total 2 209 kb/s.
- Vía de reproducción: NPMM.dll importa `CoCreateInstance` + `AMGetErrorTextA` de quartz → DirectShow (grafo por filtros, no VFW). En Wine 64 bits depende de `winegstreamer`/`quartz` con GStreamer (ver F5).
- Consecuencia D8: el códec original (MPEG-1/MP2) es de los más sencillos; el primer peldaño (códec original en Wine/GStreamer) es el que hay que probar en C. Los frames de salida son 800×608 frente a una ventana de 800×600 observada: hay recorte o escalado de 8 px (sin verificar).
- Voz/diálogo sin texto y canciones: el OP contiene música (posible canción → `excluded:lyrics` si trae letra en subtítulos; **no determinado**, no se inspeccionó el audio). No hay más vídeo en el juego instalado (`mpeg.npp` solo tiene OP). Voz: `voice.npp` (no analizado aquí).

## B.11 Saves y configuración (F10)
- Cadenas rutas relativas en nps.exe: `./data/save/co_%c.png`, `exit_%03d.png`, `load_back.png`, `save_back.png`, `50paal.png` y clase `NpsSaveWindow`; también `CONFIG_OPEN`. Son rutas **relativas al directorio de trabajo**, es decir, el juego espera guardar bajo `<instalación>/data/save/` (no hay `data/` en INSTALL_DIR; lo crearía al ejecutarse).
- Consecuencia: en Program Files (Win10/11 sin admin) la escritura fallaría → aafix debe redirigir `data/save/*` a `%APPDATA%` (F10, confirmado como riesgo por las cadenas; **la escritura real no se ha provocado todavía**: falta ejecutar un guardado en C).
- Registro: ver B.5. No hay `.ini` ni `.sav` literales en nps.exe/npmm.dll (búsqueda de cadenas).

## B.6 / B.6b Gráficos y timing (parcial, estático)
- API: DirectDraw 1.x (`DirectDrawCreate` único import de DDRAW), sin d3d (B.3) → wrapper cnc-ddraw (MIT) como primera opción (D13); dgVoodoo2/DXVK-D3D no aplican sin D3D de por medio.
- Observado (tarea 2/`04-run-copy.sh`): ventana principal de clase `nps.exe` 800×600 bajo Wine.
- Timers importados: `timeGetTime`, `timeBeginPeriod`, `timeEndPeriod`, `timeGetDevCaps` (B.3); nps.exe y npmm.dll importan además de KERNEL32 `QueryPerformanceCounter`, `GetTickCount` y `Sleep` (comprobado con `inspect-pe.py`, línea «imports relevantes», y con búsqueda de la cadena en la tabla de nombres: 1 aparición en cada archivo). No se sabe cuál gobierna el ritmo del juego (QPC puede venir solo del CRT); **no determinado**, se medirá en B.6b.
- **Sin hacer:** profundidad de color / modo exclusivo (requiere desensamblar `SetDisplayMode`/`SetCooperativeLevel`) y la medición del fundido a 60 vs 144 fps con cnc-ddraw (necesita descargar cnc-ddraw a `cache/tools/` y automatizar hasta un fundido).

## B.9 Render de texto (fuente/charset/avance)
Ghidra 12.2 headless, `scripts/ghidra/DecompFuentes.java` (decompila las 8 funciones de B.8; salida en `cache/ghidra-fuentes.log`, no se commitea).
- **Fuente:** `CreateFontIndirectA` en 0x4128b0 (fuente de uso, parámetros alto/peso/…/nombre), 0x4126a0 y 0x4127b0 (fuente por defecto: alto 16, peso 400, resto 0). `lfCharSet` se **sobrescribe con `GetTextCharset(GetDC(NULL))`**, no es fijo: depende del ACP/locale del proceso (de ahí la regla de locale 932 de aafix; con otro locale GDI daría otro charset). Resto de campos (offsets LOGFONT): outprecision/clip/quality = 0 y `lfPitchAndFamily` = 1 (FIXED_PITCH), ancho/escapement/orientación 0; italic/underline/strike vienen de parámetros. El nombre sale de un global en .bss (`0x01481cb4`, copiado con una función propia 0x444760), por tanto se rellena en ejecución; en `.rdata` hay dos nombres JP de fuente «MS Gothic» y «MS PGothic» (en ancho completo, 0x79828/0x79d40), candidatos a origen. **Sin verificar** qué escribe en 0x01481cb4.
- **Rasterizado:** el texto no se dibuja con TextOutA. Cada carácter se pide con `GetGlyphOutlineA(hdc global 0x01a9d820, código, formato, …, MAT2 identidad)`; el código es el valor **DBCS de 1-2 bytes del script** (cp932) tal cual, sin pasar por Unicode. Formato 6 = `GGO_GRAY8_BITMAP` (0x412a30: copia a un buffer RGBA 32 bpp, alfa = nivel·4−1, color de texto) y 5 = `GGO_GRAY4_BITMAP` (0x40f770: mezcla alfa directa sobre un buffer RGB 24 bpp con `nivel·16−1`). Ambas reintentan hasta 1000 veces si GDI devuelve error (0xFFFFFFFF).
- **Avance/métricas:** 0x412ba0 mide con `gmBlackBoxX` redondeado a múltiplo de 4 (`(x+3)&~3`, el pitch del bitmap GDI) y `gmBlackBoxY`; 0x412c20 guarda origen X, `tmAscent − gmptGlyphOrigin.y`, BlackBox, y `gmCellIncX/Y` (estos dos son el avance real). **Sin verificar** cuál usa la maquetación (`gmCellIncX` vs BlackBoxX): decide si una fuente latina proporcional se verá bien o si hay que forzar ancho.
- **Consecuencias para D10:** (1) se puede interceptar en un único punto con un hook de `GetGlyphOutlineA` (los 6 sitios pasan por la IAT) + `CreateFontIndirectA` para forzar cara/charset; (2) como el código es DBCS, el texto latino/ES ha de codificarse como pares cp932 o mapear a un rango que GDI acepte (la idea de la zona de usuario SJIS de la arquitectura encaja: una cadena de 2 bytes por glifo); (3) la medida y el dibujo usan la misma fuente global, por lo que un cambio de fuente en el hook afecta a todo.
- **Sin verificar:** que `<BOX>` llegue a estas rutinas (falta traza en ejecución, fase 0 C); qué ruta usa cada formato (RGBA vs RGB); el ancho de los medios-anchos (1 byte) latinos.
