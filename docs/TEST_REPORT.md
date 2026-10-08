# Reporte de pruebas

Este archivo contiene sólo ejecuciones realizadas y resultados observados. La inspección confirmó Godot 4.7.2 y Node 24.19.0.

2026-10-08, `./tools/test.ps1`: importación headless exit 0; smoke exit 0 y `PASS foundation: menu, transition, world scene`. Sin errores de GDScript. Logs en artifacts/import.*.log y smoke.*.log.

Fallos corregidos en runner: wrapper console carecía de exe con el nombre esperado; llamada GUI directa no esperaba finalización. Se usa Start-Process con handle y timeout de 45 s, exit code y rechazo de errores de motor. No se tomaron las ejecuciones anteriores como éxitos.

2026-10-08, hito movimiento/mundo: `./tools/test.ps1` pasa importación, smoke y `PASS movement: 544 checks, pathfinding + actual CharacterBody2D physics`. La suite recorre 530 frames de física: rutas alrededor de sólidos, destino sobre sólido, llegada, parada, destino continuo, bloqueo físico independiente y no cortar esquinas.

Ejecución gráfica real: `tools/invoke-godot.ps1` con --capture-menu y --capture-world, exit 0, mensajes PASS, OpenGL NVIDIA RTX 3080 Ti. artifacts/menu.png y world.png son capturas del viewport real 640x360, ambas inspeccionadas. No se probó aún backend ni multijugador.

2026-10-08, personajes: `./tools/test.ps1` vuelve a pasar importación, smoke actualizado (menú -> creación -> mundo) y 544 checks de movimiento. `PASS characters: 33 checks, all three classes created and moving`, exit 0. Verifica fórmulas numéricas conocidas, aislamiento, validación de nombres/clases, formulario, texturas reales y movimiento/animaciones de cada clase en mundo.

`--capture-classes` ejecutado con renderer OpenGL real: exit 0 y PASS; artifacts/class-warrior.png, class-mage.png y class-elf.png inspeccionadas. Textos, previews y botones caben en 640x360. No hay pruebas de combate todavía.

2026-10-08, combate: primera ejecución falló en cuatro expectativas de AoE/muerte/respawn porque el test suponía impactos garantizados, contradiciendo precisión. Se corrigió para comprobar eventos de impacto y daño/fallo coherentes por objetivo; la prueba de muerte aplica ataques reales hasta un impacto letal, con límite. No se eliminó precisión ni se ocultaron fallos. Tras corrección `PASS combat: 209 checks, skills, pursuit, autoattack, death and real respawns`, exit 0. La suite completa volvió a pasar import/smoke/544 movimiento/33 clases/209 combate tras centralizar datos de efigies.

Render real `--capture-combat`: exit 0 y PASS, captura artifacts/combat.png inspeccionada (nova, números, objetivos, maná y cooldowns). Prueba input_runtime: primero falló por consultar posición del cursor en vez del evento; se corrigió el cliente para transformar event.position. Reejecución pasa `PASS input runtime: 9 checks`, exit 0, OpenGL real, ventana reportó 2560x1440 y render interno 640x360. Comprueba eventos inyectados al viewport, routing GUI y gameplay; no acredita clics físicos del SO. Captura artifacts/input-runtime.png revisada.

Comando estándar headless: `./tools/test.ps1`. Para agregar renderer real e input: `./tools/test.ps1 -Graphics`. Sin pruebas de servidor, SQL o dos clientes aún.
