# Continuidad

Leer AGENTS.md y docs/PROGRESS.md. Objetivo activo: vertical slice completa según MASTER_PLAN.md; no detenerse después de las fundaciones.

Fundaciones, movimiento, aldea, personajes, combate, monstruos y progresión implementados. Regresión `./tools/test.ps1 -Graphics` pasa import/smoke/544 movimiento/33 clases/209 combate/1376 monstruos/138 progresión/9 input. Siguiente: inventario, tamaños/colocación, drag/drop, equipo, apilado, soltar/recoger, categorías/rarezas y mejoras configuradas. Guardado local verificable previo a SQL; no usarlo como prueba PostgreSQL. Luego economía en orden.

Combate en scripts/combat.gd, fórmulas combat_rules.gd y shared/combat.json. EterTrainingTarget ahora es CharacterBody2D base; EterMonster hereda, usa navegación, seis configs shared/monsters.json y estados propios. Combat omite el tick de efigie para monstruos. target_defeated se emite una vez por muerte; usarla para experiencia sólo en EterMonster. Catalog autoload cachea datos sin retención de scripts por static var. No reintroducir esos caches. Proyectiles visuales aplican daño al lanzamiento. No hay servidor todavía.

EterProgression en scripts/progression.gd usa shared/progression.json: curva 80*level^1.7, cap100, puntos5, asignación validada y penalización 5% de XP actual. world.reward_monster escucha target_defeated sólo para EterMonster, excluye efigies. C abre panel. App.character contiene atributos/stats/hp/mana/XP/puntos/reset_count; inventario debe extender ese estado y modificar EterCharacter.derive para bonos de equipo. Reset desactivado y no ejecutable aún.

`node tools/generate-art.mjs` regenera dieciocho PNG originales. `node tools/sync-data.mjs` copia classes/combat/monsters/progression desde shared a client/data; runner lo hace antes de importar. Tests en client/tests/. Captura: `tools/invoke-godot.ps1 -Label world -Expected 'PASS rendered world' -GodotArgs @('--path', 'C:\eter-pixel\client', '--', '--capture-world')`; también --capture-classes, --capture-combat, --capture-monsters y --capture-progression.

El ejecutable válido es C:\Godot\godot.exe; wrapper console instalado está roto. Usar tools/invoke-godot.ps1 para esperar el exe GUI, detectar errores y guardar logs. PostgreSQL/Docker no detectados; backend aún pendiente, no usar simulaciones como prueba SQL real.
