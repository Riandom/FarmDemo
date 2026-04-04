extends Node

var _tool_registry: Dictionary = {}

@onready var config_manager = get_node_or_null("/root/ConfigManager")


func _ready() -> void:
	"""初始化默认工具配置，让交互系统具备最小可运行能力。"""
	_load_default_tool_configs()


func register_tool_config(tool_config: ToolConfig) -> void:
	"""注册工具配置，供 on_tool_use 进行能力验证。"""
	if tool_config == null or tool_config.tool_id == "":
		return
	_tool_registry[tool_config.tool_id] = tool_config


func get_tool_config(tool_id: String) -> ToolConfig:
	"""根据工具 ID 获取对应配置。"""
	var tool_config: ToolConfig = _tool_registry.get(tool_id) as ToolConfig
	if tool_config != null:
		return tool_config
	return null


func on_tool_use(tool_id: String, plot: Plot, action_context: Dictionary = {}) -> Dictionary:
	"""处理工具对地块的使用请求，并返回统一 ActionResult。"""
	if plot == null:
		return _build_failed_result("目标地块不存在")

	var normalized_context: Dictionary = _normalize_action_context(tool_id, action_context)
	var action_id: String = String(normalized_context.get("action_id", ""))

	if action_id == "":
		return _build_failed_result("动作请求缺少 action_id")

	var tool_config: ToolConfig = get_tool_config(tool_id)
	if tool_config == null:
		return _build_failed_result("未找到工具配置：%s" % tool_id)

	if not tool_config.allowed_actions.has(action_id):
		return _build_failed_result("%s 无法执行 %s" % [tool_config.display_name, action_id])

	if not plot.can_perform_action(action_id, normalized_context):
		return _build_failed_result(plot.get_action_denied_message(action_id))

	return plot.execute_action(action_id, normalized_context)


func _normalize_action_context(tool_id: String, action_context: Dictionary) -> Dictionary:
	"""补齐文档约定的 ActionContext 结构。"""
	var context: Dictionary = {
		"action_id": action_context.get("action_id", ""),
		"tool_id": tool_id,
		"source": action_context.get("source", "player"),
		"parameters": action_context.get("parameters", {}),
		"timestamp": action_context.get("timestamp", Time.get_unix_time_from_system()),
		"crop_config_id": action_context.get("crop_config_id", "crop_wheat"),
	}
	return context


func _build_failed_result(message: String) -> Dictionary:
	"""生成失败态 ActionResult。"""
	return {
		"success": false,
		"message": message,
		"consumed_items": {},
		"created_items": {},
		"experience_gained": 0,
		"quality_factor": 1.0,
		"side_effects": [],
	}


func _load_default_tool_configs() -> void:
	"""加载本模块约定的默认工具配置资源。"""
	_tool_registry.clear()

	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")

	if config_manager != null:
		for tool_config in config_manager.get_all_tools():
			register_tool_config(tool_config)

	if not _tool_registry.is_empty():
		_register_seed_item_config()
		return

	var paths: PackedStringArray = [
		"res://resources/config/tools/hoe_wood.tres",
		"res://resources/config/tools/watering_can_wood.tres",
		"res://resources/config/tools/sickle_wood.tres",
	]

	for path in paths:
		if not ResourceLoader.exists(path):
			continue

		var resource := load(path)
		if resource is ToolConfig:
			register_tool_config(resource)

	_register_seed_item_config()


func _register_seed_item_config() -> void:
	"""为种子提供最小交互能力配置，避免额外引入 SeedConfig 系统。"""
	if _tool_registry.has("seed_wheat"):
		return

	var seed_config := ToolConfig.new()
	seed_config.tool_id = "seed_wheat"
	seed_config.display_name = "小麦种子"
	seed_config.allowed_actions = ["seed"]
	seed_config.energy_cost = 0
	seed_config.icon_path = "res://assets/sprites/placeholder/items/seed_wheat.png"
	register_tool_config(seed_config)
