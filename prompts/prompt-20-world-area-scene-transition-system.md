# Phase 7-B：世界区域与场景切换系统实现提示词

## 任务概述

为 FarmDemo 建立统一的世界区域与场景切换系统，正式把以下区域纳入同一套运行骨架：

- `farm`
- `house`
- `town`
- `cave`

本阶段目标不是制作大量地图内容，而是先把“区域进入、区域返回、出生点、当前区域状态、UI 显示差异、存档恢复”这些底层问题统一起来。

这是 `Phase 7` 的骨架阶段。  
后续小屋、镇子、NPC、商店入口和洞窟入口，都必须建立在这层系统之上。

---

## 核心定位

### 1. 这是区域系统，不是地图美术任务

本阶段解决的是：

- 玩家当前在哪个区域
- 如何进入另一个区域
- 切换后出生点放哪里
- 哪些 UI 只在特定区域显示
- 存档读档后如何回到正确区域

本阶段不解决：

- 镇子剧情内容
- 小屋家具系统
- 洞窟玩法深化
- NPC 关系系统

### 2. 小屋技术上是独立区域

虽然产品上小屋属于农场，但技术上必须把它当作独立区域 `house`。

原因：

- 室内外显示规则不同
- 后续睡觉、私人储物、家具和室内互动都依赖独立区域
- 能避免把农场主场景越塞越重

### 3. 先做轻量方案，不引入复杂异步加载

本阶段应采用轻量、可验证、能平滑接入现有架构的方案。

允许：

- 主场景中挂载多个区域子场景
- 通过显示/隐藏 + 玩家重定位完成第一版切换
- 或采用简化的子场景加载切换

但不应上：

- 复杂异步加载框架
- 大地图无缝流式切换
- 多区域后台保活调度器

---

## 交付范围

### 必做内容

- 统一定义世界区域 ID
- 新增区域切换管理层
- 提供统一区域进入接口
- 支持从农场进入：
  - 小屋
  - 镇子
  - 洞窟
- 支持从上述区域返回农场
- 支持出生点/入口点定位
- `GameManager.current_world_area` 与实际区域同步
- UI 可依据当前区域决定显示状态
- 存档和读档可恢复当前区域或按设计安全回退

### 本阶段不做

- 镇子细节内容
- 小屋内部生活玩法
- NPC 交互系统
- 多层洞窟
- 区域切换动画特效
- 复杂镜头切换系统

---

## 文件结构建议

```text
scripts/systems/
└── world_area_manager.gd

scripts/world/interactables/
├── area_transition_point.gd
└── return_transition_point.gd

scripts/app/
└── main.gd

scripts/systems/
├── game_manager.gd
└── save_manager.gd
```

说明：

- `WorldAreaManager` 是本阶段的新核心
- 区域传送点不要分散在各场景各写一套逻辑
- `Main` 仍可保留为当前主场景入口，但区域切换职责应逐步收敛给专门管理层

---

## 世界区域定义要求

### 固定区域 ID

第一版统一使用：

```gdscript
"farm"
"house"
"town"
"cave"
```

不要出现：

- `home`
- `inside_house`
- `village`
- `mine`

这类并存命名。

### 区域状态真相来源

当前真相来源应保持为：

```gdscript
GameManager.current_world_area
```

但本阶段之后，所有区域切换都不应直接手写改这个字段，而应统一走：

```gdscript
WorldAreaManager.request_enter_area(area_id, entry_point_id)
```

或等价接口。

---

## WorldAreaManager 要求

### 核心职责

至少负责：

- 当前区域切换请求
- 区域合法性校验
- 进入目标区域
- 按入口点放置玩家
- 更新 `GameManager.current_world_area`
- 发出区域变更信号

### 必须提供的 API

至少提供：

```gdscript
func request_enter_area(area_id: String, entry_point_id: String = "") -> bool
func return_to_area(area_id: String, entry_point_id: String = "") -> bool
func get_current_area() -> String
func get_previous_area() -> String
```

### 信号建议

至少建议有：

```gdscript
signal world_area_will_change(from_area: String, to_area: String)
signal world_area_changed(from_area: String, to_area: String)
```

如果现有项目继续复用 `GameManager.world_area_changed`，也必须保证对外行为清晰，不出现双重真相来源。

---

## 区域入口与出生点要求

### 入口点机制

每个区域都应支持命名入口点，例如：

- `farm_from_house`
- `farm_from_town`
- `farm_from_cave`
- `house_from_farm`
- `town_from_farm`
- `cave_from_farm`

本阶段不要求通用数据表，但要求命名清晰且统一。

### 玩家重定位要求

区域切换后必须：

- 找到目标入口点
- 将玩家放到该位置
- 重置必要的交互状态

不允许出现：

- 玩家还停留在旧区域坐标
- 切换后 UI 状态错乱
- 进入新区域后立刻又触发入口

---

## 与现有洞窟原型的整合要求

现有 `cave` 已经有战斗原型。  
本阶段要做的是把它纳入统一区域系统，而不是重做战斗。

要求：

- 洞窟入口不再只是一段孤立传送逻辑
- 洞窟退出和战败返回都应与区域系统兼容
- 洞窟专属 HUD 继续由当前区域决定显隐

本阶段不允许：

- 新增敌人
- 新增洞窟房间
- 新增战斗武器

---

## 与存档系统的整合要求

### 必须保存的区域状态

存档至少要能恢复：

- 当前区域 ID
- 必要时的入口点信息

### 兼容策略

旧档若没有区域信息：

- 默认安全回退到 `farm`

不要因为旧档缺字段直接报错。

### 版本建议

若 `Prompt 19` 已升到 `0.8.0`，本阶段可继续升到：

- `0.8.1`

但必须兼容读取 `0.8.0` 和 `0.7.x`。

---

## UI 与交互整合要求

区域切换后，以下内容必须正常：

- 洞窟生命 UI 仅在 `cave` 显示
- 农场交互提示不在非农场区域乱出现
- 模态 UI 打开时不应允许误触发区域切换
- 返回后玩家控制状态恢复正常

本阶段重点是“稳定性”，不是视觉表现。

---

## 验收标准

- 玩家能在 `farm -> house -> farm` 间稳定往返
- 玩家能在 `farm -> town -> farm` 间稳定往返
- 玩家能在 `farm -> cave -> farm` 间稳定往返
- 切换后玩家出生点正确
- `GameManager.current_world_area` 始终与实际区域一致
- 存档读档后区域状态正确或安全回退
- 现有背包、订单、商店、洞窟原型不因区域系统接入而回归损坏

---

## 实现建议

### 建议优先顺序

1. 先定义统一区域 ID 和管理器接口
2. 再改造现有洞窟入口/返回链路接入这套系统
3. 再接入小屋和镇子占位区域
4. 最后补存档与 UI 区域同步

### 推荐做法

- 先保留现有 `Main` 作为主入口
- 用区域管理器统一调度
- 让交互入口都走统一传送 API

### 不推荐做法

- 农场、小屋、镇子、洞窟各写一套切换逻辑
- 直接在多个脚本里随手改 `current_world_area`
- 把存档恢复和区域切换混成一坨条件分支

