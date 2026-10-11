# Spot Editor
Crear desde WORLD > Maps, debajo del formulario: herramienta Spot, selector de monstruo, click.
Se muestran centro, nombre, Spawn Radius y Walk Radius. Select / Move arrastra el centro. Formulario de instancia: Quantity, Species, Walk Radius, Spawn Radius, Respawn, Enabled y override de aggro cuando corresponda.
El runtime expande cantidades en spawns con IDs deterministas; cliente y servidor usan el mismo adapter. Las colocaciones antiguas conservan IDs.
Para varios tipos se pueden usar entries bajo el spot; deben ser grupos con species/quantity. La UI de creación de entries aún debe verificarse con la versión exacta instalada. No usar JSON manual como solución del editor.
WORLD > Spots lista las instancias entre mapas. Su ID incluye mapa; eliminar no borra la especie global.
Guardar y Build; Test Maps para comprobar ubicación/radios. No ubicar dentro de obstáculos o fuera de bordes. Límite inicial64 unidades por grupo.
