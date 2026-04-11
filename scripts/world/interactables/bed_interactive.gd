extends Area2D

@export var interaction_radius: float = 50.0
@export var bed_label: String = "休息"
@export var required_area_id: String = ""

@onready var fade_overlay: ColorRect = $CanvasLayer/FadeOverlay
@onready var save_manager = get_node_or_null("/root/SaveManager")
@onready var time_manager = get_node_or_null("/root/TimeManager")


func _ready() -> void:
	add_to_group("player_interactable")
	fade_overlay.modulate.a = 0.0


func get_interaction_hint(_current_tool_id: String = "") -> String:
	if not _is_available_in_current_area():
		return ""
	return "按 F %s" % bed_label


func get_interaction_range() -> float:
	return interaction_radius


func interact(_player: Node) -> Dictionary:
	if not _is_available_in_current_area():
		return {
			"success": false,
			"message": "现在无法休息",
		}

	if save_manager == null or time_manager == null:
		return {
			"success": false,
			"message": "休息系统未就绪",
		}

	save_manager.save_game_auto()
	time_manager.skip_to_next_day_mao_hour()
	_play_fade_effect()
	return {
		"success": true,
		"message": "新的一天开始了！卯时",
	}


func _play_fade_effect() -> void:
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.15)
	tween.tween_interval(0.3)
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.15)


func _is_available_in_current_area() -> bool:
	if required_area_id == "":
		return true

	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return false

	return String(game_manager.get("current_world_area")) == required_area_id
