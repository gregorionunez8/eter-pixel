# Arquitectura

Monorepositorio: client/ (Godot), server/ (TypeScript), shared/ (datos y protocolo), tools/ (generadores y scripts), tests/ (integración), docs/ (continuidad).

Cliente: autoload App para configuración, recursos y registro; Main para flujo de pantallas; escenas independientes de mundo y actor. Resolución interna 640x360, viewport e integer scaling, renderer Compatibility y nearest.

Movimiento: AStarGrid2D sobre tiles 32x32 con diagonales sin atravesar esquinas. Cuerpo CharacterBody2D y obstáculos StaticBody2D; navegación y física deben compartir las mismas huellas. Cámara sobre el actor, objetos con Y-sorting.

Backend previsto: tick fijo autoritativo, comandos validados, snapshots WebSocket y repositorio transaccional PostgreSQL. Es una decisión de diseño; aún no existe implementación del backend.

Personajes: shared/classes.json contiene atributos y coeficientes; sync-data.mjs copia sólo el recurso empaquetado al cliente. EterCharacter valida nombres/clases, crea estado independiente y calcula estadísticas. App retiene el personaje activo en memoria. El backend deberá reutilizar los datos y comprobar equivalencia de fórmulas; aún no existe guardado de personaje ni autenticación.

Combate local: EterCombat recibe comandos de selección/cast y procesa temporizadores, validación y efectos. EterCombatRules resuelve impactos con rolls explícitos, coeficientes shared/combat.json. Targets de entrenamiento exponen estado y representación, el controlador aplica daño/respawn. Señal hit_resolved entrega evidencia del impacto; state_changed actualiza HUD. Cada habilidad valida clase, maná, cooldown, rango, vivo y línea de visión antes de consumir recursos. El servidor sustituirá esta autoridad local; no aceptar estos resultados del cliente online.

Input: coordenadas de InputEvent transformadas con get_global_transform_with_canvas().affine_inverse(), almacenadas para destino continuo. GUI recibe primero eventos y sólo gameplay no consumido llega a _unhandled_input. Pruebas gráficas usan Viewport.push_input con coordenadas locales y proceso real. Referencia: https://docs.godotengine.org/en/stable/classes/class_viewport.html

Catalog autoload contiene el cache de JSON empaquetados y se registra antes de App. Las funciones estáticas de reglas no almacenan variables estáticas; evita retención de recursos observada en importación. EterMonster hereda de la base CharacterBody2D de objetivos, tiene su propio tick de IA/física y usa el controlador de combate como Node para resolver daño. EterCombat emite target_defeated una vez; daño a cadáver se rechaza. Los estados de IA y temporizadores son locales por ahora.

EterProgression centraliza XP requerido, premios/niveles, asignación y penalización. Datos shared/progression.json. world recompensa sólo muerte de EterMonster; efigies excluidas. Al subir nivel recalcula estadísticas y llena recursos; al asignar aumenta límites conservando déficit. Penalización descuenta sólo XP actual sin bajar nivel. Reset sólo cuenta y valida elegibilidad según flag, operación todavía no implementada.

Referencia de escalado: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
