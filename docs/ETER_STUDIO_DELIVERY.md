# ÉTER Studio — entrega de primera versión
Fecha: 10/10/2026. Godot4.7.2 estable, Node24.19 y PostgreSQL18.4 en Windows.

Esta es una versión funcional y extensible de las herramientas. No se acredita el100% del pedido avanzado. Los campos preparados se distinguen de los que consume el runtime. No se reemplazaron los catálogos originales ni los PNG existentes, ni se creó otro backend.

## A. Implementado
- Plugin Main Screen ÉTER Studio con navegación CONTENT/WORLD/GAME/MEDIA/TOOLS.
- Registry/adapters sobre shared: CRUD, IDs únicos, búsqueda/filtro/orden, referencias, confirmación de borrado, dirty state, conflictos externos, backups acotados y Build Content.
- Items: tipos actuales y pants/wings/pet, clases/nivel, precios, flags,12 opciones con reglas por tipo, libro aprendible, icono/suelo/equipment independientes y preview de upgrade.
- Pixel Asset Editor: presets, PNG, lápiz/goma/fill/picker/paleta, zoom/grid, undo/redo, clear/mirror/resize. Guardado dentro de client/assets.
- Monsters: estadísticas/AI existentes, hojas/mappings, preview, drops decimales con cantidades/upgrades/opciones y prueba de spawn.
- Maps/Spots: pintura por capas, biblioteca, colisiones por celda, colocación/arrastre de NPCs/spots/portales/spawns/zonas/audio. Multi entries bajo spot, IDs deterministas compatibles con cliente/servidor.
- NPCs/Shops: definiciones separadas de instancias; stock/precios/permisos; NPCs shop/quest/reset/dialogue/other sobre consumidores existentes.
- Skills: daño/mana/cooldown/clase/nivel/icono, modos existentes y CREATE SKILL BOOK; aprendizaje único y persistencia.
- Balance: progresión/XP fórmula o tabla, fórmulas de atributos actuales, reglas de ataque por clase, upgrades/economía, multiplicadores de monstruos/skills/drops y reset.
- Audio: import WAV/OGG, preview play/pause/stop/loop/volumen/pitch, manager/buses, mapa/zonas/pasos y eventos locales soportados.
- Validation bloquea Build ante errores; búsqueda/referencias globales. Sala Test Content aislada con runtime real, dummy, skill cast, dar item y spawn de monster; portales conservan cooldowns.
- Guías para diseñador y pruebas reproducibles Windows.

## B. Parcial
- Skills: projectile/multiple reutilizan efectos y selección actuales. Cast time, física configurable de proyectil, duraciones/buffs/debuffs/directional y VFX externos no están completos. Modos no soportados bloquean Build; cast time/VFX externos advierten.
- Animation preview muestra primera fila; no hay timeline avanzado ni editor de direcciones. Monster hit no tiene fase visual propia. Frame Width/Height son metadata; Hframes/Vframes e imagen determinan el tamaño.
- Monster Max MP/Magic Defense no crean todavía lógica nueva de magia enemiga.
- Zonas: overlays y aggro disabled funcionan. PvP, skill restrictions, town/respawn policies son metadata preparada, sin combate PvP nuevo.
- Audio: conectados mapa/ambient/zonas/footsteps; NPC interaction/shop; skills cast/impact y eventos locales de monstruo/item/portal. Arrival, repair/upgrade, voces quest/reset y varios eventos online pendientes. Fade in disponible; crossfade completo pendiente. QA audible con audio final pendiente.
- Equipment: capas locales y descriptores públicos remotos implementados; el test monta descriptor remoto, la regresión online verifica dos clientes con contenido original. No se acredita aquí un pipeline de arte equipado completo de todas las direcciones.
- Balance: formulas de HP/MP son compartidas según arquitectura actual. Luck/Excellent, PvP multiplier, durability scaling y almacenamiento futuro no agregan mecánicas nuevas.
- El borrado puede dejar una referencia rota en el draft tras confirmación; Save/Build la bloquean hasta corregirla. No hay borrado en cascada silencioso.
- NPC Interaction Radius está preparado por definición; las operaciones usan el radio global Economy/npc_range por compatibilidad con la economía autoritativa actual. Facing selecciona una de las8 filas de la hoja.
- Colisión: borrado visual de celdas nuevas; rectángulos legacy grandes siguen editables en su formulario.
- Tests automatizados ejercitan controles/datos y runtime; no equivalen a varias horas de uso manual del diseñador ni a QA de cientos de recursos.

## C. No implementado
Polígonos/paint de zonas irregulares, editor de triggers, editor de partículas, capas/selecciones complejas de pixel art, PvP avanzado, almacenamiento nuevo, nuevas clases, guilds, auction/crafting, arte final y contenido masivo. No se hizo push, deploy ni instalación global.

## D. Abrir
Abrir client/project.godot; pestaña superior ÉTER Studio. Si falta: Project Settings > Plugins > ÉTER Studio > Enable. Formularios a la derecha; hacer scroll para llegar al lienzo de mapa.

## E–G. Item y sus tres visuales
CONTENT > Items > Create > ID blade_001. Type weapon; Name; Classes; Required Level; Bonuses/Options. Inventory Icon > Dibujar / Importar > preset Inventory Icon > New Canvas > Pencil/Palette > Save As. Ground / Drop Sprite usa otro PNG y preset Ground Item. Equipped Visual / Path usa una hoja Equipment Sheet4×8 o un sprite estático Hframes1/Vframes1; configurar Offset/Scale/Layer. Save All > Build > TEST; abrir inventario y equipar.

## H–I. Monster y drops
CONTENT > Monsters > Create; Name/HP/Level/Attack o Damage Min/Max/Speed. Visual selecciona hoja e Hframes/Vframes/mapping. Drops > + Agregar fila; selector Item; Chance% decimal; cantidades/upgrades/opciones. Ordenar por chance. TEST > TEST SPAWN utiliza AI y combate reales.

## J. Spot
WORLD > Maps > abrir mapa > herramienta Spot > elegir especie > click. Select / Move arrastra el centro. Quantity/Spawn Radius/Walk Radius/Respawn/Enabled se editan en instancia. Entries > + Agregar fila permite varias especies; lista no vacía reemplaza Species/Quantity general. Máximo64 unidades.

## K–L. Mapa y zona segura
Maps > Create o abrir village/forest/crypt. Paint/Library/Atlas tile/Layer para suelo o decoración; Collision para celdas; Default Spawn con click. NPC/Portal/Spot colocan referencias, Select / Move las mueve. Safe Zone crea rectángulo; Width/Height ajustan y Monster Aggro Disabled activa la regla real. PvP Zone tiene otro overlay y metadata, sin PvP nuevo.

## M–N. Skill y libro
CONTENT > Skills > Create. Seleccionar clases/nivel/mana/cooldown/daño/icono y Behavior soportado. CREATE SKILL BOOK abre el item generado: editar Inventory Icon y Ground Sprite, clases/nivel. No equipable; consumo aprende una vez, repetido no consume. TEST CAST con clase compatible muestra damage, mana y cooldown.

## O. Audio
MEDIA > Audio > Create > Path > Importar audio (WAV/OGG). Play/Pause/Stop; Volume/Pitch/Loop. Luego seleccionar su ID en el campo Audio del contenido o Music/Ambient del mapa. Footsteps asocia Surface de Assets a sonido. Audio Zone permite overrides y prioridad. Consultar AUDIO_EDITOR para eventos conectados.

## P. Balance y publicación
GAME > Balance/Progression/Reset/Classes. Cambiar máximos/XP/atributos/intervalos/upgrades/multiplicadores. Reset requiere Progression/reset_enabled y NPC tipo reset. Save All > Validate > Build Content. Reiniciar juego/servidor: servidor consume shared y cliente client/data construido. No ejecutar generate-world sobre mapas editados.

## Q–S. Evidencia y Git
Los resultados finales y commits se registran en TEST_REPORT.md y PROGRESS.md. NEXT_TASK.md registra continuidad y límites. Artefactos, backups, logs y bases de prueba quedan ignorados en artifacts. El cambio previo de configuración client/project.godot se conserva fuera de estos commits.
