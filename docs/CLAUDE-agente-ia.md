# Angelos Armas - Rebirth
Fix de compatibilidad (Win10/11 + Wine) + traducción EN/ES en runtime de 天使ノ二挺拳銃 -Angelos Armas- (Nitroplus, 2005). Fan, no oficial. El repo NUNCA contiene archivos del juego ni derivados byte a byte.

## Presupuesto (regla nº 1)
Única fuente: plan Pro, 2 semanas de cuota. Sin API de pago. Cada token cuenta.
- **Lectura al arrancar, solo esto:** «## Estado» de docs/PROGRESO.md, docs/SALTADO.md y, si existen, docs/REVISION-PENDIENTE.md y docs/BUGS-USUARIO.md. Decisiones: `docs/decisiones-indice.md` (1 línea por D) y luego `grep -A3 "D12 ·" docs/decisiones.md`. Brief y fase-0 solo con grep. `scripts/docs-compact.py` archiva lo viejo en docs/historial/ (no se lee): no lo imites a mano.
- **Salidas de herramientas:** nunca `cat` de logs, decompilados ni archivos > 100 líneas: `grep -m`, `head`/`tail -n 40`, `wc`. Wine: `WINEDEBUG=-all` salvo un canal concreto; salida a archivo + grep. Ghidra: solo las funciones necesarias, a archivo + grep. Si existe `cache/index/`, haz grep ahí antes de decompilar.
- **Modelos:** tú eres Sonnet. Opus solo entra por el bucle (puerta de fase, o en tu lugar tras 2 iteraciones sin avance). Haiku solo audita traducciones (`translate.py audit`). Sin subagentes. Sin web para lo que ya sabes; sí para lo que depende de versiones.
- **GPU local primero:** `scripts/local-llm.py` (Ollama): `resumir ARCHIVO --pregunta "..."` en vez de leer logs o decompilados largos (luego confirma con grep) y las pasadas masivas de la fase 4. No para código ni decisiones.
- **Bloques grandes:** 2-4 tareas relacionadas por sesión.
- **Tope de 3 intentos por problema.** Al tercero: hipótesis y evidencia en PROGRESO, `docs/BLOQUEADO.md` y a otra cosa. Problemas del arnés de pruebas (clics bajo Xvfb, F17) no son del port: no gastes intentos; vía más simple con evidencia suficiente.
- **Alcance:** solo el «Plan 7 días»; lo demás está fuera.
- **Escritura telegráfica** en PROGRESO, informes y commits.

## Bucle autónomo
Te ejecuta `scripts/run-agent.sh` (sin supervisión; estas reglas son la única red).
- **No hagas commit, push, reset ni stash.** Deja los cambios y escribe el mensaje en `../cache/agent/COMMIT_MSG`. El bucle comitea tras `scripts/check.py` (reglas duras sin IA: rutas, assets, > 1 MB, volcados JP, secretos, sintaxis). Si falla → `docs/REVISION-PENDIENTE.md` con el motivo: corrígelo y bórralo. 3 fallos seguidos → cambios apartados y tarea saltada.
- **Puertas de Opus:** solo H2 (fin del día 3) y H6 (entrega). Al cumplirlas escribe `docs/CIERRE-FASE.md` (≤ 40 líneas: criterio → evidencia con ruta de log o captura; pendientes; riesgos). OK → se archiva y se comitea; CAMBIOS → REVISION-PENDIENTE (corrige y reescribe). Los demás hitos: evidencia en PROGRESO, sin Opus.
- **Saltos, no pausas.** Si algo te impide seguir (DRM, sudo sin alternativa, contenido que no vas a procesar, algo irreversible, contradicción con el brief): `docs/BLOQUEADO.md` (qué, evidencia, qué haría falta) y termina. Pasa a `docs/SALTADO.md` y no se reintenta. Saltar no es eludir: nunca rodees D6 ni D7.
- **Dudas no bloqueantes:** decide lo razonable y una línea en `docs/PREGUNTAS.md` (fecha · pregunta · qué asumiste · cómo revertir).
- **Sesión:** lee lo mínimo (arriba) → haz el bloque → verifica con evidencia («verifiqué X con Y»; lo no verificado, dilo) → actualiza PROGRESO y COMMIT_MSG → termina.
- **PROGRESO.md:** «## Estado» arriba, máx. 40 líneas (fase, hecho, pendiente, siguiente, riesgos); el detalle va a `docs/historial/`.
- **Nunca:** `sudo`; escribir en GAME_DIR ni tocar sus permisos; `--no-verify`; editar `.aa-allow`; ventanas en la pantalla del usuario (DISPLAY vacío; usa tu Xvfb de `scripts/lib-wine.sh`).
- Procesos largos: en segundo plano, log en `cache/`, comprueba con tail.

## Rutas (`.env.local`)
ROOT `<RAIZ>` · GAME_DIR `$ROOT/game` (imágenes BIN/CUE + parche 1.1.200; root, solo lectura) · WORK_DIR `$ROOT/repo` · BUILD_CACHE `$ROOT/cache` · WINEPREFIX `$ROOT/prefix` · INSTALL_DIR (en `.env.local`; solo lectura; para ejecutar, copia desechable en `cache/run/`) · herramientas `cache/tools/`.
Host: openSUSE TW, RTX 4060 Ti 8 GB, X11, Wine 11 WoW64 nuevo (GStreamer 64 bits), ja_JP.UTF-8, MinGW i686, CMake, Python 3.13, ffmpeg, 7z, bchunk, gh, gitleaks. binutils puede estar roto: usa Python para inspeccionar PE.

## Plan 7 días (prioridad absoluta; detalle y recortes en docs/PLAN-7D.md)
Meta: el usuario completa la historia en español en su PC (openSUSE + Wine 11). Plazo fijo: se recorta alcance, nunca plazo. Fuera: Win11, launcher/ajustes, EN elegible, escalado, subtítulos de video, mando, fase 7, release. El prompt te dice qué día es; del plan lee solo su tabla (`grep -n '^| ' docs/PLAN-7D.md`).
- **H0 (día 1)** `cache/text/glosario.tsv` curado (≤ 40 filas con género y tratamiento; parte de `local-glosario.tsv`). Desbloquea el borrador de la GPU: hazlo en el primer bloque.
- **H1 (día 1)** la copia desechable (`cache/run/`) llega al título y a la 1ª escena en Wine. `scripts/jugar.sh` la lanza (`LC_ALL=ja_JP.UTF-8`) para que el usuario la pruebe.
- **H2 (días 2-3)** `aafix.dll` como proxy en la copia, sin launcher: sustitución por hash e ida y vuelta de la escena de referencia. **Fin del día 3: GO/NO-GO** con `docs/CIERRE-FASE.md`. Sin hook estable al día 4 → Plan B (overlay) del plan.
- **H3 (día 4)** á é í ó ú ñ ¿ ¡ (D11) y ajuste con `\n`; build con todo el borrador.
- **H4 (día 5)** historia completa sin crash (recorrido rápido por capítulo; video que cuelga → se omite). El usuario empieza a jugar.
- **H5 (días 5-7)** rodaje: `docs/BUGS-USUARIO.md` va primero; `AA_AUDIT_MAX=60 python3 scripts/translate.py audit` y `fix` en orden de historia, por delante del usuario.
- **H6 (día 7)** entrega + `CIERRE-FASE.md` final. Opus revisa solo H2 y H6.
Pruebas: `scripts/test-escena.sh` (copia desechable, Xvfb, capturas en cache/test/, salida ≤ 20 líneas); índice Ghidra en `cache/index/` si existe. Si el arnés de clics falla, no gastes intentos.
Docs: `docs/brief.md` (solo grep) · `docs/decisiones-indice.md` (D1-D21) · `docs/PLAN-7D.md` · `docs/playbook-fallos.md`.

### Traducción por capas (ya construida; la GPU hace el borrador en paralelo desde el día 1)
Entrada: `cache/text/lines.jsonl` (`{"id": hash, "scene", "speaker", "text"}`), nunca en git. `cache/text/modelos.json` = ganadores del bake-off (JA→EN y EN→ES): no lo cambies a mano. Si `lines.jsonl` ya existe y modelos.json dice corpus «sintetico», ejecuta una vez `python3 scripts/bakeoff.py --real --force` y deja que lo actualice.
1. **Local (gratis; lo ejecuta `aa-gpu` en paralelo y `run-agent.sh` en las esperas de cuota):** `local-llm.py clasificar` (D7), `resumir-escenas`, `glosario`. Revisa los términos de frecuencia alta (una llamada tuya) y fija `cache/text/glosario.tsv` (mismas columnas + `genero` Male/Female).
2. `translate.py draft` (local): dos pasadas, A JA→EN y B EN→ES (un modelo a la vez en la GPU), por escena con ficha, resumen y 5 líneas previas. Incluye las `explicit` (solo local).
3. `translate.py check` (sin IA): códigos de control, kana, idioma, longitud.
4. `translate.py audit` (Haiku) → severidad 0-3 por línea; `translate.py fix` (Sonnet) para sev ≥ 2 o fallos de check. Ambos excluyen `explicit`.
5. Muestra para la puerta final (H6): `translate.py sample` (2 % + toda sev 3) y Opus; desempate de glosario y estilo.
6. `translate.py export` → `cache/text/translations.jsonl`; precedencia manual (D12) > fix > draft.
7. **Contenido explicit:** nunca abras, leas ni envíes a Claude líneas `explicit` ni sus borradores. `lyrics` y `excluir` (sexual con un personaje no claramente adulto o ambiguo, o violencia sexual) no se traducen; `cache/text/excluded-scenes.txt` fuerza escenas fuera. Nunca rellenes las excluidas (D12: las traduce el usuario).
8. Antes de lanzar `audit`/`fix`: mide líneas y caracteres, cronometra 1 escena y escribe la estimación de horas de GPU y de cuota en el informe.

## Arquitectura
AALauncher.exe (ajustes → proceso suspendido → aafix.dll añadida a los imports en memoria → resume). aafix.dll (MinHook): redirección de archivos y saves, registro virtual, locale 932, sustitución de texto por hash, fuente latina (zona de usuario de SJIS), wrapper gráfico, video. Overlay = translations/ + BUILD_CACHE.

## Reglas
- Nunca escribir en GAME_DIR/INSTALL_DIR. Nunca commitear assets, script original, texto JP del juego, capturas, extracciones ni secretos.
- Traducciones: hash → texto (D3). Sin DRM (D6).
- D7/D20: entre personajes claramente adultos se traduce todo; las líneas explícitas solo con borrador local (Claude no las ve); letras (`lyrics`) y `excluir` quedan en el original, cada exclusión con motivo.
- Video (D8): nunca distribuirlo. Presentación (D13): wrapper por inyección; la velocidad del juego no depende de los Hz.
- Build: i686-w64-mingw32 + CMake + MinHook. Ante un fallo: mira primero `docs/playbook-fallos.md`.
