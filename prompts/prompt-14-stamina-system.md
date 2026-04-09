# Phase 5-A: 体力与行动消耗系统实现提示词

## 任务概述

为 FarmDemo 实现最小可用的 `Stamina` 体力系统，用于给现有农场循环加入行动成本和每日节奏压力。

这是 Demo 0.5.0 的第一部分，目标不是做完整生存系统，而是先让以下问题成立：

- 玩家每天不能无限制重复农活
- 玩家需要决定今天把体力花在哪里
- 睡觉/次日开始具有恢复意义

---

## 核心定位

### 1. 体力只服务农场玩法

本阶段的 `stamina`：

- 不是生命值
- 不与未来战斗 HP 共用
- 不引入饥饿/口渴/睡眠多资源系统

它只负责描述：

- 当前还能做多少农活
- 什么时候该结束一天

### 2. 体力检查应集中在 FarmInteractionSystem

当前项目的真实动作执行入口是：

`PlayerInputBridge -> FarmInteractionSystem -> Plot.execute_action()`

因此体力检查的主入口必须放在 `FarmInteractionSystem`，而不是散落到：

- `Plot`
- `Player`
- 各个 UI

否则后面接订单、探索、食物恢复时会很难维护。

### 3. 体力恢复只走明确时机

本阶段只允许两种恢复方式：

- 睡觉跳到下一天时恢复
- 正常进入新的一天时恢复

不做：

- 被动秒回
- 行走中回复
- 道具回复

---

## 交付范围

### 必做内容

- `GameManager` 增加体力字段与信号
- 体力相关 API
- `FarmInteractionSystem` 体力前置检查
- 不同农活动作使用不同消耗
- `SaveManager` 存档/读档支持体力
- 睡觉或 `day_started` 恢复体力
- UI 体力显示
- 体力不足的明确反馈

### 本阶段不做

- 食物恢复
- 体力药剂
- 战斗伤害与生命值
- 耐力上限成长树
- 复杂 debuff / overweight 机制

---

## 文件结构

```text
scripts/systems/
├── game_manager.gd
├── farm_interaction_system.gd
├── save_manager.gd
└── time_manager.gd

scripts/ui/
└── stamina_display.gd

scenes/ui/
└── stamina_display.tscn
```

说明：

- `stamina_display` 为本阶段新增 UI
- `UIRoot` 和 `main` 需要把它接入当前界面结构

---

## GameManager 新增字段与 API

至少新增：

```gdscript
signal stamina_changed(current_stamina: int, max_stamina: int)

@export var stamina: int = 100
@export var max_stamina: int = 100
```

至少新增以下方法：

```gdscript
func spend_stamina(amount: int) -> bool
func restore_stamina(amount: int = -1) -> void
func is_stamina_enough(amount: int) -> bool
func get_stamina_ratio() -> float
```

### 强制约束

- `spend_stamina()` 失败时必须返回 `false`
- 不允许体力变成负数
- `restore_stamina(-1)` 表示直接恢复满
- 恢复后要发 `stamina_changed`
- `export_save_data()` / `apply_save_data()` 必须接入体力字段

---

## 动作消耗规则

推荐默认值：

| 动作 | 消耗 |
|---|---:|
| `plow` | 12 |
| `seed` | 6 |
| `water` | 8 |
| `harvest` | 5 |

### 工程要求

- 消耗值可以先写在 `FarmInteractionSystem` 的常量中
- 不要求本阶段就把消耗完全资源化
- 但必须集中定义，不能散落在多个函数里

例如：

```gdscript
const ACTION_STAMINA_COSTS: Dictionary = {
    "plow": 12,
    "seed": 6,
    "water": 8,
    "harvest": 5,
}
```

---

## 与现有系统的集成要求

### 1. FarmInteractionSystem

在当前执行顺序基础上增加：

1. 验证工具能力
2. 验证地块是否允许动作
3. 读取该动作所需体力
4. 检查 `GameManager.is_stamina_enough()`
5. 若不足，返回失败结果，不执行动作
6. 若足够，先扣体力，再执行动作

### 2. GameManager

`GameManager` 仍然是当前玩家经济和行动状态的中心。  
体力必须进入：

- 默认初始化
- 存档导出
- 存档应用
- 信号广播

### 3. SaveManager

遵守当前项目风格：

- 不新增单独 stamina 文件
- 只通过 `GameManager.export_save_data()` 和 `apply_save_data()` 进入读写链路

### 4. TimeManager

需要提供体力恢复触发点。  
推荐优先复用现有 `day_started` 流程：

- 新一天开始时恢复满体力
- 床互动跳过到次日时同样恢复满体力

不要额外创建第二套“只给体力系统用的日切事件”。

### 5. UI

新增 `StaminaDisplay`，最低要求：

- 显示当前值和上限，例如 `体力 64/100`
- 监听 `GameManager.stamina_changed`
- 首次 `_ready()` 时同步当前状态

本阶段不强制做进度条动画，但显示必须稳定。

---

## 失败反馈要求

### 动作失败时必须明确区分“体力不足”

例如：

```gdscript
{
    "success": false,
    "message": "体力不足，无法继续开垦",
    ...
}
```

不能把体力不足和“地块状态不允许”混成同一条模糊提示。

### 推荐提示语

- `plow`: `体力不足，无法继续开垦`
- `seed`: `体力不足，无法继续播种`
- `water`: `体力不足，无法继续浇水`
- `harvest`: `体力不足，无法继续收获`

---

## 验收标准

### 基础功能

- `GameManager` 有 `stamina` 和 `max_stamina`
- 可以检查体力是否足够
- 可以扣除体力
- 可以恢复体力
- 体力变化时会发出 `stamina_changed`

### 集成功能

- 四类农活都能按动作消耗体力
- 体力不足时动作被拒绝
- 被拒绝时地块状态不发生变化
- 新一天开始后体力恢复
- 睡觉跳到次日后体力恢复
- 体力进入存档和读档
- UI 正常显示体力变化

### 错误处理

- 扣除 0 或负数体力时不崩溃
- 存档缺少体力字段时有默认回退
- `GameManager` 暂时缺失时不导致 UI 崩溃

---

## 实现建议

### 推荐做法

```gdscript
func spend_stamina(amount: int) -> bool:
    if amount <= 0:
        return true
    if stamina < amount:
        return false
    stamina -= amount
    emit_signal("stamina_changed", stamina, max_stamina)
    return true
```

### 不推荐做法

```gdscript
# 不要在 Plot 里各自直接访问 /root/GameManager 扣体力
game_manager.spend_stamina(12)
```

原因：

- 会把体力逻辑散到所有地块实现里
- 后面接入食物、工具减耗、Buff 时难以统一处理

---

## 手动测试建议

1. 进入游戏，观察体力显示是否正常初始化
2. 连续开垦多个地块，确认体力递减
3. 体力不足时尝试继续开垦，确认动作失败且地块不变化
4. 睡觉进入次日，确认体力恢复满值
5. 手动存档后读档，确认体力值保持正确
