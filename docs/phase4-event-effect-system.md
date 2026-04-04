# Phase 4: 事件系统与状态系统

## 文档概述

**目标**：为 FarmDemo 建立跨系统通信机制和统一的运行时状态管理层，为天气、NPC、任务、建筑等后续系统提供稳定底座。  
**版本**：Demo 0.4.0  
**前置条件**：Phase 3（数据配置系统 + 完整四季循环）已完成并通过测试  
**Phase 范围**：仅包含 2 个系统

- Phase 4-A：事件系统（EventManager）
- Phase 4-B：状态系统（EffectManager + ActiveEffect）

本阶段是**完整独立游戏 Demo 的基础设施阶段**，不是最终形态的通用事件/状态框架。目标是先把最关键的架构接好，并交付至少两个真实可见的效果闭环。

---

## 核心定位

### 1. EventManager 负责什么

EventManager 只负责**跨系统广播**，不替代 Godot signal。

适合走 EventManager 的内容：
- `season_changed`
- `day_started`
- `save_loaded`
- `effect_added`
- `effect_expired`

不适合强行走 EventManager 的内容：
- `Plot.state_changed`
- 单个 UI 场景内部节点通信
- 单个场景内部的局部刷新

原则：
- 局部节点通信继续使用 Godot signal
- 跨系统广播才使用 EventManager

---

### 2. EffectManager 负责什么

EffectManager 负责统一管理**运行中的状态实例**，例如：
- 夏季生长加成
- 冬季室外生长停滞
- 临时的一天期增益

它不直接决定业务规则归属。业务规则仍然属于：
- TimeManager
- Plot / 农场逻辑
- 未来的 WeatherManager / NPCManager / QuestManager

EffectManager 做的是：
- 记录当前有哪些效果处于激活状态
- 管理剩余持续时间
- 提供统一查询
- 负责存档恢复

---

### 3. 为什么本阶段不用“效果模板资源化”

本阶段优先落地，先把运行时闭环做通。  
因此 Phase 4 里的 `Effect` 应明确视为**ActiveEffect / 活跃效果实例**，不是长期复用的效果模板。

这意味着：
- 当前对象代表“此刻正在生效的一条状态”
- 它包含运行时字段，如剩余秒数、剩余天数、目标 ID
- Phase 5+ 如有必要，再拆出 `EffectDefinition` 或 Resource 配置层

这样做的好处是：
- 先把系统接入现有 0.3 架构
- 不在 Demo 0.4.0 过早引入模板层复杂度
- 存档和读档语义清晰

---

## Phase 4-A：事件系统基础

### 目标

实现一个最小但可长期演进的事件总线，用于跨系统广播。

本阶段范围：
- `EventManager` 单例
- 订阅 / 取消订阅 / 发布
- 事件历史记录（调试用途）
- 与 `TimeManager`、`SaveManager` 的现实集成
- 为 `EffectManager` 提供后续可订阅入口

本阶段不做：
- 事件优先级
- 条件过滤
- 网络同步
- 回放系统

---

### 最小事件目录

Demo 0.4.0 必须明确支持以下事件：

| 事件名 | 发布者 | 用途 |
|---|---|---|
| `season_changed` | `TimeManager` | 季节切换 |
| `day_started` | `TimeManager` | 新的一天开始 |
| `save_loaded` | `SaveManager` | 读档完成后广播 |
| `effect_added` | `EffectManager` | 新效果激活 |
| `effect_expired` | `EffectManager` | 效果过期 |

事件命名规范：
- 小写 + 下划线
- 动词过去式或完成态
- 表达“已经发生的事”

---

### EventManager 职责

EventManager 只做四件事：

1. 管理订阅关系
2. 发布事件并通知订阅者
3. 支持取消订阅，避免对象销毁后残留引用
4. 保留最近 N 条事件历史供调试查看

不负责：
- 事件优先级
- 业务逻辑执行顺序控制
- 替代所有 Godot signal

---

### 核心 API

```gdscript
func subscribe(event_type: String, callback: Callable) -> void
func unsubscribe(event_type: String, callback: Callable) -> void
func unsubscribe_all(callback: Callable) -> void
func publish(event_type: String, data: Dictionary = {}) -> void
func get_event_history(last_n: int = 10) -> Array[Dictionary]
```

工程约束：
- 必须防止重复订阅
- 取消不存在的订阅时不能崩溃
- 事件历史只用于调试，不参与核心逻辑

---

### 与现有 0.3.0 架构的正确集成方式

#### TimeManager

`TimeManager` 是 Phase 4 最重要的事件发布者。

必须发布：
- `season_changed`
- `day_started`

示例数据应基于当前真实时间结构，而不是不存在的字段：

```gdscript
{
    "old_season": "spring",
    "new_season": "summer",
    "year_count": 1,
    "solar_term": "lichun",
    "day_in_term": 1
}
```

注意：
- 不再使用文档中旧的 `year_day_count`
- 保留 `TimeManager` 现有 Godot signals，作为局部兼容路径

#### SaveManager

`SaveManager` 在读档成功后发布：

```gdscript
EventManager.publish("save_loaded", {
    "slot_type": "manual",
    "slot_index": 2
})
```

这样后续 `EffectManager`、UI、分析工具都可以在读档后同步刷新，而不需要直接耦合 `SaveManager`。

#### 不再以 FarmManager 作为季节倍率主链路

Phase 3 的真实生长链路已经是：

`TimeManager -> Plot`

因此 Phase 4 文档不再把 `FarmManager` 订阅季节事件并应用倍率写成主方案。  
`FarmManager` 可以是订阅者，但不应承担四季倍率主逻辑。

---

### 验收标准

- EventManager 单例正常启动
- `season_changed`、`day_started` 能正常发布
- `save_loaded` 能在读档成功后发布
- 重复订阅有 warning
- 取消订阅和取消全部订阅都可用
- 事件历史有上限，不无限增长
- 原有局部 signal 不受影响

---

## Phase 4-B：状态系统基础

### 目标

实现统一的运行时状态管理层，用于描述“当前有哪些增益/减益正在生效”，并与四季系统形成真实可见闭环。

本阶段范围：
- `EffectManager` 单例
- `ActiveEffect` 运行时实例
- 叠加规则
- 作用域查询
- 持续时间更新
- 存档/读档
- 与 `TimeManager`、`Plot` 的现实集成

本阶段不做：
- EffectDefinition 资源化模板
- 真正的 `AREA` 几何范围判定
- 复杂优先级和冲突系统

---

### ActiveEffect 定位

Phase 4 中的效果对象应明确定位为：

**ActiveEffect / 活跃效果实例**

它表示的是“当前正在生效的一条效果”，而不是可复用的静态模板。

最低需要包含的运行时信息：
- `effect_id`
- `effect_type`
- `value`
- `stack_type`
- `scope`
- `target_id`
- `category`
- `remaining_seconds`
- `remaining_days`

如果未来需要资源化模板，放到 Phase 5+ 再做。

---

### 最低可落地的作用域

Demo 0.4.0 真正要求落地的 scope 只有三类：

- `GLOBAL`
- `SINGLE_TARGET`
- `CATEGORY`

`AREA` 只保留为预留字段，不要求本版真正实现几何判定。  
否则文档会出现“字段存在但业务无法正确查询”的空心设计。

---

### 状态系统的查询接口

`get_effect_value(effect_type)` 不足以支持目标和类别作用域。  
因此 Phase 4 文档必须固定为以下最小接口：

```gdscript
func has_effect(effect_type: String, target_id := "", category := "") -> bool
func get_effect_value(effect_type: String, target_id := "", category := "") -> float
func add_effect(effect: ActiveEffect) -> void
func remove_effect(effect_id: String) -> void
func export_save_data() -> Dictionary
func apply_save_data(data: Dictionary) -> void
```

这套接口可以直接支撑：
- 全局季节效果
- 某个地块的单体效果
- 某类作物的类别效果

---

### 持续时间更新规则

#### 短期效果

短期效果仍可使用 `_process(delta)` 更新，但必须服从当前游戏时间状态。

明确约束：
- 只有在 `TimeManager` 未暂停时推进
- PauseMenu 打开时不能继续倒计时

否则会出现：
- 游戏时间暂停
- 但效果仍然在消失

这会导致状态系统与时间系统脱节。

#### 长期效果

长期效果继续通过 `day_started` 事件推进：
- 每到新的一天减少 `remaining_days`
- 到期自动过期并广播 `effect_expired`

---

### 与现有存档架构的对齐

当前仓库已经形成统一模式：
- 各系统自己 `export_save_data()`
- 各系统自己 `apply_save_data()`
- `SaveManager` 只做编排

因此 EffectManager 必须遵守同一模式，不再另立风格。

不推荐作为主接口的写法：
- `save_effects()`
- `load_effects()`

推荐主接口：

```gdscript
func export_save_data() -> Dictionary
func apply_save_data(data: Dictionary) -> void
```

---

### 0.4.0 必须交付的真实效果闭环

本阶段不能只做空框架，必须至少交付两个玩家能感知到的效果：

1. `SUMMER_GROWTH_BOOST`
   - 夏季全局作物生长加成
   - 通过 `season_changed` 激活

2. `WINTER_OUTDOOR_GROWTH_BLOCK`
   - 冬季室外作物停止自然生长
   - 通过 `season_changed` 激活

建议再补一个短期测试效果占位，便于验证系统完整性：
- `TEMP_GROWTH_BOOST`
- 或“睡觉后获得 1 天加成”

这样 Demo 0.4.0 才是完整独立游戏 Demo 的一部分，而不是纯基础设施演示。

---

### 与现有 0.3.0 架构的正确集成方式

#### TimeManager

`TimeManager` 发布：
- `season_changed`
- `day_started`

`EffectManager` 订阅这些事件，决定何时添加或移除长期效果。

#### Plot

效果查询的最终应用点应靠近真正消费数值的业务逻辑。  
当前四季生长主链在 `TimeManager -> Plot`，所以季节/状态效果应最终影响：
- `Plot.advance_growth(...)`
- 或 `TimeManager.trigger_crop_growth()` 计算传入值

而不是回到旧式的 `FarmManager` 汇总应用。

#### SaveManager

读档时：
- `SaveManager` 恢复 `TimeManager`
- `SaveManager` 恢复 `EffectManager`
- 完成后发布 `save_loaded`

这样状态系统能保持和现有 Phase 2/3 架构一致。

---

## 实施边界与未来性判断

### 这版方案的优点

- 与现有 0.3.0 架构直接兼容
- 没有把 EventManager 和 signal 混成一套
- 效果查询接口已能覆盖全局、目标、类别三类用途
- 状态存档风格和现有系统一致
- 至少有两个真实 gameplay 闭环，而不是空框架

### 这版方案故意不做的事

- 不做工业级通用事件平台
- 不做 EffectDefinition 模板层
- 不做 AREA 几何效果
- 不做粒度极细的优先级和冲突系统
- 不做网络、回放、版本控制

这不是欠缺，而是本阶段的边界控制。

---

## 验证清单

### 文档一致性

- [ ] 总文档与 Prompt 12/13 的职责划分一致
- [ ] 不再出现 `FarmManager` 作为四季倍率主链路的错误描述
- [ ] 不再出现把 EventManager 当作所有 signal 替代品的描述

### 架构完整性

- [ ] EventManager 的定位清晰：跨系统广播
- [ ] ActiveEffect 的定位清晰：运行时实例
- [ ] EffectManager 查询接口支持 target/category
- [ ] 短期效果更新时间受 TimeManager 暂停状态约束
- [ ] 存档接口风格与当前 SaveManager 模式一致

### 产品完整性

- [ ] 文档明确至少两个真实效果闭环
- [ ] 文档没有把远期联机/回放等内容当成当前实现负担

---

## 结论

修订后的 Phase 4 方案适合作为 Demo 0.4.0 的开发基线。

它的定位是：
- 先把事件和状态底座接好
- 与 0.3.0 真实代码结构直接兼容
- 保留未来可扩展空间
- 不在本阶段过度抽象

这套方案已经具备**合格的可扩展性和面向未来性**，可以支撑后续天气、NPC、任务、建筑等系统继续接入。

---

**文档版本**：v3.0  
**修订日期**：2026-04-04  
**适用阶段**：Demo 0.4.0 - 事件系统与状态系统  
**下一步**：按 Prompt 12 和 Prompt 13 分次进入代码实现
