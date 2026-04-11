extends Node2D
class_name CaveEntrance

@export var interaction_radius: float = 56.0


func _ready() -> void:
	add_to_group("player_interactable")


func get_interaction_hint(_current_tool_id: String = "") -> String:
	return "按 F 进入洞窟"


func get_interaction_range() -> float:
	return interaction_radius


func interact(_player: Node) -> Dictionary:
	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("enter_cave"):
		return {
			"success": false,
			"message": "洞窟入口未就绪",
		}

	var success: bool = bool(current_scene.call("enter_cave"))
	return {
		"success": success,
		"message": "你走进了昏暗的洞窟" if success else "现在无法进入洞窟",
	}
