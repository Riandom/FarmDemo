extends Control
class_name ShopUI

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)
signal shop_transaction_completed(item_id: String, is_buy: bool, amount: int)

const _FILTER_ALL: String = "all"
const _FILTER_TOOL: String = "tool"
const _FILTER_SEED: String = "seed"
const _FILTER_CROP: String = "crop"
const _FILTER_MATERIAL: String = "material"
const _UI_PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"
const _UI_BUTTON_NORMAL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_normal.png"
const _UI_BUTTON_HOVER_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_hover.png"
const _UI_BUTTON_PRESSED_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_pressed.png"

@export var shop_config: ShopConfig
@export var ui_type: String = "shop"
@export var panel_title: String = "商店"
@export var buy_title: String = "购买"
@export var sell_title: String = "售卖"
@export var feedback_welcome_text: String = "欢迎光临"

var _ui_root: UIRoot = null
var _warned_missing_game_manager: bool = false
var _valid_buy_items: Dictionary = {}
var _valid_sell_items: Dictionary = {}
var _buy_filter: String = _FILTER_ALL
var _sell_filter: String = _FILTER_ALL
var _sort_entries: Dictionary = {}

@onready var config_manager = get_node_or_null("/root/ConfigManager")
@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var title_label: Label = $Panel/VBoxContainer/Header/Title
@onready var buy_title_label: Label = $Panel/VBoxContainer/Content/BuyColumn/BuyTitle
@onready var sell_title_label: Label = $Panel/VBoxContainer/Content/SellColumn/SellTitle
@onready var buy_all_button: Button = $Panel/VBoxContainer/Content/BuyColumn/BuyFilterBar/AllButton
@onready var buy_tool_button: Button = $Panel/VBoxContainer/Content/BuyColumn/BuyFilterBar/ToolButton
@onready var buy_seed_button: Button = $Panel/VBoxContainer/Content/BuyColumn/BuyFilterBar/SeedButton
@onready var buy_crop_button: Button = $Panel/VBoxContainer/Content/BuyColumn/BuyFilterBar/CropButton
@onready var buy_material_button: Button = $Panel/VBoxContainer/Content/BuyColumn/BuyFilterBar/MaterialButton
@onready var sell_all_button: Button = $Panel/VBoxContainer/Content/SellColumn/SellFilterBar/AllButton
@onready var sell_tool_button: Button = $Panel/VBoxContainer/Content/SellColumn/SellFilterBar/ToolButton
@onready var sell_seed_button: Button = $Panel/VBoxContainer/Content/SellColumn/SellFilterBar/SeedButton
@onready var sell_crop_button: Button = $Panel/VBoxContainer/Content/SellColumn/SellFilterBar/CropButton
@onready var sell_material_button: Button = $Panel/VBoxContainer/Content/SellColumn/SellFilterBar/MaterialButton
@onready var buy_grid: GridContainer = $Panel/VBoxContainer/Content/BuyColumn/BuyScroll/BuyGrid
@onready var sell_grid: GridContainer = $Panel/VBoxContainer/Content/SellColumn/SellScroll/SellGrid
@onready var feedback_label: Label = $Panel/VBoxContainer/FeedbackLabel
@onready var panel: PanelContainer = $Panel


func _ready() -> void:
	"""初始化商店数据源、筛选器和按钮事件。"""
	visible = false
	_apply_ui_theme()
	_apply_text_labels()
	_connect_buttons()
	_prepare_config()
	call_deferred("_connect_game_manager")
	update_shop_display()


## 注入 UI 根节点引用
func set_ui_root(ui_root: UIRoot) -> void:
	_ui_root = ui_root


## 打开商店界面
func open_ui() -> void:
	if visible:
		return

	visible = true
	feedback_label.text = feedback_welcome_text
	update_shop_display()
	emit_signal("ui_opened", ui_type)


## 关闭商店界面
func close_ui() -> void:
	if not visible:
		return

	visible = false
	emit_signal("ui_closed", ui_type)


## 开关商店界面
func toggle_shop() -> void:
	if visible:
		close_ui()
	else:
		open_ui()


## 购买商品
func buy_item(item_id: String) -> void:
	var game_manager := _get_game_manager()
	if game_manager == null:
		_show_feedback("GameManager 未就绪", false)
		return

	if not _valid_buy_items.has(item_id):
		_show_feedback("商品不存在", false)
		return

	var entry: Dictionary = _valid_buy_items[item_id]
	var price: int = int(entry["price"])

	if not bool(game_manager.call("remove_gold", price)):
		_show_feedback("金币不足", false)
		return

	game_manager.call("add_item", item_id, 1)
	emit_signal("shop_transaction_completed", item_id, true, 1)
	_show_feedback("购买成功：%s" % String(entry["display_name"]), true)
	update_shop_display()


## 售卖物品
func sell_item(item_id: String) -> void:
	var game_manager := _get_game_manager()
	if game_manager == null:
		_show_feedback("GameManager 未就绪", false)
		return

	if not _valid_sell_items.has(item_id):
		_show_feedback("商品不存在", false)
		return

	if not verify_sale(item_id, _get_inventory()):
		_show_feedback("没有可售卖的物品", false)
		return

	var entry: Dictionary = _valid_sell_items[item_id]
	var price: int = int(entry["price"])

	if not bool(game_manager.call("remove_item", item_id, 1)):
		_show_feedback("没有可售卖的物品", false)
		return

	game_manager.call("add_gold", price)
	emit_signal("shop_transaction_completed", item_id, false, 1)
	_show_feedback("售卖成功：%s" % String(entry["display_name"]), true)
	update_shop_display()


## 刷新商店显示
func update_shop_display() -> void:
	_rebuild_buy_grid()
	_rebuild_sell_grid()
	_apply_filter_button_state()


## 验证是否可以购买
func verify_purchase(item_id: String, gold: int) -> bool:
	if not _valid_buy_items.has(item_id):
		return false

	return gold >= int(_valid_buy_items[item_id]["price"])


## 验证是否可以售卖
func verify_sale(item_id: String, inventory: Dictionary) -> bool:
	return int(inventory.get(item_id, 0)) > 0


func _connect_buttons() -> void:
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	for button in [buy_all_button, buy_tool_button, buy_seed_button, buy_crop_button, buy_material_button]:
		if not button.pressed.is_connected(_on_buy_filter_pressed.bind(String(button.name))):
			button.pressed.connect(_on_buy_filter_pressed.bind(String(button.name)))

	for button in [sell_all_button, sell_tool_button, sell_seed_button, sell_crop_button, sell_material_button]:
		if not button.pressed.is_connected(_on_sell_filter_pressed.bind(String(button.name))):
			button.pressed.connect(_on_sell_filter_pressed.bind(String(button.name)))


func _prepare_config() -> void:
	"""验证并过滤商店配置，保证运行时只展示合法商品。"""
	if shop_config == null:
		push_warning("[ShopUI] shop_config missing")
		_valid_buy_items = {}
		_valid_sell_items = {}
		return

	shop_config.validate_config()
	_valid_buy_items = shop_config.get_valid_items("buy")
	_valid_sell_items = shop_config.get_valid_items("sell")


func _apply_text_labels() -> void:
	title_label.text = panel_title
	buy_title_label.text = buy_title
	sell_title_label.text = sell_title


func _connect_game_manager() -> void:
	"""连接金币和背包变化信号，用于实时刷新商店卡片状态。"""
	var game_manager := _get_game_manager()
	if game_manager == null:
		if not _warned_missing_game_manager:
			push_warning("[ShopUI] GameManager not ready")
			_warned_missing_game_manager = true
		return

	if game_manager.has_signal("gold_changed") and not game_manager.is_connected("gold_changed", Callable(self, "_on_gold_changed")):
		game_manager.connect("gold_changed", Callable(self, "_on_gold_changed"))

	if game_manager.has_signal("inventory_changed") and not game_manager.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		game_manager.connect("inventory_changed", Callable(self, "_on_inventory_changed"))

	update_shop_display()


func _rebuild_buy_grid() -> void:
	_clear_container(buy_grid)
	var current_gold := _get_gold_amount()
	var item_ids: Array = _get_filtered_sorted_item_ids(_valid_buy_items, _buy_filter)

	for item_id in item_ids:
		var entry: Dictionary = _valid_buy_items[item_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 96)
		button.icon = _safe_load_texture(String(entry.get("icon", "")))
		button.text = "%s\n%d金" % [String(entry["display_name"]), int(entry["price"])]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.disabled = not verify_purchase(String(item_id), current_gold)
		_apply_button_theme(button)
		button.pressed.connect(_on_buy_button_pressed.bind(String(item_id)))
		buy_grid.add_child(button)


func _rebuild_sell_grid() -> void:
	_clear_container(sell_grid)
	var inventory := _get_inventory()
	var item_ids: Array = _get_filtered_sorted_item_ids(_valid_sell_items, _sell_filter)

	for item_id in item_ids:
		var entry: Dictionary = _valid_sell_items[item_id]
		var owned_count: int = int(inventory.get(item_id, 0))
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 110)
		button.icon = _safe_load_texture(String(entry.get("icon", "")))
		button.text = "%s\n%d金\n持有:%d" % [String(entry["display_name"]), int(entry["price"]), owned_count]
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.disabled = not verify_sale(String(item_id), inventory)
		_apply_button_theme(button)
		button.pressed.connect(_on_sell_button_pressed.bind(String(item_id)))
		sell_grid.add_child(button)


func _get_filtered_sorted_item_ids(entries: Dictionary, filter_id: String) -> Array:
	var item_ids: Array = []
	for item_id_variant in entries.keys():
		var item_id: String = String(item_id_variant)
		if filter_id != _FILTER_ALL and _get_item_category(item_id) != filter_id:
			continue
		item_ids.append(item_id)

	_sort_entries = entries
	item_ids.sort_custom(Callable(self, "_sort_shop_item_ids"))
	return item_ids


func _sort_shop_item_ids(a: String, b: String) -> bool:
	var category_a: String = _get_item_category(a)
	var category_b: String = _get_item_category(b)
	var priority_a: int = _get_category_priority(category_a)
	var priority_b: int = _get_category_priority(category_b)
	if priority_a != priority_b:
		return priority_a < priority_b

	var entry_a: Dictionary = _sort_entries.get(a, {})
	var entry_b: Dictionary = _sort_entries.get(b, {})
	return String(entry_a.get("display_name", a)) < String(entry_b.get("display_name", b))


func _get_inventory() -> Dictionary:
	var game_manager := _get_game_manager()
	if game_manager != null:
		var inventory_value = game_manager.get("inventory")
		if inventory_value is Dictionary:
			return inventory_value.duplicate(true)
	return {}


func _get_gold_amount() -> int:
	var game_manager := _get_game_manager()
	if game_manager != null:
		return int(game_manager.get("gold"))
	return 0


func _show_feedback(message: String, success: bool) -> void:
	feedback_label.text = message
	feedback_label.modulate = Color("#4CAF50") if success else Color("#F44336")


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _get_item_category(item_id: String) -> String:
	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_category"):
		return String(config_manager.call("get_item_category", item_id))
	return "other"


func _get_category_priority(category_id: String) -> int:
	match category_id:
		"tool":
			return 0
		"seed":
			return 1
		"crop":
			return 2
		"material":
			return 3
		_:
			return 4


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_buy_button_pressed(item_id: String) -> void:
	buy_item(item_id)


func _on_sell_button_pressed(item_id: String) -> void:
	sell_item(item_id)


func _on_close_button_pressed() -> void:
	if _ui_root != null:
		_ui_root.close_modal(ui_type)
		return

	close_ui()


func _on_buy_filter_pressed(button_name: String) -> void:
	_buy_filter = _resolve_filter_from_button_name(button_name)
	update_shop_display()


func _on_sell_filter_pressed(button_name: String) -> void:
	_sell_filter = _resolve_filter_from_button_name(button_name)
	update_shop_display()


func _resolve_filter_from_button_name(button_name: String) -> String:
	match button_name:
		"ToolButton":
			return _FILTER_TOOL
		"SeedButton":
			return _FILTER_SEED
		"CropButton":
			return _FILTER_CROP
		"MaterialButton":
			return _FILTER_MATERIAL
		_:
			return _FILTER_ALL


func _on_gold_changed(_new_amount: int) -> void:
	update_shop_display()


func _on_inventory_changed(_items: Dictionary) -> void:
	update_shop_display()


func _apply_ui_theme() -> void:
	panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH, 8))
	_apply_button_theme(close_button)

	for button in [
		buy_all_button, buy_tool_button, buy_seed_button, buy_crop_button, buy_material_button,
		sell_all_button, sell_tool_button, sell_seed_button, sell_crop_button, sell_material_button,
	]:
		_apply_button_theme(button)


func _apply_filter_button_state() -> void:
	_style_filter_button(buy_all_button, _buy_filter == _FILTER_ALL)
	_style_filter_button(buy_tool_button, _buy_filter == _FILTER_TOOL)
	_style_filter_button(buy_seed_button, _buy_filter == _FILTER_SEED)
	_style_filter_button(buy_crop_button, _buy_filter == _FILTER_CROP)
	_style_filter_button(buy_material_button, _buy_filter == _FILTER_MATERIAL)
	_style_filter_button(sell_all_button, _sell_filter == _FILTER_ALL)
	_style_filter_button(sell_tool_button, _sell_filter == _FILTER_TOOL)
	_style_filter_button(sell_seed_button, _sell_filter == _FILTER_SEED)
	_style_filter_button(sell_crop_button, _sell_filter == _FILTER_CROP)
	_style_filter_button(sell_material_button, _sell_filter == _FILTER_MATERIAL)


func _style_filter_button(button: Button, is_active: bool) -> void:
	button.modulate = Color.WHITE if is_active else Color(1, 1, 1, 0.62)


func _apply_button_theme(button: Button) -> void:
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


func _safe_load_texture(texture_path: String) -> Texture2D:
	if texture_path == "":
		return null
	if ResourceLoader.exists(texture_path):
		var resource := load(texture_path)
		if resource is Texture2D:
			return resource
	return null
