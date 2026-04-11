extends Node2D
class_name CaveExit

@export var interaction_radius: float = 64.0


func _ready() -> void:
	add_to_group("player_interactable")


func get_interaction_hint(_current_tool_id: String = "") -> String:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null or String(game_manager.get("current_world_area")) != "cave":
		return ""
	return "按 F 撤离洞窟"


func get_interaction_range() -> float:
	return interaction_radius


func interact(_player: Node) -> Dictionary:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null or String(game_manager.get("current_world_area")) != "cave":
		return {
			"success": false,
			"message": "现在无法撤离",
		}

	var area_manager = get_node_or_null("/root/WorldAreaManager")
	if area_manager == null or not area_manager.has_method("return_to_area"):
		return {
			"success": false,
			"message": "撤离点未就绪",
		}

	var success: bool = bool(area_manager.call("return_to_area", "farm", "farm_from_cave"))
	return {
		"success": success,
		"message": "你安全撤离了洞窟" if success else "现在无法撤离",
	}
