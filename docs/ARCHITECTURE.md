# Arquitectura

Backend fundaciones: Store sobre pg.Pool (cuentas UUID/scrypt, personajes jsonb, UNIQUE lower(name), creación bloqueada por cuenta y revisiónCAS). rules.ts consume mismo shared JSON que Godot y genera UID/items/stats iniciales. service.ts autentica por socket y sólo acepta intenciones de registro/login/crear/cargar/listar, no recibe state. main arranca cluster embebido ligado a localhost y cierra pool+cluster. Postgres datos normal server/.local; tests artifacts separados y reinicio real. Mundo/simulación todavía no trasladados. PROTOCOL/BACKEND_SETUP describen límites y comandos.

Interfaz: map_ui proyecta geometría real del world a minimapa/mapa y sigue entidades. Barras HUD se actualizan desde estado central. chat_ui emite submitted(channel,message) sólo connected; offline no afirma entrega. RichTextLabel.add_text evita interpretar formato recibido. settings_ui reutiliza App.settings, tests no persisten cambios de configuración. Enter/Esc gestionan foco, ventanas usan resolución interna fija y escala integer.

Economía local: EterEconomy consume shared/economy.json (precios/stock/drops/rango). world conecta muerte única -> loot físico, input -> NPC/navegación y shop_ui -> transact validado por rango/LOS/vida. UI sólo envía IDs; costo no viene de la ventana. Compra draft/inserción antes de deducir, venta consume UID una vez, equipo requiere desequipar. Desgaste en hit_resolved desactiva bonos al romperse. Estos servicios todavía se ejecutan localmente y deben trasladarse al servidor autoritativo; no son seguridad online. Loot tiene RNG independiente del combate.

Monorepositorio: client/ (Godot), server/ (TypeScript), shared/ (datos y protocolo), tools/ (generadores y scripts), tests/ (integración), docs/ (continuidad).

Cliente: autoload App para configuración, recursos y registro; Main para flujo de pantallas; escenas independientes de mundo y actor. Resolución interna 640x360, viewport e integer scaling, renderer Compatibility y nearest.

Movimiento: AStarGrid2D sobre tiles 32x32 con diagonales sin atravesar esquinas. Cuerpo CharacterBody2D y obstáculos StaticBody2D; navegación y física deben compartir las mismas huellas. Cámara sobre el actor, objetos con Y-sorting.

Backend previsto: tick fijo autoritativo, comandos validados, snapshots WebSocket y repositorio transaccional PostgreSQL. Es una decisión de diseño; aún no existe implementación del backend.

Personajes: shared/classes.json contiene atributos y coeficientes; sync-data.mjs copia sólo el recurso empaquetado al cliente. EterCharacter valida nombres/clases, crea estado independiente y calcula estadísticas. App retiene el personaje activo en memoria. El backend deberá reutilizar los datos y comprobar equivalencia de fórmulas; aún no existe guardado de personaje ni autenticación.

Combate local: EterCombat recibe comandos de selección/cast y procesa temporizadores, validación y efectos. EterCombatRules resuelve impactos con rolls explícitos, coeficientes shared/combat.json. Targets de entrenamiento exponen estado y representación, el controlador aplica daño/respawn. Señal hit_resolved entrega evidencia del impacto; state_changed actualiza HUD. Cada habilidad valida clase, maná, cooldown, rango, vivo y línea de visión antes de consumir recursos. El servidor sustituirá esta autoridad local; no aceptar estos resultados del cliente online.

Input: coordenadas de InputEvent transformadas con get_global_transform_with_canvas().affine_inverse(), almacenadas para destino continuo. GUI recibe primero eventos y sólo gameplay no consumido llega a _unhandled_input. Pruebas gráficas usan Viewport.push_input con coordenadas locales y proceso real. Referencia: https://docs.godotengine.org/en/stable/classes/class_viewport.html

Catalog autoload contiene el cache de JSON empaquetados y se registra antes de App. Las funciones estáticas de reglas no almacenan variables estáticas; evita retención de recursos observada en importación. EterMonster hereda de la base CharacterBody2D de objetivos, tiene su propio tick de IA/física y usa el controlador de combate como Node para resolver daño. EterCombat emite target_defeated una vez; daño a cadáver se rechaza. Los estados de IA y temporizadores son locales por ahora.

EterProgression centraliza XP requerido, premios/niveles, asignación y penalización. Datos shared/progression.json. world recompensa sólo muerte de EterMonster; efigies excluidas. Al subir nivel recalcula estadísticas y llena recursos; al asignar aumenta límites conservando déficit. Penalización descuenta sólo XP actual sin bajar nivel. Reset sólo cuenta y valida elegibilidad según flag, operación todavía no implementada.

Inventario: lista única de instancias UID y equipo por referencia. Objetos en grid tienen x/y no negativos; equipados x=y=-1. Transacciones locales con draft para apilar/equipar evitan perder objetos si no hay espacio; remove transfiere misma instancia al suelo y pickup valida ownership/distancia/espacio antes de eliminar ground. EterCharacter.derive calcula bonos, UI emite changed y world sincroniza estado/sprite/guardado. Componentes Control usan drag APIs del motor; no hay lógica económica confiada a servidor aún.

Persistencia local previa a backend: EterSave serializa character en envelope versión1/payload/checksum, temporal y rename. Loader valida rangos/objetos y deriva stats. user://characters por nombre, último por puntero; tests/capturas usan artifacts. No guarda posición/mapa ni suelo. Checksum verifica integridad accidental; SQL y autoridad server reemplazarán el estado local online, no aceptarán este archivo como prueba de propiedad.

Referencia de escalado: https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
