# 提示词 2: 玩家控制系统

## 任务目标
创建玩家角色场景和脚本，实现移动、朝向、动画和交互功能。

---

## 项目上下文

这是 Godot 4.5 种田游戏的第 2 个模块。已完成：
- ✅ 项目初始化（project.godot, 800×600）
- ✅ 输入映射（WASD 移动，E 交互，I/B UI）
- ✅ 占位贴图生成工具

---

## 必须完成的任务

### 1. 创建玩家场景 (player.tscn)

**节点层级结构**:
```
CharacterBody2D (Player)
├── Sprite2D
│   └── AnimationPlayer
├── CollisionShape2D
└── Position2D (InteractionPoint)
```

**节点详细配置**:

#### CharacterBody2D (根节点)
- 名称：`Player`
- 用于物理移动和碰撞检测

#### Sprite2D
- 用于显示玩家精灵
- Texture 暂时使用 `res://assets/sprites/placeholder/player.png`

#### AnimationPlayer
- 创建以下动画片段：
  - `idle_down`: 1 帧，向下站立
  - `idle_up`: 1 帧，向上站立（旋转 180°）
  - `idle_left`: 1 帧，向左站立（旋转 90°）
  - `idle_right`: 1 帧，向右站立（旋转 -90°）
  - `walk_down`: 2-3 帧循环，向下走路
  - `walk_up`: 2-3 帧循环，向上走路
  - `walk_left`: 2-3 帧循环，向左走路
  - `walk_right`: 2-3 帧循环，向右走路

#### CollisionShape2D
- Shape: `RectangleShape2D`
- Size: (28, 28) - 略小于 32×32，方便移动

#### Position2D
- 名称：`InteractionPoint`
- 位置：初始为 (0, 16) - 玩家正前方 32px 处
- 用途：标记交互检测点

---

### 2. 编写玩家脚本 (player.gd)

**文件路径**: `scripts/player.gd`

**完整代码框架**:

```gdscript
extends CharacterBody2D

## 玩家移动速度（像素/秒）
@export var player_speed: float = 100.0

## 交互范围（像素）
@export var interaction_range: float = 32.0

## 交互冷却时间（秒）
@export var interact_cooldown: float = 0.3

## 信号：玩家尝试交互
## @param interact_pos 交互位置（Vector2）
## @param facing_dir 玩家朝向（Vector2）
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

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var interaction_point: Position2D = $InteractionPoint


func _ready() -> void:
	"""游戏启动时初始化"""
	animation_player.play("idle_down")


func _physics_process(delta: float) -> void:
	"""物理更新循环 - 处理移动"""
	if _ui_open:
		# UI 打开时禁用移动
		velocity = Vector2.ZERO
		move_and_collide(velocity)
		return
	
	_handle_movement(delta)
	update_facing()
	update_animation()
	move_and_collide(velocity)
	
	# 更新交互点位置到朝向前方
	_update_interaction_point()
	
	# 处理交互冷却
	if _interact_timer > 0:
		_interact_timer -= delta


func _unhandled_input(event: InputEvent) -> void:
	"""处理未处理的输入事件"""
	if _ui_open:
		return
	
	# E 键交互
	if event.is_action_pressed("interact"):
		if _interact_timer <= 0:
			_try_interact()
			_interact_timer = _interact_cooldown


## 处理玩家输入并移动
## @param delta 帧间隔时间
func _handle_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO
	
	# 获取输入方向
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	
	# 斜向移动归一化，防止加速
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
	
	# 设置速度
	velocity = input_dir * player_speed
	
	# 更新移动状态
	is_moving = input_dir.length() > 0


## 更新玩家朝向
func update_facing() -> void:
	if not is_moving:
		return
	
	# 根据移动方向更新朝向
	if abs(velocity.x) > abs(velocity.y):
		# 水平方向为主
		facing_direction = Vector2.RIGHT if velocity.x > 0 else Vector2.LEFT
	else:
		# 垂直方向为主
		facing_direction = Vector2.DOWN if velocity.y > 0 else Vector2.UP


## 更新动画播放
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
	
	# 播放动画（如果当前没在播放这个动画）
	if animation_player.current_animation != anim_name:
		animation_player.play(anim_name)


## 更新交互点位置到玩家朝向前方
func _update_interaction_point() -> void:
	interaction_point.position = facing_direction * interaction_range


## 尝试交互
func _try_interact() -> void:
	# 计算交互位置（玩家位置 + 朝向前方 32px）
	var interact_pos = global_position + (facing_direction * interaction_range)
	
	# 发送交互信号
	emit_signal("player_interacted", interact_pos, facing_direction)
	
	# 打印调试日志
	print("玩家交互：位置=", interact_pos, ", 朝向=", facing_direction)


## 请求打开 UI
## @param ui_type UI 类型
func request_open_ui(ui_type: String) -> void:
	_ui_open = true
	emit_signal("ui_interaction_requested", ui_type)


## 关闭 UI
func close_ui() -> void:
	_ui_open = false


## 检查 UI 是否打开
func is_ui_open() -> bool:
	return _ui_open
```

---

## ⛔ 避坑检查清单

### 移动相关
- ✅ `_physics_process` 中处理移动（不是 `_process`）
- ✅ 斜向移动必须调用 `normalized()` 防止加速
- ✅ 使用 `move_and_collide()` 而非 `move_and_slide()`（更精确控制）

### 朝向与动画
- ✅ 仅支持 4 个固定朝向（上/下/左/右）
- ✅ 动画命名格式：`{动作}_{方向}`（如 `idle_down`）
- ✅ 游戏启动默认播放 `idle_down`

### 交互系统
- ✅ 交互范围严格限制为前方 32px
- ✅ 交互冷却时间 0.3 秒，防止连发
- ✅ UI 打开时禁用移动和交互
- ⛔ 禁止使用范围检测（会触发多个地块）
- ⛔ 禁止在 `_process` 中持续检测交互

### 语法规范
- ✅ Godot 4.5 语法（`@export`, `@onready`, `@signal`）
- ✅ 所有 `if` 语句有完整条件表达式
- ✅ Tab 缩进，Tab size = 4
- ✅ 蛇形命名法（snake_case）

---

## ✅ 验证步骤

完成后请测试：

### 基础移动测试
1. 将玩家场景拖入主场景
2. 运行游戏，按 WASD 移动
3. **验证**: 玩家可移动，速度适中
4. **验证**: 斜向移动（同时按 W+D）速度不加快
5. **验证**: 松开按键立即停止

### 朝向与动画测试
1. 上下左右移动
2. **验证**: 玩家朝向始终面向移动方向
3. **验证**: 移动时播放 walk 动画，停止时播放 idle 动画
4. **验证**: 动画切换流畅无卡顿

### 交互测试
1. 按 E 键
2. **验证**: 控制台输出 "玩家交互：位置=..., 朝向=..."
3. **验证**: 连续快速按 E，每 0.3 秒才触发一次
4. 打开 UI（待后续 UI 模块完成后测试）
5. **验证**: UI 打开时无法移动和交互

---

## 📝 输出清单

完成后应该有以下文件：
- [ ] `scenes/player.tscn` - 玩家场景（含 7 个动画）
- [ ] `scripts/player.gd` - 玩家控制脚本
- [ ] 玩家场景可实例化，无报错警告

---

## 🔧 调试技巧

如果遇到问题：

1. **移动异常**: 检查 `_physics_process` 中是否调用了 `move_and_collide()`
2. **动画不播放**: 检查 AnimationPlayer 的动画名是否拼写正确
3. **交互不触发**: 添加 `print("_interact_timer=", _interact_timer)` 查看冷却状态
4. **朝向错误**: 添加 `print("velocity=", velocity, "facing=", facing_direction)` 调试

---

## 下一步

完成此任务后，请等待用户确认并发送 **提示词 3: 农场地块系统**。
