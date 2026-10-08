# Continuidad

Leer AGENTS.md y docs/PROGRESS.md. Objetivo activo: vertical slice completa según MASTER_PLAN.md; no detenerse después de las fundaciones.

Fundaciones, movimiento, aldea, personajes y combate local implementados. `./tools/test.ps1` pasa smoke, 544 checks navegación/física, 33 clases y 209 combate. `test_input.tscn` gráfico pasa 9 checks de eventos de mouse/teclado; `./tools/test.ps1 -Graphics` incluye esa prueba. Capturas reales revisadas. Siguiente: monstruos Araña/Goblin/Lobo/Esqueleto/Orco/Guardián oscuro y estados IA Idle/Detectar/Perseguir/Atacar/Regresar/Morir/Respawn con colisiones. Después progresión, inventario y economía en orden.

Combate actual en scripts/combat.gd, fórmulas combat_rules.gd y shared/combat.json. Tres efigies en y=27*32 junto a salida sur son objetivos temporales con represalia/respawn; EterTrainingTarget es Node2D sin navegación propia. Para monstruos separar actor con CharacterBody2D y navegación, integrar objetivos genéricos con combat.gd (tipos actuales Array[EterTrainingTarget]). hit_resolved permite verificar precisión/daño; agregar señal muerte para experiencia al llegar a progresión. Proyectiles visuales aplican daño al lanzamiento. No hay servidor todavía.

`node tools/generate-art.mjs` regenera doce PNG originales, incluidas tres clases y training.png. `node tools/sync-data.mjs` copia classes/combat desde shared a client/data; runner lo hace antes de importar. Tests en client/tests/. Captura: `tools/invoke-godot.ps1 -Label world -Expected 'PASS rendered world' -GodotArgs @('--path', 'C:\eter-pixel\client', '--', '--capture-world')`; --capture-classes genera tres previews; --capture-combat captura mago con habilidades.

El ejecutable válido es C:\Godot\godot.exe; wrapper console instalado está roto. Usar tools/invoke-godot.ps1 para esperar el exe GUI, detectar errores y guardar logs. PostgreSQL/Docker no detectados; backend aún pendiente, no usar simulaciones como prueba SQL real.
