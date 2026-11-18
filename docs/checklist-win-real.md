# Checklist máquina real (Win10/11) — texto fase 2
Para el usuario; Wine/Xvfb no llega a la 1ª escena (F17).
1. Instalar el juego + parche 1.1.200; copiar build de AALauncher/aafix a copia del juego.
2. Lanzar con `AAFIX_TRACE_TEXT=1`; llegar a la 1ª escena con diálogo.
3. Comprobar traza (cache/): ¿hay líneas hookeadas en 0x42c7d0? Anotar 3 ejemplos (hash + si contiene `<BR>` o `\n`).
4. ¿Hash coincide con index.tsv (crudo)? ¿O solo con respaldo `\n`→`<BR>`?
5. Con tabla de prueba (1 hash → texto latino): ¿se ve el texto, glifos correctos, sin cortes?
6. Anotar anchos/saltos de línea raros y cualquier crash.
Enviar: traza (sin capturas ni texto JP al repo).
