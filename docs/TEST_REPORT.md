# Reporte de pruebas

Este archivo contiene sólo ejecuciones realizadas y resultados observados. La inspección confirmó Godot 4.7.2 y Node 24.19.0.

2026-10-08, `./tools/test.ps1`: importación headless exit 0; smoke exit 0 y `PASS foundation: menu, transition, world scene`. Sin errores de GDScript. Logs en artifacts/import.*.log y smoke.*.log.

Fallos corregidos en runner: wrapper console carecía de exe con el nombre esperado; llamada GUI directa no esperaba finalización. Se usa Start-Process con handle y timeout de 45 s, exit code y rechazo de errores de motor. No se tomaron las ejecuciones anteriores como éxitos.
