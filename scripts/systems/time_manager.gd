extends Node

signal time_changed(shi_chen: int, ke: int)
signal day_changed(day_in_term: int)
signal solar_term_changed(solar_term_index: int)
signal season_changed(season_id: String, year_count: int)
signal crop_growth_triggered(plot_count: int)

const DEFAULT_SEASON: String = "spring"
const DEFAULT_SHI_CHEN_NAMES: Array[String] = [
	"子时", "丑时", "寅时", "卯时", "辰时", "巳时",
	"午时", "未时", "申时", "酉时", "戌时", "亥时",
]
const DEFAULT_KE_NAMES: Array[String] = ["初刻", "二刻", "三刻", "四刻"]
const FALLBACK_SEASON_DISPLAY_NAMES: Dictionary = {
	"spring": "春季",
	"summer": "夏季",
	"autumn": "秋季",
	"winter": "冬季",
}
const FALLBACK_SOLAR_TERMS_BY_SEASON: Dictionary = {
	"spring": ["立春", "雨水", "惊蛰", "春分", "清明", "谷雨"],
	"summer": ["立夏", "小满", "芒种", "夏至", "小暑", "大暑"],
	"autumn": ["立秋", "处暑", "白露", "秋分", "寒露", "霜降"],
	"winter": ["立冬", "小雪", "大雪", "冬至", "小寒", "大寒"],
}

@export var time_config: TimeConfig

var season: String = DEFAULT_SEASON
var solar_term_index: int = 0
var day_in_term: int = 0
var shi_chen: int = 3
var ke: int = 0
var real_play_seconds: float = 0.0
var year_count: int = 0
var current_season_config: SeasonConfig = null

var _ke_elapsed_seconds: float = 0.0
var _time_paused: bool = false

@onready var farm_manager = get_node_or_null("/root/FarmManager")
@onready var config_manager = get_node_or_null("/root/ConfigManager")
@onready var event_manager = get_node_or_null("/root/EventManager")
@onready var effect_manager = get_node_or_null("/root/EffectManager")
@onready var game_manager = get_node_or_null("/root/GameManager")


func _ready() -> void:
	if time_config == null and ResourceLoader.exists("res://resources/data/time_config.tres"):
		time_config = load("res://resources/data/time_config.tres") as TimeConfig

	_refresh_runtime_configs()
	call_deferred("_emit_current_time_state")


func _process(delta: float) -> void:
	if _time_paused:
		return

	real_play_seconds += delta
	_ke_elapsed_seconds += delta

	var ke_duration: float = max(_get_ke_duration_seconds(), 0.1)
	while _ke_elapsed_seconds >= ke_duration:
		_ke_elapsed_seconds -= ke_duration
		advance_ke()


func set_time_paused(is_paused: bool) -> void:
	_time_paused = is_paused


func is_time_paused() -> bool:
	return _time_paused


func advance_ke() -> void:
	ke += 1
	if ke >= _get_ke_names().size():
		ke = 0
		advance_shi_chen()
		return

	emit_signal("time_changed", shi_chen, ke)


func advance_shi_chen() -> void:
	shi_chen += 1
	if shi_chen >= _get_shi_chen_names().size():
		shi_chen = 0
		advance_day()
		return

	emit_signal("time_changed", shi_chen, ke)
	_check_daily_growth_trigger()


func advance_day() -> void:
	_advance_day_state()
	emit_signal("day_changed", day_in_term)
	_publish_day_started()
	_restore_player_stamina()
	emit_signal("time_changed", shi_chen, ke)
	_check_daily_growth_trigger()


func skip_to_next_day_mao_hour() -> void:
	_advance_day_state()
	shi_chen = _get_day_start_shi_chen()
	ke = 0
	_ke_elapsed_seconds = 0.0

	emit_signal("day_changed", day_in_term)
	_publish_day_started()
	_restore_player_stamina()
	emit_signal("time_changed", shi_chen, ke)
	_check_daily_growth_trigger()


func trigger_crop_growth() -> void:
	if farm_manager == null:
		farm_manager = get_node_or_null("/root/FarmManager")
	if farm_manager == null:
		emit_signal("crop_growth_triggered", 0)
		return

	var growth_units: float = get_current_growth_multiplier()
	if growth_units <= 0.0:
		emit_signal("crop_growth_triggered", 0)
		return

	var advanced_count: int = 0
	for plot in farm_manager.get_all_plots():
		if plot == null or not is_instance_valid(plot):
			continue
		if plot.has_method("advance_growth"):
			if bool(plot.call("advance_growth", growth_units)):
				advanced_count += 1
		elif plot.has_method("advance_growth_by_day"):
			if bool(plot.call("advance_growth_by_day")):
				advanced_count += 1

	emit_signal("crop_growth_triggered", advanced_count)


func get_current_growth_multiplier() -> float:
	_refresh_runtime_configs()
	var growth_multiplier: float = 1.0
	if current_season_config != null:
		growth_multiplier = max(current_season_config.growth_rate_multiplier, 0.0)

	if effect_manager == null:
		effect_manager = get_node_or_null("/root/EffectManager")
	if effect_manager == null:
		return growth_multiplier

	if effect_manager.has_method("has_effect"):
		var winter_block_active: bool = bool(effect_manager.call("has_effect", "WINTER_OUTDOOR_GROWTH_BLOCK"))
		if winter_block_active:
			return 0.0

	if effect_manager.has_method("get_effect_value"):
		var summer_boost: float = float(effect_manager.call("get_effect_value", "SUMMER_GROWTH_BOOST"))
		if summer_boost > 0.0:
			growth_multiplier = 1.0 + summer_boost

		var temp_growth_boost: float = float(effect_manager.call("get_effect_value", "TEMP_GROWTH_BOOST"))
		if temp_growth_boost != 0.0:
			growth_multiplier *= (1.0 + temp_growth_boost)

	return max(growth_multiplier, 0.0)


func get_current_season_config() -> SeasonConfig:
	_refresh_runtime_configs()
	return current_season_config


func get_time_display_string() -> String:
	return "%s\n%s" % [format_date_line(), format_clock_line()]


func format_date_line(data: Dictionary = {}) -> String:
	var snapshot: Dictionary = data if not data.is_empty() else export_save_data()
	var snapshot_season: String = String(snapshot.get("season", DEFAULT_SEASON))
	var snapshot_solar_term: int = int(snapshot.get("solar_term", solar_term_index))
	var snapshot_day: int = int(snapshot.get("day_in_term", day_in_term))
	var snapshot_year_count: int = max(int(snapshot.get("year_count", year_count)), 0)
	return "第 %d 年 %s·%s 第 %d 天" % [
		snapshot_year_count + 1,
		_get_season_display_name(snapshot_season),
		_get_solar_term_name(snapshot_season, snapshot_solar_term),
		snapshot_day + 1,
	]


func format_year_line(data: Dictionary = {}) -> String:
	var snapshot: Dictionary = data if not data.is_empty() else export_save_data()
	var snapshot_year_count: int = max(int(snapshot.get("year_count", year_count)), 0)
	return "第 %d 年" % [snapshot_year_count + 1]


func format_season_day_line(data: Dictionary = {}) -> String:
	var snapshot: Dictionary = data if not data.is_empty() else export_save_data()
	var snapshot_season: String = String(snapshot.get("season", DEFAULT_SEASON))
	var snapshot_solar_term: int = int(snapshot.get("solar_term", solar_term_index))
	var snapshot_day: int = int(snapshot.get("day_in_term", day_in_term))
	return "%s·%s 第 %d 天" % [
		_get_season_display_name(snapshot_season),
		_get_solar_term_name(snapshot_season, snapshot_solar_term),
		snapshot_day + 1,
	]


func format_clock_line(data: Dictionary = {}) -> String:
	var snapshot: Dictionary = data if not data.is_empty() else export_save_data()
	var snapshot_shi_chen: int = int(snapshot.get("shi_chen", shi_chen))
	var snapshot_ke: int = int(snapshot.get("ke", ke))
	var shi_chen_names: PackedStringArray = _get_shi_chen_names()
	var ke_names: PackedStringArray = _get_ke_names()
	return "%s%s" % [
		shi_chen_names[snapshot_shi_chen % shi_chen_names.size()],
		ke_names[snapshot_ke % ke_names.size()],
	]


func export_save_data() -> Dictionary:
	return {
		"season": season,
		"solar_term": solar_term_index,
		"day_in_term": day_in_term,
		"shi_chen": shi_chen,
		"ke": ke,
		"real_play_seconds": real_play_seconds,
		"year_count": year_count,
	}


func apply_save_data(data: Dictionary) -> void:
	season = String(data.get("season", DEFAULT_SEASON))
	solar_term_index = max(int(data.get("solar_term", 0)), 0)
	day_in_term = max(int(data.get("day_in_term", 0)), 0)
	shi_chen = clampi(int(data.get("shi_chen", 3)), 0, _get_shi_chen_names().size() - 1)
	ke = clampi(int(data.get("ke", 0)), 0, _get_ke_names().size() - 1)
	real_play_seconds = max(float(data.get("real_play_seconds", 0.0)), 0.0)
	year_count = max(int(data.get("year_count", 0)), 0)
	_ke_elapsed_seconds = 0.0
	_refresh_runtime_configs()
	_emit_current_time_state()


func _advance_day_state() -> void:
	day_in_term += 1
	var did_change_solar_term: bool = false

	if day_in_term >= _get_days_per_solar_term():
		day_in_term = 0
		solar_term_index += 1
		did_change_solar_term = true

		if solar_term_index >= _get_solar_terms_per_season():
			solar_term_index = 0
			_switch_to_next_season()

	if did_change_solar_term:
		emit_signal("solar_term_changed", solar_term_index)


func _switch_to_next_season() -> void:
	var seasons_order: PackedStringArray = _get_seasons_order()
	if seasons_order.is_empty():
		season = DEFAULT_SEASON
		_refresh_runtime_configs()
		emit_signal("season_changed", season, year_count)
		return

	var old_season: String = season
	var current_index: int = seasons_order.find(season)
	if current_index == -1:
		current_index = -1

	var next_index: int = wrapi(current_index + 1, 0, seasons_order.size())
	var did_wrap_year: bool = next_index == 0 and seasons_order.size() > 1
	season = String(seasons_order[next_index])
	if did_wrap_year:
		year_count += 1
	_refresh_runtime_configs()
	_publish_season_changed(old_season, season)
	emit_signal("season_changed", season, year_count)


func _check_daily_growth_trigger() -> void:
	if shi_chen == _get_day_start_shi_chen() and ke == 0:
		trigger_crop_growth()


func _emit_current_time_state() -> void:
	_refresh_runtime_configs()
	emit_signal("season_changed", season, year_count)
	emit_signal("solar_term_changed", solar_term_index)
	emit_signal("day_changed", day_in_term)
	emit_signal("time_changed", shi_chen, ke)


func _publish_day_started() -> void:
	if event_manager == null:
		event_manager = get_node_or_null("/root/EventManager")
	if event_manager == null or not event_manager.has_method("publish"):
		return

	event_manager.call("publish", "day_started", {
		"season": season,
		"year_count": year_count,
		"solar_term": _get_solar_term_id(season, solar_term_index),
		"day_in_term": day_in_term,
	})


func _publish_season_changed(old_season: String, new_season: String) -> void:
	if event_manager == null:
		event_manager = get_node_or_null("/root/EventManager")
	if event_manager == null or not event_manager.has_method("publish"):
		return

	event_manager.call("publish", "season_changed", {
		"old_season": old_season,
		"new_season": new_season,
		"year_count": year_count,
		"solar_term": _get_solar_term_id(new_season, solar_term_index),
		"day_in_term": day_in_term,
	})


func _restore_player_stamina() -> void:
	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null or not game_manager.has_method("restore_stamina"):
		return

	game_manager.call("restore_stamina")


func _refresh_runtime_configs() -> void:
	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	current_season_config = _resolve_season_config(season)


func _resolve_season_config(season_id: String) -> SeasonConfig:
	if config_manager != null:
		var config: SeasonConfig = config_manager.get_season_config(season_id)
		if config != null:
			return config
	return null


func _get_time_system_config() -> TimeSystemConfig:
	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager != null:
		var config: TimeSystemConfig = config_manager.get_time_config()
		if config != null:
			return config
	return null


func _get_ke_duration_seconds() -> float:
	var runtime_config: TimeSystemConfig = _get_time_system_config()
	if runtime_config != null:
		return runtime_config.ke_duration_seconds
	if time_config != null:
		return time_config.ke_duration_seconds
	return 30.0


func _get_days_per_solar_term() -> int:
	var runtime_config: TimeSystemConfig = _get_time_system_config()
	if runtime_config != null:
		return max(runtime_config.days_per_solar_term, 1)
	if time_config != null:
		return max(time_config.days_per_solar_term, 1)
	return 7


func _get_solar_terms_per_season() -> int:
	if current_season_config != null and not current_season_config.solar_terms.is_empty():
		return current_season_config.solar_terms.size()

	var runtime_config: TimeSystemConfig = _get_time_system_config()
	if runtime_config != null:
		return max(runtime_config.solar_terms_per_season, 1)
	if time_config != null:
		return max(time_config.solar_terms_per_season, 1)
	return 6


func _get_day_start_shi_chen() -> int:
	var runtime_config: TimeSystemConfig = _get_time_system_config()
	if runtime_config != null:
		return clampi(runtime_config.day_start_shi_chen, 0, _get_shi_chen_names().size() - 1)
	if time_config != null:
		return clampi(time_config.day_start_shi_chen, 0, _get_shi_chen_names().size() - 1)
	return 3


func _get_seasons_order() -> PackedStringArray:
	var runtime_config: TimeSystemConfig = _get_time_system_config()
	if runtime_config != null and not runtime_config.seasons_order.is_empty():
		return runtime_config.seasons_order
	if time_config != null and not time_config.seasons.is_empty():
		return time_config.seasons
	return PackedStringArray([DEFAULT_SEASON, "summer", "autumn", "winter"])


func _get_shi_chen_names() -> PackedStringArray:
	var runtime_config: TimeSystemConfig = _get_time_system_config()
	if runtime_config != null and not runtime_config.shi_chen_names.is_empty():
		return runtime_config.shi_chen_names
	return DEFAULT_SHI_CHEN_NAMES


func _get_ke_names() -> PackedStringArray:
	var runtime_config: TimeSystemConfig = _get_time_system_config()
	if runtime_config != null and not runtime_config.ke_names.is_empty():
		return runtime_config.ke_names
	return DEFAULT_KE_NAMES


func _get_season_display_name(season_id: String) -> String:
	var season_config: SeasonConfig = _resolve_season_config(season_id)
	if season_config != null and season_config.display_name != "":
		return season_config.display_name
	return String(FALLBACK_SEASON_DISPLAY_NAMES.get(season_id, season_id))


func _get_solar_term_name(season_id: String, term_index: int) -> String:
	var season_config: SeasonConfig = _resolve_season_config(season_id)
	if season_config != null and not season_config.solar_terms.is_empty():
		return season_config.solar_terms[term_index % season_config.solar_terms.size()]

	var raw_terms: Variant = FALLBACK_SOLAR_TERMS_BY_SEASON.get(season_id, [])
	var season_terms: Array = raw_terms if raw_terms is Array else []
	if not season_terms.is_empty():
		return String(season_terms[term_index % season_terms.size()])
	return "未知节气"


func _get_solar_term_id(season_id: String, term_index: int) -> String:
	return _get_solar_term_name(season_id, term_index)
