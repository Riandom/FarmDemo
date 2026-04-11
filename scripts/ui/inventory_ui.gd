extends Control
class_name InventoryUI

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)
signal inventory_updated(items: Dictionary)

const _FILTER_ALL: String = "all"
const _FILTER_TOOL: String = "tool"
const _FILTER_SEED: String = "seed"
const _FILTER_CROP: String = "crop"
const _FILTER_MATERIAL: String = "material"
const _HOTBAR_SIZE: int = 10
const _SLOT_COUNT: int = 50
const _ITEM_ICON_ROOT: String = "res://assets/sprites/placeholder/items"
const _UI_PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"
const _UI_BUTTON_NORMAL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_normal.png"

var _ui_root: UIRoot = null
var _warned_missing_game_manager: bool = false
var _warned_missing_config_manager: bool = false
var _selected_slot_index: int = -1
var _current_filter: String = _FILTER_ALL
var _slot_widgets: Array = []

@onready var config_manager = get_node_or_null("/root/ConfigManager")

@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var all_filter_button: Button = $Panel/VBoxContainer/FilterBar/AllButton
@onready var tool_filter_button: Button = $Panel/VBoxContainer/FilterBar/ToolButton
@onready var seed_filter_button: Button = $Panel/VBoxContainer/FilterBar/SeedButton
@onready var crop_filter_button: Button = $Panel/VBoxContainer/FilterBar/CropButton
@onready var material_filter_button: Button = $Panel/VBoxContainer/FilterBar/MaterialButton
@onready var item_grid: GridContainer = $Panel/VBoxContainer/GridPanel/ItemGrid
@onready var hint_label: Label = $Panel/VBoxContainer/Footer/HintLabel
@onready var panel: PanelContainer = $Panel


func _ready() -> void:
	"""初始化筛选按钮、固定槽位网格和背包数据连接。"""
	visible = false
	_apply_ui_theme()
	_connect_buttons()
	_build_slot_grid()
	call_deferred("_connect_game_manager")
	_refresh_inventory_view()


## 注入 UI 根节点引用
func set_ui_root(ui_root: UIRoot) -> void:
	_ui_root = ui_root


## 打开背包界面
func open_ui() -> void:
	if visible:
		return

	visible = true
	_refresh_inventory_view()
	emit_signal("ui_opened", "inventory")


## 关闭背包界面
func close_ui() -> void:
	if not visible:
		return

	visible = false
	_selected_slot_index = -1
	emit_signal("ui_closed", "inventory")


## 开关背包界面
func toggle_inventory() -> void:
	if visible:
		close_ui()
	else:
		open_ui()


func _connect_buttons() -> void:
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	if not all_filter_button.pressed.is_connected(_on_filter_button_pressed.bind(_FILTER_ALL)):
		all_filter_button.pressed.connect(_on_filter_button_pressed.bind(_FILTER_ALL))
	if not tool_filter_button.pressed.is_connected(_on_filter_button_pressed.bind(_FILTER_TOOL)):
		tool_filter_button.pressed.connect(_on_filter_button_pressed.bind(_FILTER_TOOL))
	if not seed_filter_button.pressed.is_connected(_on_filter_button_pressed.bind(_FILTER_SEED)):
		seed_filter_button.pressed.connect(_on_filter_button_pressed.bind(_FILTER_SEED))
	if not crop_filter_button.pressed.is_connected(_on_filter_button_pressed.bind(_FILTER_CROP)):
		crop_filter_button.pressed.connect(_on_filter_button_pressed.bind(_FILTER_CROP))
	if not material_filter_button.pressed.is_connected(_on_filter_button_pressed.bind(_FILTER_MATERIAL)):
		material_filter_button.pressed.connect(_on_filter_button_pressed.bind(_FILTER_MATERIAL))


func _build_slot_grid() -> void:
	_slot_widgets.clear()
	for child in item_grid.get_children():
		child.queue_free()

	for slot_index in range(_SLOT_COUNT):
		var widget: Dictionary = _create_slot_widget(slot_index)
		_slot_widgets.append(widget)
		item_grid.add_child(widget["root"])


func _create_slot_widget(slot_index: int) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(72, 72)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_slot_gui_input.bind(slot_index))

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH, 4))
	root.add_child(frame)

	var equipped_overlay := ColorRect.new()
	equipped_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	equipped_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipped_overlay.color = Color(0.95, 0.82, 0.24, 0.24)
	equipped_overlay.visible = false
	root.add_child(equipped_overlay)

	var selected_overlay := ColorRect.new()
	selected_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	selected_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_overlay.color = Color(0.42, 0.76, 1.0, 0.28)
	selected_overlay.visible = false
	root.add_child(selected_overlay)

	var hotbar_label := Label.new()
	hotbar_label.position = Vector2(5, 2)
	hotbar_label.size = Vector2(18, 16)
	hotbar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar_label.add_theme_font_size_override("font_size", 12)
	hotbar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(hotbar_label)

	var icon_rect := TextureRect.new()
	icon_rect.position = Vector2(20, 18)
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon_rect)

	var count_label := Label.new()
	count_label.position = Vector2(34, 50)
	count_label.size = Vector2(34, 18)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count_label.add_theme_font_size_override("font_size", 12)
	root.add_child(count_label)

	return {
		"root": root,
		"frame": frame,
		"equipped_overlay": equipped_overlay,
		"selected_overlay": selected_overlay,
		"hotbar_label": hotbar_label,
		"icon": icon_rect,
		"count_label": count_label,
	}


func _connect_game_manager() -> void:
	"""连接 GameManager 的背包槽位信号。"""
	var game_manager := _get_game_manager()
	if game_manager == null:
		if not _warned_missing_game_manager:
			push_warning("[InventoryUI] GameManager not ready")
			_warned_missing_game_manager = true
		return

	if game_manager.has_signal("inventory_changed") and not game_manager.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		game_manager.connect("inventory_changed", Callable(self, "_on_inventory_changed"))

	if game_manager.has_signal("inventory_slots_changed") and not game_manager.is_connected("inventory_slots_changed", Callable(self, "_on_inventory_slots_changed")):
		game_manager.connect("inventory_slots_changed", Callable(self, "_on_inventory_slots_changed"))

	if game_manager.has_signal("hotbar_changed") and not game_manager.is_connected("hotbar_changed", Callable(self, "_on_hotbar_changed")):
		game_manager.connect("hotbar_changed", Callable(self, "_on_hotbar_changed"))

	_refresh_inventory_view()


func _refresh_inventory_view() -> void:
	var slots: Array = _get_inventory_slots()
	var current_hotbar_index: int = _get_current_hotbar_index()

	for slot_index in range(min(slots.size(), _slot_widgets.size())):
		_update_slot_widget(slot_index, slots[slot_index], current_hotbar_index)

	_apply_filter_button_state()
	_update_hint_label()
	emit_signal("inventory_updated", _get_inventory_snapshot())


func _update_slot_widget(slot_index: int, slot_data: Variant, current_hotbar_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_widgets.size():
		return

	var widget: Dictionary = _slot_widgets[slot_index]
	var root: Control = widget["root"]
	var equipped_overlay: ColorRect = widget["equipped_overlay"]
	var selected_overlay: ColorRect = widget["selected_overlay"]
	var hotbar_label: Label = widget["hotbar_label"]
	var icon_rect: TextureRect = widget["icon"]
	var count_label: Label = widget["count_label"]

	var item_id: String = ""
	var count: int = 0
	if slot_data is Dictionary:
		item_id = String(slot_data.get("item_id", ""))
		count = int(slot_data.get("count", 0))

	hotbar_label.text = str(_format_hotbar_number(slot_index)) if slot_index < _HOTBAR_SIZE else ""
	icon_rect.texture = _load_item_icon(item_id) if item_id != "" else null
	count_label.text = "x%d" % count if count > 1 else ""
	equipped_overlay.visible = slot_index == current_hotbar_index
	selected_overlay.visible = slot_index == _selected_slot_index

	var filter_match: bool = _matches_filter(item_id)
	if item_id == "":
		root.modulate = Color(1, 1, 1, 0.65)
	elif filter_match:
		root.modulate = Color.WHITE
	else:
		root.modulate = Color(1, 1, 1, 0.28)


func _update_hint_label() -> void:
	if _selected_slot_index == -1:
		hint_label.text = "点击两个格子交换位置，点击热栏格会同步装备。"
		return

	var slots: Array = _get_inventory_slots()
	if _selected_slot_index < 0 or _selected_slot_index >= slots.size():
		hint_label.text = "点击两个格子交换位置，点击热栏格会同步装备。"
		return

	var selected_slot = slots[_selected_slot_index]
	if selected_slot is Dictionary and String(selected_slot.get("item_id", "")) != "":
		var item_name: String = _format_item_name(String(selected_slot.get("item_id", "")))
		hint_label.text = "已选中：%s，点击另一格交换；再次点击取消。" % item_name
	else:
		hint_label.text = "已选中空槽，点击另一格交换；再次点击取消。"


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var game_manager := _get_game_manager()
	if game_manager == null:
		return

	if slot_index < _HOTBAR_SIZE and game_manager.has_method("set_current_hotbar_index"):
		game_manager.call("set_current_hotbar_index", slot_index)

	if _selected_slot_index == -1:
		_selected_slot_index = slot_index
	elif _selected_slot_index == slot_index:
		_selected_slot_index = -1
	else:
		if game_manager.has_method("swap_inventory_slots"):
			game_manager.call("swap_inventory_slots", _selected_slot_index, slot_index)
		_selected_slot_index = -1

	_refresh_inventory_view()


func _on_filter_button_pressed(filter_id: String) -> void:
	_current_filter = filter_id
	_refresh_inventory_view()


func _get_inventory_slots() -> Array:
	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.has_method("get_inventory_slots"):
		return game_manager.call("get_inventory_slots") as Array
	return []


func _get_inventory_snapshot() -> Dictionary:
	var game_manager := _get_game_manager()
	if game_manager != null:
		var inventory_value = game_manager.get("inventory")
		if inventory_value is Dictionary:
			return inventory_value.duplicate(true)
	return {}


func _get_current_hotbar_index() -> int:
	var game_manager := _get_game_manager()
	if game_manager != null and game_manager.has_method("get_current_hotbar_index"):
		return int(game_manager.call("get_current_hotbar_index"))
	return 0


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_item_category(item_id: String) -> String:
	if item_id == "":
		return "other"

	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_category"):
		return String(config_manager.call("get_item_category", item_id))

	if not _warned_missing_config_manager:
		push_warning("[InventoryUI] ConfigManager not ready, fallback to other category")
		_warned_missing_config_manager = true
	return "other"


func _matches_filter(item_id: String) -> bool:
	if item_id == "" or _current_filter == _FILTER_ALL:
		return true
	return _get_item_category(item_id) == _current_filter


func _format_item_name(item_id: String) -> String:
	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_display_name"):
		return String(config_manager.call("get_item_display_name", item_id))

	if not _warned_missing_config_manager:
		push_warning("[InventoryUI] ConfigManager not ready, fallback to raw item id")
		_warned_missing_config_manager = true

	return item_id


func _apply_filter_button_state() -> void:
	_style_filter_button(all_filter_button, _current_filter == _FILTER_ALL)
	_style_filter_button(tool_filter_button, _current_filter == _FILTER_TOOL)
	_style_filter_button(seed_filter_button, _current_filter == _FILTER_SEED)
	_style_filter_button(crop_filter_button, _current_filter == _FILTER_CROP)
	_style_filter_button(material_filter_button, _current_filter == _FILTER_MATERIAL)


func _style_filter_button(button: Button, is_active: bool) -> void:
	button.modulate = Color.WHITE if is_active else Color(1, 1, 1, 0.62)


func _on_inventory_changed(items: Dictionary) -> void:
	emit_signal("inventory_updated", items.duplicate(true))


func _on_inventory_slots_changed(_slots: Array) -> void:
	_refresh_inventory_view()


func _on_hotbar_changed(_slots: Array, _current_index: int) -> void:
	_refresh_inventory_view()


func _on_close_button_pressed() -> void:
	if _ui_root != null:
		_ui_root.close_modal("inventory")
		return

	close_ui()


func _apply_ui_theme() -> void:
	panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH, 8))
	close_button.add_theme_stylebox_override("normal", _build_textured_stylebox(_UI_BUTTON_NORMAL_TEXTURE_PATH, 8))
	close_button.add_theme_stylebox_override("hover", _build_textured_stylebox("res://assets/sprites/placeholder/ui/button_hover.png", 8))
	close_button.add_theme_stylebox_override("pressed", _build_textured_stylebox("res://assets/sprites/placeholder/ui/button_pressed.png", 8))

	for button in [all_filter_button, tool_filter_button, seed_filter_button, crop_filter_button, material_filter_button]:
		button.add_theme_stylebox_override("normal", _build_textured_stylebox(_UI_BUTTON_NORMAL_TEXTURE_PATH, 8))
		button.add_theme_stylebox_override("hover", _build_textured_stylebox("res://assets/sprites/placeholder/ui/button_hover.png", 8))
		button.add_theme_stylebox_override("pressed", _build_textured_stylebox("res://assets/sprites/placeholder/ui/button_pressed.png", 8))


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
