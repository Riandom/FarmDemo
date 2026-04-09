extends Node

signal gold_changed(new_amount: int)
signal inventory_changed(items: Dictionary)
signal inventory_slots_changed(slots: Array)
signal hotbar_changed(slots: Array, current_index: int)
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal tool_equipped(tool_id: String)
signal stamina_changed(current_stamina: int, max_stamina: int)
signal game_saved(timestamp: int)
signal game_loaded(data: Dictionary)

const INVENTORY_COLUMNS: int = 10
const INVENTORY_ROWS: int = 5
const HOTBAR_SIZE: int = 10
const INVENTORY_SLOT_COUNT: int = INVENTORY_COLUMNS * INVENTORY_ROWS
const _DEFAULT_TOOL_ID: String = "hoe_wood"
const _DEFAULT_LEGACY_INVENTORY: Dictionary = {
	"seed_wheat": 5,
	"crop_wheat": 0,
	"hoe_wood": 1,
	"watering_can_wood": 1,
	"sickle_wood": 1,
}
const _CATEGORY_PRIORITY: Dictionary = {
	"tool": 0,
	"seed": 1,
	"crop": 2,
	"other": 3,
}

## 当前金币数量
@export var gold: int = 50

## 当前体力
@export var stamina: int = 100

## 体力上限
@export var max_stamina: int = 100

## 聚合后的背包物品字典，保留给旧接口和 UI 兼容使用
@export var inventory: Dictionary = {}

## 固定 50 格槽位背包
@export var inventory_slots: Array = []

## 当前选中的热栏索引
@export_range(0, 9, 1) var current_hotbar_index: int = 0

## 当前手持项；值来自当前热栏槽位内的 item_id
@export var current_tool: String = _DEFAULT_TOOL_ID

## 兼容旧逻辑的手持项缓存，内容来自热栏非空物品
@export var unlocked_tools: PackedStringArray = PackedStringArray()

## 以下字段为扩展接口预留
@export var total_harvest_count: int = 0
@export var total_earnings: int = 0
@export var plot_states: Dictionary = {}
@export var save_file_path: String = "user://save_1.save"


func _ready() -> void:
	"""初始化 Demo 默认数据，并向现有 UI 广播一次状态。"""
	_initialize_default_data()
	_emit_full_state()


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


func spend_stamina(amount: int) -> bool:
	if amount <= 0:
		return true

	if not is_stamina_enough(amount):
		return false

	stamina = maxi(stamina - amount, 0)
	emit_signal("stamina_changed", stamina, max_stamina)
	return true


func restore_stamina(amount: int = -1) -> void:
	if max_stamina <= 0:
		max_stamina = 100

	if amount < 0:
		stamina = max_stamina
	else:
		stamina = clampi(stamina + amount, 0, max_stamina)

	emit_signal("stamina_changed", stamina, max_stamina)


func is_stamina_enough(amount: int) -> bool:
	if amount <= 0:
		return true

	return stamina >= amount


func get_stamina_ratio() -> float:
	if max_stamina <= 0:
		return 0.0
	return float(stamina) / float(max_stamina)


## 添加物品到背包
func add_item(item_id: String, count: int = 1) -> void:
	if item_id == "" or count <= 0:
		return

	var existing_index: int = _find_slot_index_by_item(item_id)
	if existing_index != -1:
		var slot: Dictionary = _get_slot(existing_index)
		slot["count"] = int(slot.get("count", 0)) + count
		inventory_slots[existing_index] = slot
	else:
		var target_index: int = _find_preferred_empty_slot(item_id)
		if target_index == -1:
			push_warning("[GameManager] Inventory full, failed to add item: %s" % item_id)
			return
		inventory_slots[target_index] = {
			"item_id": item_id,
			"count": count,
		}

	_refresh_inventory_state()
	emit_signal("item_added", item_id, count)


## 从背包移除物品；成功时返回 true
func remove_item(item_id: String, count: int = 1) -> bool:
	if item_id == "" or count < 0:
		return false

	if count == 0:
		return true

	if get_item_count(item_id) < count:
		return false

	var remaining: int = count
	for slot_index in range(INVENTORY_SLOT_COUNT):
		var slot: Dictionary = _get_slot(slot_index)
		if String(slot.get("item_id", "")) != item_id:
			continue

		var slot_count: int = int(slot.get("count", 0))
		if slot_count <= remaining:
			remaining -= slot_count
			inventory_slots[slot_index] = {}
		else:
			slot["count"] = slot_count - remaining
			inventory_slots[slot_index] = slot
			remaining = 0

		if remaining <= 0:
			break

	_refresh_inventory_state()
	emit_signal("item_removed", item_id, count)
	return true


## 检查是否有足够物品
func has_item(item_id: String, count: int = 1) -> bool:
	if count <= 0:
		return true

	return get_item_count(item_id) >= count


## 获取物品数量
func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in inventory_slots:
		if not (slot is Dictionary):
			continue
		if String(slot.get("item_id", "")) != item_id:
			continue
		total += int(slot.get("count", 0))
	return total


func get_inventory_slots() -> Array:
	return _duplicate_slots(inventory_slots)


func get_hotbar_slots() -> Array:
	var hotbar_slots: Array = []
	for index in range(HOTBAR_SIZE):
		hotbar_slots.append(_get_slot(index).duplicate(true))
	return hotbar_slots


func swap_inventory_slots(from_index: int, to_index: int) -> bool:
	if not _is_valid_slot_index(from_index) or not _is_valid_slot_index(to_index):
		return false

	if from_index == to_index:
		return false

	var from_slot: Dictionary = _get_slot(from_index)
	var to_slot: Dictionary = _get_slot(to_index)
	inventory_slots[from_index] = to_slot
	inventory_slots[to_index] = from_slot
	_refresh_inventory_state()
	return true


func sort_inventory_slots() -> void:
	inventory_slots = _migrate_legacy_inventory_to_slots(_build_inventory_snapshot())
	_refresh_inventory_state()


## 设置当前热栏索引
func set_current_hotbar_index(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE:
		return

	if current_hotbar_index == index:
		return

	current_hotbar_index = index
	_refresh_hotbar_state()


func get_current_hotbar_index() -> int:
	return current_hotbar_index


## 设置当前手持项
func set_current_tool(tool_id: String) -> void:
	if tool_id == "":
		return

	var hotbar_index: int = _find_hotbar_index_by_item(tool_id)
	if hotbar_index == -1:
		return

	set_current_hotbar_index(hotbar_index)


## 获取当前手持项
func get_current_tool() -> String:
	return current_tool


## 获取已解锁手持项列表
func get_unlocked_tools() -> PackedStringArray:
	var result := PackedStringArray()
	for slot in get_hotbar_slots():
		if not (slot is Dictionary):
			continue
		var item_id: String = String(slot.get("item_id", ""))
		if item_id != "" and not result.has(item_id):
			result.append(item_id)
	return result


func export_save_data() -> Dictionary:
	"""导出当前玩家经济、热栏和槽位背包状态。"""
	return {
		"gold": gold,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"inventory": inventory.duplicate(true),
		"inventory_slots": _duplicate_slots(inventory_slots),
		"unlocked_tools": Array(get_unlocked_tools()),
		"current_hotbar_index": current_hotbar_index,
		"current_tool": current_tool,
	}


func apply_save_data(data: Dictionary) -> void:
	"""应用存档中的 GameManager 状态并广播刷新。"""
	gold = max(int(data.get("gold", 50)), 0)
	max_stamina = max(int(data.get("max_stamina", 100)), 1)
	stamina = clampi(int(data.get("stamina", max_stamina)), 0, max_stamina)

	var saved_slots = data.get("inventory_slots", null)
	if saved_slots is Array:
		inventory_slots = _normalize_slots_array(saved_slots)
	else:
		var saved_inventory = data.get("inventory", {})
		if saved_inventory is Dictionary:
			inventory_slots = _migrate_legacy_inventory_to_slots(saved_inventory)
		else:
			inventory_slots = _create_empty_slots()

	inventory = _build_inventory_snapshot()

	var saved_hotbar_index: int = int(data.get("current_hotbar_index", -1))
	if saved_hotbar_index >= 0 and saved_hotbar_index < HOTBAR_SIZE:
		current_hotbar_index = saved_hotbar_index
	else:
		var saved_tool: String = String(data.get("current_tool", ""))
		var resolved_index: int = _find_hotbar_index_by_item(saved_tool)
		current_hotbar_index = resolved_index if resolved_index != -1 else _find_first_occupied_hotbar_index()

	if current_hotbar_index < 0 or current_hotbar_index >= HOTBAR_SIZE:
		current_hotbar_index = 0

	_refresh_unlocked_tools_from_hotbar()
	_sync_current_tool(false)
	_emit_full_state()
	emit_signal("game_loaded", export_save_data())


func _initialize_default_data() -> void:
	"""若编辑器未手工配置数据，则回填 Demo 需要的默认值。"""
	if max_stamina <= 0:
		max_stamina = 100
	stamina = clampi(stamina, 0, max_stamina)

	if inventory_slots.is_empty():
		var source_inventory: Dictionary = inventory.duplicate(true)
		if source_inventory.is_empty():
			source_inventory = _DEFAULT_LEGACY_INVENTORY.duplicate(true)
		inventory_slots = _migrate_legacy_inventory_to_slots(source_inventory)
	else:
		inventory_slots = _normalize_slots_array(inventory_slots)

	inventory = _build_inventory_snapshot()
	if current_hotbar_index < 0 or current_hotbar_index >= HOTBAR_SIZE:
		current_hotbar_index = 0
	_refresh_unlocked_tools_from_hotbar()
	_sync_current_tool(false)
	if current_tool == "":
		current_hotbar_index = _find_first_occupied_hotbar_index()
		_sync_current_tool(false)


func _emit_full_state() -> void:
	emit_signal("gold_changed", gold)
	emit_signal("inventory_changed", inventory.duplicate(true))
	emit_signal("inventory_slots_changed", _duplicate_slots(inventory_slots))
	emit_signal("hotbar_changed", get_hotbar_slots(), current_hotbar_index)
	emit_signal("tool_equipped", current_tool)
	emit_signal("stamina_changed", stamina, max_stamina)


func _refresh_inventory_state() -> void:
	inventory = _build_inventory_snapshot()
	_refresh_unlocked_tools_from_hotbar()
	_sync_current_tool(true)
	emit_signal("inventory_changed", inventory.duplicate(true))
	emit_signal("inventory_slots_changed", _duplicate_slots(inventory_slots))
	emit_signal("hotbar_changed", get_hotbar_slots(), current_hotbar_index)


func _refresh_hotbar_state() -> void:
	_refresh_unlocked_tools_from_hotbar()
	_sync_current_tool(true)
	emit_signal("hotbar_changed", get_hotbar_slots(), current_hotbar_index)


func _sync_current_tool(emit_changed_signal: bool) -> void:
	var next_tool: String = ""
	var selected_slot: Dictionary = _get_slot(current_hotbar_index)
	if not selected_slot.is_empty():
		next_tool = String(selected_slot.get("item_id", ""))

	if current_tool == next_tool:
		return

	current_tool = next_tool
	if emit_changed_signal:
		emit_signal("tool_equipped", current_tool)


func _refresh_unlocked_tools_from_hotbar() -> void:
	unlocked_tools = get_unlocked_tools()


func _create_empty_slots() -> Array:
	var slots: Array = []
	for _i in range(INVENTORY_SLOT_COUNT):
		slots.append({})
	return slots


func _duplicate_slots(source_slots: Array) -> Array:
	var duplicated: Array = []
	for slot in source_slots:
		if slot is Dictionary:
			duplicated.append(slot.duplicate(true))
		else:
			duplicated.append({})
	return duplicated


func _normalize_slots_array(source_slots: Array) -> Array:
	var normalized: Array = _create_empty_slots()
	for slot_index in range(min(source_slots.size(), INVENTORY_SLOT_COUNT)):
		var slot_data = source_slots[slot_index]
		if not (slot_data is Dictionary):
			continue

		var item_id: String = String(slot_data.get("item_id", ""))
		var count: int = max(int(slot_data.get("count", 0)), 0)
		if item_id == "" or count <= 0:
			continue

		normalized[slot_index] = {
			"item_id": item_id,
			"count": count,
		}
	return normalized


func _build_inventory_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for slot in inventory_slots:
		if not (slot is Dictionary):
			continue
		var item_id: String = String(slot.get("item_id", ""))
		var count: int = int(slot.get("count", 0))
		if item_id == "" or count <= 0:
			continue
		snapshot[item_id] = int(snapshot.get(item_id, 0)) + count
	return snapshot


func _migrate_legacy_inventory_to_slots(legacy_inventory: Dictionary) -> Array:
	var migrated_slots: Array = _create_empty_slots()
	var prioritized_entries: Array = []
	var normal_entries: Array = []

	for item_id_variant in legacy_inventory.keys():
		var item_id: String = String(item_id_variant)
		var count: int = max(int(legacy_inventory[item_id_variant]), 0)
		if item_id == "" or count <= 0:
			continue

		var entry: Dictionary = {
			"item_id": item_id,
			"count": count,
			"category": _get_item_category(item_id),
			"display_name": _get_item_display_name(item_id),
		}

		var category: String = String(entry["category"])
		if category == "tool" or category == "seed":
			prioritized_entries.append(entry)
		else:
			normal_entries.append(entry)

	prioritized_entries.sort_custom(Callable(self, "_sort_inventory_entries"))
	normal_entries.sort_custom(Callable(self, "_sort_inventory_entries"))

	var hotbar_index: int = 0
	for entry in prioritized_entries:
		if hotbar_index >= HOTBAR_SIZE:
			break
		migrated_slots[hotbar_index] = {
			"item_id": String(entry["item_id"]),
			"count": int(entry["count"]),
		}
		hotbar_index += 1

	var inventory_index: int = HOTBAR_SIZE
	for entry in normal_entries:
		while inventory_index < INVENTORY_SLOT_COUNT and not _slot_data_is_empty(migrated_slots[inventory_index]):
			inventory_index += 1
		if inventory_index >= INVENTORY_SLOT_COUNT:
			break
		migrated_slots[inventory_index] = {
			"item_id": String(entry["item_id"]),
			"count": int(entry["count"]),
		}
		inventory_index += 1

	if hotbar_index < HOTBAR_SIZE:
		for entry in prioritized_entries.slice(hotbar_index):
			while inventory_index < INVENTORY_SLOT_COUNT and not _slot_data_is_empty(migrated_slots[inventory_index]):
				inventory_index += 1
			if inventory_index >= INVENTORY_SLOT_COUNT:
				break
			migrated_slots[inventory_index] = {
				"item_id": String(entry["item_id"]),
				"count": int(entry["count"]),
			}
			inventory_index += 1

	return migrated_slots


func _sort_inventory_entries(a: Dictionary, b: Dictionary) -> bool:
	var category_a: String = String(a.get("category", "other"))
	var category_b: String = String(b.get("category", "other"))
	var priority_a: int = int(_CATEGORY_PRIORITY.get(category_a, 99))
	var priority_b: int = int(_CATEGORY_PRIORITY.get(category_b, 99))
	if priority_a != priority_b:
		return priority_a < priority_b

	var hotbar_priority_a: int = _get_hotbar_priority(String(a.get("item_id", "")))
	var hotbar_priority_b: int = _get_hotbar_priority(String(b.get("item_id", "")))
	if hotbar_priority_a != hotbar_priority_b:
		return hotbar_priority_a < hotbar_priority_b

	return String(a.get("display_name", a.get("item_id", ""))) < String(b.get("display_name", b.get("item_id", "")))


func _find_slot_index_by_item(item_id: String) -> int:
	for slot_index in range(INVENTORY_SLOT_COUNT):
		if String(_get_slot(slot_index).get("item_id", "")) == item_id:
			return slot_index
	return -1


func _find_preferred_empty_slot(item_id: String) -> int:
	var category: String = _get_item_category(item_id)
	if category == "tool" or category == "seed":
		for slot_index in range(HOTBAR_SIZE):
			if _is_slot_empty(slot_index):
				return slot_index
		for slot_index in range(HOTBAR_SIZE, INVENTORY_SLOT_COUNT):
			if _is_slot_empty(slot_index):
				return slot_index
	else:
		for slot_index in range(HOTBAR_SIZE, INVENTORY_SLOT_COUNT):
			if _is_slot_empty(slot_index):
				return slot_index
		for slot_index in range(HOTBAR_SIZE):
			if _is_slot_empty(slot_index):
				return slot_index

	return -1


func _find_hotbar_index_by_item(item_id: String) -> int:
	if item_id == "":
		return -1

	for slot_index in range(HOTBAR_SIZE):
		if String(_get_slot(slot_index).get("item_id", "")) == item_id:
			return slot_index
	return -1


func _find_first_occupied_hotbar_index() -> int:
	for slot_index in range(HOTBAR_SIZE):
		if not _is_slot_empty(slot_index):
			return slot_index
	return 0


func _get_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot_index(slot_index):
		return {}

	var slot_data = inventory_slots[slot_index]
	if slot_data is Dictionary:
		return slot_data
	return {}


func _is_slot_empty(slot_index: int) -> bool:
	return _slot_data_is_empty(_get_slot(slot_index))


func _slot_data_is_empty(slot_data: Dictionary) -> bool:
	return String(slot_data.get("item_id", "")) == "" or int(slot_data.get("count", 0)) <= 0


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < INVENTORY_SLOT_COUNT


func _get_item_category(item_id: String) -> String:
	var config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_category"):
		return String(config_manager.call("get_item_category", item_id))
	return "other"


func _get_item_display_name(item_id: String) -> String:
	var config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_display_name"):
		return String(config_manager.call("get_item_display_name", item_id))
	return item_id


func _get_hotbar_priority(item_id: String) -> int:
	match item_id:
		"hoe_wood":
			return 0
		"watering_can_wood":
			return 1
		"sickle_wood":
			return 2
		"seed_wheat":
			return 3
		_:
			return 50
