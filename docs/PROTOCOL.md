# Protocolo local v1

WebSocket `ws://127.0.0.1:8080`, texto JSON, 8 KiB máximo, sin compresión.
Solicitud: `{ "v":1, "id":"secuencia-única", "op":"operación", "data":{} }`.
Respuesta: `{ "v":1, "id":"misma-id", "ok":true, "data":... }` o `ok:false,error:"código"`.

Operaciones implementadas:

| op | data | resultado |
|---|---|---|
| register | username,password | registered:true; no autentica automáticamente |
| login | username,password | authenticated:true; sesión asociada al socket |
| characters | vacío | resúmenes de los personajes propios |
| create_character | name,class_id | id,state,revision creados por servidor |
| load_character | character_id | sólo personaje de la cuenta actual |
| enter_world | character_id | sesión exclusiva, state propio y world público |
| move | x,y numéricos | intención; servidor calcula ruta/tiempo/velocidad |
| select_target | target_id; vacío cancela | selecciona enemigo vivo, servidor persigue |
| cast | skill_id | servidor valida clase/rango/LOS/maná/cooldown y calcula daño |
| allocate | attribute,amount entero | puntos propios/cap; deriva stats |
| buy | shop_id,definition | stock/rango/precio servidor; insertar antes de descontar |
| sell | shop_id,uid | vende pila propia no equipada |
| pickup | ground_id | propietario temporal/rango/LOS; consume drop una vez |
| drop | uid | retira inventario y crea suelo persistente |
| equip / consume / repair / upgrade | uid | reglas de clase/vida/consumible o herrero/costo servidor |
| unequip | slot | exige espacio disponible |
| inventory_move | uid,x,y | coordenadas enteras, ocupación validada |

No existe operación para enviar estado, daño, experiencia, inventario ni oro. Crear acepta sólo nombre/clase; campos adicionales se rechazan. Tres personajes máximo por cuenta, nombre global insensible a mayúsculas, validación de nombre compartida. Login requiere registro previo. Sesiones se pierden al desconectar; reconectar con login conserva personajes por SQL, aún sin token de reanudación.

Servidor serializa mensajes por socket, cola8, tasa20/s, máximo64 sockets. IDs repetidos se rechazan dentro de ventana de256 solicitudes por conexión. Binario/sobrecarga cierra conexión. Persistencia usa revision optimista y creación bloquea cuenta en transacción. Sólo servicios internos pueden guardar estado.

Evento sin id: `{v:1,event:"snapshot",data:{tick,map_id,players:[{id,name,class_id,level,hp,position}]}}`,20Hz para jugadores en mundo. Inventario/oro no son públicos. Cliente nunca envía posición actual, delta ni velocidad, sólo destino; coordenadas finitas dentro de mundo. Servidor navega alrededor de sólidos y respeta presupuesto speed*tiempo real. Personaje no admite otra sesión activa. Al desconectar guarda posición/estado/revisión SQL antes de liberar exclusión. Ping/pong10s limpia conexiones silenciosas.

Snapshot ahora incluye enemies (id/species/name/level/hp/max_hp/phase/position) y últimos128 events con sequence/kind. Eventos hit/skill/defeated/player_death/player_respawn/enemy_respawn. Procesar sólo sequence nueva. self privado: `{v:1,event:"self",data:{state,cooldowns}}`, nunca se transmite a otros peers. Combat/IA/XP se resuelven por tick servidor. No hay award_experience/damage/save_state y campos extra se rechazan.

Snapshot incluye ground con UID, item/gold, position y protección temporal. Transacciones económicas confirman checkpoint SQL de todos los actores y suelo antes de responder. Checkpoint periódico1s y al desconectar; fallo de desconexión mantiene exclusión y reintenta. Estado privado incluye combat_state con deadlines persistentes de cooldown/respawn/regeneración. Identificadores no se reintentan automáticamente: tras un timeout hay que reconciliar estado para evitar repetir una compra con otra id.

Pendiente: reconexión/cliente Godot online, chat, party/comercio y mapas adicionales. Ante muerte del proceso durante una interrupción SQL prolongada se conserva el último checkpoint confirmado; las transacciones fallidas no se reconocen como exitosas.

Godot integrado: client/scripts/online_lobby.gd + online_world.gd usan protocolo v1. Public player ahora expone max_hp y weapon_equipped para UI/sprite, no inventario/oro. inventory_move permite mover un objeto equipado a grid y quitar slot en una sola transacción; si destino inválido no cambia nada. self normaliza representación de enteros JSON sin calcular gameplay local. Eventos se deduplican por sequence y al reconectar se omiten efectos históricos.
