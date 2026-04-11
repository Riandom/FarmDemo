extends Control
class_name OrderBoardUI

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)

const _ITEM_ICON_ROOT: String = "res://assets/sprites/placeholder/items"
const _UI_PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"
const _UI_BUTTON_NORMAL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_normal.png"
const _UI_BUTTON_HOVER_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_hover.png"
const _UI_BUTTON_PRESSED_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_pressed.png"

var _ui_root: UIRoot = null
var _warned_missing_order_manager: bool = false
var _warned_missing_game_manager: bool = false
var _is_refreshing_orders: bool = false
var _pending_refresh: bool = false

@onready var config_manager = get_node_or_null("/root/ConfigManager")
@onready var order_manager = get_node_or_null("/root/OrderManager")
@onready var game_manager = get_node_or_null("/root/GameManager")
@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var orders_list: VBoxContainer = $Panel/VBoxContainer/OrdersScroll/OrdersList
@onready var feedback_label: Label = $Panel/VBoxContainer/FeedbackLabel
@onready var panel: PanelContainer = $Panel


func _ready() -> void:
	visible = false
	_apply_ui_theme()
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	call_deferred("_connect_runtime_dependencies")
	_refresh_orders()


func set_ui_root(ui_root: UIRoot) -> void:
	_ui_root = ui_root


func open_ui() -> void:
	if visible:
		return

	visible = true
	_refresh_orders()
	emit_signal("ui_opened", "orders")


func close_ui() -> void:
	if not visible:
		return

	visible = false
	emit_signal("ui_closed", "orders")


func _connect_runtime_dependencies() -> void:
	order_manager = _get_order_manager()
	game_manager = _get_game_manager()

	if order_manager == null:
		if not _warned_missing_order_manager:
			push_warning("[OrderBoardUI] OrderManager not ready")
			_warned_missing_order_manager = true
		return

	if order_manager.has_signal("orders_changed") and not order_manager.is_connected("orders_changed", Callable(self, "_on_orders_changed")):
		order_manager.connect("orders_changed", Callable(self, "_on_orders_changed"))

	if order_manager.has_signal("order_submitted") and not order_manager.is_connected("order_submitted", Callable(self, "_on_order_submitted")):
		order_manager.connect("order_submitted", Callable(self, "_on_order_submitted"))

	if game_manager != null:
		if game_manager.has_signal("inventory_changed") and not game_manager.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
			game_manager.connect("inventory_changed", Callable(self, "_on_inventory_changed"))
		if game_manager.has_signal("gold_changed") and not game_manager.is_connected("gold_changed", Callable(self, "_on_gold_changed")):
			game_manager.connect("gold_changed", Callable(self, "_on_gold_changed"))
	else:
		if not _warned_missing_game_manager:
			push_warning("[OrderBoardUI] GameManager not ready")
			_warned_missing_game_manager = true

	_refresh_orders()


func _refresh_orders() -> void:
	if _is_refreshing_orders:
		_pending_refresh = true
		return

	_is_refreshing_orders = true
	_clear_orders()

	var runtime_order_manager := _get_order_manager()
	if runtime_order_manager == null or not runtime_order_manager.has_method("get_orders"):
		_show_feedback("订单系统未就绪", false)
		_finish_refresh_cycle()
		return
	if runtime_order_manager.has_method("ensure_orders_for_today"):
		runtime_order_manager.call("ensure_orders_for_today")

	var orders: Array = runtime_order_manager.call("get_orders") as Array
	if orders.is_empty():
		_show_feedback("今日暂无订单", false)
		_finish_refresh_cycle()
		return

	_show_feedback("每天刷新 3 条订单，奖励高于直接售卖。", true)
	for order_data in orders:
		if not (order_data is Dictionary):
			continue
		orders_list.add_child(_build_order_card(order_data))

	_finish_refresh_cycle()


func _build_order_card(order_data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 108)
	card.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH, 8))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)

	var root := HBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon_rect.texture = _load_item_icon(String(order_data.get("item_id", "")))
	root.add_child(icon_rect)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 4)
	root.add_child(text_column)

	var title_label := Label.new()
	title_label.text = String(order_data.get("title", "订单"))
	title_label.add_theme_font_size_override("font_size", 18)
	text_column.add_child(title_label)

	var item_name: String = _format_item_name(String(order_data.get("item_id", "")))
	var required_count: int = int(order_data.get("required_count", 0))
	var owned_count: int = _get_owned_count(String(order_data.get("item_id", "")))

	var requirement_label := Label.new()
	requirement_label.text = "需求：%s x%d    持有：%d" % [item_name, required_count, owned_count]
	text_column.add_child(requirement_label)

	var reward_label := Label.new()
	reward_label.text = "奖励：%d 金" % int(order_data.get("reward_gold", 0))
	text_column.add_child(reward_label)

	var publisher_npc_id: String = String(order_data.get("publisher_npc_id", ""))
	if publisher_npc_id != "":
		var publisher_label := Label.new()
		var publisher_name: String = _format_publisher_name(publisher_npc_id)
		var affinity_reward: int = int(order_data.get("affinity_reward", 0))
		publisher_label.text = "发布者：%s    关系奖励：+%d" % [publisher_name, affinity_reward]
		text_column.add_child(publisher_label)

	var submit_button := Button.new()
	submit_button.custom_minimum_size = Vector2(140, 48)
	submit_button.text = "提交订单"
	_apply_button_theme(submit_button)

	var status: String = String(order_data.get("status", "active"))
	var order_id: String = String(order_data.get("order_id", ""))
	if status != "active":
		submit_button.text = "已完成"
		submit_button.disabled = true
	else:
		submit_button.disabled = not _can_submit_order(order_id)
		submit_button.pressed.connect(_on_submit_order_pressed.bind(order_id))

	root.add_child(submit_button)
	return card


func _can_submit_order(order_id: String) -> bool:
	var runtime_order_manager := _get_order_manager()
	if runtime_order_manager == null or not runtime_order_manager.has_method("can_submit_order"):
		return false
	return bool(runtime_order_manager.call("can_submit_order", order_id))


func _get_owned_count(item_id: String) -> int:
	var runtime_game_manager := _get_game_manager()
	if runtime_game_manager == null or not runtime_game_manager.has_method("get_item_count"):
		return 0
	return int(runtime_game_manager.call("get_item_count", item_id))


func _format_item_name(item_id: String) -> String:
	if item_id == "":
		return "未知物品"
	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_display_name"):
		return String(config_manager.call("get_item_display_name", item_id))
	return item_id


func _format_publisher_name(npc_id: String) -> String:
	var runtime_order_manager := _get_order_manager()
	if runtime_order_manager != null and runtime_order_manager.has_method("get_npc_display_name"):
		return String(runtime_order_manager.call("get_npc_display_name", npc_id))
	return npc_id


func _on_submit_order_pressed(order_id: String) -> void:
	var runtime_order_manager := _get_order_manager()
	if runtime_order_manager == null or not runtime_order_manager.has_method("submit_order"):
		_show_feedback("订单系统未就绪", false)
		return

	var result: Dictionary = runtime_order_manager.call("submit_order", order_id) as Dictionary
	var success: bool = bool(result.get("success", false))
	_show_feedback(String(result.get("message", "提交失败")), success)
	_refresh_orders()


func _on_orders_changed(_orders: Array) -> void:
	if visible:
		call_deferred("_refresh_orders")


func _on_order_submitted(result: Dictionary) -> void:
	_show_feedback(String(result.get("message", "订单完成")), bool(result.get("success", false)))


func _on_inventory_changed(_items: Dictionary) -> void:
	if visible:
		_refresh_orders()


func _on_gold_changed(_amount: int) -> void:
	if visible:
		_refresh_orders()


func _on_close_button_pressed() -> void:
	if _ui_root != null:
		_ui_root.close_modal("orders")
		return
	close_ui()


func _clear_orders() -> void:
	for child in orders_list.get_children():
		orders_list.remove_child(child)
		child.queue_free()


func _show_feedback(message: String, success: bool) -> void:
	feedback_label.text = message
	feedback_label.modulate = Color("#4CAF50") if success else Color("#F44336")


func _apply_ui_theme() -> void:
	panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH, 8))
	_apply_button_theme(close_button)


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


func _load_item_icon(item_id: String) -> Texture2D:
	return _safe_load_texture("%s/%s.png" % [_ITEM_ICON_ROOT, item_id])


func _safe_load_texture(texture_path: String) -> Texture2D:
	if texture_path == "":
		return null
	if ResourceLoader.exists(texture_path):
		var resource := load(texture_path)
		if resource is Texture2D:
			return resource
	return null


func _get_order_manager() -> Node:
	if order_manager == null:
		order_manager = get_node_or_null("/root/OrderManager")
	return order_manager


func _get_game_manager() -> Node:
	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	return game_manager


func _finish_refresh_cycle() -> void:
	_is_refreshing_orders = false
	if _pending_refresh:
		_pending_refresh = false
		call_deferred("_refresh_orders")
