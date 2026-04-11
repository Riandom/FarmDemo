extends RefCounted
class_name NPCRelationshipRuntime

const MIN_AFFINITY: int = 0
const MAX_AFFINITY: int = 100


static func clamp_affinity(value: int) -> int:
	return clampi(value, MIN_AFFINITY, MAX_AFFINITY)


static func build_affinity_feedback(display_name: String, delta: int, total_affinity: int) -> String:
	if delta > 0:
		return "%s 对你的态度变好了（好感 %d，当前 %d）" % [display_name, delta, total_affinity]
	if delta < 0:
		return "%s 明显有些不高兴（好感 %d，当前 %d）" % [display_name, delta, total_affinity]
	return "%s 的态度没有变化（当前 %d）" % [display_name, total_affinity]
