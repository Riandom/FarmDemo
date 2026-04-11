extends Node

const _DEFAULT_SEASON_ID: String = "spring"

@export var crops_dir: String = "res://resources/data/crops"
@export var items_dir: String = "res://resources/data/items"
@export var tools_dir: String = "res://resources/data/tools"
@export var seasons_dir: String = "res://resources/data/seasons"
@export var time_system_config_path: String = "res://resources/data/time_system_config.tres"

var _crop_map: Dictionary = {}
var _item_map: Dictionary = {}
var _tool_map: Dictionary = {}
var _season_map: Dictionary = {}
var _time_config: TimeSystemConfig = null

@onready var time_manager = get_node_or_null("/root/TimeManager")


func _ready() -> void:
	preload_all_configs()


func preload_all_configs() -> void:
	_crop_map.clear()
	_item_map.clear()
	_tool_map.clear()
	_season_map.clear()
	_time_config = null

	_load_crop_configs()
	_load_item_configs()
	_load_tool_configs()
	_load_season_configs()
	_load_time_system_config()


func get_crop_config(crop_id: String) -> CropConfig:
	var config: CropConfig = _crop_map.get(crop_id) as CropConfig
	if config != null:
		return config
	push_warning("[ConfigManager] Crop config not found: %s" % crop_id)
	return null


func get_all_crops() -> Array[CropConfig]:
	var result: Array[CropConfig] = []
	for value in _crop_map.values():
		if value is CropConfig:
			result.append(value)
	return result


func get_crop_config_by_seed_item(seed_item_id: String) -> CropConfig:
	for value in _crop_map.values():
		var config: CropConfig = value as CropConfig
		if config != null and config.seed_item_id == seed_item_id:
			return config
	return null


func get_crop_config_by_harvest_item(harvest_item_id: String) -> CropConfig:
	for value in _crop_map.values():
		var config: CropConfig = value as CropConfig
		if config != null and config.harvest_item_id == harvest_item_id:
			return config
	return null


func get_item_config(item_id: String) -> ItemConfig:
	var config: ItemConfig = _item_map.get(item_id) as ItemConfig
	if config != null:
		return config
	return null


func get_all_items() -> Array[ItemConfig]:
	var result: Array[ItemConfig] = []
	for value in _item_map.values():
		if value is ItemConfig:
			result.append(value)
	return result


func get_item_display_name(item_id: String) -> String:
	if _tool_map.has(item_id):
		var tool_config: ToolConfig = _tool_map.get(item_id) as ToolConfig
		if tool_config != null and tool_config.display_name != "":
			return tool_config.display_name

	var seed_crop: CropConfig = get_crop_config_by_seed_item(item_id)
	if seed_crop != null:
		return "%s种子" % seed_crop.display_name

	var harvest_crop: CropConfig = get_crop_config_by_harvest_item(item_id)
	if harvest_crop != null and harvest_crop.display_name != "":
		return harvest_crop.display_name

	var item_config: ItemConfig = get_item_config(item_id)
	if item_config != null and item_config.display_name != "":
		return item_config.display_name

	return item_id


func get_item_category(item_id: String) -> String:
	if item_id == "":
		return "other"

	if _tool_map.has(item_id):
		return "tool"

	if get_crop_config_by_seed_item(item_id) != null:
		return "seed"

	if get_crop_config_by_harvest_item(item_id) != null:
		return "crop"

	var item_config: ItemConfig = get_item_config(item_id)
	if item_config != null and item_config.category != "":
		return item_config.category

	return "other"


func get_tool_config(tool_id: String) -> ToolConfig:
	var config: ToolConfig = _tool_map.get(tool_id) as ToolConfig
	if config != null:
		return config
	push_warning("[ConfigManager] Tool config not found: %s" % tool_id)
	return null


func get_all_tools() -> Array[ToolConfig]:
	var result: Array[ToolConfig] = []
	for value in _tool_map.values():
		if value is ToolConfig:
			result.append(value)
	return result


func get_season_config(season_id: String) -> SeasonConfig:
	var config: SeasonConfig = _season_map.get(season_id) as SeasonConfig
	if config != null:
		return config
	push_warning("[ConfigManager] Season config not found: %s" % season_id)
	return null


func get_all_seasons() -> Array[SeasonConfig]:
	var result: Array[SeasonConfig] = []
	for value in _season_map.values():
		if value is SeasonConfig:
			result.append(value)
	return result


func get_current_season_config() -> SeasonConfig:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")

	var current_season_id: String = _DEFAULT_SEASON_ID
	if time_manager != null:
		current_season_id = String(time_manager.get("season"))
		if current_season_id == "":
			current_season_id = _DEFAULT_SEASON_ID

	var config: SeasonConfig = get_season_config(current_season_id)
	if config != null:
		return config
	return _season_map.get(_DEFAULT_SEASON_ID) as SeasonConfig


func get_current_season() -> SeasonConfig:
	return get_current_season_config()


func get_time_config() -> TimeSystemConfig:
	if _time_config == null:
		_load_time_system_config()
	return _time_config


func sync_configs_from_server(_server_url: String) -> bool:
	push_warning("[ConfigManager] Remote config sync is reserved for future versions")
	return false


func update_crop_config(crop_id: String, new_data: Dictionary) -> void:
	var crop_config: CropConfig = _crop_map.get(crop_id) as CropConfig
	if crop_config == null:
		push_warning("[ConfigManager] Cannot update missing crop config: %s" % crop_id)
		return

	for key in new_data.keys():
		crop_config.set(String(key), new_data[key])


func _load_crop_configs() -> void:
	for path in _list_tres_files(crops_dir):
		var resource: Resource = load(path)
		if resource is CropConfig and _validate_crop_config(resource):
			_crop_map[resource.crop_id] = resource


func _load_item_configs() -> void:
	for path in _list_tres_files(items_dir):
		var resource: Resource = load(path)
		if resource is ItemConfig and _validate_item_config(resource):
			_item_map[resource.item_id] = resource


func _load_tool_configs() -> void:
	for path in _list_tres_files(tools_dir):
		var resource: Resource = load(path)
		if resource is ToolConfig and _validate_tool_config(resource):
			_tool_map[resource.tool_id] = resource


func _load_season_configs() -> void:
	for path in _list_tres_files(seasons_dir):
		var resource: Resource = load(path)
		if resource is SeasonConfig and _validate_season_config(resource):
			_season_map[resource.season_id] = resource


func _load_time_system_config() -> void:
	if not ResourceLoader.exists(time_system_config_path):
		push_warning("[ConfigManager] Time system config missing: %s" % time_system_config_path)
		return

	var resource: Resource = load(time_system_config_path)
	if resource is TimeSystemConfig:
		_time_config = resource
	else:
		push_warning("[ConfigManager] Invalid time system config: %s" % time_system_config_path)


func _list_tres_files(dir_path: String) -> PackedStringArray:
	var file_paths: PackedStringArray = PackedStringArray()
	var file_names: PackedStringArray = DirAccess.get_files_at(dir_path)
	for file_name in file_names:
		if file_name.ends_with(".tres"):
			file_paths.append("%s/%s" % [dir_path, file_name])
	return file_paths


func _validate_crop_config(config: CropConfig) -> bool:
	if config.crop_id == "":
		push_warning("[ConfigManager] Ignored crop config with empty crop_id")
		return false
	if config.seed_item_id == "":
		push_warning("[ConfigManager] Ignored crop config with empty seed_item_id: %s" % config.crop_id)
		return false
	if config.harvest_item_id == "":
		push_warning("[ConfigManager] Ignored crop config with empty harvest_item_id: %s" % config.crop_id)
		return false
	return true


func _validate_item_config(config: ItemConfig) -> bool:
	if config.item_id == "":
		push_warning("[ConfigManager] Ignored item config with empty item_id")
		return false
	return true


func _validate_tool_config(config: ToolConfig) -> bool:
	if config.tool_id == "":
		push_warning("[ConfigManager] Ignored tool config with empty tool_id")
		return false
	return true


func _validate_season_config(config: SeasonConfig) -> bool:
	if config.season_id == "":
		push_warning("[ConfigManager] Ignored season config with empty season_id")
		return false
	if config.solar_terms.is_empty():
		push_warning("[ConfigManager] Ignored season config with no solar terms: %s" % config.season_id)
		return false
	return true
