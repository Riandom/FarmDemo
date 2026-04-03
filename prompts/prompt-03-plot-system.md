# 提示词 3: 地块系统（Demo 精简版 + 扩展接口）

## 项目上下文

这是 Godot 4.5 种田游戏的核心基础模块。当前目标是**快速完成 Demo**，但架构设计要**预留扩展接口**以支持未来成为完整独立游戏。

**已完成模块**：
- 项目初始化（project.godot, 800×600, 输入映射）
- 玩家控制系统（移动、朝向、交互检测）

**本模块核心职责**：管理地块的 5 状态流转、生长定时器、基础交互。

**扩展性要求**：预留 buffs/debuffs、环境参数、事件日志等接口，但不实现具体逻辑。

---

## 第 1 章：系统架构

### 1.1 设计原则

**核心原则**：
1. **协议式交互** - 工具声明能力，地块验证权限
2. **逻辑与渲染分离** - 地块发射信号，渲染系统监听
3. **集中化管理** - FarmManager 单例统一管理所有地块
4. **数据驱动** - 作物配置使用 Resource，便于扩展

### 1.2 单例注册

以下单例需要在 project.godot 的 autoload 列表中注册：

| 单例名称 | 脚本路径 | 说明 |
|---------|---------|------|
| FarmManager | res://scripts/systems/farm_manager.gd | 地块管理器 |
| FarmInteractionSystem | res://scripts/systems/farm_interaction_system.gd | 交互中介系统 |
| FarmRenderSystem | res://scripts/systems/farm_render_system.gd | 渲染系统 |

---

## 第 2 章：地块状态系统

### 2.1 地块属性表

每个地块包含以下属性：

| 字段名 | 类型 | 说明 | 必填 | Demo 阶段 |
|--------|------|------|------|----------|
| grid_position | Vector2i | 网格坐标 [列，行] | ✅ | 使用 |
| plot_type | String | 地块类型标识 | ✅ | 使用 |
| base_state | String | 基础状态（5 选 1） | ✅ | 使用 |
| growth_stage | int | 生长阶段（0-3） | ✅ | 使用 |
| growth_progress | float | 当前阶段进度（0.0-1.0） | ✅ | 使用 |
| crop_config_id | String | 作物配置资源 ID | ❌ | 使用（小麦专用） |
| buffs | Array[Dictionary] | 增益效果列表 | ❌ | **预留接口** |
| debuffs | Array[Dictionary] | 减益效果列表 | ❌ | **预留接口** |
| environment | Dictionary | 环境参数字典 | ❌ | **预留接口** |
| metadata | Dictionary | 其他元数据 | ❌ | **预留接口** |

### 2.2 基础状态定义（Demo 核心）

基础状态共 5 种，形成循环：

| 状态值 | 状态名称 | 含义 | 可执行动作 | 下一状态 |
|--------|---------|------|-----------|---------|
| waste | 荒地 | 未开垦的野地 | plow | plowed |
| plowed | 已开垦 | 可以播种的熟地 | seed | seeded |
| seeded | 已播种 | 种子刚种下去 | water | watered |
| watered | 已浇水 | 正在生长中 | 无（自动生长） | mature |
| mature | 已成熟 | 作物可以收获了 | harvest | plowed |

### 2.3 扩展接口预留（未来功能）

#### Buff 接口预留

```
数据结构（暂不实现具体逻辑）：
{
    "effect_id": String,       # 效果 ID
    "duration_seconds": int,   # 持续时长
    "effects_on_growth": float # 生长速度倍率
}

使用场景（未来）：
- 施肥：添加 "fertilizer" buff，生长速度 +50%
- 营养液：添加 "nutrient_solution" buff，品质提升
```

#### Debuff 接口预留

```
数据结构（暂不实现具体逻辑）：
{
    "effect_id": String,     # 效果 ID
    "severity": float,       # 严重程度
    "effects_on_yield": float # 产量惩罚系数
}

使用场景（未来）：
- 干旱：添加 "drought" debuff，生长停止
- 病害：添加 "disease" debuff，产量降低
```

#### Environment 接口预留


## 第 3 章：交互协议系统

### 3.1 完整交互流程

```
步骤 1: 玩家站在某个地块旁边，按下工具键（如 E 键）
         ↓
步骤 2: 游戏检测玩家手中持有的工具
         ↓
步骤 3: 游戏查询该工具的 allowed_actions 能力清单
         ↓
步骤 4: 游戏找出玩家面前的目标地块（使用 FarmManager.get_plot_at_world_position()）
         ↓
步骤 5: 游戏构建 ActionContext 动作请求对象
         ↓
步骤 6: 调用 FarmInteractionSystem.on_tool_use(tool_id, plot, action_context)
         ↓
步骤 7: FarmInteractionSystem 检查 tool_data.allowed_actions 是否包含该动作
         ↓
步骤 8: 调用 plot.can_perform_action(action_id, action_context) 进行权限验证
         ↓
步骤 9: 如果验证通过，调用 plot.execute_action(action_id, action_context)
         ↓
步骤 10: 地块更新状态，发射 signal: state_changed(old_state, new_state)
         ↓
步骤 11: FarmRenderSystem 监听信号，调用 refresh_plot_visual(plot) 更新画面
         ↓
步骤 12: 返回 ActionResult 给调用方，显示反馈信息
```

### 3.2 ActionContext 数据结构

| 字段名 | 类型 | 必填 | 说明 | Demo 阶段 |
|--------|------|------|------|----------|
| action_id | String | ✅ | 动作的唯一标识 | 使用 |
| tool_id | String | ✅ | 使用的工具 ID | 使用 |
| source | Node/String | ✅ | 发起者（玩家或机器） | 使用 |
| parameters | Dictionary | ❌ | 自定义参数 | **预留接口** |
| timestamp | int | ❌ | 请求发生的时间戳 | **预留接口** |

### 3.3 ActionResult 数据结构

| 字段名 | 类型 | 说明 | Demo 阶段 |
|--------|------|------|----------|
| success | bool | 是否成功执行 | 使用 |
| message | String | 反馈给玩家的文本 | 使用 |
| consumed_items | Dictionary | 消耗的物品列表 | 使用（简化版） |
| created_items | Dictionary | 产出的物品列表 | 使用（简化版） |
| experience_gained | int | 玩家获得的经验值 | **预留接口** |
| quality_factor | float | 品质系数 | **预留接口** |
| side_effects | Array | 连锁反应 | **预留接口** |

### 3.4 权限验证规则

Plot.can_perform_action() 的验证逻辑：

```
步骤 1: 检查基础状态是否匹配
       - 如果 action_id == "plow": 要求 base_state ∈ ["waste", "plowed"]
       - 如果 action_id == "seed": 要求 base_state == "plowed"
       - 如果 action_id == "water": 要求 base_state ∈ ["seeded", "watered"]
       - 如果 action_id == "harvest": 要求 base_state == "mature"
       
步骤 2: 返回验证结果
       - 匹配：返回 true
       - 不匹配：返回 false
```

---

## 第 4 章：生长系统

### 4.1 生长定时器

每个 CropPlot 包含一个 Timer 节点：

| 属性 | 值 | 说明 |
|------|-----|------|
| Wait Time | 5.0 | 每 5 秒推进一个生长阶段 |
| One Shot | false | 重复触发 |
| Autostart | false | 手动启动（仅在浇水后） |

### 4.2 生长阶段推进逻辑

```
步骤 1: Timer 超时，触发 _on_grow_timer_timeout()
步骤 2: 检查 base_state 是否为 "watered"
步骤 3: growth_stage += 1
步骤 4: 检查是否达到最大生长阶段（3）
       - 如果 growth_stage >= 3:
           * base_state = "mature"
           * 停止 Timer
           * 发射 crop_harvested 信号
       - 否则:
           * growth_progress = growth_stage / 3.0
           * 发射 state_changed 信号
```

### 4.3 离线生长接口预留

```
未来实现思路（暂不实现）：
1. 在 metadata 中记录 last_watered_time 时间戳
2. 读取存档时计算 offline_seconds = current_time - last_saved_time
3. 根据 offline_seconds 和生长速度计算 growth_amount
4. 更新 growth_stage 和 growth_progress
```

---

## 第 5 章：信号定义

### 5.1 Plot 类信号

| 信号名 | 参数 | 触发时机 |
|--------|------|---------|
| state_changed | old_state: String, new_state: String | 地块状态变更时 |
| visual_update_requested | plot: Plot | 需要更新视觉时 |
| crop_harvested | plot: Plot | 作物被收获时 |

### 5.2 FarmManager 信号

| 信号名 | 参数 | 触发时机 |
|--------|------|---------|
| plot_registered | plot: Plot | 新地块注册时 |
| plot_unregistered | plot: Plot | 地块注销时 |

---

## 第 6 章：FarmManager 查询接口

### 6.1 基础查询方法（必须实现）

| 方法名 | 参数 | 返回 | 说明 |
|--------|------|------|------|
| register_plot | plot: Plot | void | 注册地块 |
| unregister_plot | plot: Plot | void | 注销地块 |
| get_plot_at_grid_position | Vector2i | Plot | 按网格坐标查找 |
| get_plot_at_world_position | Vector2, float(max_distance=20) | Plot | 按世界坐标查找 |
| get_all_plots | 无 | Array[Plot] | 获取所有地块 |

### 6.2 高级查询方法（预留接口）

```
未来实现（暂不实现）：
- get_plots_in_radius(center: Vector2i, radius: int) -> Array[Plot]
- get_plots_in_rectangle(top_left: Vector2i, bottom_right: Vector2i) -> Array[Plot]
- find_plots_by_condition(predicate: Callable) -> Array[Plot]
- count_plots_by_condition(predicate: Callable) -> int
```

---

## 第 7 章：配置系统

### 7.1 CropConfig 资源配置

CropConfig 继承 Resource，包含以下导出属性：

| 属性名 | 类型 | 说明 | 小麦示例值 |
|--------|------|------|-----------|
| crop_id | String | 唯一标识符 | "crop_wheat" |
| display_name | String | 显示名称 | "小麦" |
| growth_stages | int | 总生长阶段数 | 3 |
| stage_base_duration | float | 基础每阶段时长（秒） | 5.0（Demo 加速） |
| yield_base | int | 基础产量 | 3 |
| sell_price_base | int | 基础售价 | 15 |
| sprites_per_stage | Array[String] | 每个阶段的贴图路径 | [...] |

### 7.2 ToolConfig 资源配置

ToolConfig 继承 Resource，包含以下导出属性：

| 属性名 | 类型 | 说明 | 木锄头示例 |
|--------|------|------|-----------|
| tool_id | String | 工具唯一 ID | "hoe_wood" |
| display_name | String | 显示名称 | "木锄头" |
| allowed_actions | Array[String] | 允许的动作列表 | ["plow"] |
| energy_cost | int | 体力消耗 | 5 |
| icon_path | String | 图标路径 | "res://assets/tools/hoe_wood.png" |

---

## 第 8 章：验证场景

### 场景 1: 完整的种植循环

**前提条件**：
- 玩家背包有：5 个小麦种子、1 个锄头、1 个水壶
- 农场有一块荒地 [grid: (3,2)]

**操作步骤**：
1. 玩家走到地块 [3,2] 旁边
2. 装备锄头，按 E 键 → 开垦
3. 装备种子，按 E 键 → 播种
4. 装备水壶，按 E 键 → 浇水
5. 等待 15 秒（3 阶段×5 秒）
6. 作物成熟，按 E 键 → 收获

**预期结果**：
- ✅ 步骤 2: 地块从"waste"变为"plowed"
- ✅ 步骤 3: 地块从"plowed"变为"seeded"
- ✅ 步骤 4: 地块从"seeded"变为"watered"，启动 Timer
- ✅ 步骤 5: 每 5 秒 growth_stage +1，共 3 次
- ✅ 步骤 6: 地块从"watered"变为"mature"，收获后变回"plowed"
- ✅ 背包增加 3 个小麦
- ✅ 所有信号正确发射
- ✅ 无报错、无卡顿

### 场景 2: 错误操作处理

**前提条件**：
- 玩家站在一块荒地 [grid: (4,1)] 旁边
- 玩家背包只有种子，没有锄头

**操作步骤**：
1. 玩家装备种子
2. 对着荒地按 E 键，试图直接播种

**预期结果**：
- ✅ 地块状态不变（仍是"waste"）
- ✅ 屏幕显示提示："这块地还没开垦，无法播种"
- ✅ 不消耗种子
- ✅ can_perform_action() 返回 false

### 场景 3: 生长定时器测试

**前提条件**：
- 地块 [3,2] 处于"seeded"状态

**操作步骤**：
1. 对地块浇水
2. 观察 Timer 是否启动
3. 等待 5 秒
4. 检查 growth_stage 变化

**预期结果**：
- ✅ 步骤 1: 地块变为"watered"，Timer.start()
- ✅ 步骤 2: Timer.is_running() == true
- ✅ 步骤 3: growth_stage 从 0 变为 1
- ✅ 步骤 4: 再次等待 5 秒，growth_stage 从 1 变为 2
- ✅ 步骤 5: 第三次等待，growth_stage 从 2 变为 3，base_state 变为"mature"，Timer.stop()

### 场景 4: 信号监听测试

**前提条件**：
- FarmRenderSystem 已连接所有地块的 state_changed 信号

**操作步骤**：
1. 对地块执行浇水动作
2. 观察 FarmRenderSystem 是否收到信号

**预期结果**：
- ✅ 地块发射 state_changed("seeded", "watered")
- ✅ FarmRenderSystem 收到信号
- ✅ 调用 refresh_plot_visual(plot)
- ✅ 地块贴图更新为"已浇水"外观

### 场景 5: FarmManager 查询测试

**前提条件**：
- 农场有 6×6 = 36 块地

**操作步骤**：
1. 调用 get_plot_at_grid_position(Vector2i(3, 2))
2. 调用 get_plot_at_world_position(Vector2(200, 150), 20.0)
3. 调用 get_all_plots()

**预期结果**：
- ✅ 步骤 1: 返回地块 [3,2]
- ✅ 步骤 2: 返回距离 (200,150) 最近的地块（距离<20px）
- ✅ 步骤 3: 返回 36 个地块的数组

---

## 第 9 章：输出清单

### 必须交付的文件

**脚本文件**：
- [ ] scripts/plot/plot.gd - Plot 基类
- [ ] scripts/plot/crop_plot.gd - CropPlot 子类
- [ ] scripts/systems/farm_manager.gd - FarmManager 单例
- [ ] scripts/systems/farm_interaction_system.gd - FarmInteractionSystem 单例
- [ ] scripts/systems/farm_render_system.gd - FarmRenderSystem 单例
- [ ] scripts/resources/crop_config.gd - CropConfig Resource 类
- [ ] scripts/resources/tool_config.gd - ToolConfig Resource 类

**场景文件**：
- [ ] scenes/plot/crop_plot.tscn - 作物地块场景（Area2D + Sprite2D + CollisionShape2D + Timer）
- [ ] scenes/systems/farm_manager.tscn - FarmManager 单例场景
- [ ] scenes/systems/farm_interaction_system.tscn - FarmInteractionSystem 单例场景
- [ ] scenes/systems/farm_render_system.tscn - FarmRenderSystem 单例场景

**配置文件**：
- [ ] resources/config/crops/wheat_config.tres - 小麦配置
- [ ] resources/config/tools/hoe_wood.tres - 木锄头配置
- [ ] resources/config/tools/watering_can_wood.tres - 木水壶配置
- [ ] resources/config/tools/sickle_wood.tres - 木镰刀配置

**项目设置**：
- [ ] project.godot - 添加 3 个单例到 autoload 列表

---

## 下一步

完成本地块系统后，继续：
1. **提示词 4**: 工具系统（详细 ToolConfig 和 FarmInteractionSystem 实现）
2. **提示词 5**: 作物配置系统（CropConfig 详解）
3. **提示词 6**: 渲染系统（FarmRenderSystem 信号监听和贴图管理）
4. **提示词 7**: UI 系统（交互提示、背包、商店）
5. **提示词 8**: 主控制器（Main 游戏入口和信号汇总）
