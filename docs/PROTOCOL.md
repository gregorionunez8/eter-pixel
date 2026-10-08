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

No existe operación para enviar estado, daño, experiencia, inventario ni oro. Crear acepta sólo nombre/clase; campos adicionales se rechazan. Tres personajes máximo por cuenta, nombre global insensible a mayúsculas, validación de nombre compartida. Login requiere registro previo. Sesiones se pierden al desconectar; reconectar con login conserva personajes por SQL, aún sin token de reanudación.

Servidor serializa mensajes por socket, cola8, tasa20/s, máximo64 sockets. IDs repetidos se rechazan dentro de ventana de256 solicitudes por conexión. Binario/sobrecarga cierra conexión. Persistencia usa revision optimista y creación bloquea cuenta en transacción. Sólo servicios internos pueden guardar estado.

Pendiente: selección exclusiva de personaje, simulación de mundo y snapshots, movimiento/rango/combate/loot/inventario/economía autoritativos, heartbeat/reconexión, chat, party/comercio y cliente Godot online. Estas fundaciones no son todavía multijugador jugable.
