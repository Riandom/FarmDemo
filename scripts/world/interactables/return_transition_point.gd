extends AreaTransitionPoint
class_name ReturnTransitionPoint

@export var return_area_id: String = "farm"


func interact(_player: Node) -> Dictionary:
	var world_area_manager = get_node_or_null("/root/WorldAreaManager")
	if world_area_manager == null or not world_area_manager.has_method("return_to_area"):
		return {
			"success": false,
			"message": failure_message,
		}

	var success: bool = bool(world_area_manager.call("return_to_area", return_area_id, entry_point_id))
	return {
		"success": success,
		"message": success_message if success else failure_message,
	}
