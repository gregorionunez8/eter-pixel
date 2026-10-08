# ÉTER — reglas permanentes

- Construir una vertical slice verificable, no declarar un MMORPG terminado.
- Godot 4 estable / GDScript; Node.js / TypeScript; WebSocket; PostgreSQL.
- Orden: fundaciones, movimiento, mundo, personajes, combate, monstruos, progresión, inventario, economía, interfaz, servidor, multijugador, contenido, QA, entrega.
- Incrementos pequeños: implementar, reproducir errores, corregir, verificar y registrar antes de avanzar.
- Recursos originales locales; no copiar MU Online. Base 640x360, nearest, tiles 32x32 y personajes 32x48.
- Servidor autoritativo para movimientos, combate, inventario y economía. No confiar en datos económicos del cliente.
- No software global, gastos, despliegues, secretos ni push sin autorización. No modificar otros proyectos.
- Commits locales por hitos estables. Actualizar docs/PROGRESS.md, TEST_REPORT.md y NEXT_TASK.md con evidencia real.
- Nunca inventar pruebas exitosas. Distinguir implementado, verificado y pendiente.
- Continuar autónomamente sin solicitar decisiones menores. Si hay un bloqueo, registrar diagnóstico y recuperación.
- Mantener scripts reproducibles de arranque y pruebas para Windows.
