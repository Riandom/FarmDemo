extends Area2D
class_name Plot

## 地块状态变更时发射，供逻辑和 UI 监听
signal state_changed(old_state: String, new_state: String)

## 地块需要刷新视觉表现时发射，供渲染系统监听
signal visual_update_requested(plot: Plot)

## 作物被收获时发射
signal crop_harvested(plot: Plot)

const STATE_WASTE: String = "waste"
const STATE_PLOWED: String = "plowed"
const STATE_SEEDED: String = "seeded"
const STATE_WATERED: String = "watered"
const STATE_MATURE: String = "mature"

const VALID_STATES: PackedStringArray = [
	STATE_WASTE,
	STATE_PLOWED,
	STATE_SEEDED,
	STATE_WATERED,
	STATE_MATURE,
]

## 网格坐标 [列, 行]
@export var grid_position: Vector2i = Vector2i.ZERO

## 地块类型标识，便于未来扩展不同土壤或功能地块
@export var plot_type: String = "crop_plot"

## 当前基础状态，严格遵循文档中的 5 状态循环
@export_enum("waste", "plowed", "seeded", "watered", "mature")
var base_state: String = STATE_WASTE

## 生长阶段，Demo 范围为 0~3
@export var growth_stage: int = 0

## 当前阶段的进度，范围 0.0~1.0
@export_range(0.0, 1.0, 0.01) var growth_progress: float = 0.0

## 当前地块绑定的作物配置 ID，Demo 默认用小麦
@export var crop_config_id: String = "crop_wheat"

## 以下字段为未来扩展预留，本次仅保留数据结构，不实现效果逻辑
@export var buffs: Array = []
@export var debuffs: Array = []
@export var environment: Dictionary = {}
@export var metadata: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D
@onready var grow_timer: Timer = $GrowTimer
@onready var farm_manager = get_node_or_null("/root/FarmManager")


func _ready() -> void:
	"""初始化地块基础逻辑并注册到 FarmManager。"""
	_validate_state()
	_setup_grow_timer()
	_connect_internal_signals()
	_register_to_farm_manager()
	request_visual_refresh()


func _exit_tree() -> void:
	"""节点离开场景树时从 FarmManager 注销，避免悬挂引用。"""
	if farm_manager != null:
		farm_manager.unregister_plot(self)


func _validate_state() -> void:
	"""确保编辑器里配置的状态值合法，非法时回退到 waste。"""
	if not VALID_STATES.has(base_state):
		base_state = STATE_WASTE


func _setup_grow_timer() -> void:
	"""配置生长计时器，满足文档要求的 5 秒/阶段、重复触发、手动启动。"""
	var crop_config: CropConfig = _load_crop_config()
	grow_timer.wait_time = crop_config.stage_base_duration if crop_config != null else 5.0
	grow_timer.one_shot = false
	grow_timer.autostart = false


func _connect_internal_signals() -> void:
	"""连接地块内部需要的信号。"""
	if not grow_timer.timeout.is_connected(_on_grow_timer_timeout):
		grow_timer.timeout.connect(_on_grow_timer_timeout)


func _register_to_farm_manager() -> void:
	"""将当前地块注册到集中管理器。"""
	if farm_manager == null:
		farm_manager = get_node_or_null("/root/FarmManager")
	if farm_manager != null:
		farm_manager.register_plot(self)


func can_perform_action(action_id: String, action_context: Dictionary = {}) -> bool:
	"""验证当前状态是否允许执行指定动作。"""
	match action_id:
		"plow":
			return base_state == STATE_WASTE or base_state == STATE_PLOWED
		"seed":
			return base_state == STATE_PLOWED
		"water":
			return base_state == STATE_SEEDED or base_state == STATE_WATERED
		"harvest":
			return base_state == STATE_MATURE
		_:
			return false


func get_action_denied_message(action_id: String) -> String:
	"""返回动作被拒绝时的玩家提示文本。"""
	return _build_invalid_action_message(action_id)


func execute_action(action_id: String, action_context: Dictionary = {}) -> Dictionary:
	"""执行动作并返回统一的 ActionResult 字典。"""
	if not can_perform_action(action_id, action_context):
		return _build_action_result(false, _build_invalid_action_message(action_id))

	match action_id:
		"plow":
			return _execute_plow()
		"seed":
			return _execute_seed(action_context)
		"water":
			return _execute_water()
		"harvest":
			return _execute_harvest()
		_:
			return _build_action_result(false, "未知动作：%s" % action_id)


func request_visual_refresh() -> void:
	"""通知渲染系统刷新该地块表现。"""
	emit_signal("visual_update_requested", self)


func get_interaction_hint(current_tool_id: String = "") -> String:
	"""根据当前状态和手持项返回给玩家的交互提示。"""
	match base_state:
		STATE_WASTE:
			if current_tool_id == "" or current_tool_id == "hoe_wood":
				return "按 E 开垦"
			return "切换到木锄头开垦"
		STATE_PLOWED:
			if current_tool_id == "" or current_tool_id == "seed_wheat":
				return "按 E 播种"
			return "切换到小麦种子播种"
		STATE_SEEDED:
			if current_tool_id == "" or current_tool_id == "watering_can_wood":
				return "按 E 浇水"
			return "切换到木水壶浇水"
		STATE_WATERED:
			return "生长中..."
		STATE_MATURE:
			if current_tool_id == "" or current_tool_id == "sickle_wood":
				return "按 E 收获"
			return "切换到木镰刀收获"
		_:
			return ""


func get_state_label() -> String:
	"""返回便于日志和 UI 展示的人类可读状态名称。"""
	match base_state:
		STATE_WASTE:
			return "荒地"
		STATE_PLOWED:
			return "已开垦"
		STATE_SEEDED:
			return "已播种"
		STATE_WATERED:
			return "已浇水"
		STATE_MATURE:
			return "已成熟"
		_:
			return "未知"


func _execute_plow() -> Dictionary:
	"""执行开垦：荒地进入已开垦状态。"""
	if base_state == STATE_PLOWED:
		return _build_action_result(true, "地块已经开垦完成")

	_transition_to_state(STATE_PLOWED)
	return _build_action_result(true, "地块已开垦")


func _execute_seed(action_context: Dictionary) -> Dictionary:
	"""执行播种：进入已播种状态并重置生长进度。"""
	var crop_id_from_context: String = String(action_context.get("crop_config_id", crop_config_id))
	if crop_id_from_context != "":
		crop_config_id = crop_id_from_context

	growth_stage = 0
	growth_progress = 0.0
	_transition_to_state(STATE_SEEDED)
	return _build_action_result(
		true,
		"已播种",
		{"seed_wheat": 1},
		{}
	)


func _execute_water() -> Dictionary:
	"""执行浇水：首次浇水进入 watered 并启动生长，重复浇水只刷新进度。"""
	if base_state == STATE_SEEDED:
		_transition_to_state(STATE_WATERED)
		_start_growing()
		return _build_action_result(true, "已浇水，开始生长")

	# 文档允许 seeded 和 watered 状态都可执行 water，这里对重复浇水做幂等处理。
	return _build_action_result(true, "地块已保持湿润")


func _execute_harvest() -> Dictionary:
	"""执行收获：产出作物并回到 plowed，保留下一轮耕作状态。"""
	var yield_amount: int = _get_crop_yield()
	_stop_growing()
	growth_stage = 0
	growth_progress = 0.0
	_transition_to_state(STATE_PLOWED)
	emit_signal("crop_harvested", self)
	return _build_action_result(
		true,
		"收获完成",
		{},
		{"crop_wheat": yield_amount}
	)


func _start_growing() -> void:
	"""启动生长计时器，仅在进入 watered 后调用。"""
	if grow_timer.is_stopped():
		grow_timer.start()


func _stop_growing() -> void:
	"""停止生长计时器。"""
	if not grow_timer.is_stopped():
		grow_timer.stop()


func _on_grow_timer_timeout() -> void:
	"""按固定节拍推进生长阶段，并在成熟时切换状态。"""
	if base_state != STATE_WATERED:
		return

	growth_stage += 1
	var total_stages: int = _get_growth_stage_count()

	if total_stages <= 0:
		total_stages = 3

	growth_progress = clamp(float(growth_stage) / float(total_stages), 0.0, 1.0)

	if growth_stage >= total_stages:
		_stop_growing()
		_transition_to_state(STATE_MATURE)
		return

	request_visual_refresh()


func _transition_to_state(new_state: String) -> void:
	"""统一处理状态切换，保证信号和视觉刷新顺序稳定。"""
	var old_state: String = base_state
	base_state = new_state
	emit_signal("state_changed", old_state, new_state)
	request_visual_refresh()


func _build_invalid_action_message(action_id: String) -> String:
	"""为错误动作生成更准确的玩家提示文本。"""
	match action_id:
		"plow":
			return "当前状态无法开垦"
		"seed":
			if base_state == STATE_WASTE:
				return "这块地还没开垦，无法播种"
			return "当前状态无法播种"
		"water":
			return "当前状态无法浇水"
		"harvest":
			return "作物尚未成熟，无法收获"
		_:
			return "当前状态无法执行该动作"


func _build_action_result(
	success: bool,
	message: String,
	consumed_items: Dictionary = {},
	created_items: Dictionary = {}
) -> Dictionary:
	"""构造统一的 ActionResult 返回结构，未实现字段保留默认值。"""
	return {
		"success": success,
		"message": message,
		"consumed_items": consumed_items,
		"created_items": created_items,
		"experience_gained": 0,
		"quality_factor": 1.0,
		"side_effects": [],
	}


func _get_growth_stage_count() -> int:
	"""读取作物配置中的阶段数；配置缺失时回退到 Demo 默认值。"""
	var crop_config: CropConfig = _load_crop_config()
	if crop_config != null:
		return crop_config.growth_stages
	return 3


func _get_crop_yield() -> int:
	"""读取作物配置中的基础产量；配置缺失时回退到 Demo 默认值。"""
	var crop_config: CropConfig = _load_crop_config()
	if crop_config != null:
		return crop_config.yield_base
	return 3


func _load_crop_config() -> CropConfig:
	"""从约定目录加载作物配置资源。"""
	var candidate_paths: PackedStringArray = [
		"res://resources/config/crops/wheat_config.tres",
	]

	for path in candidate_paths:
		if ResourceLoader.exists(path):
			var resource := load(path)
			if resource is CropConfig and resource.crop_id == crop_config_id:
				return resource

	return null
