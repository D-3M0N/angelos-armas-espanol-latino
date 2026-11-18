# Informe de la fase 0 (2026-11-15)
Entorno: Wine 11.21 WoW64 nuevo, Xvfb. Sin Win10/11 real. Detalle en `fase-0-B-inventario.md`, `fase-0-C-baseline.md`, `playbook-fallos.md`, `plan-fases.md`.

## Inventario (resumen)
- Juego v1.1.200 instalado y parcheado; manifiestos de GAME_DIR e INSTALL_DIR sin cambios (sha256).
- Ejecutables `nps.exe` y `npmm.dll`: PE32, linker 7.10, sin packer ni protección (D6 no aplica). Comprobación de CD solo con `GetDriveTypeA`/`GetVolumeInformationA`; vale un CD virtual con la etiqueta.
- Nombres de archivo: 10/10 ASCII. Gráficos: un `DirectDrawCreate`, sin dinput ni d3d.
- Contenedor `.npp`: índice + LZSS (Okumura); script = cp932 con etiquetas, 363 entradas, ≈177 k líneas.
- Texto: `GetGlyphOutlineA` con código DBCS (6 llamadas en 4 funciones), `TextOutA` solo 1; punto de hook claro.
- Vídeo OP: MPEG-1 800×608 29,97 fps + MP2 (ffprobe).
- Saves: rutas `./data/save/…` (por cadenas).
- Baseline: arranca en ja_JP y C.UTF-8, 0 `err:`, título visible. No se pasó del título (F17).

## Estado F1-F16
F1 confirmado (parcial, título de ventana con C.UTF-8) · F2 descartado · F3 descartado con CD virtual · F4 sin evidencia · F5 sin evidencia · F6 confirmado solo en diálogos del sistema · F7-F16 sin evidencia (F7-F9 solo estático; F10, F13 solo cadenas/imports; F11, F12, F14-F16 aún sin trabajo asociado).

## Hecho / verificado / pendiente
- **Hecho y verificado:** A (repo, hook, licencias), B.1-B.5, B.7-B.11 y B.6 estático (ejecutando los scripts y Ghidra headless), C parcial.
- **Pendiente:** llegar a la OP/primera escena (F17); B.6b (fundido 60 vs 144 Hz): pendiente de máquina real, no medible bajo Xvfb (intento 44); F5, F7-F10, F13 en ejecución; todo en Win10/11 real.
- **Renumeración de scripts** (`01-04` de la tarea 2) y `00-host-setup.sh`: sin hacer. `02-install.sh` y su paso GUI no se han re-ejecutado.

## Scripts para el usuario, en orden
1. `scripts/01-mkprefix.sh` → 2. `scripts/02-install.sh` (xdotool; clics estimados, puede requerir ajuste) → 3. `scripts/03-patch.sh` (`--verify` sin riesgo) → 4. `scripts/04-run-copy.sh` (ejecuta una copia desechable) → 5. `scripts/05-baseline.sh`. Además `make-manifest.sh` y `check-no-game-data.sh`.

## Checklist para el usuario (no verificable por el agente)
- [ ] Ejecutar el juego en Windows 10/11 real con el parche: ¿arranca sin crack ni CD físico?
- [ ] Anotar si START/clic responde con el juego original (descarta F17 como problema del juego).
- [ ] Antivirus/SmartScreen con la copia desechable (F11).
- [ ] Monitor de 144/165 Hz: velocidad de los fundidos (F13).

## Riesgos no pedidos
1. La entrada en el título (F17) bloquea todas las pruebas en ejecución; la fase 1 empieza por cnc-ddraw y una ventana con gestor mínimo.
2. JDK 25 de Minecraft usado para Ghidra (ajeno al proyecto): instalar un JDK 21 completo en `cache/tools/`.
3. Deuda de instalación con ACP 1252 (PREGUNTAS): si aparecen rarezas, reinstalar.
