# Continuidad

Leer AGENTS.md y docs/PROGRESS.md. Objetivo activo: vertical slice completa según MASTER_PLAN.md; no detenerse después de las fundaciones.

Fundaciones, movimiento, primera aldea y personajes implementados. `./tools/test.ps1` pasa smoke, 544 checks de navegación/física y 33 de clases. Capturas reales revisadas. Siguiente: combate con objetivo de entrenamiento, autoataque/persecución, rangos, cooldown, maná, críticos, muerte/respawn/regeneración y dos habilidades por clase. Después monstruos e IA según MASTER_PLAN; no reducir el objetivo al prototipo actual.

`node tools/generate-art.mjs` regenera once PNG originales, incluidas tres clases. `node tools/sync-data.mjs` copia shared/classes.json a client/data; runner de tests lo hace antes de importar. Fórmulas cliente en character_rules.gd. Tests en client/tests/. Captura: `tools/invoke-godot.ps1 -Label world -Expected 'PASS rendered world' -GodotArgs @('--path', 'C:\eter-pixel\client', '--', '--capture-world')`; --capture-classes genera tres previews.

El ejecutable válido es C:\Godot\godot.exe; wrapper console instalado está roto. Usar tools/invoke-godot.ps1 para esperar el exe GUI, detectar errores y guardar logs. PostgreSQL/Docker no detectados; backend aún pendiente, no usar simulaciones como prueba SQL real.
