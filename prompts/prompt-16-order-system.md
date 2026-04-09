# Phase 5-C: 订单与农场经济反馈系统实现提示词

## 任务概述

为 FarmDemo 实现轻量订单系统，让玩家在“直接售卖”和“为了更高回报保留产出”之间做选择。

这是 Demo 0.5.0 的第三部分，依赖 Prompt 14 的体力系统和 Prompt 15 的多作物经营系统。  
本阶段目标不是做完整任务系统，而是先给农场经济加入短中期目标层。

---

## 核心定位

### 1. 订单不是剧情任务

本阶段的 `Order` 应被理解为：

- 轻量经营订单
- 公告板委托
- 可刷新、可提交、可结算的资源目标

不是：

- 完整 NPC 叙事任务
- 多阶段剧情线
- 条件复杂的成就树

### 2. 订单系统的价值在于“让玩家暂时不卖”

当前经济链路是：

`收获 -> 商店售卖 -> 得金币`

本阶段要让玩家第一次面对：

- 现在卖，拿即时收益
- 留着做订单，拿更高收益

这才是订单系统的核心意义。

### 3. 订单先做轻量系统，不要过度框架化

本阶段可以新增：

- `OrderManager`

但不要一上来做成：

- 通用任务框架
- 剧情/委托/成就统一系统

---

## 交付范围

### 必做内容

- `OrderManager` autoload 单例
- 订单数据结构
- 每日或节气刷新订单
- 订单查询、提交、完成结算
- 订单进入存档/读档
- UI 查看订单与提交订单
- 至少 3 条可玩的示例订单

### 本阶段不做

- NPC 发单人系统
- 多步骤链式订单
- 稀有度/权重池
- 特殊剧情奖励
- 探索掉落类订单

---

## 文件结构

```text
scripts/systems/
└── order_manager.gd

scripts/ui/
└── order_board_ui.gd

scenes/systems/
└── order_manager.tscn

scenes/ui/
└── order_board_ui.tscn
```

说明：

- `OrderManager` 建议作为新 autoload
- `UIRoot` 需要接入订单界面

---

## 最低订单数据结构

订单最低应包含：

```gdscript
{
    "order_id": "daily_wheat_01",
    "title": "交付小麦",
    "item_id": "crop_wheat",
    "required_count": 6,
    "reward_gold": 120,
    "reward_items": {},
    "status": "active"
}
```

至少需要的字段：

- `order_id`
- `title`
- `item_id`
- `required_count`
- `reward_gold`
- `reward_items`
- `status`

状态最低支持：

- `active`
- `completed`

本阶段不要求做 `claimed`、`expired`、`failed` 等复杂状态。

---

## OrderManager 核心 API

至少提供：

```gdscript
func get_active_orders() -> Array[Dictionary]
func refresh_daily_orders() -> void
func can_submit_order(order_id: String) -> bool
func submit_order(order_id: String) -> Dictionary
func export_save_data() -> Dictionary
func apply_save_data(data: Dictionary) -> void
```

### 返回结果要求

`submit_order()` 至少返回：

```gdscript
{
    "success": true,
    "message": "订单完成",
    "reward_gold": 120,
    "reward_items": {}
}
```

---

## 刷新规则

推荐本阶段采用：

- 每天开始时刷新一批订单

可选保留：

- 后续扩展为节气刷新

### 与当前系统的正确集成方式

推荐订阅：

- `day_started`
- 可选 `save_loaded`

通过 `EventManager` 完成刷新，而不是让 `TimeManager` 直接知道 `OrderManager`。

---

## 与现有系统的集成要求

### 1. GameManager

订单提交与奖励结算必须通过 `GameManager` 完成：

- 扣除需求物品
- 发放金币奖励
- 发放额外物品奖励

不要直接在 `OrderManager` 内部操作多个零散节点状态。

### 2. SaveManager

遵守当前项目风格：

- `OrderManager.export_save_data()`
- `OrderManager.apply_save_data()`
- `SaveManager` 只做编排

### 3. UIRoot

订单界面应纳入当前模态 UI 体系，不要绕开 `UIRoot` 私自开关界面。  
也就是说：

- 需要可注册为 modal
- 开关时与现有背包/商店/PauseMenu 行为一致

### 4. ShopUI

本阶段不要求把订单系统强耦合进 `ShopUI`。  
订单 UI 和商店 UI 应是两个相邻但独立的界面。

---

## 示例订单要求

至少提供 3 条示例订单，建议覆盖：

1. 低门槛基础订单  
   例如：交 3 个基础作物，奖励略高于直接售卖

2. 中等数量订单  
   例如：交 6 到 8 个作物，奖励更高

3. 季节性或收益型订单  
   例如：要求某个利润型作物

### 奖励原则

- 奖励必须高于直接卖出总价
- 但不应高到让“直接售卖”彻底失去意义

---

## UI 要求

新增 `OrderBoardUI`，最低要求：

- 显示当前活跃订单列表
- 每条订单显示标题、需求数量、奖励金币
- 有提交按钮
- 提交后立即刷新显示
- 提交失败时显示原因

本阶段不要求复杂分页、筛选或美术强化。

### 推荐交互

- 订单界面绑定一个新输入动作，例如 `open_orders`
- 或通过公告板交互打开

如果新增输入动作，必须同步更新：

- `project.godot`
- `UIRoot`

---

## 存档要求

订单系统必须存：

- 当前活跃订单列表
- 已完成订单状态
- 本轮刷新用到的必要数据

最低目标：

- 读档后玩家看到的订单状态与存档前一致

本阶段不要求跨天历史统计。

---

## 验收标准

### 基础功能

- `OrderManager` 单例正常启动
- 可生成并返回当前订单列表
- 可验证订单是否可提交
- 可提交订单并返回结果
- 奖励发放正确

### 集成功能

- `day_started` 后可刷新订单
- 背包足够时订单可提交
- 背包不足时订单被拒绝
- 订单状态进入存档和读档
- UI 可查看并提交订单

### 错误处理

- 不存在的 `order_id` 不会导致崩溃
- 存档缺失订单字段时有默认回退
- 奖励配置缺失时给 warning，而不是静默失败

---

## 实现建议

### 推荐做法

订单数据先使用轻量字典数组即可，不强制本阶段上 Resource 化。

原因：

- 本阶段重点是闭环成立
- 订单数量很少
- 先把刷新、提交、奖励链路跑通更重要

### 不推荐做法

```gdscript
# 不要一上来做完整任务系统基类、目标系统、步骤系统
class_name QuestBase
class_name QuestStep
class_name QuestReward
```

这会明显超过本阶段范围。

---

## 手动测试建议

1. 进入游戏，打开订单界面，确认有订单显示
2. 背包不足时尝试提交，确认失败且提示明确
3. 准备足够作物后提交，确认物品被扣除、金币增加
4. 进入下一天，确认订单按设计刷新
5. 存档并读档，确认订单状态保持一致
