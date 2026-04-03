extends CanvasLayer
class_name UIRoot

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)
signal inventory_updated(items: Dictionary)
signal shop_transaction_completed(item_id: String, is_buy: bool, amount: int)

var _modal_registry: Dictionary = {}
var _current_modal_type: String = ""
var _player: Node = null

@onready var interaction_prompt: Control = $InteractionPrompt
@onready var inventory_ui: Control = $InventoryUI
@onready var shop_ui: Control = $ShopUI
@onready var gold_display: Control = $GoldDisplay
@onready var time_display: Control = $TimeDisplay
@onready var solar_term_popup: Control = $SolarTermPopup
@onready var pause_menu_ui: Control = $PauseMenuUI


func _ready() -> void:
	"""初始化 UI 注册表并连接子组件信号。"""
	register_modal_ui("inventory", inventory_ui)
	register_modal_ui("shop", shop_ui)
	register_modal_ui("pause_menu", pause_menu_ui)
	_connect_ui_signals()
	_bind_child_context()


func _unhandled_input(event: InputEvent) -> void:
	"""处理 UI 层输入，统一开关背包和商店。"""
	if event.is_action_pressed("pause_menu"):
		toggle_pause_menu()
		get_viewport().set_input_as_handled()
		return

	if _current_modal_type == "pause_menu":
		return

	if event.is_action_pressed("open_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("open_shop"):
		toggle_shop()
		get_viewport().set_input_as_handled()


## 设置玩家引用，供交互提示和输入锁定使用
func set_player(player: Node) -> void:
	_player = player
	if interaction_prompt != null and interaction_prompt.has_method("set_player"):
		interaction_prompt.call("set_player", player)

	_sync_player_ui_state(is_any_modal_open())


## 注册模态 UI 到统一注册表
func register_modal_ui(ui_type: String, ui_node: Control) -> void:
	if ui_type == "" or ui_node == null:
		push_warning("[UIRoot] register_modal_ui invalid: %s" % ui_type)
		return

	_modal_registry[ui_type] = ui_node


## 打开指定模态 UI；如已有其他模态打开则先关闭再打开
func open_modal(ui_type: String) -> void:
	var modal := _get_modal(ui_type)
	if modal == null:
		push_warning("[UIRoot] modal not registered: %s" % ui_type)
		return

	if _current_modal_type == ui_type and modal.visible:
		return

	if _current_modal_type != "":
		close_current_ui()

	if modal.has_method("open_ui"):
		modal.call("open_ui")


## 关闭指定模态 UI
func close_modal(ui_type: String) -> void:
	var modal := _get_modal(ui_type)
	if modal == null:
		push_warning("[UIRoot] modal not registered: %s" % ui_type)
		return

	if modal.has_method("close_ui"):
		modal.call("close_ui")


## 关闭当前正在打开的模态 UI
func close_current_ui() -> void:
	if _current_modal_type == "":
		return

	close_modal(_current_modal_type)


## 切换背包界面
func toggle_inventory() -> void:
	if _current_modal_type == "inventory":
		close_current_ui()
		return

	open_modal("inventory")


## 切换商店界面
func toggle_shop() -> void:
	if _current_modal_type == "shop":
		close_current_ui()
		return

	open_modal("shop")


func toggle_pause_menu() -> void:
	if _current_modal_type == "pause_menu":
		close_current_ui()
		return

	open_modal("pause_menu")


## 当前是否有任意模态 UI 打开
func is_any_modal_open() -> bool:
	return _current_modal_type != ""


func _get_modal(ui_type: String) -> Control:
	var modal = _modal_registry.get(ui_type)
	if modal is Control:
		return modal
	return null


func _connect_ui_signals() -> void:
	"""连接所有子 UI 的开关和数据通知。"""
	if inventory_ui.has_signal("ui_opened") and not inventory_ui.is_connected("ui_opened", Callable(self, "_on_modal_ui_opened")):
		inventory_ui.connect("ui_opened", Callable(self, "_on_modal_ui_opened"))
	if inventory_ui.has_signal("ui_closed") and not inventory_ui.is_connected("ui_closed", Callable(self, "_on_modal_ui_closed")):
		inventory_ui.connect("ui_closed", Callable(self, "_on_modal_ui_closed"))
	if inventory_ui.has_signal("inventory_updated") and not inventory_ui.is_connected("inventory_updated", Callable(self, "_on_inventory_updated")):
		inventory_ui.connect("inventory_updated", Callable(self, "_on_inventory_updated"))

	if shop_ui.has_signal("ui_opened") and not shop_ui.is_connected("ui_opened", Callable(self, "_on_modal_ui_opened")):
		shop_ui.connect("ui_opened", Callable(self, "_on_modal_ui_opened"))
	if shop_ui.has_signal("ui_closed") and not shop_ui.is_connected("ui_closed", Callable(self, "_on_modal_ui_closed")):
		shop_ui.connect("ui_closed", Callable(self, "_on_modal_ui_closed"))
	if shop_ui.has_signal("shop_transaction_completed") and not shop_ui.is_connected("shop_transaction_completed", Callable(self, "_on_shop_transaction_completed")):
		shop_ui.connect("shop_transaction_completed", Callable(self, "_on_shop_transaction_completed"))

	if pause_menu_ui.has_signal("ui_opened") and not pause_menu_ui.is_connected("ui_opened", Callable(self, "_on_modal_ui_opened")):
		pause_menu_ui.connect("ui_opened", Callable(self, "_on_modal_ui_opened"))
	if pause_menu_ui.has_signal("ui_closed") and not pause_menu_ui.is_connected("ui_closed", Callable(self, "_on_modal_ui_closed")):
		pause_menu_ui.connect("ui_closed", Callable(self, "_on_modal_ui_closed"))


func _bind_child_context() -> void:
	"""向子 UI 注入上下文对象，避免它们直接搜索场景树。"""
	if interaction_prompt != null and interaction_prompt.has_method("set_ui_root"):
		interaction_prompt.call("set_ui_root", self)

	if inventory_ui != null and inventory_ui.has_method("set_ui_root"):
		inventory_ui.call("set_ui_root", self)

	if shop_ui != null and shop_ui.has_method("set_ui_root"):
		shop_ui.call("set_ui_root", self)

	if pause_menu_ui != null and pause_menu_ui.has_method("set_ui_root"):
		pause_menu_ui.call("set_ui_root", self)


func _on_modal_ui_opened(ui_type: String) -> void:
	"""更新当前模态状态并广播打开事件。"""
	_current_modal_type = ui_type
	_sync_player_ui_state(true)
	emit_signal("ui_opened", ui_type)


func _on_modal_ui_closed(ui_type: String) -> void:
	"""清理当前模态状态并广播关闭事件。"""
	if _current_modal_type == ui_type:
		_current_modal_type = ""

	_sync_player_ui_state(false)
	emit_signal("ui_closed", ui_type)


func _on_inventory_updated(items: Dictionary) -> void:
	"""转发背包刷新事件。"""
	emit_signal("inventory_updated", items)


func _on_shop_transaction_completed(item_id: String, is_buy: bool, amount: int) -> void:
	"""转发商店交易完成事件。"""
	emit_signal("shop_transaction_completed", item_id, is_buy, amount)


func _sync_player_ui_state(is_open: bool) -> void:
	"""同步玩家输入锁状态，但不依赖未来 Main 的中转。"""
	if _player == null:
		return

	if _player.has_method("set_ui_open"):
		_player.call("set_ui_open", is_open)
	elif not is_open and _player.has_method("close_ui"):
		_player.call("close_ui")
