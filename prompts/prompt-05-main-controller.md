# 提示词 5: 主控制器（游戏入口、地块网格生成、信号汇总）

## 项目上下文

这是 Godot 4.5 种田游戏的主控制器模块。当前目标是**快速完成 Demo**，但架构设计要**预留扩展接口**以支持未来成为完整独立游戏。

**已完成模块**：
- 项目初始化（project.godot, 800×600, 输入映射）
- 玩家控制系统（移动、朝向、交互检测）
- 地块系统（5 状态流转、生长定时器、基础交互）
- UI 系统（交互提示、背包、商店、金币显示）
- 系统单例（FarmManager, FarmInteractionSystem, FarmRenderSystem）

**本模块核心职责**：作为游戏入口点，初始化所有系统、生成 6×6 地块网格、统一管理全局状态、协调信号联动。

**扩展性要求**：使用 GameManager 单例管理全局状态，支持存档读档、场景切换、事件系统，但不实现具体逻辑。

---

## 第 1 章：系统架构

### 1.1 设计原则

**核心原则**：
1. **单一入口** - Main 场景是游戏的唯一入口点
2. **集中管理** - GameManager 单例存储全局状态
3. **信号解耦** - 系统间仅通过信号通信，不直接引用
4. **数据持久化** - 所有重要数据支持存档读档

### 1.2 Main 场景层级结构

```
Node2D (Main)
├── WorldEnvironment (可选，环境效果)
├── Player
├── FarmTiles (Node2D)
│   └── [动态生成的 36 个 CropPlot 实例]
├── UI (CanvasLayer)
│   ├── InteractionPrompt
│   ├── InventoryUI
│   ├── ShopUI
│   └── GoldDisplay
└── GameManager (Node)
```

### 1.3 GameManager 单例注册

| 单例名称 | 脚本路径 | 说明 |
|---------|---------|------|
| GameManager | res://scripts/systems/game_manager.gd | 全局状态管理器 |

---

## 第 2 章：GameManager 全局状态

### 2.1 数据存储结构

```gdscript
# 玩家数据
{
    "gold": 50,                    # 金币数量
    "inventory": {                 # 背包物品
        "seed_wheat": 5,
        "crop_wheat": 0,
        "tool_hoe_wood": 1,
        "tool_watering_can_wood": 1
    },
    "current_tool": "hoe_wood",    # 当前装备工具
    "unlocked_tools": ["hoe_wood", "watering_can_wood"],  # 已解锁工具
    "total_harvest_count": 0,      # 累计收获次数
    "total_earnings": 0            # 累计收入
}

# 农场数据
{
    "farm_layout": "6x6",          # 农场布局标识
    "plot_states": {},             # 各地块状态（坐标→状态字典）
    "last_save_time": 0            # 上次存档时间戳
}
```

### 2.2 GameManager 属性表

| 字段名 | 类型 | 说明 | 必填 | Demo 阶段 |
|--------|------|------|------|----------|
| gold | int | 金币数量 | ✅ | 使用 |
| inventory | Dictionary | 背包物品字典 | ✅ | 使用 |
| current_tool | String | 当前装备工具 ID | ✅ | 使用 |
| unlocked_tools | Array[String] | 已解锁工具列表 | ❌ | **预留接口** |
| total_harvest_count | int | 累计收获次数 | ❌ | **预留接口** |
| total_earnings | int | 累计收入 | ❌ | **预留接口** |
| plot_states | Dictionary | 地块状态缓存 | ❌ | **预留接口** |
| save_file_path | String | 存档文件路径 | ❌ | **预留接口** |

### 2.3 核心函数清单

| 函数名 | 参数 | 返回 | 说明 | Demo 阶段 |
|--------|------|------|------|----------|
| _ready | 无 | void | 初始化默认数据 | 使用 |
| add_gold | amount: int | void | 增加金币 | 使用 |
| remove_gold | amount: int | bool | 减少金币（成功返回 true） | 使用 |
| add_item | item_id: String, count: int | void | 添加物品到背包 | 使用 |
| remove_item | item_id: String, count: int | bool | 从背包移除物品 | 使用 |
| has_item | item_id: String, count: int | bool | 检查是否有足够物品 | 使用 |
| get_item_count | item_id: String | int | 获取物品数量 | 使用 |
| set_current_tool | tool_id: String | void | 装备工具 | 使用 |
| get_current_tool | 无 | String | 获取当前工具 ID | 使用 |
| save_game | 无 | bool | 保存游戏数据 | ❌ | **预留接口** |
| load_game | 无 | bool | 读取游戏数据 | ❌ | **预留接口** |

### 2.4 信号定义

| 信号名 | 参数 | 触发时机 |
|--------|------|---------|
| gold_changed | new_amount: int | 金币数量变更时 |
| inventory_changed | items: Dictionary | 背包内容变更时 |
| item_added | item_id: String, count: int | 添加物品时 |
| item_removed | item_id: String, count: int | 移除物品时 |
| tool_equipped | tool_id: String | 切换工具时 |
| game_saved | timestamp: int | 游戏保存时 |
| game_loaded | data: Dictionary | 游戏读取时 |

---

## 第 3 章：Main 控制器逻辑

### 3.1 Main 脚本属性表

| 字段名 | 类型 | 说明 | 必填 | Demo 阶段 |
|--------|------|------|------|----------|
| player | CharacterBody2D | 玩家节点引用 | ✅ | 使用 |
| farm_tiles_parent | Node2D | 地块父节点 | ✅ | 使用 |
| ui_root | CanvasLayer | UI 根节点 | ✅ | 使用 |
| crop_plot_scene | PackedScene | 地块预制体 | ✅ | 使用 |
| farm_rows | int | 农场行数 | ✅ | 使用（6） |
| farm_cols | int | 农场列数 | ✅ | 使用（6） |
| tile_spacing | float | 地块间距 | ✅ | 使用（32） |
| farm_offset | Vector2 | 农场起始偏移 | ❌ | 使用 |

### 3.2 核心函数清单

| 函数名 | 参数 | 返回 | 说明 | Demo 阶段 |
|--------|------|------|------|----------|
| _ready | 无 | void | 初始化所有系统 | 使用 |
| spawn_farm_tiles | rows: int, cols: int | void | 生成地块网格 | 使用 |
| connect_all_signals | 无 | void | 连接所有信号 | 使用 |
| _on_player_interacted | pos: Vector2, dir: Vector2 | void | 处理玩家交互 | 使用 |
| _on_tile_state_changed | old_state: String, new_state: String | void | 监听地块状态变更 | 使用 |
| _on_crop_harvested | plot: Plot | void | 处理作物收获 | 使用 |
| _on_ui_opened | ui_type: String | void | UI 打开时禁用玩家输入 | 使用 |
| _on_ui_closed | ui_type: String | void | UI 关闭时恢复玩家输入 | 使用 |
| _on_gold_changed | new_amount: int | void | 更新金币显示 | 使用 |
| _on_inventory_updated | items: Dictionary | void | 更新背包显示 | 使用 |

### 3.3 地块网格生成算法

```
步骤 1: 计算农场总宽度 = cols × tile_spacing
         ↓
步骤 2: 计算农场总高度 = rows × tile_spacing
         ↓
步骤 3: 计算居中偏移 offset = (screen_size - farm_size) / 2
         ↓
步骤 4: for row in range(rows):
           for col in range(cols):
               - 实例化 crop_plot_scene
               - 设置 grid_position = Vector2i(col, row)
               - 设置 global_position = offset + Vector2(col, row) × tile_spacing
               - 添加到 farm_tiles_parent
               - 调用 FarmManager.register_plot()
               - 连接信号：state_changed, visual_update_requested, crop_harvested
```

### 3.4 信号连接清单

**Main 需要连接的信号**：

| 信号来源 | 信号名 | 回调函数 | 说明 |
|---------|--------|---------|------|
| Player | player_interacted | _on_player_interacted | 处理玩家交互请求 |
| Player | ui_interaction_requested | _on_ui_interaction_requested | 处理 UI 开关请求 |
| CropPlot | state_changed | _on_tile_state_changed | 监听地块状态变更 |
| CropPlot | crop_harvested | _on_crop_harvested | 处理作物收获 |
| GameManager | gold_changed | _on_gold_changed | 更新金币 UI |
| GameManager | inventory_changed | _on_inventory_updated | 更新背包 UI |
| InventoryUI | ui_opened | _on_ui_opened | 禁用玩家输入 |
| InventoryUI | ui_closed | _on_ui_closed | 恢复玩家输入 |
| ShopUI | ui_opened | _on_ui_opened | 禁用玩家输入 |
| ShopUI | ui_closed | _on_ui_closed | 恢复玩家输入 |

---

## 第 4 章：玩家交互处理流程

### 4.1 完整交互时序图

```
步骤 1: 玩家按下 E 键
         ↓
步骤 2: Player 检测前方是否有地块
         ↓
步骤 3: 如果有：发射 player_interacted(position, direction)
         ↓
步骤 4: Main._on_player_interacted() 接收信号
         ↓
步骤 5: 调用 FarmManager.get_plot_at_world_position(position)
         ↓
步骤 6: 如果找到地块：获取玩家当前工具 ID
         ↓
步骤 7: 调用 FarmInteractionSystem.on_tool_use(tool_id, plot, context)
         ↓
步骤 8: FarmInteractionSystem 验证工具能力 → 验证地块权限 → 执行动作
         ↓
步骤 9: Plot.execute_action() 改变状态并发射 signal
         ↓
步骤 10: Main._on_tile_state_changed() 接收信号
         ↓
步骤 11: 如果需要消耗/获得物品：调用 GameManager.add/remove_item()
         ↓
步骤 12: GameManager 发射 inventory_changed, gold_changed
         ↓
步骤 13: UI 监听信号并更新显示
```

### 4.2 交互验证逻辑

```gdscript
func _on_player_interacted(pos: Vector2, dir: Vector2) -> void:
    # 步骤 1: 查找目标地块
    var target_plot = FarmManager.get_plot_at_world_position(pos + dir * 32, 20.0)
    if target_plot == null:
        return  # 没有可交互的地块
    
    # 步骤 2: 获取当前工具
    var current_tool = GameManager.get_current_tool()
    if current_tool == "":
        return  # 没有装备工具
    
    # 步骤 3: 构建交互上下文
    var action_context = {
        "action_id": _guess_action_from_tool(current_tool),
        "source": "player",
        "crop_config_id": "crop_wheat"  # Demo 阶段固定小麦
    }
    
    # 步骤 4: 执行交互
    var result = FarmInteractionSystem.on_tool_use(current_tool, target_plot, action_context)
    
    # 步骤 5: 处理结果
    if result.success:
        _handle_interaction_result(result)
    else:
        _show_error_message(result.message)
```

### 4.3 工具 - 动作映射规则

| 工具 ID | allowed_actions | 对应动作 |
|--------|----------------|---------|
| hoe_wood | ["plow"] | 开垦荒地/重置熟地 |
| watering_can_wood | ["water"] | 浇水播种后的地块 |
| sickle_wood | ["harvest"] | 收获成熟作物 |

---

## 第 5 章：收获处理逻辑

### 5.1 收获流程

```
步骤 1: Plot 成熟后，玩家使用镰刀交互
         ↓
步骤 2: Plot.execute_action("harvest") 执行收获
         ↓
步骤 3: 根据 crop_config 计算产量（基础 3 个小麦）
         ↓
步骤 4: 发射 crop_harvested(plot, yield_items)
         ↓
步骤 5: Main._on_crop_harvested() 接收信号
         ↓
步骤 6: 调用 GameManager.add_item("crop_wheat", yield_count)
         ↓
步骤 7: GameManager 发射 inventory_changed
         ↓
步骤 8: 显示浮动文字："+3 小麦"（预留接口）
         ↓
步骤 9: 更新统计：total_harvest_count += 1（预留接口）
```

### 5.2 产量计算公式（预留扩展）

```gdscript
# Demo 阶段简化版
var base_yield = crop_config.yield_base  # 3 个

# 未来扩展（暂不实现）
var final_yield = base_yield \
    * (1.0 + buff_bonus) \
    * (1.0 - debuff_penalty) \
    * environment_factor \
    * random_variance(0.9, 1.1)
```

---

## 第 6 章：初始资源配置

### 6.1 初始数据设置

```gdscript
# GameManager._ready() 中设置
gold = 50
inventory = {
    "seed_wheat": 5,
    "crop_wheat": 0,
    "tool_hoe_wood": 1,
    "tool_watering_can_wood": 1,
    "tool_sickle_wood": 1
}
current_tool = "hoe_wood"
```

### 6.2 工具配置加载

```gdscript
# Main._ready() 中加载
var tool_paths = [
    "res://resources/config/tools/hoe_wood.tres",
    "res://resources/config/tools/watering_can_wood.tres",
    "res://resources/config/tools/sickle_wood.tres"
]

for path in tool_paths:
    if ResourceLoader.exists(path):
        var config = load(path) as ToolConfig
        FarmInteractionSystem.register_tool_config(config)
```

### 6.3 作物配置加载

```gdscript
# 加载小麦配置供收获时使用
var wheat_config = load("res://resources/config/crops/wheat_config.tres") as CropConfig
```

---

## 第 7 章：扩展接口预留

### 7.1 存档读档接口

```gdscript
# 未来实现（暂不实现）
func save_game(slot: int = 1) -> bool:
    var save_data = {
        "player_data": {
            "gold": gold,
            "inventory": inventory,
            "current_tool": current_tool,
            "unlocked_tools": unlocked_tools,
            "total_harvest_count": total_harvest_count,
            "total_earnings": total_earnings
        },
        "farm_data": {
            "plot_states": _serialize_plot_states(),
            "last_save_time": Time.get_unix_time_from_system()
        },
        "metadata": {
            "version": "1.0",
            "save_slot": slot
        }
    }
    
    var file = FileAccess.open("user://save_%d.save" % slot, FileAccess.WRITE)
    file.store_var(save_data)
    file.close()
    return true

func load_game(slot: int = 1) -> bool:
    if not FileAccess.file_exists("user://save_%d.save" % slot):
        return false
    
    var file = FileAccess.open("user://save_%d.save" % slot, FileAccess.READ)
    var save_data = file.get_var()
    file.close()
    
    _deserialize_save_data(save_data)
    return true
```

### 7.2 场景切换接口

```gdscript
# 未来实现（暂不实现）
var current_scene_name: String = "main"
var scene_transition_timer: Timer

func change_scene(scene_name: String) -> void:
    match scene_name:
        "main":
            _transition_to_main()
        "farm_exterior":
            _transition_to_exterior()
        "town":
            _transition_to_town()
```

### 7.3 事件系统接口

```gdscript
# 未来实现（暂不实现）
signal game_event_triggered(event_id: String, parameters: Dictionary)

func trigger_event(event_id: String, parameters: Dictionary = {}) -> void:
    emit_signal("game_event_triggered", event_id, parameters)
    
    # 示例事件：
    # "first_harvest" - 第一次收获
    # "earned_100_gold" - 累计收入 100 金
    # "unlocked_greenhouse" - 解锁温室
```

### 7.4 成就系统接口

```gdscript
# 未来实现（暂不实现）
var achievements: Dictionary = {
    "first_harvest": {"unlocked": false, "progress": 0, "target": 1},
    "master_farmer": {"unlocked": false, "progress": 0, "target": 100},
    "wealthy": {"unlocked": false, "progress": 0, "target": 1000}
}

func check_achievement(achievement_id: String) -> void:
    var achievement = achievements.get(achievement_id)
    if achievement and achievement.progress >= achievement.target:
        achievement.unlocked = true
        emit_signal("achievement_unlocked", achievement_id)
```

---

## 第 8 章：验证场景

### 场景 1: 游戏启动测试

**前提条件**：
- 所有资源文件存在（地块预制体、工具配置、作物配置）

**操作步骤**：
1. 运行游戏
2. 观察 Main 场景是否正常加载
3. 检查是否生成 6×6=36 个地块
4. 检查玩家是否出现在场景中
5. 检查 UI 是否正常显示

**预期结果**：
- ✅ 步骤 2: 无报错，场景加载成功
- ✅ 步骤 3: 36 个地块整齐排列成 6×6 网格
- ✅ 步骤 4: 玩家在农场附近出生
- ✅ 步骤 5: 金币显示"💰 50"，其他 UI 隐藏
- ✅ 控制台打印："[Main] Game started", "[Main] Spawned 36 plots"

### 场景 2: 完整种植循环测试

**前提条件**：
- 初始金币 50，背包有 5 种子、锄头、水壶、镰刀

**操作步骤**：
1. 走到荒地旁边，按 E 开垦
2. 切换到种子，按 E 播种
3. 切换到水壶，按 E 浇水
4. 等待 15 秒（3 阶段×5 秒）
5. 切换到镰刀，按 E 收获
6. 检查背包和金币变化

**预期结果**：
- ✅ 步骤 1: 地块变为 plowed，无物品消耗
- ✅ 步骤 2: 地块变为 seeded，背包 -1 种子
- ✅ 步骤 3: 地块变为 watered，Timer 启动
- ✅ 步骤 4: 每 5 秒生长阶段 +1，共 3 次
- ✅ 步骤 5: 地块变回 plowed，背包 +3 小麦
- ✅ 步骤 6: 最终状态：金币 50，种子 4，小麦 3

### 场景 3: 商店交易测试

**前提条件**：
- 金币 50，背包有 3 个成熟小麦

**操作步骤**：
1. 按 B 打开商店
2. 售卖 3 个小麦（每个 15 金）
3. 购买 2 个种子（每个 5 金）
4. 关闭商店
5. 检查最终金币和物品

**预期结果**：
- ✅ 步骤 2: 每次售卖：+15 金，-1 小麦
- ✅ 步骤 3: 每次购买：-5 金，+1 种子
- ✅ 步骤 5: 最终状态：金币 50+45-10=85，种子 5+2=7，小麦 0

### 场景 4: 多地块并行测试

**前提条件**：
- 背包有足够种子和水

**操作步骤**：
1. 开垦 3 块荒地
2. 播种 3 块地
3. 浇水 3 块地
4. 等待 15 秒
5. 观察 3 块地是否同时成熟

**预期结果**：
- ✅ 步骤 4: 3 个地块的 Timer 独立运行
- ✅ 步骤 5: 3 块地几乎同时成熟（误差<0.1 秒）
- ✅ 无信号冲突、无状态混乱

### 场景 5: UI 互斥测试

**前提条件**：
- 无任何 UI 打开

**操作步骤**：
1. 按 I 打开背包
2. 尝试按 B 打开商店
3. 关闭背包
4. 按 B 打开商店
5. 尝试按 I 打开背包

**预期结果**：
- ✅ 步骤 2: 商店不会打开（或先关闭背包）
- ✅ 步骤 3: 背包关闭，玩家恢复控制
- ✅ 步骤 4: 商店正常打开
- ✅ 步骤 5: 背包不会打开（或先关闭商店）

### 场景 6: 错误操作处理测试

**前提条件**：
- 站在荒地旁边，只持有种子（没有锄头）

**操作步骤**：
1. 对着荒地按 E
2. 观察提示信息

**预期结果**：
- ✅ 步骤 2: 显示"这块地还没开垦，无法播种"或类似提示
- ✅ 地块状态不变（仍是 waste）
- ✅ 不消耗种子
- ✅ 无报错

---

## 第 9 章：输出清单

### 必须交付的文件

**脚本文件**：
- [ ] scripts/main.gd - 主控制器逻辑
- [ ] scripts/systems/game_manager.gd - 全局状态管理器

**场景文件**：
- [ ] scenes/main.tscn - 主场景（包含所有子系统）
- [ ] scenes/systems/game_manager.tscn - GameManager 单例场景

**配置文件**：
- [ ] （可选）resources/config/game/initial_data.tres - 初始数据配置

**项目设置**：
- [ ] project.godot - 注册 GameManager 单例
- [ ] project.godot - 设置 main.tscn 为运行场景

---

## 下一步

完成主控制器后，继续：
1. **提示词 6**: 玩家交互桥接（详细实现玩家输入到 FarmInteractionSystem 的连接逻辑）
2. **提示词 7**: 占位资源生成器（使用 GDScript 动态生成像素风格贴图）
3. **集成测试**: 运行完整游戏流程，验证所有系统协同工作
