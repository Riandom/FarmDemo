# Phase 4-A: 事件系统实现提示词

## 任务概述

为 FarmDemo 实现 `EventManager`，作为跨系统广播层使用。  
本阶段只做**跨系统事件总线**，不替代 Godot signal。

这是 Demo 0.4.0 的第一部分，目标是先把事件目录、订阅机制和与现有 0.3.0 系统的集成方式接稳。

---

## 核心原则

### 1. 何时使用 EventManager

只在以下情况使用 EventManager：
- 跨系统广播
- 发布者不应该直接知道订阅者是谁
- 事件需要被多个独立系统同时消费

典型示例：
- `TimeManager` 发布 `season_changed`
- `TimeManager` 发布 `day_started`
- `SaveManager` 发布 `save_loaded`
- `EffectManager` 发布 `effect_added` / `effect_expired`

### 2. 何时继续使用 Godot signal

以下情况继续使用原生 signal：
- 单个节点或单个场景内部通信
- `Plot.state_changed`
- UI 内部控件更新
- 本地节点生命周期通知

**不要把 EventManager 做成“所有 signal 的替代品”。**

---

## 交付范围

### 必做内容
- `EventManager` autoload 单例
- 订阅接口
- 取消订阅接口
- 全量取消订阅接口
- 发布接口
- 事件历史记录接口
- 重复订阅保护
- 与 `TimeManager` 的 `season_changed` / `day_started` 集成
- 与 `SaveManager` 的 `save_loaded` 集成预留

### 本阶段不做
- 优先级系统
- 条件过滤订阅
- 事件版本控制
- 回放系统
- 网络同步

---

## 最小事件目录

Demo 0.4.0 中 `EventManager` 至少要能支持以下事件：

| 事件名 | 发布者 | 说明 |
|---|---|---|
| `season_changed` | `TimeManager` | 季节变化完成 |
| `day_started` | `TimeManager` | 新的一天开始 |
| `save_loaded` | `SaveManager` | 读档完成 |
| `effect_added` | `EffectManager` | 效果激活 |
| `effect_expired` | `EffectManager` | 效果过期 |

命名规范：
- 小写 + 下划线
- 事件名表达“已发生的事”
- 不用含糊缩写

---

## 文件结构

```text
scripts/systems/
└── event_manager.gd

scenes/systems/
└── event_manager.tscn
```

---

## 核心 API

```gdscript
func subscribe(event_type: String, callback: Callable) -> void
func unsubscribe(event_type: String, callback: Callable) -> void
func unsubscribe_all(callback: Callable) -> void
func publish(event_type: String, data: Dictionary = {}) -> void
func get_event_history(last_n: int = 10) -> Array[Dictionary]
```

### 强制约束
- 必须防止重复订阅
- 取消不存在的订阅时不能崩溃
- 允许某个对象在 `_exit_tree()` 中批量取消订阅
- 事件历史只用于调试，不允许业务系统依赖它
- 历史记录必须有上限，不能无限增长

---

## 推荐内部结构

```gdscript
var _subscriptions: Dictionary = {}
var _event_history: Array[Dictionary] = []
var _max_history_size: int = 100
```

其中：
- `_subscriptions` 结构为 `{ event_type: Array[Callable] }`
- `_event_history` 每项至少包含 `timestamp`、`event_type`、`data`

---

## 与现有系统的集成要求

### 1. TimeManager 集成

`TimeManager` 必须成为第一个真实发布者。

需要发布两个事件：
- `season_changed`
- `day_started`

`season_changed` 示例数据：

```gdscript
{
    "old_season": "spring",
    "new_season": "summer",
    "year_count": 1,
    "solar_term": "lichun",
    "day_in_term": 1
}
```

`day_started` 示例数据：

```gdscript
{
    "season": "spring",
    "year_count": 1,
    "solar_term": "yushui",
    "day_in_term": 3
}
```

注意：
- 不允许再写 `year_day_count` 这种当前代码里不存在的字段
- 不要求删除 `TimeManager` 现有 Godot signals，保留并存即可

### 2. SaveManager 集成

本 Prompt 只要求把 `save_loaded` 的事件接口和调用位置设计清楚。  
如果在 Prompt 12 实现期内一并接入，可以在读档成功后广播：

```gdscript
EventManager.publish("save_loaded", {
    "slot_type": "manual",
    "slot_index": 2
})
```

### 3. 不再以 FarmManager 作为主示例

不要再把 `FarmManager` 写成“季节变化后统一应用倍率”的主方案。  
当前 0.3.0 的真实生长链路已经是 `TimeManager -> Plot`，Prompt 12 必须与这个现实保持一致。

---

## project.godot 要求

新增 autoload：

```ini
[autoload]
EventManager="*res://scenes/systems/event_manager.tscn"
```

位置要求：
- `EventManager` 必须早于依赖它发布或订阅事件的系统注册
- 最低要求是放在 `TimeManager`、`SaveManager`、`EffectManager` 之前
- 推荐顺序是让它作为 Phase 4 的第一个新增基础单例，避免 `_ready()` 时访问未初始化的事件总线

---

## 验收标准

### 基础功能
- [ ] EventManager 单例正常启动
- [ ] 可以订阅事件
- [ ] 可以取消订阅
- [ ] 可以取消某个回调的全部订阅
- [ ] 发布事件后所有订阅者都能收到数据
- [ ] 重复订阅会出现 warning
- [ ] 获取最近 N 条事件历史正常
- [ ] 事件历史不会无限增长

### 集成功能
- [ ] `TimeManager` 能发布 `season_changed`
- [ ] `TimeManager` 能发布 `day_started`
- [ ] `save_loaded` 事件目录已预留或已接入
- [ ] 现有局部 signal 不受影响

### 错误处理
- [ ] 发布没有订阅者的事件不会崩溃
- [ ] 取消不存在的订阅不会崩溃
- [ ] 回调异常不会导致整个事件系统静默失效

---

## 实现建议

### 推荐做法
```gdscript
func subscribe(event_type: String, callback: Callable) -> void:
    if not _subscriptions.has(event_type):
        _subscriptions[event_type] = []
    if callback in _subscriptions[event_type]:
        push_warning("[EventManager] Callback already subscribed: %s" % event_type)
        return
    _subscriptions[event_type].append(callback)
```

### 不推荐做法
```gdscript
# 不要把复杂对象直接作为事件数据主载荷
EventManager.publish("season_changed", {
    "time_manager": self,
    "plot": plot_object
})
```

事件数据优先传：
- ID
- 字符串
- 数值
- 小型字典

---

## 交付结论要求

Prompt 12 完成后，项目应拥有：
- 一套最小可用的跨系统事件总线
- 与 `TimeManager` 的真实集成
- 与 `SaveManager` / `EffectManager` 的后续接入点
- 明确的“EventManager 与 signal 分工边界”

---

**文档版本**：v2.0  
**修订日期**：2026-04-04  
**适用阶段**：Demo 0.4.0 - Prompt 12 事件系统  
**下一步**：在实现完成后，再进入 Prompt 13 状态系统
