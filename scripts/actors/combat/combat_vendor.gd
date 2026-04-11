extends Node2D
class_name CombatVendor

@export var interaction_radius: float = 58.0


func _ready() -> void:
	add_to_group("player_interactable")


func get_interaction_hint(_current_tool_id: String = "") -> String:
	return "按 F 补给飞镖"


func get_interaction_range() -> float:
	return interaction_radius


func interact(_player: Node) -> Dictionary:
	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("open_combat_vendor"):
		return {
			"success": false,
			"message": "战备商人未就绪",
		}

	var success: bool = bool(current_scene.call("open_combat_vendor"))
	return {
		"success": success,
		"message": "出征前先把飞镖备齐" if success else "现在无法打开战备商店",
	}
