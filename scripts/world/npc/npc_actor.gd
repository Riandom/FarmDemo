extends Node2D
class_name NPCActor

@export var npc_id: String = "npc_unknown"
@export var display_name: String = "居民"
@export var interaction_radius: float = 56.0
@export var required_area_id: String = "town"
@export var service_modal_type: String = ""
@export var service_label: String = ""
@export var liked_items: PackedStringArray = PackedStringArray()
@export var disliked_items: PackedStringArray = PackedStringArray()

@export_group("Dialogue")
@export_multiline var default_first_dialogue: String = "今天的天气还不错。"
@export_multiline var default_repeat_dialogue: String = "回头见。"
@export_multiline var morning_first_dialogue: String = ""
@export_multiline var morning_repeat_dialogue: String = ""
@export_multiline var afternoon_first_dialogue: String = ""
@export_multiline var afternoon_repeat_dialogue: String = ""
@export_multiline var evening_first_dialogue: String = ""
@export_multiline var evening_repeat_dialogue: String = ""

@export_group("Schedule")
@export var morning_anchor_id: String = ""
@export var morning_visible: bool = true
@export var afternoon_anchor_id: String = ""
@export var afternoon_visible: bool = true
@export var evening_anchor_id: String = ""
@export var evening_visible: bool = true

@onready var time_manager = get_node_or_null("/root/TimeManager")
@onready var game_manager = get_node_or_null("/root/GameManager")

var _current_time_period: String = "morning"


func _ready() -> void:
	add_to_group("player_interactable")
	add_to_group("npc_actor")
	_connect_time_signals()
	call_deferred("_apply_schedule")


func get_interaction_hint(_current_tool_id: String = "") -> String:
	if not _is_available_in_current_area() or not visible:
		return ""
	return "按 F 与%s交谈" % display_name


func get_interaction_range() -> float:
	return interaction_radius


func get_npc_id() -> String:
	return npc_id


func get_display_name() -> String:
	return display_name


func interact(_player: Node) -> Dictionary:
	if not _is_available_in_current_area() or not visible:
		return {
			"success": false,
			"message": "现在无法交谈",
		}

	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("open_npc_interaction"):
		return {
			"success": false,
			"message": "对话系统未就绪",
		}

	var success: bool = bool(current_scene.call("open_npc_interaction", self))
	return {
		"success": success,
		"message": "你和%s聊了几句" % display_name if success else "现在无法交谈",
	}


func build_dialogue_payload() -> Dictionary:
	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	var is_first_talk: bool = true
	if game_manager != null and game_manager.has_method("has_npc_talked_today"):
		is_first_talk = not bool(game_manager.call("has_npc_talked_today", npc_id))
	if game_manager != null and game_manager.has_method("mark_npc_talked_today"):
		game_manager.call("mark_npc_talked_today", npc_id)

	var affinity_delta: int = 0
	if is_first_talk and game_manager != null and game_manager.has_method("add_npc_affinity"):
		game_manager.call("add_npc_affinity", npc_id, 1)
		affinity_delta = 1

	var payload: Dictionary = NPCDialogueRuntime.build_dialogue_payload(self, _current_time_period, is_first_talk)
	payload["affinity"] = get_affinity()
	payload["npc_id"] = npc_id
	payload["gift_enabled"] = true
	payload["affinity_feedback"] = NPCRelationshipRuntime.build_affinity_feedback(display_name, affinity_delta, get_affinity()) if affinity_delta != 0 else ""
	return payload


func get_affinity() -> int:
	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null or not game_manager.has_method("get_npc_affinity"):
		return 0
	return int(game_manager.call("get_npc_affinity", npc_id))


func give_gift(item_id: String) -> Dictionary:
	if item_id == "":
		return {
			"success": false,
			"message": "请先装备要赠送的物品",
		}

	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return {
			"success": false,
			"message": "GameManager 未就绪",
		}
	if not game_manager.has_method("has_item") or not game_manager.has_method("remove_item"):
		return {
			"success": false,
			"message": "送礼系统未就绪",
		}
	if not bool(game_manager.call("has_item", item_id, 1)):
		return {
			"success": false,
			"message": "你没有这个物品",
		}
	if not bool(game_manager.call("remove_item", item_id, 1)):
		return {
			"success": false,
			"message": "赠送失败",
		}

	var reaction: String = NPCGiftRuntime.resolve_reaction(self, item_id)
	var affinity_delta: int = NPCGiftRuntime.get_affinity_delta(reaction)
	var total_affinity: int = get_affinity()
	if game_manager.has_method("add_npc_affinity"):
		total_affinity = int(game_manager.call("add_npc_affinity", npc_id, affinity_delta))

	var item_name: String = item_id
	var config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null and config_manager.has_method("get_item_display_name"):
		item_name = String(config_manager.call("get_item_display_name", item_id))

	return {
		"success": true,
		"message": "%s %s" % [
			NPCGiftRuntime.build_feedback(display_name, item_name, reaction),
			NPCRelationshipRuntime.build_affinity_feedback(display_name, affinity_delta, total_affinity)
		],
		"reaction": reaction,
		"affinity": total_affinity,
		"affinity_delta": affinity_delta,
	}


func _connect_time_signals() -> void:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return
	if not time_manager.time_changed.is_connected(_on_time_changed):
		time_manager.time_changed.connect(_on_time_changed)
	if not time_manager.day_changed.is_connected(_on_day_changed):
		time_manager.day_changed.connect(_on_day_changed)


func _on_time_changed(_shi_chen: int, _ke: int) -> void:
	_apply_schedule()


func _on_day_changed(_day_in_term: int) -> void:
	_apply_schedule()


func _apply_schedule() -> void:
	_current_time_period = NPCScheduleRuntime.get_time_period(time_manager)
	var schedule_map: Dictionary = {
		"morning": NPCScheduleRuntime.build_schedule_entry(morning_anchor_id, morning_visible),
		"afternoon": NPCScheduleRuntime.build_schedule_entry(afternoon_anchor_id, afternoon_visible),
		"evening": NPCScheduleRuntime.build_schedule_entry(evening_anchor_id, evening_visible),
	}
	var entry: Dictionary = NPCScheduleRuntime.get_schedule_entry(schedule_map, _current_time_period)
	visible = bool(entry.get("visible", true))
	var anchor_id: String = String(entry.get("anchor_id", ""))
	if anchor_id == "":
		return

	var anchor_provider: Node = _find_anchor_provider()
	if anchor_provider == null:
		return
	var anchor = anchor_provider.call("get_named_anchor", anchor_id)
	if anchor is Node2D:
		global_position = anchor.global_position


func _is_available_in_current_area() -> bool:
	if required_area_id == "":
		return true

	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return false

	return String(game_manager.get("current_world_area")) == required_area_id


func _find_anchor_provider() -> Node:
	var current_node: Node = get_parent()
	while current_node != null:
		if current_node.has_method("get_named_anchor"):
			return current_node
		current_node = current_node.get_parent()
	return null
