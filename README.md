# ÉTER

MMORPG 2D original en desarrollo. El objetivo es una vertical slice Godot 4 con backend TypeScript y PostgreSQL. Consultar docs/PROGRESS.md para funcionalidades realmente implementadas; no es un MMORPG terminado.

## Windows

Requiere Godot 4 estable en PATH (verificado con 4.7.2), Git y Node.js para las fases siguientes. Desde PowerShell en el repositorio:

```powershell
./tools/start-client.ps1
./tools/test.ps1
./tools/test.ps1 -Graphics
```

También se puede importar client/project.godot en el editor y pulsar F6/F5. La primera importación genera client/.godot, excluida de Git. No hay servicios remotos requeridos en esta fase.

Actualmente se puede crear Guerrero, Mago o Elfa con nombre y recorrer la Aldea de Éter: clic izquierdo mueve, mantener actualiza destino, Esc abre menú. Hay navegación alrededor de edificios/árboles y colisiones físicas. Salida al bosque señalizada, todavía sin transición. Arte original reproducible con `node tools/generate-art.mjs`. Las pruebas incluyen 544 checks de navegación/física y 33 de clases. Los personajes viven en memoria; persistencia y multijugador aún pendientes.

Combate local: caminar al sur hasta las tres efigies, clic sobre una para perseguir/autoatacar. 1/2 o botones lanzan habilidades de la clase. Se validan rango, paredes, maná y cooldown; hay críticos, muerte, respawn y regeneración. Las efigies responden a corta distancia. Suite de combate: 209 checks; `-Graphics` agrega 9 checks de input en renderer real. Todavía faltan monstruos con IA, experiencia, inventario, economía, otros mapas, SQL y multijugador.

Documentación: docs/MASTER_PLAN.md, ARCHITECTURE.md, GAME_DESIGN.md, ART_DIRECTION.md, TEST_REPORT.md y NEXT_TASK.md.
