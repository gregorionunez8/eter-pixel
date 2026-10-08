# Continuidad

Leer AGENTS.md y docs/PROGRESS.md. Objetivo activo: vertical slice completa según MASTER_PLAN.md; no detenerse después de las fundaciones.

Fundaciones, movimiento y primera aldea implementados. `./tools/test.ps1` pasa smoke y 544 comprobaciones de navegación/física. Capturas reales revisadas. Siguiente: fase personajes, tres clases por datos, pantalla de creación, atributos derivados, apariencias y pruebas. Luego combate según MASTER_PLAN; no reducir el objetivo al prototipo actual.

`node tools/generate-art.mjs` regenera ocho PNG originales. Importar antes de ejecutar. Test de movimiento está en client/tests/movement.gd. Captura: `tools/invoke-godot.ps1 -Label world -Expected 'PASS rendered world' -GodotArgs @('--path', 'C:\eter-pixel\client', '--', '--capture-world')`.

El ejecutable válido es C:\Godot\godot.exe; wrapper console instalado está roto. Usar tools/invoke-godot.ps1 para esperar el exe GUI, detectar errores y guardar logs. PostgreSQL/Docker no detectados; backend aún pendiente, no usar simulaciones como prueba SQL real.
