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

Actualmente se puede crear Guerrero, Mago o Elfa con nombre y recorrer la Aldea de Éter: clic izquierdo mueve, mantener actualiza destino, Esc abre menú. Hay navegación alrededor de edificios/árboles y colisiones físicas. Salida al bosque señalizada, todavía sin transición. Arte original reproducible con `node tools/generate-art.mjs`. Personajes/objetos se guardan en JSON local; PostgreSQL y multijugador pendientes.

Combate local: caminar al sur hasta las tres efigies, o al este al Cercado de la Niebla con seis especies y dificultad creciente. Clic sobre enemigo persigue/autoataca; 1/2 o botones lanzan habilidades. Se validan rango, paredes, maná y cooldown; hay críticos, muerte, respawn y regeneración. Monstruos detectan, persiguen, atacan y vuelven a su spawn. Matar monstruos otorga XP; al subir nivel se reciben cinco puntos. C abre atributos para asignarlos. Efigies no dan XP; muerte pierde 5% de XP parcial. Todavía faltan economía, otros mapas, SQL y multijugador; loot aún no otorgado.

I abre inventario. Arrastrá objetos para mover/equipar/desequipar; doble clic o clic derecho equipa/usa. Seleccioná equipo para Desequipar; Soltar lo deja en suelo, clic lo recoge. Equipo modifica stats, pociones curan y se apilan. Objetos del suelo desaparecen al recargar mundo.

Guardado local por nombre en `%APPDATA%/Godot/app_userdata/ÉTER/characters/`: al entrar, modificar inventario, cada30s y salir al menú/cerrar ventana. Continuar último carga último personaje; Jugar -> Cargar nombre abre otro guardado. Crear no sobrescribe nombres existentes. El loader rechaza archivos corruptos y deriva stats. Este guardado no es validación PostgreSQL ni autoridad online.

Tests headless cubren navegación, tres clases, combate, seis IA, niveles e inventario. `-Graphics` incluye eventos de mouse/teclado y arrastre real, snapshot en artifacts y recarga en otro proceso; mueve temporalmente el cursor dentro de Godot y lo restaura. Tests/capturas no escriben guardados de usuario. Reporte completo en docs/TEST_REPORT.md.

Documentación: docs/MASTER_PLAN.md, ARCHITECTURE.md, GAME_DESIGN.md, ART_DIRECTION.md, TEST_REPORT.md y NEXT_TASK.md.
