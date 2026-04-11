# Phase 5-D: 背包、快捷栏与商店 UI 重构实现提示词

## 任务概述

为 FarmDemo 把当前“字典背包 + 按钮列表商店”升级为更适合中期内容量的 UI 与数据结构：

- `10×5` 固定槽位背包
- 第一行即主界面 `1~0` 快捷栏
- 可手动交换槽位位置
- 商店改为“左买右卖”的双栏格子界面

这是 Demo `0.6.0` 的 UI 与交互重构阶段。  
本阶段目标不是追求复杂拖拽和精致美术，而是先把“物品数量变多后仍然可管理、可筛选、可快速切换”的主体验跑通。

---

## 核心定位

### 1. 背包必须从“数量表”升级为“槽位容器”

当前项目在 Prompt 15 后已经有多种：

- 工具
- 种子
- 作物

再继续沿用：

`item_id -> count`

虽然可以勉强显示数量，但无法自然支持：

- 固定热栏
- 槽位交换
- 快捷键 1~0
- 主界面和背包同源显示

因此本阶段必须让背包的真实来源变成“固定槽位数组”。

### 2. 快捷栏必须和背包第一行是同一套数据

本阶段的热栏不是独立第二套结构。  
要求：

- 背包第一行 10 格就是热栏
- 主界面 HUD 只显示这 10 格
- 玩家在背包里调整第一行顺序后，HUD 立即同步

这样可以避免：

- 背包和热栏各自维护一份数据
- 物品切换状态不同步

### 3. 商店要从“长按钮列表”变成“格子浏览”

当前内容量继续增长后，纵向按钮列表会快速失控。  
本阶段商店的核心价值是：

- 快速浏览
- 分类筛选
- 清楚看到价格和持有数量

不是复杂详情面板，也不是拖拽购物车。

---

## 交付范围

### 必做内容

- `GameManager` 改为 50 槽位背包
- 第一行 10 格热栏
- `1~0` 数字键切换热栏
- `Q / E` 作为热栏循环切换
- `InventoryUI` 改为 `10×5` 固定格子
- 背包筛选：`全部 / 工具 / 种子 / 作物`
- 点击选中 + 点击交换槽位
- 主界面常驻 `HotbarUI`
- `ShopUI` 改为双栏格子界面
- 商店两侧分类筛选
- 存档兼容旧字典背包

### 本阶段不做

- 拖拽操作
- 拆分堆叠
- 丢弃物品
- 批量购买/售卖
- 复杂道具详情弹窗
- 鼠标悬浮 Tooltip 系统

---

## 文件结构

```text
scripts/systems/
└── game_manager.gd

scripts/ui/
├── inventory_ui.gd
├── hotbar_ui.gd
└── shop_ui.gd

scripts/actors/player/
└── player_input_bridge.gd

scenes/ui/
├── inventory_ui.tscn
├── hotbar_ui.tscn
└── shop_ui.tscn

project.godot
```

说明：

- `GameManager` 是本阶段最关键的底层变更点
- `UIRoot` 需要接入新的 `HotbarUI`
- 输入映射要同步更新到 `project.godot`

---

## GameManager 背包模型要求

### 新增核心字段

至少具备：

```gdscript
@export var inventory_slots: Array = []
@export var current_hotbar_index: int = 0
```

约定：

- 背包总槽位数固定为 `50`
- 每个槽位结构统一为：

```gdscript
{}
```

或：

```gdscript
{
    "item_id": "seed_wheat",
    "count": 5
}
```

### 保留旧接口语义

以下旧接口必须继续可用：

```gdscript
func add_item(item_id: String, count: int = 1) -> void
func remove_item(item_id: String, count: int = 1) -> bool
func has_item(item_id: String, count: int = 1) -> bool
func get_item_count(item_id: String) -> int
```

但实现应基于 `inventory_slots`，而不是继续以 `inventory` 字典为主。

### 必须新增的 API

至少新增：

```gdscript
func get_inventory_slots() -> Array
func get_hotbar_slots() -> Array
func swap_inventory_slots(from_index: int, to_index: int) -> bool
func set_current_hotbar_index(index: int) -> void
func get_current_hotbar_index() -> int
```

### 信号要求

至少新增：

```gdscript
signal inventory_slots_changed(slots: Array)
signal hotbar_changed(slots: Array, current_index: int)
```

---

## 存档兼容要求

### 1. 新存档结构

`export_save_data()` 应包含：

- `inventory_slots`
- `current_hotbar_index`
- 兼容保留的 `inventory`

### 2. 旧存档迁移

若旧档只有：

```gdscript
"inventory": {
    "hoe_wood": 1,
    "seed_wheat": 5
}
```

必须自动迁移到 50 槽位结构。

推荐迁移规则：

- 工具优先进入热栏
- 种子其次进入热栏
- 其余物品按分类和名称顺序进入后续槽位

### 3. 默认新局布局

新游戏至少保证：

- 木锄头在热栏
- 木水壶在热栏
- 木镰刀在热栏
- 初始小麦种子在热栏

---

## 物品分类规则

本阶段统一使用四类：

- `tool`
- `seed`
- `crop`
- `other`

分类来源：

- `ToolConfig` -> `tool`
- `CropConfig.seed_item_id` -> `seed`
- `CropConfig.harvest_item_id` -> `crop`
- 其余 -> `other`

建议通过 `ConfigManager` 增加统一入口：

```gdscript
func get_item_category(item_id: String) -> String
```

不要把分类判断散落在多个 UI 文件里各写一套。

---

## InventoryUI 要求

### 布局

- 固定 `10×5` 格子
- 第一行显示热栏编号：`1 2 3 4 5 6 7 8 9 0`
- 顶部有筛选按钮：
  - `全部`
  - `工具`
  - `种子`
  - `作物`

### 槽位显示

每个格子最低显示：

- 图标
- 数量
- 当前装备高亮
- 选中交换高亮

空槽要求：

- 不显示名称文字
- 只保留空槽底板

### 交互规则

- 第一次左键点击：选中槽位
- 第二次点击另一格：交换两格内容
- 点击同一格：取消选中
- 点击热栏格：同步切换当前装备

### 筛选规则

筛选只影响显示高亮/浏览，不改变真实槽位位置。  
也就是说：

- 真实物品位置不变
- 不匹配当前筛选的格子可以变暗
- 不要在筛选时自动重排背包

---

## HotbarUI 要求

### 功能定位

主界面新增常驻 `HotbarUI`，只显示 `inventory_slots[0..9]`。

### 显示要求

- 显示 10 格
- 当前热栏索引高亮
- 显示快捷编号 `1~0`
- 显示图标和数量

### 同步要求

以下行为必须实时同步：

- 数字键切换
- `Q / E` 循环切换
- 背包第一行交换顺序
- 商店买到新种子进入热栏空槽

---

## 输入映射要求

`project.godot` 中至少新增：

- `hotbar_slot_1`
- `hotbar_slot_2`
- ...
- `hotbar_slot_10`

默认绑定：

- `1` 到 `0`

并要求：

- `Q` = 向前切换热栏
- `E` = 向后切换热栏
- `F` = 交互

如果已有旧映射，必须同步更新提示文本，避免输入和 UI 文案不一致。

---

## ShopUI 要求

### 布局

改为双栏：

- 左侧购买区
- 右侧售卖区

每一侧最低包含：

- 标题
- 分类筛选
- 滚动格子区

### 筛选要求

购买区和售卖区各自独立维护筛选状态：

- `全部`
- `工具`
- `种子`
- `作物`

### 商品格最低信息

购买区：

- 图标
- 名称
- 价格

售卖区：

- 图标
- 名称
- 价格
- 持有数量

### 数据来源要求

售卖区持有数量必须来自当前玩家真实背包汇总数量。  
不要继续假设 UI 自己保存一份库存。

---

## 与现有系统的集成要求

### 1. PlayerInputBridge

玩家切换逻辑必须从“按工具列表切换”切换为“按热栏槽位切换”。

要求：

- `tool_next / tool_previous` 基于热栏
- 数字键直接指定热栏槽位
- `get_current_tool()` 仍返回当前装备物品 ID，保证种田系统兼容

### 2. UIRoot

`UIRoot` 必须接入新的 `HotbarUI`，但不要把它纳入模态 UI。  
它应是常驻 HUD，而不是 `open_modal()` 体系的一部分。

### 3. Plot / FarmInteractionSystem

本阶段不要求改动农田动作规则本身。  
只要求：

- 当前手持项来源切换为热栏后，种田链路仍然正常

---

## 验收标准

### 背包基础功能

- 背包固定显示 50 格
- 第一行可作为热栏使用
- 点击两格可交换物品
- 筛选按钮生效

### 热栏功能

- 主界面显示 10 格热栏
- `1~0` 可切换热栏
- `Q / E` 可循环切换
- 当前选中热栏会高亮

### 商店功能

- 左买右卖双栏正常显示
- 两侧都可筛选
- 持有数量显示正确
- 购买后物品进入槽位背包

### 存档兼容

- 旧字典背包存档可正常读取
- 新存档保存槽位结构
- 读档后热栏和背包状态一致

### 回归要求

- 体力系统不受影响
- 多作物播种/收获链路不受影响
- `ESC` 菜单、暂停、商店、背包开关仍然正常

---

## 实现建议

### 推荐做法

先完成顺序：

1. `GameManager` 槽位化
2. `PlayerInputBridge` 改热栏切换
3. `InventoryUI` 改 `10×5`
4. 新增 `HotbarUI`
5. `ShopUI` 双栏格子化

### 不推荐做法

```gdscript
# 不要让 InventoryUI 自己维护一份 slots
var local_inventory_slots = []
```

原因：

- 会和 `GameManager` 真正状态分叉
- 商店、HUD、背包之间容易不同步

---

## 手动测试建议

1. 新开游戏，确认热栏与背包第一行一致
2. 用 `1~0`、`Q / E` 切换装备，确认 HUD 高亮变化正确
3. 在背包中交换第一行物品，确认主界面热栏同步
4. 打开商店，确认左右两栏和筛选显示正常
5. 购买种子后确认进入背包/热栏
6. 存档并读档，确认槽位顺序和当前装备保持一致
