# Phase 4-B: 状态系统实现提示词

## 任务概述

为 FarmDemo 实现统一的运行时状态管理层，包括：
- `EffectManager` 单例
- `ActiveEffect` 活跃效果实例
- 叠加与过期机制
- 与 `TimeManager` / `SaveManager` / `Plot` 的真实集成

这是 Demo 0.4.0 的第二部分，依赖 Prompt 12 的 `EventManager`。  
本阶段目标不是做“通用工业级状态框架”，而是先把真实效果闭环接入当前 0.3.0 游戏链路。

---

## 核心定位

### 1. 当前对象是 ActiveEffect，不是模板

本阶段文档中的 `Effect`，应明确理解为：

**ActiveEffect / 活跃效果实例**

它表示的是一条“当前正在生效的状态”，而不是可复用的静态模板。

这意味着它必须包含运行时数据，例如：
- `remaining_seconds`
- `remaining_days`
- `target_id`
- `category`

本阶段**不做** `EffectDefinition`、`EffectConfig` 等模板资源化层。  
如果后续需要模板系统，放到 Phase 5+ 再拆。

---

### 2. 作用域只要求落地三类

Demo 0.4.0 真正要求支持：
- `GLOBAL`
- `SINGLE_TARGET`
- `CATEGORY`

`AREA` 只作为预留字段存在，不要求本版实现几何区域判定。  
否则会形成“字段有了，但业务无法正确查询”的空心设计。

---

## 交付范围

### 必做内容
- `EffectManager` autoload 单例
- `ActiveEffect` 运行时资源类
- 添加 / 移除 / 查询效果
- 叠加规则：`ADDITIVE`、`MULTIPLICATIVE`、`MAXIMUM`
- 短期和长期效果更新
- 与 `EventManager` 的订阅集成
- 存档导出 / 应用
- 至少两个真实可见效果闭环

### 本阶段不做
- 模板资源化
- 复杂冲突优先级
- AREA 范围判定
- 可视化效果编辑器
- 网络同步

---

## 文件结构

```text
scripts/resources/
└── effect.gd

scripts/systems/
└── effect_manager.gd

scenes/systems/
└── effect_manager.tscn
```

---

## ActiveEffect 最低字段要求

```gdscript
extends Resource
class_name Effect
```

至少应包含：
- `effect_id: String`
- `effect_type: String`
- `value: float`
- `stack_type`
- `scope`
- `target_id: String`
- `target_ids: Array[String]`
- `category: String`
- `cap_value: float`
- `remaining_seconds: float`
- `remaining_days: int`

说明：
- `remaining_seconds` 用于短期效果
- `remaining_days` 用于长期效果
- 同一个实例只需要一种主要持续方式，但为了存档和序列化统一，可以同时保留两个字段

---

## EffectManager 核心 API

```gdscript
func add_effect(effect: Effect) -> void
func remove_effect(effect_id: String) -> void
func has_effect(effect_type: String, target_id := "", category := "") -> bool
func get_effect_value(effect_type: String, target_id := "", category := "") -> float
func export_save_data() -> Dictionary
func apply_save_data(data: Dictionary) -> void
```

### 为什么必须有 target/category 查询

因为本阶段明确支持：
- 全局效果
- 单目标效果
- 类别效果

如果只有：

```gdscript
func get_effect_value(effect_type: String) -> float
```

那 scope 字段就无法真正参与业务计算。  
因此 target/category 维度不是可选项，而是 P0。

---

## 推荐内部结构

```gdscript
var _short_term_effects: Dictionary = {}
var _long_term_effects: Dictionary = {}
```

建议：
- 短期效果按秒更新
- 长期效果按天更新
- 两者都按 `effect_id` 存储

---

## 持续时间更新规则

### 1. 短期效果

短期效果可以通过 `_process(delta)` 更新，但必须满足下面这条强约束：

**只有在 `TimeManager` 未暂停时才允许推进。**

也就是：
- PauseMenu 打开时
- 时间系统暂停时
- 短期效果不能偷偷减少 `remaining_seconds`

否则会导致：
- 游戏时间暂停
- 效果时间继续流逝
- 玩家感知和系统状态不一致

### 2. 长期效果

长期效果不走 `_process(delta)`，而是通过 `day_started` 推进：
- 每次新的一天开始，`remaining_days -= 1`
- 到 0 后自动过期
- 过期时广播 `effect_expired`

---

## 与 EventManager 的集成

### 必须订阅的事件
- `season_changed`
- `day_started`

### 事件用途

`season_changed`：
- 添加或切换季节型长期效果

`day_started`：
- 推进长期效果剩余天数
- 必要时触发到期移除

`save_loaded`：
- 可选订阅，用于读档后的二次刷新或日志

### 启动时初始同步要求

`EffectManager` 不能只依赖后续事件来建立季节效果。  
如果游戏启动时当前季节已经是 `summer` 或 `winter`，但尚未发生新的 `season_changed`，系统仍然必须能得到正确的基础效果。

因此必须补一条初始化约束：
- `EffectManager` 在 `_ready()` 时要根据当前 `TimeManager` 状态做一次初始效果同步
- 在 `save_loaded` 后也要重新同步一次当前季节基础效果

目标是避免以下错误状态：
- 当前季节已经是夏季，但 `SUMMER_GROWTH_BOOST` 尚未建立
- 当前季节已经是冬季，但 `WINTER_OUTDOOR_GROWTH_BLOCK` 尚未建立

---

## 与现有系统的正确集成方式

### 1. TimeManager

`TimeManager` 是本阶段最重要的事件发布者。  
`EffectManager` 不自己决定季节，而是订阅 `season_changed` 后生成或切换效果。

### 2. Plot

当前 0.3.0 的真实生长链路是：

`TimeManager -> Plot`

所以效果应用不应回到“FarmManager 统一结算”的旧方案。  
效果的最终消费位置应靠近真实生长计算，例如：
- `TimeManager.trigger_crop_growth()` 计算增长值时查询效果
- 或 `Plot.advance_growth(units)` 之前由调用方带入效果后的单位值

### 3. SaveManager

必须遵守当前仓库统一风格：
- 系统自己 `export_save_data()`
- 系统自己 `apply_save_data()`
- `SaveManager` 只做编排

因此本 Prompt 不再以 `save_effects()` / `load_effects()` 作为主接口。

---

## 0.4.0 必须交付的真实效果闭环

本阶段不能只交付空框架，必须至少落地以下两个效果：

### 1. `SUMMER_GROWTH_BOOST`
- 夏季全局生长加成
- 推荐作用域：`GLOBAL`
- 推荐数值：`+0.2`
- 由 `season_changed` 触发激活

### 2. `WINTER_OUTDOOR_GROWTH_BLOCK`
- 冬季室外自然生长停滞
- 推荐作用域：`GLOBAL` 或未来可扩为 `CATEGORY`
- 推荐数值：`0.0` 或等价阻断规则
- 由 `season_changed` 触发激活

### 3. 推荐附加测试效果
- `TEMP_GROWTH_BOOST`
- 或“睡觉后一天内加成”

第三类不是硬性 P0，但强烈建议加入，因为这样可以验证：
- 短期效果链路
- 长期效果链路
- 存档恢复链路

---

## project.godot 要求

新增 autoload：

```ini
[autoload]
EffectManager="*res://scenes/systems/effect_manager.tscn"
```

位置要求：
- 放在 `EventManager` 之后
- 以便 `_ready()` 中可以直接订阅事件

---

## 验收标准

### 基础能力
- [ ] EffectManager 单例正常启动
- [ ] ActiveEffect 可以创建、添加、移除
- [ ] 叠加规则计算正确
- [ ] `has_effect(..., target_id, category)` 正常工作
- [ ] `get_effect_value(..., target_id, category)` 正常工作

### 时间更新
- [ ] 短期效果只在时间未暂停时推进
- [ ] 长期效果只在 `day_started` 时推进
- [ ] 到期后效果自动移除
- [ ] 过期时可发布 `effect_expired`

### 存档集成
- [ ] `export_save_data()` 返回结构稳定的数据
- [ ] `apply_save_data()` 正确恢复效果
- [ ] 存档后读档，效果剩余时间/天数不丢失

### 真实 gameplay 闭环
- [ ] 夏季生长加成真实生效
- [ ] 冬季室外生长停滞真实生效
- [ ] 原有 0.3.0 四季、存档、暂停菜单链路不退化

---

## 推荐实现建议

### 推荐做法
```gdscript
func get_effect_value(effect_type: String, target_id := "", category := "") -> float:
    # 先筛选 effect_type
    # 再按 scope 过滤 GLOBAL / SINGLE_TARGET / CATEGORY
    # 最后按 stack_type 汇总
    return 0.0
```

### 不推荐做法
```gdscript
# 只有 effect_type，没有目标过滤
func get_effect_value(effect_type: String) -> float:
    return 0.0
```

这个接口对全局效果够用，但对单目标和类别效果不够用，后续一定返工。

---

## 交付结论要求

Prompt 13 完成后，项目应拥有：
- 一套真正可用的运行时状态系统
- 与 EventManager、TimeManager、SaveManager 的现实集成
- 至少两个可见的效果闭环
- 能继续扩展到天气、NPC、任务等系统的底座

---

**文档版本**：v2.0  
**修订日期**：2026-04-04  
**适用阶段**：Demo 0.4.0 - Prompt 13 状态系统  
**前置条件**：Prompt 12 事件系统已实现
