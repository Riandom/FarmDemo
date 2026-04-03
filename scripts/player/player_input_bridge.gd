extends Node
class_name PlayerInputBridge

## 交互距离（像素）
@export var interaction_range: float = 32.0

## 交互冷却（秒）
@export var interaction_cooldown: float = 0.3

## 当前锁定的目标地块
var current_target_plot: Plot = null
var current_target_interactable: Node = null

## 上次交互时间（秒）
var last_interaction_time: float = -1.0

## 未来自动朝向接口预留
@export var auto_face_target: bool = false

## 调试覆盖层接口预留
@export var show_debug_overlay: bool = false

@onready var player = get_parent()
@onready var interaction_detector: Area2D = null  # 延迟获取，避免节点未就绪
@onready var game_manager = get_node_or_null("/root/GameManager")
@onready var farm_manager = get_node_or_null("/root/FarmManager")
@onready var farm_interaction_system = get_node_or_null("/root/FarmInteractionSystem")


func _ready() -> void:
	"""从父玩家同步交互参数并获取 InteractionDetector 引用。"""
	if player != null:
		interaction_range = float(player.get("interaction_range"))
		interaction_cooldown = float(player.get("interact_cooldown"))
	
	# 安全获取兄弟节点 InteractionDetector
	if player != null and player.has_node("InteractionDetector"):
		interaction_detector = player.get_node("InteractionDetector")
	else:
		push_warning("[PlayerInputBridge] InteractionDetector not found, interaction detection will be limited")


func _process(_delta: float) -> void:
	"""同步前方检测器位置，仅作为结构化组件存在。"""
	if player == null or interaction_detector == null:
		return

	var facing_direction: Vector2 = player.get("facing_direction")
	interaction_detector.position = facing_direction * (interaction_range * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	"""统一接管交互键和手持项切换键。"""
	if _is_player_ui_locked():
		return

	if event.is_action_pressed("interact"):
		_handle_interaction_input()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("tool_next"):
		cycle_tool(1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("tool_previous"):
		cycle_tool(-1)
		get_viewport().set_input_as_handled()


## 处理交互输入
func _handle_interaction_input() -> void:
	if is_interaction_on_cooldown():
		return

	current_target_interactable = detect_interaction_target()
	current_target_plot = current_target_interactable as Plot
	if current_target_interactable == null:
		return

	if _try_execute_generic_interaction(current_target_interactable):
		last_interaction_time = _get_now_seconds()
		return

	if game_manager == null:
		show_interaction_feedback(false, "GameManager 未就绪")
		return

	var current_item := String(game_manager.get_current_tool())
	if current_item == "":
		show_interaction_feedback(false, "请先装备工具")
		return

	var action_id := guess_action_from_tool_and_plot(current_item, current_target_plot)
	if action_id == "":
		show_interaction_feedback(false, _build_invalid_interaction_message(current_item, current_target_plot))
		last_interaction_time = _get_now_seconds()
		return

	execute_interaction(current_target_plot, action_id)


## 检测前方可交互地块
func detect_interaction_target() -> Node:
	var interactable := _detect_generic_interactable()
	if interactable != null:
		return interactable

	if player == null or farm_manager == null:
		return null

	var player_pos: Vector2 = player.global_position
	var facing_dir: Vector2 = player.get("facing_direction")
	var detect_pos := player_pos + (facing_dir * interaction_range)
	var target_plot: Plot = farm_manager.get_plot_at_world_position(detect_pos, 20.0)
	if target_plot == null:
		return null

	var distance := player_pos.distance_to(target_plot.global_position)
	if distance > interaction_range + 10.0:
		return null

	return target_plot


func get_current_interaction_target() -> Node:
	return detect_interaction_target()


## 根据当前手持项和地块状态推断动作
func guess_action_from_tool_and_plot(tool_id: String, plot: Plot) -> String:
	match plot.base_state:
		Plot.STATE_WASTE:
			return "plow" if tool_id == "hoe_wood" else ""
		Plot.STATE_PLOWED:
			return "seed" if tool_id == "seed_wheat" else ""
		Plot.STATE_SEEDED:
			return "water" if tool_id == "watering_can_wood" else ""
		Plot.STATE_WATERED:
			return "water" if tool_id == "watering_can_wood" else ""
		Plot.STATE_MATURE:
			return "harvest" if tool_id == "sickle_wood" else ""
		_:
			return ""


## 执行交互逻辑
func execute_interaction(plot: Plot, action_id: String) -> void:
	if game_manager == null or farm_interaction_system == null:
		show_interaction_feedback(false, "交互系统未就绪")
		return

	var current_item := String(game_manager.get_current_tool())
	var action_context := {
		"action_id": action_id,
		"source": "player",
		"crop_config_id": "crop_wheat",
		"timestamp": Time.get_unix_time_from_system(),
	}
	var result: Dictionary = farm_interaction_system.on_tool_use(current_item, plot, action_context)

	if bool(result.get("success", false)):
		_handle_successful_interaction(result)
	else:
		_handle_failed_interaction(result)

	last_interaction_time = _get_now_seconds()


## 应用成功交互的结果
func _handle_successful_interaction(result: Dictionary) -> void:
	var consumed_items: Dictionary = result.get("consumed_items", {})
	var created_items: Dictionary = result.get("created_items", {})

	for item_id in consumed_items.keys():
		game_manager.remove_item(String(item_id), int(consumed_items[item_id]))

	for item_id in created_items.keys():
		game_manager.add_item(String(item_id), int(created_items[item_id]))

	show_interaction_feedback(true, String(result.get("message", "")))


## 处理失败交互
func _handle_failed_interaction(result: Dictionary) -> void:
	show_interaction_feedback(false, String(result.get("message", "无法执行此操作")))


## 显示简化版交互反馈
func show_interaction_feedback(success: bool, message: String) -> void:
	print("[Interaction] %s: %s" % ["✓" if success else "✗", message])


## 检查交互是否处于冷却中
func is_interaction_on_cooldown() -> bool:
	if last_interaction_time < 0.0:
		return false

	return (_get_now_seconds() - last_interaction_time) < interaction_cooldown


## 循环切换当前手持项
func cycle_tool(direction: int) -> void:
	if game_manager == null:
		show_interaction_feedback(false, "GameManager 未就绪")
		return

	var unlocked_tools: PackedStringArray = game_manager.get_unlocked_tools()
	if unlocked_tools.size() <= 1:
		return

	var current_tool := String(game_manager.get_current_tool())
	var current_index := unlocked_tools.find(current_tool)
	if current_index == -1:
		current_index = 0

	var next_index := wrapi(current_index + direction, 0, unlocked_tools.size())
	var next_tool := String(unlocked_tools[next_index])
	game_manager.set_current_tool(next_tool)
	show_tool_switch_feedback(next_tool)


## 显示手持项切换反馈
func show_tool_switch_feedback(tool_id: String) -> void:
	var display_name := ""
	var tool_config = null
	if farm_interaction_system != null:
		tool_config = farm_interaction_system.get_tool_config(tool_id)
	if tool_config != null:
		display_name = tool_config.display_name
	elif tool_id == "seed_wheat":
		display_name = "小麦种子"
	else:
		display_name = tool_id

	show_interaction_feedback(true, "装备：%s" % display_name)


func _try_execute_generic_interaction(target: Node) -> bool:
	if target == null or target is Plot:
		return false

	if not target.has_method("interact"):
		return false

	var result = target.call("interact", player)
	if result is Dictionary:
		show_interaction_feedback(bool(result.get("success", false)), String(result.get("message", "")))
	else:
		show_interaction_feedback(true, "交互完成")
	return true


func _build_invalid_interaction_message(tool_id: String, plot: Plot) -> String:
	match plot.base_state:
		Plot.STATE_WASTE:
			if tool_id == "seed_wheat":
				return plot.get_action_denied_message("seed")
			if tool_id != "hoe_wood":
				return "请切换到木锄头后再开垦"
		Plot.STATE_PLOWED:
			if tool_id == "hoe_wood":
				return "这块地已经开垦，切换到小麦种子后再播种"
			if tool_id != "seed_wheat":
				return "请切换到小麦种子后再播种"
		Plot.STATE_SEEDED, Plot.STATE_WATERED:
			if tool_id != "watering_can_wood":
				return "请切换到木水壶后再浇水"
		Plot.STATE_MATURE:
			if tool_id != "sickle_wood":
				return "请切换到木镰刀后再收获"

	return "无法执行此操作"


func _is_player_ui_locked() -> bool:
	if player == null:
		return false

	if player.has_method("is_ui_open"):
		return bool(player.call("is_ui_open"))

	return false


func _get_now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _detect_generic_interactable() -> Node:
	if player == null:
		return null

	var best_target: Node = null
	var best_distance: float = interaction_range + 18.0
	var player_pos: Vector2 = player.global_position
	var facing_dir: Vector2 = player.get("facing_direction")

	for node in get_tree().get_nodes_in_group("player_interactable"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		if node == player:
			continue

		var interactable_node: Node2D = node
		var distance: float = player_pos.distance_to(interactable_node.global_position)
		var allowed_distance: float = interaction_range + 18.0
		if node.has_method("get_interaction_range"):
			allowed_distance = max(float(node.call("get_interaction_range")), allowed_distance)

		if distance > allowed_distance:
			continue

		var direction_to_target: Vector2 = (interactable_node.global_position - player_pos).normalized()
		if facing_dir.dot(direction_to_target) < 0.1:
			continue

		if distance < best_distance:
			best_distance = distance
			best_target = node

	return best_target
