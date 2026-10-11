# ÉTER Studio
Estado: implementación en curso, primer incremento verificable (10/10/2026).

Abrir client/project.godot con Godot 4 estable y elegir la pantalla **ÉTER Studio** en la barra superior. Si no aparece: Project > Project Settings > Plugins > ÉTER Studio > Enable.

Navegación a la izquierda; buscador, filtro y orden en el centro; formulario visual a la derecha. Create solicita un ID estable (minúsculas, números, guión o guión bajo). Duplicate crea una copia con otro ID. Delete pide confirmación y muestra referencias.

**Save / Save All** valida y guarda los cambios en shared. **Build Content** valida, guarda y copia a client/data. Reiniciar el juego y el servidor después de construir. Nunca ejecutar generate-world para publicar contenido de diseñador: es el generador procedural original.

Los formularios editan valores y selectores, no requieren editar JSON. Campos opcionales del esquema pueden estar preparados pero todavía necesitan integración runtime: consultar el informe de pruebas y el alcance de cada editor. No confundir que un valor se guarde con que tenga efecto en combate.

**Asset Editor** abre una ventana de dibujo: presets, lápiz, goma, fill, selector de color, paleta, zoom, grid, undo/redo, limpiar, mirror y resize. Open PNG puede leer archivos externos; Save As guarda dentro de client/assets. Los botones Dibujar / Importar de formularios conectan el PNG guardado al campo.

**Maps** abre el formulario y debajo un lienzo visual. Elegir herramienta y contenido en el selector; click para pintar o colocar. Select / Move permite seleccionar y arrastrar. El formulario de instancia permite ajustar radios, cantidad y demás propiedades. Delete selected instance conserva la definición global.

Validate muestra errores, warnings e información. Click abre el contenido correspondiente. Search permite buscar globalmente; References muestra consumidores del registro seleccionado.

Los datos originales no se reemplazan al abrir. Cambios externos se detectan antes de guardar. Se conserva una copia anterior acotada en artifacts/studio-backup; es local, no se carga en runtime y no se versiona.

Pruebas: tools/test-studio.ps1 (en desarrollo) y tools/test.ps1 para la base del juego.
