# Phase 5-B: 多作物与季节经营系统实现提示词

## 任务概述

为 FarmDemo 把当前单一小麦链路扩展为多作物、可比较、受季节影响的轻量经营系统。

这是 Demo 0.5.0 的第二部分，依赖 Prompt 14 的体力系统。  
本阶段目标不是一次性堆很多内容，而是先让玩家在“种什么、什么时候种、是否值得种”之间做选择。

---

## 核心定位

### 1. 本阶段重点是“作物差异”，不是“作物数量”

3 到 5 种作物就够。  
关键是它们之间必须有真实区别，而不是只换名字和贴图。

### 2. 必须去掉当前单作物硬编码

当前项目里仍存在多处：

- `seed_wheat`
- `crop_wheat`
- `crop_wheat` 唯一作物收益

这些在本阶段必须从主链路中退场，至少做到：

- 地块播种读取 `crop_config_id`
- 背包与商店可显示多作物
- 收获产物按作物配置返回

### 3. 继续走 ConfigManager 统一入口

本阶段新增作物必须继续通过：

- `resources/data/crops/*.tres`
- `ConfigManager.get_crop_config()`

接入，不允许为了快而把新作物数据写回：

- `Plot`
- `ShopUI`
- `InventoryUI`

---

## 交付范围

### 必做内容

- 扩展 `CropConfig` 经营字段
- 新增至少 3 个可玩作物配置
- 商店支持购买多种种子
- 地块支持播种不同作物
- 收获按当前作物配置发放产物
- 背包 UI 支持显示多种种子/作物
- 季节限制真正影响播种决策

### 本阶段不做

- 大量新贴图资产
- 品质系统
- 肥料系统
- 多地块类型
- 天气联动

---

## 推荐内容结构

至少包含以下定位：

| 类型 | 特征 |
|---|---|
| 快生长低利润 | 成熟快，收益低，适合短周转 |
| 中庸型 | 周期和收益平衡 |
| 慢生长高利润 | 占地时间长，但收益更高 |
| 季节限制型 | 至少有 1 个明确依赖适种季节 |

推荐保留现有小麦，并新增 2 至 4 种作物。

---

## 文件结构

```text
scripts/data/
└── crop_config.gd

scripts/systems/
├── config_manager.gd
└── farm_interaction_system.gd

scripts/world/farm/
└── plot.gd

scripts/ui/
├── inventory_ui.gd
└── shop_ui.gd

resources/data/crops/
├── wheat_config.tres
├── turnip_config.tres
├── bean_config.tres
└── pumpkin_config.tres
```

说明：

- 文件名可根据作物命名调整
- 但必须至少新增 2 个 `.tres`

---

## CropConfig 扩展要求

在当前字段基础上，至少新增：

```gdscript
@export var seed_item_id: String = ""
@export var harvest_item_id: String = ""
@export var seed_price: int = 0
@export var sell_price: int = 0
@export var description: String = ""
```

如果已有 `sell_price_base`，本阶段应统一命名，避免同时保留两套近义字段。  
推荐直接收敛为：

- `sell_price`

### 强制约束

- `crop_id`、`seed_item_id`、`harvest_item_id` 不能为空
- `ConfigManager` 读取后必须可用作统一商品来源
- `yield_base` 继续保留作为产量字段

---

## 与现有系统的集成要求

### 1. Plot

当前 `Plot` 中有这些硬编码需要退场：

- 播种默认消耗 `seed_wheat`
- 收获默认产出 `crop_wheat`
- 提示文本默认写成“小麦种子”

本阶段应改为：

- 根据 `crop_config_id` 查 `CropConfig`
- 播种时消耗 `seed_item_id`
- 收获时产出 `harvest_item_id`
- 提示文本显示当前配置的作物名

### 2. FarmInteractionSystem

当前它通过 `crop_config_id` 放进 `ActionContext`，这条路应保留。  
本阶段要求：

- 当前手持种子决定 `crop_config_id`
- 不能再默认只有 `crop_wheat`

推荐增加“根据当前手持种子 item_id 反查 crop_config”的小型辅助方法。

### 3. ShopUI

商店购买列表必须从当前多作物配置中得出，而不是只卖一套小麦种子。  
本阶段允许继续沿用 `ShopConfig`，但要求：

- 至少把多种种子接入购买区
- 售卖区支持多种作物产出
- 显示名称和价格都来自配置/商店表

### 4. InventoryUI

当前 `InventoryUI._format_item_name()` 中是固定匹配。  
本阶段必须至少支持：

- 新增作物和种子不会只显示原始 ID
- 名称映射不再只服务小麦

允许做法：

- 增加统一的物品名称映射表
- 或通过 `ConfigManager` / 商店表推导显示名

但不要继续单独为每个新增作物手写分支。

---

## 适种季节规则

### 最低要求

- `CropConfig.suitable_seasons` 真正参与播种限制
- 不适季作物不能播种
- UI 提示要明确说明原因

### 推荐玩家提示

```gdscript
"当前季节不适合播种%s" % crop_display_name
```

不要继续只显示泛化的“无法播种”。

---

## 数据接入要求

### 1. 新增作物资源

至少新增：

- 1 种春季友好作物
- 1 种夏季友好作物
- 1 种收益型作物

### 2. 旧存档兼容

旧档中的：

- `crop_config_id = "crop_wheat"`

仍必须可读取，不允许因为新增作物而破坏旧档。

### 3. 默认背包与默认商店

要补齐最小默认值：

- 初始背包允许玩家买或持有至少一种新增种子
- 商店中有明确的种子购买入口

---

## 验收标准

### 基础功能

- 至少 3 种作物可配置、可读取、可显示
- 每种作物有不同经营定位
- 商店可购买多种种子
- 地块可播种不同作物
- 收获结果与当前作物对应

### 集成功能

- 背包能正确显示多种作物和种子
- 不适季时无法播种
- 玩家提示文本能显示正确作物名
- 旧档读入后不崩溃

### 错误处理

- 缺失作物配置时给 warning，而不是直接崩溃
- 未知种子 item_id 不导致播种链路静默失败
- 商店中缺失图标路径时 UI 仍可打开

---

## 实现建议

### 推荐做法

在 `ConfigManager` 中补一类辅助查找：

```gdscript
func get_crop_config_by_seed_item(seed_item_id: String) -> CropConfig
```

这样：

- `FarmInteractionSystem` 可从手持种子反查作物
- UI 也可重用同一入口

### 不推荐做法

```gdscript
if current_tool == "seed_wheat":
    crop_config_id = "crop_wheat"
elif current_tool == "seed_turnip":
    crop_config_id = "crop_turnip"
...
```

原因：

- 扩作物时会快速失控
- 与当前数据驱动方向冲突

---

## 手动测试建议

1. 打开商店，确认能看到多种种子
2. 购买不同种子，确认背包正常显示
3. 在允许季节中播种，确认对应作物生长
4. 在不适季节中播种，确认被拒绝并提示明确
5. 收获不同作物，确认掉落正确、售价正确
