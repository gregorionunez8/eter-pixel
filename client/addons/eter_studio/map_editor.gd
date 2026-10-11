@tool
extends VBoxContainer
signal asset_requested(current: String,setter: Callable)
const Canvas=preload("map_canvas.gd")
const Form=preload("form.gd")
var registry: RefCounted
var map: Dictionary
var canvas: Control
var instance_form: VBoxContainer
var selected_key := ""
var selected_index := -1
var choice := OptionButton.new()
var tools := OptionButton.new()
var caption := Label.new()
func open(store: RefCounted,value: Dictionary) -> void:
	registry=store; map=value
func _ready() -> void:
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	for mode in ["Select / Move","Paint","Erase Paint","Collision","Erase Collision","Spot","NPC","Portal","Player Spawn","Default Spawn","Safe Zone","PvP Zone","Audio Zone"]: tools.add_item(mode)
	toolbar.add_child(tools); toolbar.add_child(choice)
	tools.item_selected.connect(func(_index): update_choices())
	choice.item_selected.connect(func(_index): canvas.asset=choice.get_item_text(choice.selected); canvas.content_id=canvas.asset)
	var layers := OptionButton.new(); toolbar.add_child(layers)
	for layer in ["Ground","Secondary Ground","Decoration Below Player","Objects","Decoration Above Player"]: layers.add_item(layer)
	layers.item_selected.connect(func(index): canvas.layer=layers.get_item_text(index))
	var zoom := SpinBox.new(); zoom.min_value=0.25; zoom.max_value=2; zoom.step=0.25; zoom.value=0.5; zoom.prefix="Zoom "; toolbar.add_child(zoom)
	zoom.value_changed.connect(func(value): canvas.zoom=value; canvas.refresh())
	add_child(caption); caption.text="Elegir herramienta y hacer click. Select / Move arrastra instancias; Collision marca celdas; zonas se redimensionan en su formulario."
	var split := HSplitContainer.new(); add_child(split); split.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size=Vector2(600,430); split.add_child(scroll)
	canvas=Canvas.new(); scroll.add_child(canvas); canvas.configure(registry,map)
	var fields := VBoxContainer.new(); split.add_child(fields); fields.custom_minimum_size.x=280
	var remove := Button.new(); remove.text="Delete selected instance"; fields.add_child(remove)
	remove.pressed.connect(delete_selected)
	instance_form=Form.new(); fields.add_child(instance_form)
	instance_form.asset_requested.connect(func(current,setter): asset_requested.emit(current,setter))
	canvas.selected.connect(select_instance)
	update_choices()
func update_choices() -> void:
	canvas.tool=tools.get_item_text(tools.selected); choice.clear()
	var kind := "Monsters" if canvas.tool=="Spot" else "NPCs" if canvas.tool=="NPC" else "Maps" if canvas.tool=="Portal" else "Assets"
	for id in registry.records(kind): choice.add_item(id)
	if choice.item_count>0: canvas.asset=choice.get_item_text(0); canvas.content_id=canvas.asset
func select_instance(key: String,index: int) -> void:
	selected_key=key; selected_index=index
	instance_form.open(registry,"Spots" if key=="monsters" else "NPCs" if key=="npcs" else "Maps",map[key][index])
	if not instance_form.edited.is_connected(canvas.queue_redraw): instance_form.edited.connect(canvas.queue_redraw)
func delete_selected() -> void:
	if selected_index<0: return
	var dialog := ConfirmationDialog.new(); dialog.dialog_text="¿Eliminar la instancia seleccionada del mapa? La definición global se conserva."; add_child(dialog)
	dialog.confirmed.connect(func():
		map[selected_key].remove_at(selected_index); selected_index=-1; registry.touch(); canvas.queue_redraw()
		for child in instance_form.get_children(): child.queue_free()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered()
