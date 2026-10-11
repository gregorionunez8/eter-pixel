# Audio Editor
MEDIA > Audio > Create. ID único, Name, Category. Path > Importar audio abre WAV/OGG externo y copia a res://assets/audio. Rechaza sobrescribir archivos con el mismo nombre.
Play/Stop previsualizan con Volume/Pitch. La biblioteca de sonidos inicia vacía: no se agrega audio final ni archivos externos sin elección del diseñador.
Referenciar ID del sonido desde Audio en items, monsters, NPCs, skills/portals; mapas tienen Music/Ambient Sound, Volume/Fade Duration. Las rutas de assets se validan.
Runtime central: buses Master, Music, Ambient, SFX, UI, Combat, Voice. Respeta volumen Master existente. Funciona audio de mapa/zona, footsteps configurados en audio.footsteps, interacción/apertura NPC, cast y eventos locales de monstruo.
Algunas referencias (item/portal/impact/exit/online monster) todavía necesitan conexión y prueba; no se consideran completas por mostrar un campo. Loop/crossfade avanzado y variación de pitch están parciales.
WORLD > Maps > Audio Zone: click rectángulo; formulario music, ambient_sound, priority y fade_time. Mayor prioridad gana.
Para superficies: MEDIA > Assets > Surface; asociar sonidos en la configuración Footsteps. El paso toma la superficie de tiles pintados.
Guardar > Build > reiniciar. Probar reproducción audible además de pruebas headless.
