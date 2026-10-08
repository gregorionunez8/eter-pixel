# Plan maestro

Objetivo: vertical slice original de ÉTER, MMORPG 2D con control por mouse, persistencia PostgreSQL y dos clientes simultáneos.

1. Fundaciones: estructura, menú, configuración, transición, importación y ejecución Godot.
2. Movimiento: navegación por cuadrícula con A*, cuerpo físico, ocho direcciones, destino continuo, cámara y pruebas de obstáculos.
3. Mundo: Aldea de Éter con plaza, caminos, viviendas, herrero, tienda, vegetación, muros y salida.
4. Personajes: datos de tres clases, creación, atributos derivados y apariencias.
5. Combate: persecución, autoataque, muerte, regeneración y habilidades.
6. Monstruos: seis especies, estados de IA, colisiones y respawn.
7. Progresión: fórmulas centralizadas, experiencia, atributos y penalización.
8. Inventario: cuadrícula, tamaños, apilado, equipo y validación.
9. Economía: loot, oro, compras, venta, reparación y mejoras.
10. Interfaz: HUD, ventanas, minimapa y atajos.
11. Servidor: protocolo, autenticación local y almacenamiento PostgreSQL.
12. Multijugador: autoridad, interpolación, reconexión, chat, party y comercio.
13. Contenido: tres mapas conectados, misiones, NPC, mini jefe y ciclo completo.
14. QA: pruebas de reglas, motor, red, datos y dos clientes reales.
15. Entrega: README, scripts Windows, exportación si existen plantillas y límites explícitos.

Cada hito requiere evidencia y commit. La falta de PostgreSQL no debe ocultarse usando una prueba simulada como persistencia SQL real.

Estado2026-10-08: módulos1-10 integrados en modo local y verificados por suites del motor; chat UI rechaza entrega offline hasta servidor. Persisten objetos/personaje/oro en JSON local. Próximo módulo11 servidor. Multijugador, SQL y tres mapas aún pendientes, objetivo completo no cumplido.
