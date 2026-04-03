extends Control
class_name InventoryUI

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)
signal inventory_updated(items: Dictionary)

const _FALLBACK_ITEMS: Dictionary = {
	"seed_wheat": 5,
	"crop_wheat": 0,
	"hoe_wood": 1,
	"watering_can_wood": 1,
	"sickle_wood": 1,
}
const _ITEM_ICON_ROOT: String = "res://assets/sprites/placeholder/items"
const _UI_PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"
const _UI_BUTTON_NORMAL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_normal.png"

var _ui_root: UIRoot = null
var _warned_missing_game_manager: bool = false

@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var item_grid: GridContainer = $Panel/VBoxContainer/ScrollContainer/ItemGrid
@onready var panel: PanelContainer = $Panel


func _ready() -> void:
	"""初始化关闭按钮和背包显示。"""
	visible = false
	_apply_ui_theme()
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	call_deferred("_connect_game_manager")
	update_item_display(_get_current_items())


## 注入 UI 根节点引用
func set_ui_root(ui_root: UIRoot) -> void:
	_ui_root = ui_root


## 打开背包界面
func open_ui() -> void:
	if visible:
		return

	visible = true
	update_item_display(_get_current_items())
	emit_signal("ui_opened", "inventory")


## 关闭背包界面
func close_ui() -> void:
	if not visible:
		return

	visible = false
	emit_signal("ui_closed", "inventory")


## 开关背包界面
func toggle_inventory() -> void:
	if visible:
		close_ui()
	else:
		open_ui()


## 刷新物品显示
func update_item_display(items: Dictionary) -> void:
	_clear_item_grid()

	var item_ids: Array = items.keys()
	item_ids.sort()

	for item_id in item_ids:
		var slot := create_item_slot(String(item_id), int(items[item_id]))
		item_grid.add_child(slot)

	emit_signal("inventory_updated", items.duplicate(true))


## 创建单个物品槽
func create_item_slot(item_id: String, count: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(72, 88)
	panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.texture = _load_item_icon(item_id)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = _format_item_name(item_id)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var count_label := Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.text = "x%d" % count

	box.add_child(icon_rect)
	box.add_child(name_label)
	box.add_child(count_label)
	panel.add_child(box)
	return panel


func _connect_game_manager() -> void:
	"""连接 GameManager 的背包更新信号；若不存在则使用占位数据。"""
	var game_manager := _get_game_manager()
	if game_manager == null:
		if not _warned_missing_game_manager:
			push_warning("[InventoryUI] GameManager not ready, using fallback items")
			_warned_missing_game_manager = true
		return

	if game_manager.has_signal("inventory_changed") and not game_manager.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		game_manager.connect("inventory_changed", Callable(self, "_on_inventory_changed"))

	update_item_display(_get_current_items())


func _get_current_items() -> Dictionary:
	"""优先读取 GameManager 数据，缺失时返回占位背包。"""
	var game_manager := _get_game_manager()
	if game_manager != null:
		var inventory_value = game_manager.get("inventory")
		if inventory_value is Dictionary:
			return inventory_value.duplicate(true)

	if not _warned_missing_game_manager:
		push_warning("[InventoryUI] GameManager not ready, using fallback items")
		_warned_missing_game_manager = true

	return _FALLBACK_ITEMS.duplicate(true)


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _on_inventory_changed(items: Dictionary) -> void:
	"""响应 GameManager 背包变化。"""
	update_item_display(items)


func _on_close_button_pressed() -> void:
	"""关闭按钮优先委托给 UIRoot 统一处理。"""
	if _ui_root != null:
		_ui_root.close_modal("inventory")
		return

	close_ui()


func _clear_item_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()


func _format_item_name(item_id: String) -> String:
	match item_id:
		"seed_wheat":
			return "小麦种子"
		"crop_wheat":
			return "小麦"
		"hoe_wood":
			return "木锄头"
		"watering_can_wood":
			return "木水壶"
		"sickle_wood":
			return "木镰刀"
		_:
			return item_id


func _apply_ui_theme() -> void:
	panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH))
	close_button.add_theme_stylebox_override("normal", _build_textured_stylebox(_UI_BUTTON_NORMAL_TEXTURE_PATH))
	close_button.add_theme_stylebox_override("hover", _build_textured_stylebox("res://assets/sprites/placeholder/ui/button_hover.png"))
	close_button.add_theme_stylebox_override("pressed", _build_textured_stylebox("res://assets/sprites/placeholder/ui/button_pressed.png"))


func _build_textured_stylebox(texture_path: String) -> StyleBoxTexture:
	var style_box := StyleBoxTexture.new()
	var texture := _safe_load_texture(texture_path)
	if texture != null:
		style_box.texture = texture
		style_box.texture_margin_left = 6
		style_box.texture_margin_top = 6
		style_box.texture_margin_right = 6
		style_box.texture_margin_bottom = 6
	style_box.content_margin_left = 8
	style_box.content_margin_top = 8
	style_box.content_margin_right = 8
	style_box.content_margin_bottom = 8
	return style_box


func _load_item_icon(item_id: String) -> Texture2D:
	return _safe_load_texture("%s/%s.png" % [_ITEM_ICON_ROOT, item_id])


func _safe_load_texture(texture_path: String) -> Texture2D:
	if ResourceLoader.exists(texture_path):
		var resource := load(texture_path)
		if resource is Texture2D:
			return resource
	return null
