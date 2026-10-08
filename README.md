# ÉTER

MMORPG 2D original en desarrollo con Godot 4, GDScript, Node.js/TypeScript, WebSocket y PostgreSQL. La vertical slice completa sigue en construcción: todavía no es un MMORPG terminado.

Cliente local jugable: Aldea de Éter original, movimiento por mouse con colisiones y navegación, Guerrero/Mago/Elfa, seis especies de monstruos, combate y seis habilidades, niveles/atributos, inventario con drag/drop, equipo, drops, oro, tiendas, reparación/mejoras, minimapa y guardado JSON. Backend independiente: cuentas/personajes SQL, sesiones exclusivas, movimiento/combate/IA/progresión autoritativos y snapshots entre dos peers WebSocket. Godot aún funciona offline.

## Ejecutar en Windows

Requiere Godot 4 estable (verificado con 4.7.2), Node24/npm y Git. Desde PowerShell en este repositorio:

```powershell
./tools/start-client.ps1 -Godot C:/Godot/godot.exe
./tools/test.ps1 -Godot C:/Godot/godot.exe -Graphics
./tools/start-server.ps1 -Install
./tools/test-server.ps1
```

Si Godot está en PATH, se puede omitir -Godot. También se puede importar client/project.godot y ejecutar F5. start-server instala dependencias sólo en server/node_modules, compila y arranca PostgreSQL en127.0.0.1:55432 y WebSocket en127.0.0.1:8080. Ctrl+C detiene el backend. Tras instalar, no requiere red para arrancar. `./tools/start-server.ps1 -Smoke` verifica arranque/cierre sin dejarlo corriendo. Detalles y credenciales públicas sólo de desarrollo en [BACKEND_SETUP](docs/BACKEND_SETUP.md); mensajes en [PROTOCOL](docs/PROTOCOL.md).

## Jugar el cliente local

Jugar permite crear nombre/clase. Continuar último y Cargar nombre recuperan guardados. Clic izquierdo mueve; mantener actualiza destino; clic en enemigo persigue y autoataca. 1/2 o botones lanzan habilidades con rango/maná/cooldown. Entrená al este en el Cercado de la Niebla; las efigies al sur no dan recompensas. Monstruos dejan XP, oro y objetos; clic recoge drops. Al subir nivel se reciben cinco puntos; C abre atributos.

I abre inventario: arrastrá para mover/equipar/desequipar, doble clic o clic derecho equipa/usa. Soltar deja el objeto en suelo. Pociones curan y se apilan. Equipo afecta estadísticas; quitar arma cambia sprite. Iria vende provisiones y Daro vende armas/protecciones, repara y mejora hasta+15. Clic en NPC navega y abre al acercarse. Vender consume la pila entera y exige desequipar. Oro inicial0, obtenido de monstruos. Golpes desgastan arma/armadura; roto pierde bonos hasta reparar. Costos/probabilidades configurables.

M o clic en minimapa abre mapa. Enter abre chat con Global/Local; offline informa que no envía. Esc cierra chat/mapa/tienda antes del menú. Configuración de pantalla/volumen disponible desde menú. Resolución interna640x360, nearest y escala integer; UI probada a960x540/1280x720.

## Datos y pruebas

Cliente guarda por nombre en `%APPDATA%/Godot/app_userdata/ÉTER/characters/`: inventario/equipo/oro/XP, checksum y escritura temporal/rename. Servidor guarda cuentas/personajes/posición en SQL, directorio server/.local ignorado por Git. Son dos modos separados: no hay migración de guardados locales a cuentas online todavía.

Test cliente importa/headless y verifica movimiento, clases, combate, IA, progresión, inventario y economía. -Graphics añade input/drag reales, NPC/tiendas, mapa/chat/UI, snapshots a disco y recarga en otro proceso. Tests/capturas no guardan personajes ni configuración del usuario; fixtures en artifacts. Backend tiene39 tests: movimiento/combate/IA/progresión, dos peersWS, ownership/concurrencia, heartbeat, SQL/reinicio y cierre Windows ordenado/idempotente. [TEST_REPORT](docs/TEST_REPORT.md) distingue pruebas reales y pendientes.

Recursos originales locales generados con `node tools/generate-art.mjs`; geometría original compartida con `node tools/generate-world.mjs`; `node tools/sync-data.mjs` sincroniza catálogos (runner lo hace automáticamente). Sin recursos remotos durante juego. PostgreSQL viene de dependencia local, no requiere instalación global ni Docker.

## Límites actuales y continuidad

Godot online, inventario/loot/economía autoritativos, interacción entre dos clientes Godot, reconexión, party/comercio, tres mapas conectados, misiones/contenido y exportaciónWindows están pendientes. Dos peersWS verificados no equivalen a multijugador jugable completo. Objetos del suelo del cliente son temporales, posición local no se guarda; arte procedural sigue provisional, modelos de armadura visual limitados y proyectiles resuelven daño al lanzar. Servidor guarda al desconectar: checkpoints, recuperación durable ante falloSQL y cooldowns persistentes al reconectar pendientes.

Continuar por [NEXT_TASK](docs/NEXT_TASK.md), [PROGRESS](docs/PROGRESS.md) y [MASTER_PLAN](docs/MASTER_PLAN.md). Reglas en AGENTS.md, arquitectura/diseño/arte en docs. Commits locales por hitos, sin push ni despliegue.
