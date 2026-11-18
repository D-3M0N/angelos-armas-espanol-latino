# Fase 1 · Compatibilidad · informe (2026-11-15)

## Hecho (con test sintético bajo Wine+Xvfb, salvo indicación)
| Pieza | Estado | Evidencia |
|---|---|---|
| Launcher `aalauncher.exe` | Proceso suspendido → `LoadLibraryW` remoto de aafix.dll → resume. Compila (mingw i686). | intento 4; hook cargado en nps.exe real (`aafix cargada … MH_OK`) |
| aafix.dll (MinHook) | Compila; hooks activos en nps.exe real (GetSystemMetrics, GetCursorPos, GetWindowRect). | intentos 4-5 |
| Inyección | **Parcial**: `LoadLibraryW` remoto. La inyección por tabla de imports en memoria (brief) **no está hecha**. | — |
| Redirección de saves | `<cwd>\data\save\…` → `AAFIX_SAVE_DIR` (CreateFileA/GetFileAttributesA/CreateDirectoryA). | `14-test-saves.sh` OK |
| Locale 932 | GetACP/GetOEMCP/MultiByteToWideChar/WideCharToMultiByte → 932 bajo en_US. | `15-test-cp932.sh` OK |
| Registro virtual | Claves `NitroPlus\…` → `HKCU\Software\AngelosArmasRebirth`, siembra `execute`. | `16-test-reg.sh` OK (lectura y escritura) |
| Gráficos | **No resuelto**: cnc-ddraw v7.1.0.0 da blanco (gdi) / negro (GL) bajo Xvfb. El juego sin wrapper se ve y corre en Wine. | intento 1 |

## No hecho / sin verificar
- Wrapper gráfico (D13) en Win10/11 real; fijar 60/144 Hz; B.6b (fundido) sigue «pendiente de máquina real».
- Inyección por imports; saves: solo API «A», no FindFirstFile/DeleteFile/MoveFile/CreateFileW; compatibilidad de saves con el original.
- Registro: solo `execute` conocido; locale: sin LCID/IsDBCSLeadByte/fuentes SHIFTJIS; nombres de archivo SJIS.
- Nada probado en Windows real; nada con la escena de referencia completa (OP → primera elección).

## Estado de F17 (el clic cae ~14-34 px sobre el botón)
- Es un fallo del **arnés de pruebas** bajo Xvfb/openbox, no del port: la zona activa del juego (`FUN_004212e0`: cursor − rect − marco − caption − menú) no coincide con lo dibujado. En Windows real puede ser distinto; **sin verificar**.
- Apaño de pruebas en aafix (`AAFIX_F17_DY`, def. 34, solo si el llamador es `FUN_004212e0`; `AAFIX_NO_F17=1` lo desactiva). No es un fix a distribuir.
- `12-lote.sh` reintenta hasta que START activa (~50 % por intento). Tras START el avance por clic se atasca de forma intermitente (estado de la VM del guion, FUN_00416f10; flags de Win32 descartados, intentos 40-43). Limitación conocida del arnés; no se le dedican más intentos salvo que bloquee algo real.
