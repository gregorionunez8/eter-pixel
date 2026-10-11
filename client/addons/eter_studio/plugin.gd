@tool
extends EditorPlugin
var studio: Control

func _enter_tree() -> void:
	studio = preload("studio.gd").new()
	studio.editor_plugin = self
	get_editor_interface().get_editor_main_screen().add_child(studio)
	studio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	studio.hide()

func _exit_tree() -> void:
	if is_instance_valid(studio): studio.queue_free()

func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "ÉTER Studio"
func _get_plugin_icon() -> Texture2D: return get_editor_interface().get_base_control().get_theme_icon("Edit","EditorIcons")
func _make_visible(visible: bool) -> void:
	if is_instance_valid(studio): studio.visible = visible
func _get_unsaved_status(_for_scene: String) -> String:
	return "ÉTER Studio tiene contenido sin guardar." if is_instance_valid(studio) and (studio.registry.dirty() or (studio.asset_editor!=null and studio.asset_editor.dirty)) else ""
func _save_external_data() -> void:
	if is_instance_valid(studio) and studio.registry.dirty(): studio.save_all()
