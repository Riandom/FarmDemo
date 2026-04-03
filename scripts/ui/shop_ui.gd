extends Control
class_name ShopUI

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)
signal shop_transaction_completed(item_id: String, is_buy: bool, amount: int)

const _UI_PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"
const _UI_BUTTON_NORMAL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_normal.png"
const _UI_BUTTON_HOVER_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_hover.png"
const _UI_BUTTON_PRESSED_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_pressed.png"

@export var shop_config: ShopConfig

var _ui_root: UIRoot = null
var _warned_missing_game_manager: bool = false
var _valid_buy_items: Dictionary = {}
var _valid_sell_items: Dictionary = {}

@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var buy_list: VBoxContainer = $Panel/VBoxContainer/TabContainer/购买/BuyScroll/BuyList
@onready var sell_list: VBoxContainer = $Panel/VBoxContainer/TabContainer/售卖/SellScroll/SellList
@onready var feedback_label: Label = $Panel/VBoxContainer/FeedbackLabel
@onready var panel: PanelContainer = $Panel


func _ready() -> void:
	"""初始化商店数据源和按钮事件。"""
	visible = false
	_apply_ui_theme()
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

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
	update_shop_display()
	emit_signal("ui_opened", "shop")


## 关闭商店界面
func close_ui() -> void:
	if not visible:
		return

	visible = false
	emit_signal("ui_closed", "shop")


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
	_rebuild_buy_list()
	_rebuild_sell_list()


## 验证是否可以购买
func verify_purchase(item_id: String, gold: int) -> bool:
	if not _valid_buy_items.has(item_id):
		return false

	return gold >= int(_valid_buy_items[item_id]["price"])


## 验证是否可以售卖
func verify_sale(item_id: String, inventory: Dictionary) -> bool:
	return int(inventory.get(item_id, 0)) > 0


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


func _connect_game_manager() -> void:
	"""连接金币和背包变化信号，用于实时刷新商店按钮状态。"""
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


func _rebuild_buy_list() -> void:
	_clear_container(buy_list)
	var current_gold := _get_gold_amount()
	var item_ids: Array = _valid_buy_items.keys()
	item_ids.sort()

	for item_id in item_ids:
		var entry: Dictionary = _valid_buy_items[item_id]
		var button := Button.new()
		button.text = "购买 %s - %d金" % [String(entry["display_name"]), int(entry["price"])]
		button.icon = _safe_load_texture(String(entry.get("icon", "")))
		button.disabled = not verify_purchase(String(item_id), current_gold)
		_apply_button_theme(button)
		button.pressed.connect(_on_buy_button_pressed.bind(String(item_id)))
		buy_list.add_child(button)


func _rebuild_sell_list() -> void:
	_clear_container(sell_list)
	var inventory := _get_inventory()
	var item_ids: Array = _valid_sell_items.keys()
	item_ids.sort()

	for item_id in item_ids:
		var entry: Dictionary = _valid_sell_items[item_id]
		var owned_count: int = int(inventory.get(item_id, 0))
		var button := Button.new()
		button.text = "售卖 %s - %d金 (持有:%d)" % [String(entry["display_name"]), int(entry["price"]), owned_count]
		button.icon = _safe_load_texture(String(entry.get("icon", "")))
		button.disabled = not verify_sale(String(item_id), inventory)
		_apply_button_theme(button)
		button.pressed.connect(_on_sell_button_pressed.bind(String(item_id)))
		sell_list.add_child(button)


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


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _on_buy_button_pressed(item_id: String) -> void:
	buy_item(item_id)


func _on_sell_button_pressed(item_id: String) -> void:
	sell_item(item_id)


func _on_close_button_pressed() -> void:
	if _ui_root != null:
		_ui_root.close_modal("shop")
		return

	close_ui()


func _on_gold_changed(new_amount: int) -> void:
	update_shop_display()


func _on_inventory_changed(items: Dictionary) -> void:
	update_shop_display()


func _apply_ui_theme() -> void:
	panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH))
	_apply_button_theme(close_button)


func _apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _build_textured_stylebox(_UI_BUTTON_NORMAL_TEXTURE_PATH))
	button.add_theme_stylebox_override("hover", _build_textured_stylebox(_UI_BUTTON_HOVER_TEXTURE_PATH))
	button.add_theme_stylebox_override("pressed", _build_textured_stylebox(_UI_BUTTON_PRESSED_TEXTURE_PATH))


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


func _safe_load_texture(texture_path: String) -> Texture2D:
	if texture_path == "":
		return null
	if ResourceLoader.exists(texture_path):
		var resource := load(texture_path)
		if resource is Texture2D:
			return resource
	return null
