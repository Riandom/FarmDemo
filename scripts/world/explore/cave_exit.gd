extends Node2D
class_name CaveExit

@export var interaction_radius: float = 64.0


func _ready() -> void:
	add_to_group("player_interactable")


func get_interaction_hint(_current_tool_id: String = "") -> String:
	return "按 F 撤离洞窟"


func get_interaction_range() -> float:
	return interaction_radius


func interact(_player: Node) -> Dictionary:
	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("exit_cave"):
		return {
			"success": false,
			"message": "撤离点未就绪",
		}

	var success: bool = bool(current_scene.call("exit_cave", true, false))
	return {
		"success": success,
		"message": "你安全撤离了洞窟" if success else "现在无法撤离",
	}
