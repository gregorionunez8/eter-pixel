# Monster Editor
CONTENT > Monsters muestra las seis especies actuales. Create/Duplicate usan IDs propios, nunca nombre visible como referencia.
Editar Name, Level, Max HP, Attack, Defense, Speed, Aggro Range, Return / Walk Range, Attack Range, Attack Interval, Respawn Time, Collision Radius, Accuracy/Evasion y Experience.
Visual contiene Path, Hframes/Vframes, Scale y mapping de animación. Frames actuales:4 columnas; sprites actuales32×32 salvo especies de otra altura original. Para contenido nuevo, asignar una hoja con dimensiones divisibles por frames. Pivot desplaza el sprite; Collision Radius es circular. Frame Width/Height y Magic Defense/Max MP son campos preparados; el tamaño efectivo viene de la imagen y Hframes/Vframes. Ajustar y probar según el dibujo.
El preview anima la primera fila de la hoja. Los mappings del runtime utilizan idle, walk, attack y death según los estados disponibles; hit no tiene fase visual propia todavía. no es un editor avanzado de timeline.
La sección Drops está debajo: + Agregar fila, item mediante selector, Chance%, cantidades, upgrades y opciones con valor. Chance admite0.0001%. Ordenar drops por chance.
TEST abre la sala aislada, elegir especie en selector y TEST SPAWN. Usa AI/combat existentes.
