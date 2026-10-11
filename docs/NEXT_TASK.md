# Continuidad

Objetivo de estabilización solicitado: tiendas, Encargos existentes, tres quests, cooldowns entre mapas, cap de oro local y pruebas sin cascadas. Implementación verificada local y online; no continuar agregando sistemas o contenido sin nueva instrucción. No declarar un MMORPG terminado.

Leer AGENTS.md, PROGRESS.md y TEST_REPORT.md. Godot4 estable/GDScript, Node/TS/WebSocket/PostgreSQL; servidor autoritativo. Sin instalaciones globales, gastos, deploy, secretos ni push. Mantener el cambio previo de client/project.godot ajeno a este hito.

Estado: World crea quest_ui existente, asigna App.character y conecta requested a request_quest. Local utiliza EterQuests; online envía sólo quest_id al backend ya existente. Muertes reales y self actualizan diario/UI; busy bloquea dobles solicitudes; Shop/Quest se excluyen y Escape cierra Quest. Orden de hijos HUD evita que Jugadores intercepte Encargos. JSON y SQL conservan quests, recompensa única. Tres encargos del catálogo sin contenido nuevo.

Main transfiere cooldowns locales con descuento de tiempo de transición; online conserva deadlines del servidor. EterEconomy.credit usa gold_cap del catálogo compartido en pickup, venta y premio de quest. Exceso rechaza la operación completa sin pérdida; save/load rechazan balances inválidos.

Verificación reproducible, PowerShell en C:/eter-pixel:

- ./tools/test.ps1 -Godot C:/Godot/godot.exe -Graphics (incluye quests local, proceso nuevo y renderer).
- ./tools/test-server.ps1 (82 tests + smoke; PostgreSQL18.4 real).
- ./tools/test-online-world.ps1 -Godot C:/Godot/godot.exe -Graphics (dos clientes,144 checks).
- ./tools/test-online-quests.ps1 -Godot C:/Godot/godot.exe -Graphics (133 checks gráficos/122 headless, aventura real autoritativa y SQL; fixture atributos1000 sólo para acelerar combate).
- ./tools/test-online-transport.ps1 -Godot C:/Godot/godot.exe.
- Fallo controlado desde server/: node dist/tests/godot-network-runner.js C:/Godot/godot.exe world-failure --fail-role0. Debe salir1 rápidamente, sin error de script ni timeout.

No reiniciar una prueba porque el log esté quieto: seguir su session_id. Quests online camina las rutas de los tres mapas y puede tardar varios minutos (timeout global360s, precondiciones acotadas12–35s, aborta el primer fallo). El runner cancela otros peers y cierra SQL al fallar. invoke-godot corta errores de parse/runtime mientras ejecuta. Godot clases nuevas necesitan import; tests con App/Catalog usan escenas Node, no --script SceneTree. Capturas/logs/DB en artifacts, ignorados Git; UID y escenas versionados.

Si el usuario pide otra tarea, trabajar desde esta base y reproducir primero el fallo concreto. No iniciar cofres/audio/boss/items/mapas/editor ni rediseño por cuenta propia. Limitaciones preexistentes: suelo local temporal, arte provisional, party sin reparto automático de XP/loot, reconexión explícita, QA masiva/exportación/balance general sin acreditar. Fixtures actuales no prueban balance.


## ÉTER Studio — incremento en curso, 10/10/2026
Continuar objetivo activo: previews y test tools, item visual/options/libros, consumo runtime de balance/audio, paridad cliente/servidor y regresiones finales. No declarar completado ÉTER Studio con este primer incremento.

## ÉTER Studio — segundo hito verificado
Continuar MVP: biblioteca/pintura de tiles, multi entries visuales, validación defensiva, previews actualizados y advertencias de campos preparados. Probar online mundo/quests. Campos avanzados de skills/audio/zonas se deben reportar parciales; no considerarlos completos por guardar metadata.