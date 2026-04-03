extends Node

signal gold_changed(new_amount: int)
signal inventory_changed(items: Dictionary)
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal tool_equipped(tool_id: String)
signal game_saved(timestamp: int)
signal game_loaded(data: Dictionary)

## 当前金币数量
@export var gold: int = 50

## 背包物品字典
@export var inventory: Dictionary = {}

## 当前手持项；既可以是工具，也可以是种子
@export var current_tool: String = "hoe_wood"

## 已解锁/可切换的手持项列表
@export var unlocked_tools: PackedStringArray = PackedStringArray([
	"hoe_wood",
	"seed_wheat",
	"watering_can_wood",
	"sickle_wood",
])

## 以下字段为扩展接口预留
@export var total_harvest_count: int = 0
@export var total_earnings: int = 0
@export var plot_states: Dictionary = {}
@export var save_file_path: String = "user://save_1.save"


func _ready() -> void:
	"""初始化 Demo 默认数据，并向现有 UI 广播一次状态。"""
	_initialize_default_data()
	emit_signal("gold_changed", gold)
	emit_signal("inventory_changed", inventory.duplicate(true))
	emit_signal("tool_equipped", current_tool)


## 增加金币
func add_gold(amount: int) -> void:
	if amount <= 0:
		return

	gold += amount
	total_earnings += amount
	emit_signal("gold_changed", gold)


## 减少金币；成功时返回 true
func remove_gold(amount: int) -> bool:
	if amount < 0:
		return false

	if amount == 0:
		return true

	if gold < amount:
		return false

	gold -= amount
	emit_signal("gold_changed", gold)
	return true


## 添加物品到背包
func add_item(item_id: String, count: int = 1) -> void:
	if item_id == "" or count <= 0:
		return

	inventory[item_id] = get_item_count(item_id) + count
	emit_signal("item_added", item_id, count)
	emit_signal("inventory_changed", inventory.duplicate(true))


## 从背包移除物品；成功时返回 true
func remove_item(item_id: String, count: int = 1) -> bool:
	if item_id == "" or count < 0:
		return false

	if count == 0:
		return true

	var current_count := get_item_count(item_id)
	if current_count < count:
		return false

	var new_count := current_count - count
	if new_count == 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = new_count

	emit_signal("item_removed", item_id, count)
	emit_signal("inventory_changed", inventory.duplicate(true))
	return true


## 检查是否有足够物品
func has_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return true

	return get_item_count(item_id) >= count


## 获取物品数量
func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


## 设置当前手持项
func set_current_tool(tool_id: String) -> void:
	if tool_id == "" or not unlocked_tools.has(tool_id):
		return

	if current_tool == tool_id:
		return

	current_tool = tool_id
	emit_signal("tool_equipped", current_tool)


## 获取当前手持项
func get_current_tool() -> String:
	return current_tool


## 获取已解锁手持项列表
func get_unlocked_tools() -> PackedStringArray:
	return unlocked_tools.duplicate()


## 保存接口预留
func save_game() -> bool:
	push_warning("[GameManager] save_game not implemented in demo")
	return false


## 读取接口预留
func load_game() -> bool:
	push_warning("[GameManager] load_game not implemented in demo")
	return false


func _initialize_default_data() -> void:
	"""若编辑器未手工配置数据，则回填 Demo 需要的默认值。"""
	if inventory.is_empty():
		inventory = {
			"seed_wheat": 5,
			"crop_wheat": 0,
			"hoe_wood": 1,
			"watering_can_wood": 1,
			"sickle_wood": 1,
		}

	if current_tool == "":
		current_tool = "hoe_wood"
