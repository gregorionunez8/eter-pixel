# Continuidad de ÉTER Studio
Estado: primera versión funcional y extensible entregada; no se considera completa toda la especificación avanzada. Leer AGENTS.md, ETER_STUDIO_DELIVERY.md, TEST_REPORT.md y DESIGNER_START_HERE.md antes de continuar.

## Base preservada
Cliente Godot4.7.2 estable, backend TypeScript/WebSocket/PostgreSQL18.4, shared como fuente de verdad; Build Content copia client/data y genera world legacy desde village. Los catálogos y PNG originales no cambiaron. No ejecutar generate-world para publicar contenido diseñado.

## Verificación reproducible
Desde C:/eter-pixel, PowerShell:
- ./tools/test-studio.ps1 -Godot C:/Godot/godot.exe -Graphics (65 comprobaciones: registry21/UI5/assets9/maps10/runtime20).
- ./tools/test.ps1 -Godot C:/Godot/godot.exe -Graphics (base del juego, quests reales, shops, UI, save/load y renderer).
- ./tools/test-server.ps1 (88 tests y startup WS/PostgreSQL real).
- ./tools/test-online-world.ps1 -Godot C:/Godot/godot.exe -Graphics (dos mundos144).
- ./tools/test-online-quests.ps1 -Godot C:/Godot/godot.exe -Graphics (aventura134).
No cambiar scripts durante una suite Godot ni lanzar imports paralelos; seguir session_id. Quests online camina los3 mapas y tarda varios minutos. Precondiciones fallan limpiamente; no ocultar SCRIPT ERROR aunque el proceso imprima PASS.

## Pendiente dentro del alcance avanzado
1. QA manual del diseñador usando las guías durante una sesión extensa; corregir fricción de formularios/previews y probar un lote de contenido nuevo local/online.
2. Skill behaviors buff/debuff/directional, cast time/duración/proyectiles configurables y VFX externos. Hoy Validate bloquea modos no soportados y advierte metadata. No reescribir combate estable.
3. Zonas poligonales/paint, triggers, skill restrictions/town/respawn policies y PvP preparado. No crear PvP avanzado.
4. Completar eventos de audio pendientes/online y crossfade; QA audible con sonidos originales proporcionados por diseñador. Biblioteca inicial vacía.
5. Monster hit/direcciones/timeline, magic defense/max MP; opciones Luck/Excellent y durability scaling siguen preparadas.
6. NPC Interaction Radius por definición sigue preparado: hoy manda Economy/npc_range global, compartido con autoridad del servidor. Facing sí modifica fila visual.
7. Mejorar publicación multiarchivo ante fallos de disco durante Build y validación de formas/colisiones complejas; Save ya usa backup/conflicto/replacement/rollback. Verificar migraciones con fixtures antes de tocar shared.
8. Preservar el cambio previo de client/project.godot fuera de commits de herramientas. No push, deploy, instalación global ni contenido final sin instrucción.

No hay bloqueo conocido en los flujos existentes probados. No afirmar que los campos preparados tienen efecto por aparecer en un formulario. No iniciar sistemas fuera del pedido.
