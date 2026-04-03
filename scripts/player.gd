extends CharacterBody2D

## 玩家移动速度（像素/秒）
@export var player_speed: float = 100.0

## 交互范围（像素）
@export var interaction_range: float = 32.0

## 交互冷却时间（秒）
@export var interact_cooldown: float = 0.3

## 信号：玩家尝试交互
## @param interact_pos 交互位置（Vector2，世界坐标）
## @param facing_dir 玩家朝向（Vector2，单位方向）
signal player_interacted(interact_pos: Vector2, facing_dir: Vector2)

## 信号：请求打开 UI
## @param ui_type UI 类型 ("inventory" 或 "shop")
signal ui_interaction_requested(ui_type: String)

## 当前朝向（上/下/左/右）
var facing_direction: Vector2 = Vector2.DOWN

## 是否正在移动
var is_moving: bool = false

## 交互冷却计时器
var _interact_timer: float = 0.0

## UI 打开状态
var _ui_open: bool = false

const _PLAYER_TEXTURE_PATHS: Dictionary = {
	"idle_down": "res://assets/sprites/placeholder/player/idle_down.png",
	"idle_up": "res://assets/sprites/placeholder/player/idle_up.png",
	"idle_left": "res://assets/sprites/placeholder/player/idle_left.png",
	"idle_right": "res://assets/sprites/placeholder/player/idle_right.png",
	"walk_down": "res://assets/sprites/placeholder/player/walk_down.png",
	"walk_up": "res://assets/sprites/placeholder/player/walk_up.png",
	"walk_left": "res://assets/sprites/placeholder/player/walk_left.png",
	"walk_right": "res://assets/sprites/placeholder/player/walk_right.png",
}

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_point: Node2D = $InteractionPoint

var _player_textures: Dictionary = {}
var _walk_bob_timer: float = 0.0


func _ready() -> void:
	"""游戏启动时初始化"""
	_load_player_textures()
	_apply_facing_transform()
	_apply_texture_for_animation("idle_down")


func _physics_process(delta: float) -> void:
	"""物理更新循环 - 处理移动"""
	if _ui_open:
		# UI 打开时禁用移动与物理推进
		velocity = Vector2.ZERO
		return

	_handle_movement(delta)
	update_facing()
	_update_walk_bob(delta)
	update_animation()
	position += velocity * delta

	# 更新交互点位置到玩家朝向前方
	_update_interaction_point()

	# 处理交互冷却
	if _interact_timer > 0.0:
		_interact_timer -= delta


## 处理玩家输入并移动
## @param delta 帧间隔时间（本函数目前未使用，但保留以满足扩展）
func _handle_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO

	# 获取输入方向
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	# 斜向移动归一化，防止加速
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()

	# 设置速度（速度单位：像素/秒）
	velocity = input_dir * player_speed

	# 更新移动状态
	is_moving = input_dir.length() > 0.0


## 更新玩家朝向（只在移动时更新）
func update_facing() -> void:
	if not is_moving:
		return

	# 根据移动方向更新朝向
	if abs(velocity.x) > abs(velocity.y):
		# 水平方向为主
		facing_direction = Vector2.RIGHT if velocity.x > 0.0 else Vector2.LEFT
	else:
		# 垂直方向为主
		facing_direction = Vector2.DOWN if velocity.y > 0.0 else Vector2.UP

	# 保险起见：直接设置精灵朝向（即使动画轨道路径配置有差异，也能保证朝向正确）
	_apply_facing_transform()


## 根据 facing_direction 直接更新精灵朝向
func _apply_facing_transform() -> void:
	# Prompt 7 起改为使用独立方向贴图，朝向不再通过旋转单张图完成。
	sprite.rotation = 0.0

	# idle 基准帧：默认让精灵回到原始位置（walk 的抖动会由动画或后续逻辑实现）
	if not is_moving:
		sprite.position = Vector2.ZERO


## 更新玩家动画播放
func update_animation() -> void:
	var anim_name: String

	if is_moving:
		anim_name = "walk_"
	else:
		anim_name = "idle_"

	# 根据朝向拼接动画名
	match facing_direction:
		Vector2.DOWN:
			anim_name += "down"
		Vector2.UP:
			anim_name += "up"
		Vector2.LEFT:
			anim_name += "left"
		Vector2.RIGHT:
			anim_name += "right"
		_:
			anim_name += "down"

	_apply_texture_for_animation(anim_name)


## 更新交互点位置到玩家朝向前方
func _update_interaction_point() -> void:
	# InteractionPoint 在角色正前方 32px 处的视觉位置要求是 (0,16) 起步，
	# 因此使用 interaction_range 的一半作为节点位置偏移。
	interaction_point.position = facing_direction * (interaction_range * 0.5)


## 尝试交互
func _try_interact() -> void:
	# 计算交互位置（玩家位置 + 朝向前方 32px）
	var interact_pos := global_position + (facing_direction * interaction_range)

	# 发射交互信号给主控系统
	emit_signal("player_interacted", interact_pos, facing_direction)

	print("玩家交互：位置=", interact_pos, ", 朝向=", facing_direction)


## 请求打开 UI
## @param ui_type UI 类型
func request_open_ui(ui_type: String) -> void:
	if _ui_open:
		return
	_ui_open = true
	emit_signal("ui_interaction_requested", ui_type)


## 关闭 UI
func close_ui() -> void:
	_ui_open = false


## 直接设置 UI 打开状态，不发射额外信号
## @param is_open 是否打开 UI
func set_ui_open(is_open: bool) -> void:
	_ui_open = is_open


## 检查 UI 是否打开
func is_ui_open() -> bool:
	return _ui_open


func _load_player_textures() -> void:
	_player_textures.clear()
	for anim_name in _PLAYER_TEXTURE_PATHS.keys():
		var texture_path: String = _PLAYER_TEXTURE_PATHS[anim_name]
		if ResourceLoader.exists(texture_path):
			_player_textures[anim_name] = load(texture_path)


func _apply_texture_for_animation(anim_name: String) -> void:
	var texture = _player_textures.get(anim_name)
	if texture is Texture2D:
		sprite.texture = texture


func _update_walk_bob(delta: float) -> void:
	"""用脚本直接更新 Sprite2D 的抖动，避免 AnimationPlayer 误改玩家根节点位置。"""
	if not is_moving:
		_walk_bob_timer = 0.0
		sprite.position = Vector2.ZERO
		return

	_walk_bob_timer += delta * 10.0
	match facing_direction:
		Vector2.LEFT, Vector2.RIGHT:
			sprite.position = Vector2(0.0, sin(_walk_bob_timer) * 2.0)
		Vector2.UP, Vector2.DOWN:
			sprite.position = Vector2(sin(_walk_bob_timer) * 1.5, 0.0)
		_:
			sprite.position = Vector2.ZERO
