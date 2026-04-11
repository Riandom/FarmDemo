# CODEX 提示词使用指南（当前版本）

## 文件说明

本文件夹包含从 `Prompt 01` 到 `Prompt 23` 的阶段提示词，用于分阶段推进 FarmDemo。  
当前项目已经从“项目初始化阶段”推进到“Phase 7 世界区域 / 镇子 / NPC 第一轮骨架已接入阶段”。

这些 Prompt 不再适合按 `01 -> 16` 机械全量重跑。  
正确用法是：

- 旧 Prompt 用于回溯某个历史阶段的实现边界
- 新 Prompt 用于继续推进当前项目

---

## 当前阶段建议

如果你是基于现在这个仓库继续开发，**不要直接继续扩写战斗**。  
`Prompt 19 -> 23` 已经按顺序接入，当前更适合做的是：

- 回归验证
- 文档与索引同步
- 在 `Phase 7` 基础上继续做后续细化功能

建议先看：

1. `docs/phase7-town-npc-world-structure.md`
2. `docs/guides/current-to-full-game-roadmap.md`
3. `docs/phase6-combat-prototype-implementation.md`

Phase 7 已接入内容：

- `19` 农场生活支撑系统补完
- `20` 世界区域与场景切换系统
- `21` 镇子地图、小屋接入与基础入口布局
- `22` NPC 交互框架、基础对话与简单日程
- `23` 好感度、送礼、NPC 委托与镇子商店承载

原因：

- `Prompt 18` 已经把 Phase 6 的战斗探索最小闭环接入到当前仓库
- 当前更适合先冻结战斗原型，转做世界结构、镇子与 NPC 基础层
- 这样能承接现有种田、商店、订单、背包和时间系统

---

## 提示词清单

| 阶段 | 文件名 | 功能定位 | 当前状态 |
|---|---|---|---|
| 0 | `00-PROJECT-OVERVIEW.md` | 项目总览与历史架构背景 | 参考文档 |
| 1 | `prompt-01-project-init.md` | 项目初始化 | 历史阶段 |
| 2 | `prompt-02-player.md` | 玩家控制系统 | 历史阶段 |
| 3 | `prompt-03-plot-system.md` | 地块系统 | 历史阶段 |
| 4 | `prompt-04-ui-system.md` | UI 系统 | 历史阶段 |
| 5 | `prompt-05-main-controller.md` | 主控制器 | 历史阶段 |
| 6 | `prompt-06-player-bridge.md` | 玩家输入桥接 | 历史阶段 |
| 7 | `prompt-07-placeholder-assets.md` | 占位符资源 | 历史阶段 |
| 8 | `prompt-08-save-system.md` | 存档系统 | 已接入 |
| 9 | `prompt-09-time-system.md` | 时间系统 | 已接入 |
| 10 | `prompt-10-data-config-system.md` | 数据配置系统 | 已接入 |
| 11 | `prompt-11-four-seasons-cycle.md` | 四季循环 | 已接入 |
| 12 | `prompt-12-event-system.md` | 事件系统 | 已接入 |
| 13 | `prompt-13-effect-system.md` | 状态/效果系统 | 已接入 |
| 14 | `prompt-14-stamina-system.md` | 体力与行动消耗系统 | 已接入 |
| 15 | `prompt-15-multi-crop-season-economy.md` | 多作物与季节经营系统 | 已接入 |
| 16 | `prompt-16-order-system.md` | 订单与农场经济反馈系统 | 已接入 |
| 17 | `prompt-17-inventory-hotbar-shop-ui.md` | 背包、快捷栏与商店 UI 重构 | 已接入 |
| 18 | `prompt-18-dart-cave-combat-prototype.md` | 飞镖战斗与小型洞窟探索原型 | 已接入原型 |
| 19 | `prompt-19-farm-life-support-system.md` | 农场生活支撑系统补完 | 已接入 |
| 20 | `prompt-20-world-area-scene-transition-system.md` | 世界区域与场景切换系统 | 已接入 |
| 21 | `prompt-21-town-house-layout-and-entry.md` | 镇子地图、小屋接入与基础入口布局 | 已接入 |
| 22 | `prompt-22-npc-interaction-dialogue-schedule.md` | NPC 交互框架、基础对话与简单日程 | 已接入 |
| 23 | `prompt-23-affinity-gifts-npc-orders-town-shop.md` | 好感度、送礼、NPC 委托与镇子商店承载 | 已接入 |

---

## Phase 7 Prompt 状态

以下 Prompt 已按 `Phase 7` 顺序生成并接入代码，后续若继续扩写应以这些实现为基线：

| 阶段 | 预定功能定位 | 当前状态 |
|---|---|---|
| 19 | 农场生活支撑系统补完 | 已接入 |
| 20 | 世界区域与场景切换系统 | 已接入 |
| 21 | 镇子地图、小屋接入与基础入口布局 | 已接入 |
| 22 | NPC 交互框架、基础对话与简单日程 | 已接入 |
| 23 | 好感度、送礼、NPC 委托与镇子商店承载 | 已接入 |

---

## 当前推荐使用方式

### 继续推进现有项目

适用场景：

- 你已经有当前仓库
- 你不想回滚到最初阶段
- 你要在 `Phase 7` 已有骨架上继续扩写

操作方式：

1. 打开 `docs/phase7-town-npc-world-structure.md`
2. 先核对 `Prompt 19 -> 23` 的已实现边界
3. 在 Godot 中验证新增功能没有回归
4. 再基于现有实现继续生成后续 Prompt

### 回查历史设计

适用场景：

- 想看某个系统最初是怎么设计的
- 想核对边界和验收标准

操作方式：

- 直接打开对应历史 Prompt 阅读即可

---

## 每个新 Prompt 的最低执行要求

### Prompt 14 验证要点

- 体力显示存在且会变化
- 开垦/播种/浇水/收获会消耗体力
- 体力不足时动作失败且地块不变
- 次日开始或睡觉后恢复体力
- 存档读档后体力保持正确

### Prompt 15 验证要点

- 至少 3 种作物可正常经营
- 商店能买不同种子
- 地块能播种不同作物
- 收获产物和当前作物一致
- 季节限制生效

### Prompt 16 验证要点

- 订单能显示
- 背包不足时不能提交
- 提交成功会扣物品并给奖励
- 次日刷新逻辑成立
- 存档读档后订单状态不丢失

### Prompt 18 验证要点

- 玩家能购买并装备飞镖
- 玩家能进入洞窟并进行俯视即时战斗
- 飞镖数量与耐久/损耗逻辑成立
- 战败或撤退能正确返回
- 洞窟收益能回到主循环

### Prompt 19 验证要点

- 农场中有 1 个可交互储物箱
- 玩家可在背包和储物箱之间稳定存取物品
- 储物箱内容可正确存档和读档恢复
- 背包和商店筛选能识别 `材料`
- `ore_fragment`、`cave_essence` 被正确归类为 `material`

### Prompt 20 验证要点

- 玩家能在 `farm / house / town / cave` 之间稳定切换
- 各区域入口和返回点不会串场
- 存档读档后当前区域恢复正确
- 洞窟原型能兼容新区域系统

### Prompt 21 验证要点

- 小屋内有床和主储物箱
- 镇子有稳定的 hub 布局与入口锚点
- 农场里不再残留旧床和旧主储物箱交互
- 农场、小屋、镇子之间的往返链路稳定

### Prompt 22 验证要点

- 镇子里 3 个 NPC 可见且可交互
- 同一天首次对话和重复对话文本不同
- 杂货商可通过对话服务按钮打开商店
- NPC 会按时段切换站位或显隐状态

### Prompt 23 验证要点

- NPC 好感度会在首次对话和送礼后变化
- 送礼会消耗物品并给出喜欢/普通/不喜欢反馈
- 部分订单会显示发布 NPC 和关系奖励
- 完成 NPC 委托后金币与好感度都会增长
- 存档读档后好感度和订单状态保持正确

---

## 使用原则

### 1. 一次只推进一个 Prompt

不要把 `14/15/16` 一次性混在一个请求里。  
当前项目已经进入中期阶段，系统耦合比最初更高，拆开验证更稳。

### 2. 每个 Prompt 完成后必须进 Godot 验证

新的问题往往不是“代码没写完”，而是：

- 运行时报错
- 旧系统被回归破坏
- UI 没有接上
- 存档结构不兼容

### 3. Prompt 应该贴近当前目录结构

当前项目目录已经是新版结构，使用 Prompt 时要以真实目录为准，例如：

- `scripts/world/farm/`
- `scripts/data/`
- `resources/data/`
- `tools/`

不要再按旧文档里的：

- `scripts/plot/`
- `scripts/resources/`
- `resources/config/`

回退。

---

## 相关文档

- `docs/phase4-event-effect-system.md`
- `docs/phase5-farming-economy-system.md`
- `docs/phase6-combat-cave-prototype.md`
- `docs/phase6-combat-prototype-implementation.md`
- `docs/phase7-town-npc-world-structure.md`
- `docs/guides/current-to-full-game-roadmap.md`

如果目标是继续推进当前游戏，而不是回顾历史，优先看：

1. `current-to-full-game-roadmap.md`
2. `phase7-town-npc-world-structure.md`
3. `phase6-combat-prototype-implementation.md`
