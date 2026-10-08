# Arquitectura

Monorepositorio: client/ (Godot), server/ (TypeScript), shared/ (datos y protocolo), tools/ (generadores y scripts), tests/ (integración), docs/ (continuidad).

Cliente: autoload App para configuración, recursos y registro; Main para flujo de pantallas; escenas independientes de mundo y actor. Resolución interna 640x360, viewport e integer scaling, renderer Compatibility y nearest.

Movimiento: AStarGrid2D sobre tiles 32x32 con diagonales sin atravesar esquinas. Cuerpo CharacterBody2D y obstáculos StaticBody2D; navegación y física deben compartir las mismas huellas. Cámara sobre el actor, objetos con Y-sorting.

Backend previsto: tick fijo autoritativo, comandos validados, snapshots WebSocket y repositorio transaccional PostgreSQL. Es una decisión de diseño; aún no existe implementación del backend.

Referencia de escalado: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
