# Servidor local Windows

Node24/npm y red para instalar dependencias la primera vez. Todo se instala en server/node_modules; no servicio Windows ni usuario nuevo. PostgreSQL18.4 real se inicia con embedded-postgres. Después de instalar, arranque/pruebas no descargan recursos.

```powershell
./tools/start-server.ps1 -Install
```

Compila TypeScript e inicia PostgreSQL en127.0.0.1:55432 y WebSocket en127.0.0.1:8080. Ctrl+C cierra ambos. Datos persistentes en server/.local/postgres (ignorado por Git). Segundo arranque no requiere -Install. Credenciales SQL públicas exclusivamente de desarrollo: usuarioeter/contraseñaeter-local-development; no usar para despliegue. No se ejecuta en interfaces públicas. ETER_PORT/ETER_DB_PORT permiten cambiar puertos en el proceso. No ejecutar dos servidores con el mismo directorio de cluster.

```powershell
./tools/test-server.ps1
```

Pruebas compilan y levantan cluster real en artifacts/postgres-backend-test, puerto55439, servicios WebSocket en puerto efímero. No alteran cuentas de server/.local. Repetibles, nombres de fixtures únicos. Apagan/reabren PostgreSQL y comprueban persistencia; no usan mocks SQL. Logs de fallo se imprimen; datos de fixtures se conservan.

Certificados: este entorno requirió NODE_USE_SYSTEM_CA=1 para npm. start-server lo configura sólo en su proceso, sin desactivar validaciónTLS ni cambiar configuración global. Si instalación falla por CA, usar certificados del sistema; no usar strict-ssl=false.

Postinstall pendiente en npm para @embedded-postgres/windows-x64: inspeccionado scripts/hydrate-symlinks.js, su manifiesto native/pg-symlinks.json está vacío enWindows y no requiere enlaces. Arranque/pruebas pasan sin aprobar scripts globalmente. El wrapper npm tiene versión prerelease18.4.0-beta.17; el binario ejecutado reporta PostgreSQL18.4. Sin Docker disponible, esta es la ruta verificada.

Referencias: [embedded-postgres, API y licenciaMIT](https://github.com/leinelissen/embedded-postgres), [PostgreSQL para Windows](https://www.postgresql.org/download/windows/). Dependencias ws/pg bajoMIT, TypeScript bajoApache2.0, PostgreSQL bajoPostgreSQLLicense; fuentes/licencias dentro de paquetes locales. No se redistribuyen binarios en Git. Protocolo documentado en PROTOCOL.md. Godot continúa offline por ahora.

Launcher Windows actualizado: wrapper se usa sólo para initdb, luego pg_ctl local inicia/cierra con -w/-m fast, spawn sin pipes heredadas y ventana oculta. Evita taskkill del wrapper. Logs en directorio padre del cluster (<nombre>.log), nunca dentro del data dir. Si PID existe, pg_ctl status distingue cluster vivo de PID stale; no iniciar segunda instancia. Cierre repetido es idempotente. Tests crean también cluster limpio en artifacts/postgres-launcher-clean-test:55441 y comprueban doble arranque/cierre. Pruebas actuales39, combate/IA/progresión y peersWS incluidos. Inventario/economía server todavía pendientes.

Pruebas económicas SQL usan artifacts/postgres-economy-test puerto55442, separado del cluster normal. Migración crea world_states para suelo persistente/revision; checkpoint de actores y suelo en una sola transacción. test-server.ps1 verifica fallos SQL deliberados, rollback/reintento, reinicio y propiedad única de UID. No borrar directorios de datos para resolver un cluster activo. Si el proceso cae durante fallo SQL prolongado, queda el último checkpoint confirmado.
