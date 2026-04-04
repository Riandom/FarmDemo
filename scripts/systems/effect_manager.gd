extends Node

signal effect_added(effect_type: String, effect_id: String)
signal effect_expired(effect_type: String, effect_id: String)

const EFFECT_SUMMER_GROWTH_BOOST: String = "SUMMER_GROWTH_BOOST"
const EFFECT_WINTER_OUTDOOR_GROWTH_BLOCK: String = "WINTER_OUTDOOR_GROWTH_BLOCK"
const EFFECT_TEMP_GROWTH_BOOST: String = "TEMP_GROWTH_BOOST"

const _SEASONAL_EFFECT_IDS: PackedStringArray = [
	"season_summer_growth_boost",
	"season_winter_growth_block",
]
const _SEASONAL_PERSIST_DAYS: int = 999999

var _short_term_effects: Dictionary = {}
var _long_term_effects: Dictionary = {}

@onready var event_manager = get_node_or_null("/root/EventManager")
@onready var time_manager = get_node_or_null("/root/TimeManager")
@onready var config_manager = get_node_or_null("/root/ConfigManager")


func _ready() -> void:
	_subscribe_events()
	_sync_current_season_effects()


func _exit_tree() -> void:
	_unsubscribe_events()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	if _is_time_paused():
		return

	var expired_ids: Array[String] = []
	for effect_id: Variant in _short_term_effects.keys():
		var key: String = String(effect_id)
		var effect: Effect = _short_term_effects.get(key) as Effect
		if effect == null:
			expired_ids.append(key)
			continue

		effect.remaining_seconds = max(effect.remaining_seconds - delta, 0.0)
		if effect.remaining_seconds <= 0.0:
			expired_ids.append(key)

	for effect_id: String in expired_ids:
		remove_effect(effect_id)


func add_effect(effect: Effect) -> void:
	if effect == null or effect.effect_id == "" or effect.effect_type == "":
		push_warning("[EffectManager] Invalid effect add request")
		return

	if _short_term_effects.has(effect.effect_id) or _long_term_effects.has(effect.effect_id):
		remove_effect(effect.effect_id)

	if effect.is_short_term():
		_short_term_effects[effect.effect_id] = effect
	else:
		_long_term_effects[effect.effect_id] = effect

	emit_signal("effect_added", effect.effect_type, effect.effect_id)
	_publish_effect_event("effect_added", effect)


func remove_effect(effect_id: String) -> void:
	var effect: Effect = null
	if _short_term_effects.has(effect_id):
		effect = _short_term_effects.get(effect_id) as Effect
		_short_term_effects.erase(effect_id)
	elif _long_term_effects.has(effect_id):
		effect = _long_term_effects.get(effect_id) as Effect
		_long_term_effects.erase(effect_id)

	if effect == null:
		return

	emit_signal("effect_expired", effect.effect_type, effect.effect_id)
	_publish_effect_event("effect_expired", effect)


func has_effect(effect_type: String, target_id := "", category := "") -> bool:
	return not _collect_matching_effects(effect_type, String(target_id), String(category)).is_empty()


func get_effect_value(effect_type: String, target_id := "", category := "") -> float:
	var effects: Array[Effect] = _collect_matching_effects(effect_type, String(target_id), String(category))
	if effects.is_empty():
		return 0.0

	var first_effect: Effect = effects[0]
	match first_effect.stack_type:
		Effect.StackType.ADDITIVE:
			var total: float = 0.0
			for effect: Effect in effects:
				total += effect.value
			return min(total, first_effect.cap_value)
		Effect.StackType.MULTIPLICATIVE:
			var multiplier: float = 1.0
			for effect: Effect in effects:
				multiplier *= (1.0 + effect.value)
			return min(multiplier - 1.0, first_effect.cap_value)
		Effect.StackType.MAXIMUM:
			var max_value: float = -INF
			for effect: Effect in effects:
				max_value = max(max_value, effect.value)
			return min(max_value, first_effect.cap_value)
		_:
			return 0.0


func export_save_data() -> Dictionary:
	var serialized_effects: Array[Dictionary] = []
	for effect: Effect in _short_term_effects.values():
		if effect != null:
			serialized_effects.append(effect.to_dict())
	for effect: Effect in _long_term_effects.values():
		if effect != null:
			serialized_effects.append(effect.to_dict())

	return {
		"effects": serialized_effects,
	}


func apply_save_data(data: Dictionary) -> void:
	_short_term_effects.clear()
	_long_term_effects.clear()

	var raw_effects: Variant = data.get("effects", [])
	if raw_effects is Array:
		for item: Variant in raw_effects:
			if item is Dictionary:
				var effect: Effect = Effect.from_dict(item)
				add_effect(effect)


func _on_day_started(_data: Dictionary) -> void:
	var expired_ids: Array[String] = []
	for effect_id: Variant in _long_term_effects.keys():
		var key: String = String(effect_id)
		if _SEASONAL_EFFECT_IDS.has(key):
			continue

		var effect: Effect = _long_term_effects.get(key) as Effect
		if effect == null:
			expired_ids.append(key)
			continue
		if effect.remaining_days > 0:
			effect.remaining_days -= 1
		if effect.remaining_days <= 0:
			expired_ids.append(key)

	for effect_id: String in expired_ids:
		remove_effect(effect_id)


func _on_season_changed(_data: Dictionary) -> void:
	_sync_current_season_effects()


func _on_save_loaded(_data: Dictionary) -> void:
	_sync_current_season_effects()


func _subscribe_events() -> void:
	if event_manager == null:
		event_manager = get_node_or_null("/root/EventManager")
	if event_manager == null or not event_manager.has_method("subscribe"):
		return

	event_manager.call("subscribe", "day_started", Callable(self, "_on_day_started"))
	event_manager.call("subscribe", "season_changed", Callable(self, "_on_season_changed"))
	event_manager.call("subscribe", "save_loaded", Callable(self, "_on_save_loaded"))


func _unsubscribe_events() -> void:
	if event_manager == null:
		event_manager = get_node_or_null("/root/EventManager")
	if event_manager == null or not event_manager.has_method("unsubscribe"):
		return

	event_manager.call("unsubscribe", "day_started", Callable(self, "_on_day_started"))
	event_manager.call("unsubscribe", "season_changed", Callable(self, "_on_season_changed"))
	event_manager.call("unsubscribe", "save_loaded", Callable(self, "_on_save_loaded"))


func _sync_current_season_effects() -> void:
	for effect_id: String in _SEASONAL_EFFECT_IDS:
		remove_effect(effect_id)

	var season_id: String = _get_current_season_id()
	var season_config: SeasonConfig = _get_current_season_config()

	match season_id:
		"summer":
			var bonus_value: float = 0.2
			if season_config != null:
				bonus_value = max(season_config.growth_rate_multiplier - 1.0, 0.0)

			var summer_effect := Effect.new()
			summer_effect.init_long_term(
				"season_summer_growth_boost",
				EFFECT_SUMMER_GROWTH_BOOST,
				bonus_value,
				_SEASONAL_PERSIST_DAYS
			)
			summer_effect.scope = Effect.TargetScope.GLOBAL
			summer_effect.stack_type = Effect.StackType.ADDITIVE
			add_effect(summer_effect)
		"winter":
			var winter_effect := Effect.new()
			winter_effect.init_long_term(
				"season_winter_growth_block",
				EFFECT_WINTER_OUTDOOR_GROWTH_BLOCK,
				1.0,
				_SEASONAL_PERSIST_DAYS
			)
			winter_effect.scope = Effect.TargetScope.GLOBAL
			winter_effect.stack_type = Effect.StackType.MAXIMUM
			add_effect(winter_effect)
		_:
			pass


func _collect_matching_effects(effect_type: String, target_id: String, category: String) -> Array[Effect]:
	var result: Array[Effect] = []
	for effect: Effect in _short_term_effects.values():
		if _matches_effect(effect, effect_type, target_id, category):
			result.append(effect)
	for effect: Effect in _long_term_effects.values():
		if _matches_effect(effect, effect_type, target_id, category):
			result.append(effect)
	return result


func _matches_effect(effect: Effect, effect_type: String, target_id: String, category: String) -> bool:
	if effect == null or effect.effect_type != effect_type:
		return false

	match effect.scope:
		Effect.TargetScope.GLOBAL:
			return true
		Effect.TargetScope.SINGLE_TARGET:
			if target_id == "":
				return false
			return effect.target_id == target_id or effect.target_ids.has(target_id)
		Effect.TargetScope.CATEGORY:
			if category == "":
				return false
			return effect.category == category
		_:
			return false


func _publish_effect_event(event_type: String, effect: Effect) -> void:
	if event_manager == null:
		event_manager = get_node_or_null("/root/EventManager")
	if event_manager == null or not event_manager.has_method("publish"):
		return

	event_manager.call("publish", event_type, {
		"effect_id": effect.effect_id,
		"effect_type": effect.effect_type,
		"value": effect.value,
	})


func _get_current_season_id() -> String:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return "spring"
	return String(time_manager.get("season"))


func _get_current_season_config() -> SeasonConfig:
	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager == null or not config_manager.has_method("get_current_season_config"):
		return null

	return config_manager.call("get_current_season_config") as SeasonConfig


func _is_time_paused() -> bool:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null or not time_manager.has_method("is_time_paused"):
		return false
	return bool(time_manager.call("is_time_paused"))
