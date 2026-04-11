extends Control
class_name HotbarUI

const _HOTBAR_SIZE: int = 10
const _ITEM_ICON_ROOT: String = "res://assets/sprites/placeholder/items"
const _PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"

var _slot_widgets: Array = []
var _warned_missing_game_manager: bool = false

@onready var slot_container: HBoxContainer = $Panel/HBoxContainer
@onready var config_manager = get_node_or_null("/root/ConfigManager")


func _ready() -> void:
	_apply_ui_theme()
	_build_hotbar_slots()
	call_deferred("_connect_game_manager")
	_refresh_hotbar([], 0)


func _build_hotbar_slots() -> void:
	_slot_widgets.clear()
	for child in slot_container.get_children():
		child.queue_free()

	for slot_index in range(_HOTBAR_SIZE):
		var widget: Dictionary = _create_hotbar_slot(slot_index)
		_slot_widgets.append(widget)
		slot_container.add_child(widget["root"])


func _create_hotbar_slot(slot_index: int) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(56, 56)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _build_textured_stylebox(_PANEL_TEXTURE_PATH, 4))
	root.add_child(frame)

	var active_overlay := ColorRect.new()
	active_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	active_overlay.color = Color(0.95, 0.82, 0.24, 0.26)
	active_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_overlay.visible = false
	root.add_child(active_overlay)

	var key_label := Label.new()
	key_label.position = Vector2(4, 2)
	key_label.size = Vector2(16, 16)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.text = str(_format_hotbar_number(slot_index))
	root.add_child(key_label)

	var icon_rect := TextureRect.new()
	icon_rect.position = Vector2(12, 14)
	icon_rect.custom_minimum_size = Vector2(32, 24)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon_rect)

	var count_label := Label.new()
	count_label.position = Vector2(24, 38)
	count_label.size = Vector2(28, 16)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 11)
	root.add_child(count_label)

	return {
		"root": root,
		"active_overlay": active_overlay,
		"icon": icon_rect,
		"count_label": count_label,
	}


func _connect_game_manager() -> void:
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager == null:
		if not _warned_missing_game_manager:
			push_warning("[HotbarUI] GameManager not ready")
			_warned_missing_game_manager = true
		return

	if game_manager.has_signal("hotbar_changed") and not game_manager.is_connected("hotbar_changed", Callable(self, "_on_hotbar_changed")):
		game_manager.connect("hotbar_changed", Callable(self, "_on_hotbar_changed"))

	if game_manager.has_method("get_hotbar_slots") and game_manager.has_method("get_current_hotbar_index"):
		_refresh_hotbar(game_manager.call("get_hotbar_slots"), int(game_manager.call("get_current_hotbar_index")))


func _on_hotbar_changed(slots: Array, current_index: int) -> void:
	_refresh_hotbar(slots, current_index)


func _refresh_hotbar(slots: Array, current_index: int) -> void:
	for slot_index in range(_HOTBAR_SIZE):
		var widget: Dictionary = _slot_widgets[slot_index] if slot_index < _slot_widgets.size() else {}
		if widget.is_empty():
			continue

		var slot_data: Dictionary = {}
		if slot_index < slots.size() and slots[slot_index] is Dictionary:
			slot_data = slots[slot_index]

		var item_id: String = String(slot_data.get("item_id", ""))
		var count: int = int(slot_data.get("count", 0))
		var icon_rect: TextureRect = widget["icon"]
		var count_label: Label = widget["count_label"]
		var active_overlay: ColorRect = widget["active_overlay"]
		var root: Control = widget["root"]

		icon_rect.texture = _load_item_icon(item_id) if item_id != "" else null
		count_label.text = "x%d" % count if count > 1 else ""
		active_overlay.visible = slot_index == current_index
		root.modulate = Color.WHITE if item_id != "" else Color(1, 1, 1, 0.58)


func _apply_ui_theme() -> void:
	$Panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_PANEL_TEXTURE_PATH, 6))


func _build_textured_stylebox(texture_path: String, margin: int) -> StyleBoxTexture:
	var style_box := StyleBoxTexture.new()
	var texture := _safe_load_texture(texture_path)
	if texture != null:
		style_box.texture = texture
		style_box.texture_margin_left = 6
		style_box.texture_margin_top = 6
		style_box.texture_margin_right = 6
		style_box.texture_margin_bottom = 6
	style_box.content_margin_left = margin
	style_box.content_margin_top = margin
	style_box.content_margin_right = margin
	style_box.content_margin_bottom = margin
	return style_box


func _load_item_icon(item_id: String) -> Texture2D:
	var default_texture := _safe_load_texture("%s/%s.png" % [_ITEM_ICON_ROOT, item_id])
	if default_texture != null:
		return default_texture

	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_config"):
		var item_config = config_manager.call("get_item_config", item_id)
		if item_config != null:
			return _safe_load_texture(String(item_config.icon_path))
	return null


func _safe_load_texture(texture_path: String) -> Texture2D:
	if ResourceLoader.exists(texture_path):
		var resource := load(texture_path)
		if resource is Texture2D:
			return resource
	return null


func _format_hotbar_number(slot_index: int) -> int:
	return 0 if slot_index == 9 else slot_index + 1
