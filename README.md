# ÉTER

MMORPG 2D original en desarrollo. El objetivo es una vertical slice Godot 4 con backend TypeScript y PostgreSQL. Consultar docs/PROGRESS.md para funcionalidades realmente implementadas; no es un MMORPG terminado.

## Windows

Requiere Godot 4 estable en PATH (verificado con 4.7.2), Git y Node.js para las fases siguientes. Desde PowerShell en el repositorio:

```powershell
./tools/start-client.ps1
./tools/test.ps1
```

También se puede importar client/project.godot en el editor y pulsar F6/F5. La primera importación genera client/.godot, excluida de Git. No hay servicios remotos requeridos en esta fase.

Actualmente se puede recorrer la Aldea de Éter: clic izquierdo mueve, mantener actualiza destino, Esc abre menú. Hay navegación alrededor de edificios/árboles y colisiones físicas. Salida al bosque señalizada, todavía sin transición. Arte original reproducible con `node tools/generate-art.mjs`. Las pruebas incluyen 544 comprobaciones de navegación y física real de Godot.

Documentación: docs/MASTER_PLAN.md, ARCHITECTURE.md, GAME_DESIGN.md, ART_DIRECTION.md, TEST_REPORT.md y NEXT_TASK.md.
