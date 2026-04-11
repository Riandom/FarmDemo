extends RefCounted
class_name NPCDialogueRuntime


static func build_dialogue_payload(npc: Node, time_period: String, is_first_talk: bool) -> Dictionary:
	var display_name: String = ""
	if npc.has_method("get_display_name"):
		display_name = String(npc.call("get_display_name"))

	var dialogue_text: String = _resolve_dialogue_text(npc, time_period, is_first_talk)
	var payload: Dictionary = {
		"npc_id": String(npc.get("npc_id")),
		"npc_name": display_name,
		"text": dialogue_text,
		"time_period": time_period,
		"is_first_talk": is_first_talk,
	}

	var service_modal_type: String = String(npc.get("service_modal_type"))
	var service_label: String = String(npc.get("service_label"))
	if service_modal_type != "" and service_label != "":
		payload["service_modal_type"] = service_modal_type
		payload["service_label"] = service_label

	return payload


static func _resolve_dialogue_text(npc: Node, time_period: String, is_first_talk: bool) -> String:
	var first_value: String = ""
	var repeat_value: String = ""
	match time_period:
		"morning":
			first_value = String(npc.get("morning_first_dialogue"))
			repeat_value = String(npc.get("morning_repeat_dialogue"))
		"afternoon":
			first_value = String(npc.get("afternoon_first_dialogue"))
			repeat_value = String(npc.get("afternoon_repeat_dialogue"))
		"evening":
			first_value = String(npc.get("evening_first_dialogue"))
			repeat_value = String(npc.get("evening_repeat_dialogue"))

	if is_first_talk:
		if first_value != "":
			return first_value
		return String(npc.get("default_first_dialogue"))

	if repeat_value != "":
		return repeat_value
	return String(npc.get("default_repeat_dialogue"))
