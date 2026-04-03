extends Node

signal time_changed(shi_chen: int, ke: int)
signal day_changed(day_in_term: int)
signal solar_term_changed(solar_term_index: int)
signal crop_growth_triggered(plot_count: int)

const DEFAULT_SEASON: String = "spring"
const SHI_CHEN_NAMES: Array[String] = [
	"子时", "丑时", "寅时", "卯时", "辰时", "巳时",
	"午时", "未时", "申时", "酉时", "戌时", "亥时",
]
const KE_NAMES: Array[String] = ["初刻", "二刻", "三刻", "四刻"]
const SEASON_DISPLAY_NAMES: Dictionary = {
	"spring": "春季",
	"summer": "夏季",
	"autumn": "秋季",
	"winter": "冬季",
}
const SOLAR_TERMS_BY_SEASON: Dictionary = {
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

var _ke_elapsed_seconds: float = 0.0
var _time_paused: bool = false

@onready var farm_manager = get_node_or_null("/root/FarmManager")


func _ready() -> void:
	if time_config == null:
		time_config = load("res://resources/config/time_config.tres") as TimeConfig

	call_deferred("_emit_current_time_state")


func _process(delta: float) -> void:
	if _time_paused or time_config == null:
		return

	real_play_seconds += delta
	_ke_elapsed_seconds += delta

	var ke_duration: float = max(time_config.ke_duration_seconds, 0.1)
	while _ke_elapsed_seconds >= ke_duration:
		_ke_elapsed_seconds -= ke_duration
		advance_ke()


func set_time_paused(is_paused: bool) -> void:
	_time_paused = is_paused


func is_time_paused() -> bool:
	return _time_paused


func advance_ke() -> void:
	ke += 1
	if ke >= 4:
		ke = 0
		advance_shi_chen()
		return

	emit_signal("time_changed", shi_chen, ke)


func advance_shi_chen() -> void:
	shi_chen += 1
	if shi_chen >= 12:
		shi_chen = 0
		advance_day()
	else:
		emit_signal("time_changed", shi_chen, ke)
		_check_daily_growth_trigger()


func advance_day() -> void:
	day_in_term += 1
	var did_change_solar_term: bool = false

	if time_config != null and day_in_term >= time_config.days_per_solar_term:
		day_in_term = 0
		solar_term_index += 1
		did_change_solar_term = true

		var max_terms: int = max(time_config.solar_terms_per_season, 1)
		if solar_term_index >= max_terms:
			solar_term_index = 0

	if did_change_solar_term:
		emit_signal("solar_term_changed", solar_term_index)

	emit_signal("day_changed", day_in_term)
	emit_signal("time_changed", shi_chen, ke)
	_check_daily_growth_trigger()


func skip_to_next_day_mao_hour() -> void:
	var target_shi_chen: int = 3
	if time_config != null:
		target_shi_chen = time_config.day_start_shi_chen

	day_in_term += 1
	var did_change_solar_term: bool = false
	if time_config != null and day_in_term >= time_config.days_per_solar_term:
		day_in_term = 0
		solar_term_index += 1
		did_change_solar_term = true

		var max_terms: int = max(time_config.solar_terms_per_season, 1)
		if solar_term_index >= max_terms:
			solar_term_index = 0

	shi_chen = target_shi_chen
	ke = 0
	_ke_elapsed_seconds = 0.0

	if did_change_solar_term:
		emit_signal("solar_term_changed", solar_term_index)

	emit_signal("day_changed", day_in_term)
	emit_signal("time_changed", shi_chen, ke)
	_check_daily_growth_trigger()


func trigger_crop_growth() -> void:
	if farm_manager == null:
		farm_manager = get_node_or_null("/root/FarmManager")
	if farm_manager == null:
		emit_signal("crop_growth_triggered", 0)
		return

	var advanced_count: int = 0
	for plot in farm_manager.get_all_plots():
		if plot != null and is_instance_valid(plot) and plot.has_method("advance_growth_by_day"):
			if bool(plot.call("advance_growth_by_day")):
				advanced_count += 1

	emit_signal("crop_growth_triggered", advanced_count)


func get_time_display_string() -> String:
	return "%s\n%s" % [format_date_line(), format_clock_line()]


func format_date_line(data: Dictionary = {}) -> String:
	var snapshot: Dictionary = data if not data.is_empty() else export_save_data()
	var snapshot_season: String = String(snapshot.get("season", DEFAULT_SEASON))
	var snapshot_solar_term: int = int(snapshot.get("solar_term", solar_term_index))
	var snapshot_day: int = int(snapshot.get("day_in_term", day_in_term))
	return "%s·%s 第 %d 天" % [
		SEASON_DISPLAY_NAMES.get(snapshot_season, snapshot_season),
		_get_solar_term_name(snapshot_season, snapshot_solar_term),
		snapshot_day + 1,
	]


func format_clock_line(data: Dictionary = {}) -> String:
	var snapshot: Dictionary = data if not data.is_empty() else export_save_data()
	var snapshot_shi_chen: int = int(snapshot.get("shi_chen", shi_chen))
	var snapshot_ke: int = int(snapshot.get("ke", ke))
	return "%s%s" % [
		SHI_CHEN_NAMES[snapshot_shi_chen % SHI_CHEN_NAMES.size()],
		KE_NAMES[snapshot_ke % KE_NAMES.size()],
	]


func export_save_data() -> Dictionary:
	return {
		"season": season,
		"solar_term": solar_term_index,
		"day_in_term": day_in_term,
		"shi_chen": shi_chen,
		"ke": ke,
		"real_play_seconds": real_play_seconds,
	}


func apply_save_data(data: Dictionary) -> void:
	season = String(data.get("season", DEFAULT_SEASON))
	solar_term_index = max(int(data.get("solar_term", 0)), 0)
	day_in_term = max(int(data.get("day_in_term", 0)), 0)
	shi_chen = clampi(int(data.get("shi_chen", 3)), 0, 11)
	ke = clampi(int(data.get("ke", 0)), 0, 3)
	real_play_seconds = max(float(data.get("real_play_seconds", 0.0)), 0.0)
	_ke_elapsed_seconds = 0.0
	_emit_current_time_state()


func _check_daily_growth_trigger() -> void:
	var target_shi_chen: int = 3
	if time_config != null:
		target_shi_chen = time_config.day_start_shi_chen

	if shi_chen == target_shi_chen and ke == 0:
		trigger_crop_growth()


func _emit_current_time_state() -> void:
	emit_signal("time_changed", shi_chen, ke)
	emit_signal("day_changed", day_in_term)


func _get_solar_term_name(snapshot_season: String, snapshot_solar_term: int) -> String:
	var raw_terms = SOLAR_TERMS_BY_SEASON.get(snapshot_season, [])
	var season_terms: Array = raw_terms if raw_terms is Array else []
	if season_terms.size() > 0:
		return season_terms[snapshot_solar_term % season_terms.size()]
	return "未知节气"
