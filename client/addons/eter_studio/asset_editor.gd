@tool
extends VBoxContainer
signal saved(path: String)
const Canvas = preload("pixel_canvas.gd")
const PRESETS := {"Inventory Icon":Vector2i(16,16),"Ground Item":Vector2i(16,16),"Weapon Equipped":Vector2i(32,48),"Helmet Equipped":Vector2i(32,48),"Chest Equipped":Vector2i(32,48),"Gloves Equipped":Vector2i(32,48),"Pants Equipped":Vector2i(32,48),"Boots Equipped":Vector2i(32,48),"Wings":Vector2i(32,48),"Pet":Vector2i(32,32),"Monster":Vector2i(128,32),"NPC":Vector2i(128,384),"Skill Icon":Vector2i(16,16),"Skill Book":Vector2i(16,16),"Tile":Vector2i(32,32),"Decoration":Vector2i(32,32),"Equipment Sheet (4x8)":Vector2i(128,384)}
var canvas: Control
var filename := ""
var dirty := false
var status := Label.new()
var width := SpinBox.new()
var height := SpinBox.new()
var picker := ColorPickerButton.new()
var presets := OptionButton.new()

func _ready() -> void:
	canvas = Canvas.new()
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	for preset in PRESETS: presets.add_item(preset)
	toolbar.add_child(presets)
	for entry in [["New Canvas",new_canvas],["Open PNG",open_dialog],["Save PNG",save],["Save As",save_dialog],["Undo",canvas.undo],["Redo",canvas.redo]]:
		button(toolbar,entry[0],entry[1])
	var tools := HBoxContainer.new(); add_child(tools)
	for name in ["Pencil","Eraser","Fill","Color Picker"]:
		button(tools,name,func(): canvas.tool=name; update_status())
	picker.color = Color.WHITE; tools.add_child(picker); picker.color_changed.connect(func(value): canvas.color=value)
	canvas.picked.connect(func(value): picker.color=value; canvas.color=value)
	var zoom := SpinBox.new(); zoom.min_value=1; zoom.max_value=32; zoom.value=12; zoom.prefix="Zoom "; tools.add_child(zoom)
	zoom.value_changed.connect(func(value): canvas.zoom=int(value); canvas.refresh())
	var grid := CheckBox.new(); grid.text="Grid"; grid.button_pressed=true; tools.add_child(grid); grid.toggled.connect(func(value): canvas.grid=value; canvas.queue_redraw())
	var transforms := HBoxContainer.new(); add_child(transforms)
	for control in [width,height]: control.min_value=1; control.max_value=512; control.value=16; transforms.add_child(control)
	button(transforms,"Resize",func(): canvas.resize_canvas(int(width.value),int(height.value)))
	button(transforms,"Mirror H",func(): canvas.mirror(true)); button(transforms,"Mirror V",func(): canvas.mirror(false))
	button(transforms,"Clear",func(): confirm_destructive(func(): canvas.reset(canvas.bitmap.get_width(),canvas.bitmap.get_height())))
	var palette := HBoxContainer.new(); add_child(palette)
	for hex in ["111522","75828b","d5aa64","64c8cf","82bf85","b94c4c","487dbc","ffffff"]:
		var color := Color(hex)
		var choice := Button.new(); choice.text="■"; choice.modulate=color; palette.add_child(choice)
		choice.pressed.connect(func(): picker.color=color; canvas.color=color)
	add_child(status)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.y=420; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; add_child(scroll); scroll.add_child(canvas)
	canvas.edited.connect(func(): dirty=true; update_status())
	update_status()

func button(parent: Node,text: String,action: Callable) -> void:
	var control := Button.new(); control.text=text; parent.add_child(control); control.pressed.connect(action)

func update_status() -> void:
	status.text = ("● Sin guardar · " if dirty else "")+(filename if not filename.is_empty() else "Nuevo PNG")+" · "+canvas.tool+" · "+str(canvas.bitmap.get_size())

func confirm_destructive(action: Callable) -> void:
	if not dirty: action.call(); return
	var dialog := ConfirmationDialog.new(); dialog.dialog_text="Hay cambios en el dibujo sin guardar. ¿Descartarlos?"; add_child(dialog)
	dialog.confirmed.connect(func(): action.call(); dialog.queue_free()); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()

func new_canvas() -> void:
	confirm_destructive(func():
		var dimensions: Vector2i = PRESETS[presets.get_item_text(presets.selected)]
		canvas.reset(dimensions.x,dimensions.y); width.value=dimensions.x; height.value=dimensions.y; filename=""; update_status())

func open_dialog() -> void:
	confirm_destructive(func():
		var dialog := FileDialog.new(); dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE; dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.filters=PackedStringArray(["*.png ; PNG"]); add_child(dialog)
		dialog.file_selected.connect(func(selected): open_png(selected); dialog.queue_free()); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(820,560)))

func open_png(file_path: String) -> bool:
	var image := Image.new()
	if image.load(file_path) != OK: status.text="No se pudo abrir PNG."; return false
	if image.get_width()>512 or image.get_height()>512: status.text="Máximo512×512. Usar una hoja dentro de este límite."; return false
	image.convert(Image.FORMAT_RGBA8); canvas.bitmap=image; canvas.undo_stack.clear(); canvas.redo_stack.clear(); canvas.refresh()
	filename=file_path; width.value=image.get_width(); height.value=image.get_height(); dirty=false; update_status(); return true

func save_dialog() -> void:
	var dialog := FileDialog.new(); dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE; dialog.access=FileDialog.ACCESS_RESOURCES
	dialog.current_dir="res://assets"; dialog.current_file="new_asset.png"; dialog.filters=PackedStringArray(["*.png ; PNG"]); add_child(dialog)
	dialog.file_selected.connect(func(selected): save_png(selected); dialog.queue_free()); dialog.canceled.connect(dialog.queue_free); dialog.popup_centered(Vector2i(820,560))

func save() -> void:
	if filename.is_empty() or not ProjectSettings.localize_path(filename).begins_with("res://assets/"): save_dialog()
	else: save_png(filename)

func save_png(file_path: String) -> bool:
	var local := ProjectSettings.localize_path(file_path)
	if not local.begins_with("res://assets/"): status.text="Guardar en res://assets/ para conservar referencias del juego."; return false
	if canvas.bitmap.save_png(file_path) != OK: status.text="No se pudo guardar PNG."; return false
	filename=local; dirty=false; update_status(); saved.emit(local); return true
