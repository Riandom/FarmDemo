extends Node

signal world_area_will_change(from_area: String, to_area: String)
signal world_area_changed(from_area: String, to_area: String)

const VALID_AREAS: PackedStringArray = ["farm", "house", "town", "cave"]

var previous_area: String = "farm"
var current_entry_point_id: String = ""

@onready var game_manager = get_node_or_null("/root/GameManager")


func request_enter_area(area_id: String, entry_point_id: String = "") -> bool:
	if not VALID_AREAS.has(area_id):
		push_warning("[WorldAreaManager] Invalid area requested: %s" % area_id)
		return false

	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_warning("[WorldAreaManager] GameManager not ready")
		return false

	var current_area: String = String(game_manager.get("current_world_area"))
	if current_area == "":
		current_area = "farm"

	var current_scene := get_tree().current_scene
	if current_scene == null or not current_scene.has_method("enter_world_area"):
		push_warning("[WorldAreaManager] Current scene cannot handle world area transitions")
		return false

	emit_signal("world_area_will_change", current_area, area_id)
	var success: bool = bool(current_scene.call("enter_world_area", area_id, entry_point_id))
	if not success:
		return false

	previous_area = current_area
	current_entry_point_id = entry_point_id
	game_manager.call("set_current_world_area", area_id)
	emit_signal("world_area_changed", previous_area, area_id)
	return true


func return_to_area(area_id: String, entry_point_id: String = "") -> bool:
	return request_enter_area(area_id, entry_point_id)


func get_current_area() -> String:
	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return "farm"

	var current_area: String = String(game_manager.get("current_world_area"))
	return "farm" if current_area == "" else current_area


func get_previous_area() -> String:
	return previous_area
