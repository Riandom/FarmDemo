extends Node2D
class_name AreaTransitionPoint

@export var interaction_radius: float = 58.0
@export var prompt_text: String = "前往下一区域"
@export var required_area_id: String = "farm"
@export var target_area_id: String = "farm"
@export var entry_point_id: String = ""
@export var success_message: String = "你走向了新的区域"
@export var failure_message: String = "现在无法前往该区域"


func _ready() -> void:
	add_to_group("player_interactable")


func get_interaction_hint(_current_tool_id: String = "") -> String:
	if not _is_available_in_current_area():
		return ""
	return "按 F %s" % prompt_text


func get_interaction_range() -> float:
	return interaction_radius


func interact(_player: Node) -> Dictionary:
	if not _is_available_in_current_area():
		return {
			"success": false,
			"message": failure_message,
		}

	var world_area_manager = get_node_or_null("/root/WorldAreaManager")
	if world_area_manager == null or not world_area_manager.has_method("request_enter_area"):
		return {
			"success": false,
			"message": failure_message,
		}

	var success: bool = bool(world_area_manager.call("request_enter_area", target_area_id, entry_point_id))
	return {
		"success": success,
		"message": success_message if success else failure_message,
	}


func _is_available_in_current_area() -> bool:
	if required_area_id == "":
		return true

	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return false

	return String(game_manager.get("current_world_area")) == required_area_id
