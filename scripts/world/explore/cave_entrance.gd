extends Node2D
class_name CaveEntrance

@export var interaction_radius: float = 56.0


func _ready() -> void:
	add_to_group("player_interactable")


func get_interaction_hint(_current_tool_id: String = "") -> String:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null or String(game_manager.get("current_world_area")) != "farm":
		return ""
	return "按 F 进入洞窟"


func get_interaction_range() -> float:
	return interaction_radius


func interact(_player: Node) -> Dictionary:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null or String(game_manager.get("current_world_area")) != "farm":
		return {
			"success": false,
			"message": "现在无法进入洞窟",
		}

	var area_manager = get_node_or_null("/root/WorldAreaManager")
	if area_manager == null or not area_manager.has_method("request_enter_area"):
		return {
			"success": false,
			"message": "洞窟入口未就绪",
		}

	var success: bool = bool(area_manager.call("request_enter_area", "cave", "cave_from_farm"))
	return {
		"success": success,
		"message": "你走进了昏暗的洞窟" if success else "现在无法进入洞窟",
	}
