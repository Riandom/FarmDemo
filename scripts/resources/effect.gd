extends Resource
class_name Effect

enum StackType {
	ADDITIVE,
	MULTIPLICATIVE,
	MAXIMUM,
}

enum TargetScope {
	GLOBAL,
	SINGLE_TARGET,
	AREA,
	CATEGORY,
}

@export var effect_id: String = ""
@export var effect_type: String = ""
@export var value: float = 0.0
@export var target_id: String = ""
@export var target_ids: Array[String] = []
@export var category: String = ""
@export var cap_value: float = 999.0
@export var stack_type: StackType = StackType.ADDITIVE
@export var scope: TargetScope = TargetScope.GLOBAL

var remaining_seconds: float = 0.0
var remaining_days: int = 0


func is_short_term() -> bool:
	return remaining_seconds > 0.0


func is_long_term() -> bool:
	return remaining_days > 0


func init_short_term(
	id: String,
	type: String,
	val: float,
	duration_seconds: float,
	target: String = "",
	target_category: String = ""
) -> void:
	effect_id = id
	effect_type = type
	value = val
	remaining_seconds = max(duration_seconds, 0.0)
	remaining_days = 0
	target_id = target
	category = target_category


func init_long_term(
	id: String,
	type: String,
	val: float,
	duration_days: int,
	target: String = "",
	target_category: String = ""
) -> void:
	effect_id = id
	effect_type = type
	value = val
	remaining_seconds = 0.0
	remaining_days = max(duration_days, 0)
	target_id = target
	category = target_category


func to_dict() -> Dictionary:
	return {
		"effect_id": effect_id,
		"effect_type": effect_type,
		"value": value,
		"target_id": target_id,
		"target_ids": target_ids.duplicate(),
		"category": category,
		"cap_value": cap_value,
		"stack_type": int(stack_type),
		"scope": int(scope),
		"remaining_seconds": remaining_seconds,
		"remaining_days": remaining_days,
	}


static func from_dict(data: Dictionary) -> Effect:
	var effect := Effect.new()
	effect.effect_id = String(data.get("effect_id", ""))
	effect.effect_type = String(data.get("effect_type", ""))
	effect.value = float(data.get("value", 0.0))
	effect.target_id = String(data.get("target_id", ""))
	var raw_target_ids: Variant = data.get("target_ids", [])
	if raw_target_ids is Array:
		for item: Variant in raw_target_ids:
			effect.target_ids.append(String(item))
	effect.category = String(data.get("category", ""))
	effect.cap_value = float(data.get("cap_value", 999.0))
	effect.stack_type = int(data.get("stack_type", StackType.ADDITIVE))
	effect.scope = int(data.get("scope", TargetScope.GLOBAL))
	effect.remaining_seconds = max(float(data.get("remaining_seconds", 0.0)), 0.0)
	effect.remaining_days = max(int(data.get("remaining_days", 0)), 0)
	return effect
