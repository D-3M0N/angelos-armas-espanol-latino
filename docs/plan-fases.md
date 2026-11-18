# Plan de fases 1-6 (estimación a 2026-11-15)
Basado en la fase 0 (B inventario estático, C baseline). Las estimaciones son de sesiones del agente («s»), no de tiempo de reloj; incertidumbre alta mientras no se pase de la pantalla de título.

| Fase | Estimación | Notas |
|---|---|---|
| 1 Compatibilidad | 6-10 s | Importa DirectDraw (1 `DirectDrawCreate`), sin dinput/d3d: cnc-ddraw encaja. Resolver antes F17 (entrada). Launcher + inyección por imports + redirección de saves |
| 2 Pipeline de texto | 6-10 s | Formato .npp y LZSS ya conocidos (B.7); script cp932 con etiquetas (B.8). Falta localizar la función de texto en ejecución y validar `<BOX>` |
| 3 Render latino | 4-6 s | `GetGlyphOutlineA` en 4 funciones, 6 llamadas (B.8/B.9): punto de hook claro; el mapeo SJIS D11 es viable en principio |
| 4 Traducción EN→ES | muchas s (≈177 000 líneas, B.8) | Dominada por coste de tokens; caché por hash; revisión ≥5 % |
| 5 Cinemáticas | 3-5 s | OP = MPEG-1 800×608 29,97 fps + MP2 (B.10) |
| 6 UI/release/validación | 5-8 s | Win11 real no verificable por el agente: checklist para el usuario |

## Peldaño D8 recomendado
**Provisional, sin evidencia en ejecución.** El OP es MPEG-1 (códec estándar): el primer peldaño («códec original») debería bastar con GStreamer de 64 bits (base/good/bad/ugly/libav instalados en el host). No confirmado porque no se llegó a la OP (C). Si falla en Wine, el segundo peldaño es transcodificar localmente (ffmpeg 7.1 disponible) a un formato legible por el reproductor.

## Cinco riesgos principales
1. **Entrada/estado del título en Wine (F17):** bloquea medir B.6b y todo lo posterior en ejecución. Alternativa: cnc-ddraw o prueba con otro Xvfb/WM mínimo.
2. **Función de texto no localizada en ejecución** (solo estático): riesgo para F7-F9; mitiga Ghidra + traza de `GetGlyphOutlineA`.
3. **Volumen de traducción** (≈177 k líneas): coste y consistencia (F16).
4. **Diferencias Win real vs Wine** (F4, F12, F13) sin poder medir aquí.
5. **Detección de antivirus por inyección** (F11) y contenido adulto (repo privado, D7).

## Herramientas de terceros (licencia comprobada con `gh api repos/<r>/license`, 2026-11-15)
| Herramienta | Licencia | Uso previsto |
|---|---|---|
| cnc-ddraw (FunkyFr3sh) | MIT | wrapper DirectDraw (D13) |
| DXVK (doitsujin) | Zlib | solo si hubiera d3d8/9 (no es el caso) |
| MinHook (TsudaKageyu) | NOASSERTION en GitHub (el README lo declara BSD-2; no verificado) | hooks en aafix.dll |
| GARbro (crskycode) | MIT | referencia de formatos; no probado con .npp |
| arc_unpacker (vn-tools) | GPL-3.0 | solo referencia (copyleft: no incorporar código) |
| whisper.cpp | MIT | ASR local (F15) |
| thcrap (thpatch) | Unlicense | referencia de patrón |
| dgVoodoo2 | no consultada (freeware cerrado, según recuerdo; sin verificar) | alternativa de wrapper |
