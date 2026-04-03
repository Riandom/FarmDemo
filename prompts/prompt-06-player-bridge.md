# 提示词 6: 玩家交互桥接（连接玩家输入和 FarmInteractionSystem）

## 项目上下文

这是 Godot 4.5 种田游戏的玩家交互桥接模块。当前目标是**快速完成 Demo**，但架构设计要**预留扩展接口**以支持未来成为完整独立游戏。

**已完成模块**：
- 项目初始化（project.godot, 800×600, 输入映射）
- 玩家控制系统（移动、朝向、交互检测）
- 地块系统（5 状态流转、生长定时器、基础交互）
- UI 系统（交互提示、背包、商店、金币显示）
- 主控制器（Main 场景、6×6 地块网格生成、GameManager 单例）
- 系统单例（FarmManager, FarmInteractionSystem, FarmRenderSystem）

**本模块核心职责**：将玩家的 E 键交互输入转换为 FarmInteractionSystem 可理解的工具使用请求，实现玩家与地块系统的无缝连接。

**扩展性要求**：支持多种输入方式（键盘、手柄、触摸）、连击检测、输入缓冲，但不实现具体逻辑。

---

## 第 1 章：系统架构

### 1.1 设计原则

**核心原则**：
1. **输入抽象** - 玩家输入与具体动作分离，便于扩展手柄/触摸支持
2. **智能推断** - 根据工具和地块状态自动推断意图动作
3. **反馈及时** - 交互结果立即通过 UI 提示玩家
4. **容错友好** - 误操作时提供清晰提示，不消耗资源

### 1.2 交互桥接层级结构

```
Player (CharacterBody2D)
├── InteractionDetector (Area2D)
│   └── CollisionShape2D (前方 32px 扇形区域)
└── PlayerInputBridge (脚本组件)
    ├── 监听输入事件
    ├── 检测交互目标
    ├── 推断动作意图
    └── 调用 FarmInteractionSystem

FarmInteractionSystem (Singleton)
└── 验证工具能力 → 验证地块权限 → 执行动作
```

### 1.3 数据流图

```
玩家按下 E 键
    ↓
PlayerInputBridge._input(event) 捕获输入
    ↓
检查是否朝向有效地块（使用 InteractionDetector）
    ↓
获取 GameManager.current_tool（当前装备工具）
    ↓
推断 action_id（根据工具类型和地块状态）
    ↓
构建 ActionContext 字典
    ↓
调用 FarmInteractionSystem.on_tool_use(tool_id, plot, context)
    ↓
接收 ActionResult 结果
    ↓
成功：播放反馈特效/音效（预留接口）
失败：显示错误提示文本
```

---

## 第 2 章：PlayerInputBridge 核心逻辑

### 2.1 属性表

| 字段名 | 类型 | 说明 | 必填 | Demo 阶段 |
|--------|------|------|------|----------|
| interaction_detector | Area2D | 交互检测区域 | ✅ | 使用 |
| interaction_range | float | 交互距离 | ✅ | 使用（32px） |
| interaction_cooldown | float | 交互冷却时间 | ❌ | 使用（0.3 秒） |
| last_interaction_time | float | 上次交互时间戳 | ❌ | 使用 |
| current_target_plot | Plot | 当前瞄准的地块 | ❌ | 使用 |
| auto_face_target | bool | 自动朝向目标 | ❌ | **预留接口** |
| show_debug_overlay | bool | 显示调试信息 | ❌ | **预留接口** |

### 2.2 核心函数清单

| 函数名 | 参数 | 返回 | 说明 | Demo 阶段 |
|--------|------|------|------|----------|
| _ready | 无 | void | 初始化检测器 | 使用 |
| _input | event: InputEvent | void | 捕获玩家输入 | 使用 |
| _handle_interaction_input | 无 | void | 处理交互按键 | 使用 |
| detect_interaction_target | 无 | Plot | 检测前方可交互地块 | 使用 |
| guess_action_from_tool_and_plot | tool_id: String, plot: Plot | String | 推断动作意图 | 使用 |
| execute_interaction | plot: Plot, action_id: String | void | 执行交互逻辑 | 使用 |
| show_interaction_feedback | success: bool, message: String | void | 显示交互反馈 | 使用 |
| is_interaction_on_cooldown | 无 | bool | 检查冷却时间 | 使用 |

### 2.3 输入映射配置

```gdscript
# project.godot 中需要添加的输入映射
{
    "interact": {"keycode": KEY_E},           # E 键交互
    "tool_next": {"keycode": KEY_Q},          # Q 键切换下一个工具
    "tool_previous": {"keycode": KEY_F},      # F 键切换上一个工具
    "toggle_debug": {"keycode": KEY_F3}       # F3 调试开关（预留）
}
```

### 2.4 交互检测逻辑

```gdscript
func detect_interaction_target() -> Plot:
    # 步骤 1: 获取玩家位置和朝向
    var player_pos = global_position
    var facing_dir = get_facing_direction()  # 从 Player 脚本获取
    
    # 步骤 2: 计算检测点位置（玩家前方 32px）
    var detect_pos = player_pos + facing_dir * interaction_range
    
    # 步骤 3: 使用 FarmManager 查找最近地块
    var target_plot = FarmManager.get_plot_at_world_position(detect_pos, 20.0)
    
    # 步骤 4: 验证地块有效性
    if target_plot == null:
        return null
    
    # 步骤 5: 验证距离（防止隔空交互）
    var distance = global_position.distance_to(target_plot.global_position)
    if distance > interaction_range + 10.0:  # 10px 容错范围
        return null
    
    return target_plot
```

### 2.5 动作推断逻辑

```gdscript
func guess_action_from_tool_and_plot(tool_id: String, plot: Plot) -> String:
    """根据工具类型和地块状态智能推断玩家想要的动作"""
    
    # 步骤 1: 获取工具配置
    var tool_config = FarmInteractionSystem.get_tool_config(tool_id)
    if tool_config == null:
        return ""
    
    # 步骤 2: 获取工具允许的动作列表
    var allowed_actions = tool_config.allowed_actions
    
    # 步骤 3: 根据地块状态推断意图
    match plot.base_state:
        "waste":
            # 荒地只能开垦
            return "plow" if allowed_actions.has("plow") else ""
        
        "plowed":
            # 熟地可以播种（如果有种子）
            if allowed_actions.has("seed"):
                return "seed"
            # 或者重新开垦（如果拿的是锄头）
            return "plow" if allowed_actions.has("plow") else ""
        
        "seeded":
            # 已播种只能浇水
            return "water" if allowed_actions.has("water") else ""
        
        "watered":
            # 已浇水等待生长，无法交互
            return ""
        
        "mature":
            # 已成熟只能收获
            return "harvest" if allowed_actions.has("harvest") else ""
    
    return ""
```

### 2.6 交互执行流程

```gdscript
func _handle_interaction_input() -> void:
    # 步骤 1: 检查冷却时间
    if is_interaction_on_cooldown():
        return
    
    # 步骤 2: 检测交互目标
    var target_plot = detect_interaction_target()
    if target_plot == null:
        return  # 没有可交互的地块
    
    # 步骤 3: 获取当前装备的工具
    var current_tool = GameManager.get_current_tool()
    if current_tool == "":
        show_interaction_feedback(false, "请先装备工具")
        return
    
    # 步骤 4: 推断动作意图
    var action_id = guess_action_from_tool_and_plot(current_tool, target_plot)
    if action_id == "":
        show_interaction_feedback(false, "无法执行此操作")
        return
    
    # 步骤 5: 构建交互上下文
    var action_context = {
        "action_id": action_id,
        "source": "player",
        "crop_config_id": "crop_wheat",  # Demo 固定小麦
        "timestamp": Time.get_unix_time_from_system()
    }
    
    # 步骤 6: 调用交互系统
    var result = FarmInteractionSystem.on_tool_use(current_tool, target_plot, action_context)
    
    # 步骤 7: 处理结果
    if result.success:
        _handle_successful_interaction(result, target_plot)
    else:
        _handle_failed_interaction(result)
    
    # 步骤 8: 更新冷却时间
    last_interaction_time = Time.get_unix_time_from_system()
```

### 2.7 成功交互处理

```gdscript
func _handle_successful_interaction(result: Dictionary, plot: Plot) -> void:
    # 步骤 1: 显示成功反馈
    show_interaction_feedback(true, result.message)
    
    # 步骤 2: 如果有物品消耗，更新背包
    if result.consumed_items.size() > 0:
        for item_id in result.consumed_items:
            var count = result.consumed_items[item_id]
            GameManager.remove_item(item_id, count)
    
    # 步骤 3: 如果有物品产出，添加到背包
    if result.created_items.size() > 0:
        for item_id in result.created_items:
            var count = result.created_items[item_id]
            GameManager.add_item(item_id, count)
    
    # 步骤 4: 播放反馈效果（预留接口）
    # play_interaction_effect(plot.global_position)
    # play_sound_effect("interaction_success")
```

### 2.8 失败交互处理

```gdscript
func _handle_failed_interaction(result: Dictionary) -> void:
    # 显示错误提示
    show_interaction_feedback(false, result.message)
    
    # 根据错误类型播放不同反馈（预留接口）
    # if result.message.contains("权限"):
    #     play_sound_effect("action_denied")
    # elif result.message.contains("物品不足"):
    #     play_sound_effect("insufficient_items")
```

---

## 第 3 章：交互反馈系统

### 3.1 反馈类型

| 反馈类型 | 触发时机 | 显示方式 | Demo 阶段 |
|---------|---------|---------|----------|
| 成功反馈 | 交互成功 | 绿色文字 "+3 小麦" | 使用 |
| 失败反馈 | 交互失败 | 红色文字 "无法执行" | 使用 |
| 权限拒绝 | 地块状态不匹配 | 橙色文字 "还没开垦" | 使用 |
| 物品不足 | 背包缺少道具 | 黄色文字 "缺少种子" | 使用 |
| 冷却中 | 连续快速按键 | 灰色文字 "..." | **预留接口** |

### 3.2 反馈显示位置

```
方案 A: 地块上方浮动文字（推荐）
- 在世界坐标显示，跟随地块移动
- 2 秒后自动淡出消失

方案 B: 屏幕底部固定提示栏
- 在 UI 层显示，不跟随任何物体
- 持续显示直到被新提示覆盖

方案 C: 玩家头顶气泡
- 在玩家头顶显示对话框
- 适合表达玩家心情（预留接口）
```

### 3.3 反馈函数签名

```gdscript
func show_interaction_feedback(success: bool, message: String) -> void:
    """
    显示交互反馈文字
    
    @param success 是否成功
    @param message 反馈文字内容
    """
    var color = Color.GREEN if success else Color.RED
    
    # Demo 简化版：直接打印到控制台
    print("[Interaction] %s: %s" % ["✓" if success else "✗", message])
    
    # 完整版：在 UI 上显示浮动文字
    # spawn_floating_text(message, color, current_target_plot.global_position)
```

---

## 第 4 章：工具切换系统

### 4.1 工具切换逻辑

```gdscript
# PlayerInputBridge 中添加工具切换功能

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("tool_next"):
        cycle_tool(1)  # 切换到下一个工具
    elif event.is_action_pressed("tool_previous"):
        cycle_tool(-1)  # 切换到上一个工具


func cycle_tool(direction: int) -> void:
    """
    循环切换工具
    
    @param direction 1=下一个，-1=上一个
    """
    var unlocked_tools = GameManager.get_unlocked_tools()
    if unlocked_tools.size() <= 1:
        return  # 只有一个工具，无需切换
    
    var current_tool = GameManager.get_current_tool()
    var current_index = unlocked_tools.find(current_tool)
    
    # 计算新索引（循环）
    var new_index = wrapi(current_index + direction, 0, unlocked_tools.size())
    var new_tool = unlocked_tools[new_index]
    
    # 更新装备
    GameManager.set_current_tool(new_tool)
    
    # 显示切换提示
    show_tool_switch_feedback(new_tool)
```

### 4.2 工具切换反馈

```gdscript
func show_tool_switch_feedback(tool_id: String) -> void:
    """显示工具切换提示"""
    var tool_config = FarmInteractionSystem.get_tool_config(tool_id)
    if tool_config:
        var message = "装备：%s" % tool_config.display_name
        show_interaction_feedback(true, message)
```

---

## 第 5 章：扩展接口预留

### 5.1 手柄支持接口

```gdscript
# 未来实现（暂不实现）
var gamepad_vibration_enabled = true

func _input(event: InputEvent) -> void:
    # 检测手柄输入
    if event is InputEventJoypadButton:
        if event.pressed and event.button_index == JOY_BUTTON_A:
            _handle_interaction_input()
    
    # 交互成功时震动反馈
    if result.success and gamepad_vibration_enabled:
        Input.start_joy_vibration(0, 0.2, 0.5, 0.1)
```

### 5.2 触摸支持接口

```gdscript
# 未来实现（暂不实现）
var touch_interaction_enabled = false
var last_touch_position = Vector2.ZERO

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        last_touch_position = event.position
        if touch_interaction_enabled:
            _handle_touch_interaction()

func _handle_touch_interaction() -> void:
    # 将触摸坐标转换为世界坐标
    var world_pos = get_viewport().get_camera_2d().get_global_mouse_position()
    # 查找最近的地块并交互
    var target = FarmManager.get_plot_at_world_position(world_pos, 32.0)
    if target:
        execute_interaction(target, guessed_action)
```

### 5.3 连击检测接口

```gdscript
# 未来实现（暂不实现）
var combo_count = 0
var combo_timer = 0.0
var combo_window = 2.0  # 2 秒内连续交互算连击

func _handle_successful_interaction(result: Dictionary) -> void:
    combo_timer = combo_window
    combo_count += 1
    
    if combo_count >= 3:
        show_combo_feedback(combo_count)

func _process(delta: float) -> void:
    if combo_timer > 0:
        combo_timer -= delta
    else:
        combo_count = 0
```

### 5.4 输入缓冲接口

```gdscript
# 未来实现（暂不实现）
var input_buffer = []
var buffer_timeout = 0.1  # 0.1 秒缓冲窗口

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("interact"):
        # 如果正在冷却中，将输入加入缓冲
        if is_interaction_on_cooldown():
            buffer_interaction_input(event)
        else:
            _handle_interaction_input()

func buffer_interaction_input(event: InputEvent) -> void:
    input_buffer.append({
        "time": Time.get_unix_time_from_system(),
        "event": event
    })
    # 清理超时缓冲
    input_buffer = input_buffer.filter(func(x): 
        return Time.get_unix_time_from_system() - x.time < buffer_timeout
    )
```

### 5.5 自动朝向接口

```gdscript
# 未来实现（暂不实现）
var auto_face_enabled = false

func detect_interaction_target() -> Plot:
    var target = FarmManager.get_plot_at_world_position(...)
    
    if target and auto_face_enabled:
        # 玩家自动转向目标地块
        face_direction(target.global_position - global_position)
    
    return target

func face_direction(dir: Vector2) -> void:
    # 更新玩家朝向和动画
    player.set_facing_direction(dir.normalized())
```

---

## 第 6 章：验证场景

### 场景 1: 基础交互测试

**前提条件**：
- 玩家装备锄头，站在荒地旁边

**操作步骤**：
1. 面向荒地
2. 按 E 键
3. 观察地块状态变化

**预期结果**：
- ✅ 步骤 2: 检测到前方荒地
- ✅ 步骤 3: 地块从 waste 变为 plowed
- ✅ 控制台打印："✓ 开垦成功"
- ✅ 无报错，交互流畅

### 场景 2: 智能动作推断测试

**前提条件**：
- 玩家背包有种子、水壶、镰刀
- 面前有 3 块地：荒地、熟地、已播种地

**操作步骤**：
1. 装备种子，对荒地按 E
2. 装备种子，对熟地按 E
3. 装备水壶，对已播种地按 E
4. 装备镰刀，对成熟作物按 E

**预期结果**：
- ✅ 步骤 1: 提示"这块地还没开垦，无法播种"
- ✅ 步骤 2: 自动执行播种动作，地块变为 seeded
- ✅ 步骤 3: 自动执行浇水动作，地块变为 watered
- ✅ 步骤 4: 自动执行收获动作，背包 +3 小麦

### 场景 3: 交互冷却测试

**前提条件**：
- 无任何限制

**操作步骤**：
1. 连续快速按 E 键 10 次
2. 观察是否每次都能成功交互

**预期结果**：
- ✅ 步骤 2: 只有前几次成功，后续被冷却阻止
- ✅ 冷却时间约 0.3 秒
- ✅ 无连续交互导致的 Bug

### 场景 4: 工具切换测试

**前提条件**：
- 玩家解锁了锄头、水壶、镰刀

**操作步骤**：
1. 按 Q 键切换工具
2. 观察当前装备工具变化
3. 再次按 Q 键
4. 按 F 键反向切换

**预期结果**：
- ✅ 步骤 2: 显示"装备：木锄头"
- ✅ 步骤 3: 显示"装备：木水壶"
- ✅ 步骤 4: 显示"装备：木锄头"（循环）
- ✅ 切换流畅，无卡顿

### 场景 5: 错误操作处理测试

**前提条件**：
- 玩家只持有种子，没有锄头
- 面前是荒地

**操作步骤**：
1. 装备种子
2. 对着荒地按 E

**预期结果**：
- ✅ 步骤 2: 显示"这块地还没开垦，无法播种"
- ✅ 地块状态不变
- ✅ 不消耗种子
- ✅ 提示颜色为红色（失败）

### 场景 6: 交互距离验证测试

**前提条件**：
- 无任何限制

**操作步骤**：
1. 站在距离地块 30px 处，按 E
2. 站在距离地块 50px 处，按 E
3. 紧贴地块（10px），按 E

**预期结果**：
- ✅ 步骤 1: 可能成功（在 32px 范围内）
- ✅ 步骤 2: 失败，距离太远
- ✅ 步骤 3: 成功，交互流畅
- ✅ 距离判定准确，无串地

---

## 第 7 章：输出清单

### 必须交付的文件

**脚本文件**：
- [ ] scripts/player/player_input_bridge.gd - 玩家输入桥接逻辑

**场景文件**：
- [ ] （可选）scenes/player/interaction_detector.tscn - 交互检测器预制体

**项目设置**：
- [ ] project.godot - 添加工具切换输入映射（Q 键、F 键）

---

## 下一步

完成玩家交互桥接后，继续：
1. **提示词 7**: 占位符资源生成器（使用 GDScript 动态生成像素风格贴图）
2. **集成测试**: 运行完整游戏流程，验证所有系统协同工作
