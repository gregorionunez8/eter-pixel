# Asset Editor
Abrir MEDIA > Asset Editor, o Dibujar / Importar desde un campo de item/skill/monstruo.
New Canvas toma el preset seleccionado. Inventory/Ground/Skill Icon/Skill Book:16×16; equipment32×48; tile32×32; NPC y equipment sheet128×384 (4 columnas ×8 direcciones); Monster128×32 inicial. No cambiar la escala base del juego.
Pencil dibuja arrastrando. Eraser borra transparencia. Fill rellena el área contigua. Color Picker toma un píxel. ColorPickerButton permite elegir color y paleta.
Zoom y Grid afectan sólo la vista. Undo/Redo conservan estados. Clear pide confirmación si hay cambios. Mirror H/V invierte píxeles. Resize cambia lienzo sin reescalar el dibujo; limita a512×512.
Open PNG puede leer un archivo externo. Save As guarda en res://assets/ dentro del proyecto. Save PNG reutiliza esa ruta. Si abriste desde un item, guardar asigna el PNG a ese campo. Guardar el contenido y construir después.
Para equipment animado usar una hoja4×8, frame32×48. Un PNG estático requiere Hframes1/Vframes1. El editor es básico; no tiene capas de dibujo, selección compleja ni editor de partículas.
