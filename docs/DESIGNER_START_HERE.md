# Diseñador: empezar aquí
Abrir client/project.godot y elegir ÉTER Studio. No hace falta abrir scripts. IDs son internos y estables; nombres visibles pueden cambiar.

## QUIERO HACER UNA ESPADA
CONTENT > Items > Create; ID blade_001; Type weapon; Name; Bonuses/attack; Save All.

## QUIERO DIBUJAR LA ESPADA
Items > Inventory Icon > Dibujar / Importar; preset Inventory Icon; New Canvas; Pencil/Palette; Save As.

## QUIERO HACER CÓMO SE VE TIRADA
Items > Ground / Drop Sprite > Dibujar / Importar; preset Ground Item; Save As con otra ruta PNG.

## QUIERO HACER CÓMO SE VE EQUIPADA
Items > Equipped Visual > Path > Dibujar / Importar; preset Weapon Equipped o Equipment Sheet; configurar Hframes/Vframes, Offset, Scale y Layer.

## QUIERO DECIDIR QUIÉN PUEDE USARLA
Items > Allowed Classes / Classes: casillas Warrior, Mage, Elf o ALL; Required Level.

## QUIERO DARLE SKILL
Items > Options > + Agregar campo > skill; selector de poder. No usarlo en tipo no permitido.

## QUIERO HACER UN MONSTRUO
CONTENT > Monsters > Create; Name, HP, Level, Attack, Speed; TEST SPAWN en sala.

## QUIERO DIBUJAR EL MONSTRUO
Monsters > Visual > Path > Dibujar / Importar; preset Monster; configurar hoja y mapping; preview.

## QUIERO DECIDIR SUS DROPS
Monsters > Drops > + Agregar fila; elegir Item; Chance% (decimal), cantidades/upgrades y opciones.

## QUIERO HACER UN SPOT
WORLD > Maps > abrir mapa > lienzo > Spot; elegir especie; click; Select / Move para arrastrar; editar Quantity/radios/Respawn.

## QUIERO HACER UN MAPA
WORLD > Maps > Create; ID y nombre; bajar al lienzo; Paint y Layer; Collision; Default Spawn con click.

## QUIERO HACER UNA ZONA SEGURA
Maps > lienzo > Safe Zone > click; Select / Move; Width/Height y Monster Aggro Disabled. PvP avanzado no está incluido.

## QUIERO PONER UN NPC
CONTENT > NPCs > Create/editar definición; después Maps > NPC > selector del ID > click; mover/facing en instancia.

## QUIERO CREAR UNA TIENDA
CONTENT > Shops > Create; Stock > agregar items; precios y permisos; NPCs tipo shop con Shop ID; colocarlo en Maps.

## QUIERO CREAR UN PODER
CONTENT > Skills > Create; clases/nivel/mana/cooldown/daño; Behavior soportado; icono; TEST CAST.

## QUIERO HACER SU LIBRO
Skills > CREATE SKILL BOOK; Items abre el libro: clases/nivel, Inventory Icon y Ground Sprite.

## QUIERO PONERLE SONIDO
MEDIA > Audio > Create > Path > Importar audio; Play; después elegir su ID en el campo de audio del contenido. Ver conexiones soportadas en AUDIO_EDITOR.

## QUIERO CAMBIAR EL NIVEL MÁXIMO
GAME > Progression > Max Level; o Balance > Progression; revisar curva XP; Validate > Build.

## QUIERO CAMBIAR EL RESET
GAME > Progression > Reset Enabled/Reset Min Level; GAME > Balance > reset: costo/points/bonus/políticas; NPCs tipo reset.

## QUIERO CAMBIAR EL AUDIO DE LA CIUDAD
MEDIA > Audio importa la música; WORLD > Maps > village > Music/Ambient Sound, Volume/Fade Duration; Save All > Build.

Al terminar un cambio: Save All > Validate > Build Content > TEST. Reiniciar servidor para probar online. Si Validate bloquea, abrir su error y corregir el formulario. Revisar límites documentados antes de usar campos preparados.
