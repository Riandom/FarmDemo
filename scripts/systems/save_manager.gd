extends Node

signal save_started(save_type: String, slot_index: int)
signal save_completed(success: bool, file_path: String)
signal load_started(save_type: String, slot_index: int)
signal load_completed(success: bool, error_message: String)

const SAVE_VERSION: String = "0.3.0"
const SAVE_DIR: String = "user://"
const AUTO_SAVE_FILE: String = "user://save_auto.json"
const MANUAL_SAVE_FILES: PackedStringArray = [
	"user://save_01.json",
	"user://save_02.json",
	"user://save_03.json",
	"user://save_04.json",
	"user://save_05.json",
]

@onready var game_manager = get_node_or_null("/root/GameManager")
@onready var time_manager = get_node_or_null("/root/TimeManager")
@onready var farm_manager = get_node_or_null("/root/FarmManager")


func save_game_auto() -> void:
	emit_signal("save_started", "auto", -1)
	_save_to_path(AUTO_SAVE_FILE, "auto", -1)


func save_game_manual(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MANUAL_SAVE_FILES.size():
		emit_signal("save_completed", false, "")
		return

	emit_signal("save_started", "manual", slot_index)
	_save_to_path(MANUAL_SAVE_FILES[slot_index], "manual", slot_index)


func load_game_auto() -> void:
	emit_signal("load_started", "auto", -1)
	_load_from_path(AUTO_SAVE_FILE)


func load_game_manual(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= MANUAL_SAVE_FILES.size():
		emit_signal("load_completed", false, "无效的存档槽位")
		return

	emit_signal("load_started", "manual", slot_index)
	_load_from_path(MANUAL_SAVE_FILES[slot_index])


func get_save_file_info(file_path: String) -> Dictionary:
	var base_info: Dictionary = {
		"exists": false,
		"file_path": file_path,
		"label": "空",
		"version": "",
		"save_timestamp": "",
		"time": {},
	}

	if not FileAccess.file_exists(file_path):
		return base_info

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		base_info["label"] = "损坏"
		return base_info

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		base_info["label"] = "损坏"
		return base_info

	var save_data = json.data
	if not (save_data is Dictionary):
		base_info["label"] = "损坏"
		return base_info

	var game_state = save_data.get("game_state", {})
	var time_data = game_state.get("time", {}) if game_state is Dictionary else {}

	base_info["exists"] = true
	base_info["version"] = String(save_data.get("version", ""))
	base_info["save_timestamp"] = String(save_data.get("save_timestamp", ""))
	base_info["time"] = time_data
	base_info["label"] = _build_save_label(file_path, time_data)
	return base_info


func _save_to_path(file_path: String, _save_type: String, _slot_index: int) -> void:
	var save_data: Dictionary = _build_save_data()
	if save_data.is_empty():
		emit_signal("save_completed", false, file_path)
		return

	var json_string: String = JSON.stringify(save_data, "\t")
	var final_file_name: String = file_path.get_file()
	var temp_file_name: String = "%s.tmp" % final_file_name
	var temp_file_path: String = "%s%s" % [SAVE_DIR, temp_file_name]

	var temp_file := FileAccess.open(temp_file_path, FileAccess.WRITE)
	if temp_file == null:
		push_warning("[SaveManager] Failed to open temp save file: %s" % temp_file_path)
		emit_signal("save_completed", false, file_path)
		return

	temp_file.store_string(json_string)
	temp_file.close()

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		push_warning("[SaveManager] Failed to open save directory")
		emit_signal("save_completed", false, file_path)
		return

	if dir.file_exists(final_file_name):
		dir.remove(final_file_name)

	var rename_error: int = dir.rename(temp_file_name, final_file_name)
	if rename_error != OK:
		push_warning("[SaveManager] Failed to finalize save file: %s" % file_path)
		emit_signal("save_completed", false, file_path)
		return

	if game_manager != null:
		game_manager.emit_signal("game_saved", int(Time.get_unix_time_from_system()))

	emit_signal("save_completed", true, file_path)


func _load_from_path(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		emit_signal("load_completed", false, "存档不存在")
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		emit_signal("load_completed", false, "无法打开存档文件")
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		emit_signal("load_completed", false, "存档损坏，JSON 格式无效")
		return

	var save_data = json.data
	if not (save_data is Dictionary):
		emit_signal("load_completed", false, "存档结构无效")
		return

	var version: String = String(save_data.get("version", ""))
	if version == "":
		emit_signal("load_completed", false, "存档缺少版本信息")
		return
	if not version.begins_with("0.2") and not version.begins_with("0.3"):
		emit_signal("load_completed", false, "存档版本不兼容")
		return

	var game_state = save_data.get("game_state", {})
	if not (game_state is Dictionary):
		emit_signal("load_completed", false, "存档缺少 game_state")
		return

	var player_data = game_state.get("player", {})
	var time_data = game_state.get("time", {})
	var farm_data = game_state.get("farm", {})
	if not (player_data is Dictionary):
		emit_signal("load_completed", false, "存档缺少玩家数据")
		return
	if not (time_data is Dictionary):
		emit_signal("load_completed", false, "存档缺少时间数据")
		return
	if not (farm_data is Dictionary):
		emit_signal("load_completed", false, "存档缺少农场数据")
		return

	var plot_list = farm_data.get("plots", null)
	if not (plot_list is Array):
		emit_signal("load_completed", false, "存档缺少地块列表")
		return

	_apply_player_state(player_data)
	_apply_time_state(time_data)
	_apply_farm_state(farm_data)
	emit_signal("load_completed", true, "")


func _build_save_data() -> Dictionary:
	var player = _get_player_node()
	if player == null or game_manager == null or time_manager == null or farm_manager == null:
		push_warning("[SaveManager] Missing required runtime nodes for saving")
		return {}

	var player_data: Dictionary = game_manager.export_save_data()
	player_data["position_x"] = player.global_position.x
	player_data["position_y"] = player.global_position.y

	var farm_plots: Array[Dictionary] = []
	for plot in farm_manager.get_all_plots():
		if plot != null and is_instance_valid(plot) and plot.has_method("export_save_data"):
			farm_plots.append(plot.call("export_save_data"))

	return {
		"version": SAVE_VERSION,
		"save_timestamp": Time.get_datetime_string_from_system(),
		"game_state": {
			"player": player_data,
			"time": time_manager.export_save_data(),
			"farm": {
				"plots": farm_plots,
			},
		},
	}


func _apply_player_state(player_data: Variant) -> void:
	if not (player_data is Dictionary):
		return

	if game_manager != null:
		game_manager.apply_save_data(player_data)

	var player = _get_player_node()
	if player != null:
		player.global_position = Vector2(
			float(player_data.get("position_x", player.global_position.x)),
			float(player_data.get("position_y", player.global_position.y))
		)


func _apply_time_state(time_data: Variant) -> void:
	if time_manager == null or not (time_data is Dictionary):
		return

	time_manager.apply_save_data(time_data)


func _apply_farm_state(farm_data: Variant) -> void:
	if farm_manager == null:
		return

	var plots_by_key: Dictionary = {}
	for plot in farm_manager.get_all_plots():
		if plot == null or not is_instance_valid(plot):
			continue
		plots_by_key[_make_plot_key(plot.grid_position.x, plot.grid_position.y)] = plot
		if plot.has_method("apply_save_data"):
			plot.call("apply_save_data", {})

	if not (farm_data is Dictionary):
		return

	var plot_list = farm_data.get("plots", [])
	if not (plot_list is Array):
		return

	for plot_data in plot_list:
		if not (plot_data is Dictionary):
			continue

		var key: String = _make_plot_key(int(plot_data.get("grid_x", 0)), int(plot_data.get("grid_y", 0)))
		var plot = plots_by_key.get(key)
		if plot != null and is_instance_valid(plot) and plot.has_method("apply_save_data"):
			plot.call("apply_save_data", plot_data)


func _build_save_label(file_path: String, time_data: Variant) -> String:
	var prefix: String = "自动存档" if file_path == AUTO_SAVE_FILE else "存档 %d" % (MANUAL_SAVE_FILES.find(file_path) + 1)
	if not (time_data is Dictionary) or time_data.is_empty():
		return "%s - 空" % prefix

	var date_line := "时间未知"
	if time_manager != null:
		date_line = time_manager.format_date_line(time_data)

	var play_minutes: int = int(round(float(time_data.get("real_play_seconds", 0.0)) / 60.0))
	return "%s - %s (%d分钟)" % [prefix, date_line, play_minutes]


func _get_player_node() -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null
	var player = current_scene.get_node_or_null("Player")
	if player is Node2D:
		return player
	return null


func _make_plot_key(grid_x: int, grid_y: int) -> String:
	return "%d,%d" % [grid_x, grid_y]
