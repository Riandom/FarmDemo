extends Area2D
class_name StorageChest

signal slots_changed(slots: Array)

const SLOT_COUNT: int = 50

@export var chest_id: String = "farm_chest_01"
@export var interaction_radius: float = 56.0
@export var chest_label: String = "储物箱"
@export var required_area_id: String = ""
@export var slots: Array = []


func _ready() -> void:
	add_to_group("player_interactable")
	add_to_group("storage_chest")
	if slots.is_empty():
		slots = _create_empty_slots()
	else:
		slots = _normalize_slots(slots)


func get_interaction_hint(_current_tool_id: String = "") -> String:
	if not _is_available_in_current_area():
		return ""
	return "按 F 打开%s" % chest_label


func get_interaction_range() -> float:
	return interaction_radius


func interact(_player: Node) -> Dictionary:
	if not _is_available_in_current_area():
		return {
			"success": false,
			"message": "现在无法打开储物箱",
		}

	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("open_storage_chest"):
		return {
			"success": false,
			"message": "储物箱系统未就绪",
		}

	var success: bool = bool(current_scene.call("open_storage_chest", self))
	return {
		"success": success,
		"message": "整理一下今天的收获" if success else "现在无法打开储物箱",
	}


func get_slots() -> Array:
	return _duplicate_slots(slots)


func set_slots(new_slots: Array) -> void:
	slots = _normalize_slots(new_slots)
	emit_signal("slots_changed", get_slots())


func can_add_item(item_id: String, count: int = 1) -> bool:
	if item_id == "" or count <= 0:
		return false

	return _find_slot_index_by_item(item_id) != -1 or _find_empty_slot_index() != -1


func add_item(item_id: String, count: int = 1) -> bool:
	if not can_add_item(item_id, count):
		return false

	var existing_index: int = _find_slot_index_by_item(item_id)
	if existing_index != -1:
		var slot: Dictionary = _get_slot(existing_index)
		slot["count"] = int(slot.get("count", 0)) + count
		slots[existing_index] = slot
	else:
		var empty_index: int = _find_empty_slot_index()
		if empty_index == -1:
			return false
		slots[empty_index] = {
			"item_id": item_id,
			"count": count,
		}

	emit_signal("slots_changed", get_slots())
	return true


func remove_item(item_id: String, count: int = 1) -> bool:
	if item_id == "" or count <= 0:
		return false
	if get_item_count(item_id) < count:
		return false

	var remaining: int = count
	for slot_index in range(SLOT_COUNT):
		var slot: Dictionary = _get_slot(slot_index)
		if String(slot.get("item_id", "")) != item_id:
			continue

		var slot_count: int = int(slot.get("count", 0))
		if slot_count <= remaining:
			remaining -= slot_count
			slots[slot_index] = {}
		else:
			slot["count"] = slot_count - remaining
			slots[slot_index] = slot
			remaining = 0

		if remaining <= 0:
			break

	emit_signal("slots_changed", get_slots())
	return true


func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot_data in slots:
		if not (slot_data is Dictionary):
			continue
		if String(slot_data.get("item_id", "")) != item_id:
			continue
		total += int(slot_data.get("count", 0))
	return total


func export_save_data() -> Dictionary:
	return {
		"chest_id": chest_id,
		"slots": get_slots(),
	}


func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		set_slots(_create_empty_slots())
		return

	set_slots(data.get("slots", []))


func _create_empty_slots() -> Array:
	var empty_slots: Array = []
	for _i in range(SLOT_COUNT):
		empty_slots.append({})
	return empty_slots


func _normalize_slots(source_slots: Array) -> Array:
	var normalized: Array = _create_empty_slots()
	for slot_index in range(min(source_slots.size(), SLOT_COUNT)):
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


func _duplicate_slots(source_slots: Array) -> Array:
	var duplicated: Array = []
	for slot_data in source_slots:
		if slot_data is Dictionary:
			duplicated.append(slot_data.duplicate(true))
		else:
			duplicated.append({})
	return duplicated


func _find_slot_index_by_item(item_id: String) -> int:
	for slot_index in range(SLOT_COUNT):
		if String(_get_slot(slot_index).get("item_id", "")) == item_id:
			return slot_index
	return -1


func _find_empty_slot_index() -> int:
	for slot_index in range(SLOT_COUNT):
		if _get_slot(slot_index).is_empty():
			return slot_index
	return -1


func _get_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size():
		return {}

	var slot_data = slots[slot_index]
	if slot_data is Dictionary:
		return slot_data
	return {}


func _is_available_in_current_area() -> bool:
	if required_area_id == "":
		return true

	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return false

	return String(game_manager.get("current_world_area")) == required_area_id
