# CODEX 提示词使用指南（当前版本）

## 文件说明

本文件夹包含从 `Prompt 01` 到 `Prompt 16` 的阶段提示词，用于分阶段推进 FarmDemo。  
当前项目已经从“项目初始化阶段”推进到“Phase 5 种田经营深化阶段”。

这些 Prompt 不再适合按 `01 -> 16` 机械全量重跑。  
正确用法是：

- 旧 Prompt 用于回溯某个历史阶段的实现边界
- 新 Prompt 用于继续推进当前项目

---

## 当前阶段建议

如果你是基于现在这个仓库继续开发，**应从 Phase 5 开始**：

1. `prompt-14-stamina-system.md`
2. `prompt-15-multi-crop-season-economy.md`
3. `prompt-16-order-system.md`

推荐顺序必须严格保持：

- `14 -> 15 -> 16`

原因：

- `Prompt 14` 先补经营压力
- `Prompt 15` 再补经营选择
- `Prompt 16` 最后补经营目标

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
| 14 | `prompt-14-stamina-system.md` | 体力与行动消耗系统 | 下一阶段 |
| 15 | `prompt-15-multi-crop-season-economy.md` | 多作物与季节经营系统 | 下一阶段 |
| 16 | `prompt-16-order-system.md` | 订单与农场经济反馈系统 | 下一阶段 |

---

## 当前推荐使用方式

### 继续推进现有项目

适用场景：

- 你已经有当前仓库
- 你不想回滚到最初阶段
- 你要继续做 Phase 5

操作方式：

1. 打开 `prompt-14-stamina-system.md`
2. 全量发送给 AI 助手
3. 在 Godot 中验证结果
4. 验证通过后再进入 `prompt-15`
5. 完成 `prompt-15` 后再进入 `prompt-16`

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
- `docs/guides/current-to-full-game-roadmap.md`

如果目标是继续推进当前游戏，而不是回顾历史，优先看：

1. `current-to-full-game-roadmap.md`
2. `phase5-farming-economy-system.md`
3. `prompt-14` 到 `prompt-16`
