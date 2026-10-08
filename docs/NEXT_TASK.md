# Continuidad

Leer AGENTS.md y docs/PROGRESS.md. Objetivo activo: vertical slice completa según MASTER_PLAN.md; no detenerse después de las fundaciones.

Fundaciones, movimiento, aldea, personajes, combate, monstruos, progresión e inventario implementados. Regresión integrada pasa; checks modelo83/UI20 y recarga en proceso nuevo verificadas. Siguiente: economía, loot real por tablas de monstruos, oro, NPC tienda/herrero con comprar/vender/reparar/mejorar. Después interfaz completa, servidor y multijugador en orden. Guardado actual es JSON local, no SQL.

Combate en scripts/combat.gd, fórmulas combat_rules.gd y shared/combat.json. EterTrainingTarget ahora es CharacterBody2D base; EterMonster hereda, usa navegación, seis configs shared/monsters.json y estados propios. Combat omite el tick de efigie para monstruos. target_defeated se emite una vez por muerte; usarla para experiencia sólo en EterMonster. Catalog autoload cachea datos sin retención de scripts por static var. No reintroducir esos caches. Proyectiles visuales aplican daño al lanzamiento. No hay servidor todavía.

EterProgression en scripts/progression.gd usa shared/progression.json: curva 80*level^1.7, cap100, puntos5, asignación validada y penalización 5% de XP actual. world.reward_monster escucha target_defeated sólo para EterMonster, excluye efigies. C abre panel. App.character contiene atributos/stats/hp/mana/XP/puntos/reset_count; inventario debe extender ese estado y modificar EterCharacter.derive para bonos de equipo. Reset desactivado y no ejecutable aún.

EterInventory en scripts/inventory.gd y shared/items.json: state={width,height,items,equipment}; registros UID24 hex, definition/count/rarity/upgrade/durability/x/y. Equipo se queda en items con x=y=-1 y referencia por slot. Mutaciones add/equip usan draft; valid verifica ocupación y ownership. EterCharacter.derive suma bonos; world.inventory_changed refresca stats/HUD/sprite y guarda. I abre inventory_ui; Godot Control drag APIs en inventory_grid/slot. Drop/pickup en world y EterGroundItem. API upgrade ya existe pero no hay oro obtenido ni NPC de mejoras; conectar en economía.

EterSave escribe snapshots por nombre en user://characters/*.json, checksum y rename. Continuar último y Cargar nombre permiten reabrir. No guardar snapshots de tests/capturas en user:// (App.persistence_enabled=false por argumentos test_/--capture/--smoke). Fixtures sólo artifacts; objetos suelo son temporales. starter_ground_claimed evita reemitir espada inicial después de recoger/cargar. Economía debe extender loot con datos, no repetir premios tras muerte ya procesada.

`node tools/generate-art.mjs` regenera22 PNG originales (incluye atlas items y variantes unarmed). sync-data.mjs copia classes/combat/monsters/progression/items a client/data; runner lo hace antes de importar. Tests en client/tests/. -Graphics ejecuta input y drag reales con cursor warp temporal/restaurado y snapshot/reload independiente. Capturas anteriores siguen disponibles. No agregar static var caches de scripts.

El ejecutable válido es C:\Godot\godot.exe; wrapper console instalado está roto. Usar tools/invoke-godot.ps1 para esperar el exe GUI, detectar errores y guardar logs. PostgreSQL/Docker no detectados; backend aún pendiente, no usar simulaciones como prueba SQL real.
