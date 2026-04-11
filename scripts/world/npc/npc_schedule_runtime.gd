extends RefCounted
class_name NPCScheduleRuntime


static func get_time_period(time_manager: Node) -> String:
	if time_manager == null:
		return "morning"

	var shi_chen: int = int(time_manager.get("shi_chen"))
	if shi_chen >= 3 and shi_chen <= 5:
		return "morning"
	if shi_chen >= 6 and shi_chen <= 8:
		return "afternoon"
	return "evening"


static func build_schedule_entry(anchor_id: String, is_visible: bool) -> Dictionary:
	return {
		"anchor_id": anchor_id,
		"visible": is_visible,
	}


static func get_schedule_entry(schedule_map: Dictionary, time_period: String) -> Dictionary:
	var entry = schedule_map.get(time_period, {})
	if entry is Dictionary:
		return entry
	return {}
