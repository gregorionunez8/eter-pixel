# Continuidad

Leer AGENTS.md y docs/PROGRESS.md. Objetivo activo: vertical slice completa según MASTER_PLAN.md; no detenerse después de las fundaciones.

Fundaciones, movimiento, aldea, personajes, combate local y seis monstruos con IA implementados. Regresión integrada `./tools/test.ps1 -Graphics` exit 0: import/smoke/544 movimiento/33 clases/209 combate/1376 monstruos/9 input gráfico. Siguiente: progresión por experiencia real de monstruos, niveles, atributos/puntos, curva progresiva, penalización por muerte y reset preparado. Después inventario/economía en orden.

Combate en scripts/combat.gd, fórmulas combat_rules.gd y shared/combat.json. EterTrainingTarget ahora es CharacterBody2D base; EterMonster hereda, usa navegación, seis configs shared/monsters.json y estados propios. Combat omite el tick de efigie para monstruos. target_defeated se emite una vez por muerte; usarla para experiencia sólo en EterMonster. Catalog autoload cachea datos sin retención de scripts por static var. No reintroducir esos caches. Proyectiles visuales aplican daño al lanzamiento. No hay servidor todavía.

`node tools/generate-art.mjs` regenera dieciocho PNG originales. `node tools/sync-data.mjs` copia classes/combat/monsters desde shared a client/data; runner lo hace antes de importar. Tests en client/tests/. Captura: `tools/invoke-godot.ps1 -Label world -Expected 'PASS rendered world' -GodotArgs @('--path', 'C:\eter-pixel\client', '--', '--capture-world')`; también --capture-classes, --capture-combat y --capture-monsters.

El ejecutable válido es C:\Godot\godot.exe; wrapper console instalado está roto. Usar tools/invoke-godot.ps1 para esperar el exe GUI, detectar errores y guardar logs. PostgreSQL/Docker no detectados; backend aún pendiente, no usar simulaciones como prueba SQL real.
