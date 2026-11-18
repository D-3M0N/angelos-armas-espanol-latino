# Fase 4: estimación local (2026-11-15, sesión 66)
Texto: 18304 líneas únicas, ~518k caracteres (lines.jsonl).
Medido (qwen3:8b, RTX 4060 Ti, ~51 tok/s):
- clasificar: 300 líneas en 4m18s → 0,86 s/línea → ~4,4 h para todo.
- traducir (EN+ES): 20 líneas en 26 s → 1,3 s/línea → ~6,6 h.
- Muestra inicial (escena 1-0cut01, sexual): 102/300 explicit (34%) → la fracción real se verá tras la pasada completa; ante duda marca explicit (sesgo conservador).
Cuota Claude: NO medida (no cronometrado `claude -p`); pendiente antes de lanzar translate.py.
Plan: lanzar clasificar completo en segundo plano (log cache/), luego traducir solo lo traducible.
