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

No existe operación para enviar estado, daño, experiencia, inventario ni oro. Crear acepta sólo nombre/clase; campos adicionales se rechazan. Tres personajes máximo por cuenta, nombre global insensible a mayúsculas, validación de nombre compartida. Login requiere registro previo. Sesiones se pierden al desconectar; reconectar con login conserva personajes por SQL, aún sin token de reanudación.

Servidor serializa mensajes por socket, cola8, tasa20/s, máximo64 sockets. IDs repetidos se rechazan dentro de ventana de256 solicitudes por conexión. Binario/sobrecarga cierra conexión. Persistencia usa revision optimista y creación bloquea cuenta en transacción. Sólo servicios internos pueden guardar estado.

Evento sin id: `{v:1,event:"snapshot",data:{tick,map_id,players:[{id,name,class_id,level,hp,position}]}}`,20Hz para jugadores en mundo. Inventario/oro no son públicos. Cliente nunca envía posición actual, delta ni velocidad, sólo destino; coordenadas finitas dentro de mundo. Servidor navega alrededor de sólidos y respeta presupuesto speed*tiempo real. Personaje no admite otra sesión activa. Al desconectar guarda posición/estado/revisión SQL antes de liberar exclusión. Ping/pong10s limpia conexiones silenciosas.

Pendiente: combate/IA/rango/loot/inventario/economía autoritativos, reconexión Godot, chat, party/comercio y cliente Godot online. Estas fundaciones aún no son multijugador jugable completo. Servidor simple guarda al desconectar; aún no hay checkpoints periódicos de mundo ni recuperación durable de fallo de guardado.
