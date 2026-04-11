extends Control
class_name StorageChestUI

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)

const _SLOT_COUNT: int = 50
const _GRID_COLUMNS: int = 10
const _ITEM_ICON_ROOT: String = "res://assets/sprites/placeholder/items"
const _UI_PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"
const _UI_BUTTON_NORMAL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_normal.png"
const _UI_BUTTON_HOVER_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_hover.png"
const _UI_BUTTON_PRESSED_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_pressed.png"

var _ui_root: UIRoot = null
var _current_chest: StorageChest = null
var _player_slot_widgets: Array = []
var _chest_slot_widgets: Array = []
var _warned_missing_config_manager: bool = false

@onready var config_manager = get_node_or_null("/root/ConfigManager")
@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var title_label: Label = $Panel/VBoxContainer/Header/Title
@onready var player_grid: GridContainer = $Panel/VBoxContainer/Content/PlayerColumn/GridPanel/ItemGrid
@onready var chest_grid: GridContainer = $Panel/VBoxContainer/Content/ChestColumn/GridPanel/ItemGrid
@onready var hint_label: Label = $Panel/VBoxContainer/Footer/HintLabel
@onready var panel: PanelContainer = $Panel


func _ready() -> void:
	visible = false
	_apply_ui_theme()
	_connect_buttons()
	_build_slot_grids()
	call_deferred("_connect_game_manager")


func set_ui_root(ui_root: UIRoot) -> void:
	_ui_root = ui_root


func set_chest(chest: StorageChest) -> void:
	var chest_slots_changed := Callable(self, "_on_chest_slots_changed")
	if _current_chest != null and _current_chest.slots_changed.is_connected(chest_slots_changed):
		_current_chest.slots_changed.disconnect(chest_slots_changed)

	_current_chest = chest
	if _current_chest != null and not _current_chest.slots_changed.is_connected(chest_slots_changed):
		_current_chest.slots_changed.connect(chest_slots_changed)

	_refresh_view()


func open_ui() -> void:
	if _current_chest == null:
		return

	title_label.text = "%s" % _current_chest.chest_label
	hint_label.text = "点击左侧背包可存入，点击右侧储物箱可取回。"
	hint_label.modulate = Color.WHITE
	visible = true
	_refresh_view()
	emit_signal("ui_opened", "storage_chest")


func close_ui() -> void:
	if not visible:
		return

	visible = false
	hint_label.text = "点击左侧背包可存入，点击右侧储物箱可取回。"
	emit_signal("ui_closed", "storage_chest")


func _connect_buttons() -> void:
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)


func _build_slot_grids() -> void:
	_player_slot_widgets.clear()
	_chest_slot_widgets.clear()
	for child in player_grid.get_children():
		child.queue_free()
	for child in chest_grid.get_children():
		child.queue_free()

	for slot_index in range(_SLOT_COUNT):
		var player_widget: Dictionary = _create_slot_widget(slot_index, true)
		_player_slot_widgets.append(player_widget)
		player_grid.add_child(player_widget["root"])

		var chest_widget: Dictionary = _create_slot_widget(slot_index, false)
		_chest_slot_widgets.append(chest_widget)
		chest_grid.add_child(chest_widget["root"])


func _create_slot_widget(slot_index: int, is_player_side: bool) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(54, 54)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_player_side:
		root.gui_input.connect(_on_player_slot_gui_input.bind(slot_index))
	else:
		root.gui_input.connect(_on_chest_slot_gui_input.bind(slot_index))

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH, 4))
	root.add_child(frame)

	var icon_rect := TextureRect.new()
	icon_rect.position = Vector2(11, 7)
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon_rect)

	var count_label := Label.new()
	count_label.position = Vector2(20, 36)
	count_label.size = Vector2(28, 14)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 11)
	root.add_child(count_label)

	return {
		"root": root,
		"icon": icon_rect,
		"count_label": count_label,
	}


func _connect_game_manager() -> void:
	var game_manager := _get_game_manager()
	if game_manager == null:
		return

	if game_manager.has_signal("inventory_slots_changed") and not game_manager.is_connected("inventory_slots_changed", Callable(self, "_on_inventory_slots_changed")):
		game_manager.connect("inventory_slots_changed", Callable(self, "_on_inventory_slots_changed"))

	_refresh_view()


func _refresh_view() -> void:
	_refresh_player_slots()
	_refresh_chest_slots()


func _refresh_player_slots() -> void:
	var slots: Array = _get_inventory_slots()
	for slot_index in range(min(_player_slot_widgets.size(), slots.size())):
		_update_slot_widget(_player_slot_widgets[slot_index], slots[slot_index])


func _refresh_chest_slots() -> void:
	var slots: Array = _current_chest.get_slots() if _current_chest != null else []
	for slot_index in range(_chest_slot_widgets.size()):
		var slot_data: Variant = slots[slot_index] if slot_index < slots.size() else {}
		_update_slot_widget(_chest_slot_widgets[slot_index], slot_data)


func _update_slot_widget(widget: Dictionary, slot_data: Variant) -> void:
	var icon_rect: TextureRect = widget["icon"]
	var count_label: Label = widget["count_label"]
	var root: Control = widget["root"]

	var item_id: String = ""
	var count: int = 0
	if slot_data is Dictionary:
		item_id = String(slot_data.get("item_id", ""))
		count = int(slot_data.get("count", 0))

	icon_rect.texture = _load_item_icon(item_id) if item_id != "" else null
	count_label.text = "x%d" % count if count > 1 else ""
	root.modulate = Color.WHITE if item_id != "" else Color(1, 1, 1, 0.6)


func _on_player_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not _is_left_click(event) or _current_chest == null:
		return

	var slots: Array = _get_inventory_slots()
	if slot_index < 0 or slot_index >= slots.size():
		return

	var slot_data = slots[slot_index]
	if not (slot_data is Dictionary):
		return

	var item_id: String = String(slot_data.get("item_id", ""))
	var count: int = int(slot_data.get("count", 0))
	if item_id == "" or count <= 0:
		return

	if not _current_chest.add_item(item_id, count):
		_set_hint("储物箱已满，无法存入。", false)
		return

	var game_manager := _get_game_manager()
	if game_manager == null or not bool(game_manager.call("remove_item", item_id, count)):
		_current_chest.remove_item(item_id, count)
		_set_hint("玩家背包状态异常，存入失败。", false)
		return

	_set_hint("已存入：%s x%d" % [_format_item_name(item_id), count], true)
	_refresh_view()


func _on_chest_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not _is_left_click(event) or _current_chest == null:
		return

	var slots: Array = _current_chest.get_slots()
	if slot_index < 0 or slot_index >= slots.size():
		return

	var slot_data = slots[slot_index]
	if not (slot_data is Dictionary):
		return

	var item_id: String = String(slot_data.get("item_id", ""))
	var count: int = int(slot_data.get("count", 0))
	if item_id == "" or count <= 0:
		return

	var game_manager := _get_game_manager()
	if game_manager == null:
		_set_hint("GameManager 未就绪。", false)
		return

	if not bool(game_manager.call("add_item", item_id, count)):
		_set_hint("背包已满，无法取回。", false)
		return

	if not _current_chest.remove_item(item_id, count):
		game_manager.call("remove_item", item_id, count)
		_set_hint("储物箱状态异常，取回失败。", false)
		return

	_set_hint("已取回：%s x%d" % [_format_item_name(item_id), count], true)
	_refresh_view()


func _is_left_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false

	var mouse_event: InputEventMouseButton = event
	return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed


func _set_hint(message: String, success: bool) -> void:
	hint_label.text = message
	hint_label.modulate = Color("#88D38A") if success else Color("#E68A8A")


func _get_inventory_slots() -> Array:
	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.has_method("get_inventory_slots"):
		return game_manager.call("get_inventory_slots") as Array
	return []


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _format_item_name(item_id: String) -> String:
	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_display_name"):
		return String(config_manager.call("get_item_display_name", item_id))

	if not _warned_missing_config_manager:
		push_warning("[StorageChestUI] ConfigManager not ready, fallback to raw item id")
		_warned_missing_config_manager = true
	return item_id


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


func _on_inventory_slots_changed(_slots: Array) -> void:
	_refresh_player_slots()


func _on_chest_slots_changed(_slots: Array) -> void:
	_refresh_chest_slots()


func _on_close_button_pressed() -> void:
	if _ui_root != null:
		_ui_root.close_modal("storage_chest")
		return

	close_ui()


func _apply_ui_theme() -> void:
	panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH, 8))
	for button in [close_button]:
		button.add_theme_stylebox_override("normal", _build_textured_stylebox(_UI_BUTTON_NORMAL_TEXTURE_PATH, 8))
		button.add_theme_stylebox_override("hover", _build_textured_stylebox(_UI_BUTTON_HOVER_TEXTURE_PATH, 8))
		button.add_theme_stylebox_override("pressed", _build_textured_stylebox(_UI_BUTTON_PRESSED_TEXTURE_PATH, 8))


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
