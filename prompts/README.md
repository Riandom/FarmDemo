# CODEX 提示词使用指南（第二版 - 完整架构）

## 📁 文件说明

本文件夹包含 **7 个独立的提示词文件**，用于指导 CODEX/GPT-4 生成完整的 Godot 4.5 种田游戏 Demo。

### ⭐ 提示词清单（新版架构）

| 序号 | 文件名 | 功能模块 | 核心特性 | 预计耗时 |
|------|--------|----------|----------|----------|
| 1 | `prompt-01-project-init.md` | 项目初始化 | project.godot、文件夹结构、输入映射 | 2 分钟 |
| 2 | `prompt-02-player.md` | 玩家控制系统 | WASD 移动、4 方向朝向、动画状态机 | 5 分钟 |
| 3 | `prompt-03-plot-system.md` | 地块系统 ⭐ | **协议式交互**、**单例模式**、5 状态流转 | 8 分钟 |
| 4 | `prompt-04-ui-system.md` | UI 系统 ⭐ | **信号驱动**、背包/商店/金币、交互提示 | 10 分钟 |
| 5 | `prompt-05-main-controller.md` | 主控制器 ⭐ | **GameManager 单例**、6×6 网格生成、信号汇总 | 8 分钟 |
| 6 | `prompt-06-player-bridge.md` | 玩家交互桥接 ⭐ | **智能动作推断**、工具切换、输入处理 | 5 分钟 |
| 7 | `prompt-07-placeholder-assets.md` | 占位符资源 | **程序化贴图生成**、配色方案、一键生成 | 3 分钟 |

---

## 🚀 使用步骤

### 第 1 步：准备工作

1. **安装 Godot 4.5**
   - 下载地址：https://godotengine.org/download
   - 选择 "Standard" 版本即可

2. **创建项目文件夹**
   ```
   e:\FarmDemo\
   ```

3. **打开 CODEX/GPT-4**
   - 确保 AI 助手已正确配置

---

### 第 2 步：按顺序发送提示词

**重要**: 必须严格按照 **1→2→3→4→5→6→7** 的顺序执行！

#### 📋 操作流程

1. **打开提示词文件**
   - 用文本编辑器打开对应的 prompt 文件
   - 全选复制所有内容（Ctrl+A → Ctrl+C）

2. **发送给 CODEX**
   - 在对话框中粘贴（Ctrl+V）
   - 按 Enter 发送

3. **等待生成完成**
   - AI 会开始生成代码和文件
   - 通常需要 3-8 分钟（视模块复杂度而定）

4. **验证输出**
   - 检查生成的文件是否完整
   - 运行验证步骤中列出的测试

5. **继续下一个**
   - 确认无误后，打开下一个提示词文件
   - 重复上述步骤

---

### 第 3 步：每步验证要点

#### ✅ Prompt 1: 项目初始化
- [ ] `project.godot` 文件创建成功
- [ ] 所有文件夹结构完整（scenes/, scripts/, resources/, assets/）
- [ ] 输入映射配置正确（Project Settings → Input Map）
- [ ] 窗口分辨率设置为 800×600

#### ✅ Prompt 2: 玩家控制系统
- [ ] `player.tscn` 场景创建成功
- [ ] CharacterBody2D + Sprite2D + AnimationPlayer 节点结构正确
- [ ] 8 个动画片段（idle/walk × 4 方向）
- [ ] 运行游戏后可 WASD 移动
- [ ] 斜向移动速度正常（不加速）
- [ ] 按 E 控制台输出交互日志

#### ✅ Prompt 3: 地块系统 ⭐核心模块
- [ ] `scripts/systems/farm_manager.gd` 单例创建成功
- [ ] `scripts/systems/farm_interaction_system.gd` 单例创建成功
- [ ] `scripts/systems/farm_render_system.gd` 单例创建成功
- [ ] `scripts/plot/plot.gd` 基类创建成功（5 状态枚举）
- [ ] `scripts/plot/crop_plot.gd` 子类创建成功
- [ ] `scenes/plot/crop_plot.tscn` 场景创建成功
- [ ] 5 状态流转正常：waste → plowed → seeded → watered → mature
- [ ] Timer 5 秒触发一次
- [ ] 状态切换时贴图更新

#### ✅ Prompt 4: UI 系统
- [ ] `scripts/ui/interaction_prompt.gd` 创建成功
- [ ] `scripts/ui/inventory_ui.gd` 创建成功
- [ ] `scripts/ui/shop_ui.gd` 创建成功
- [ ] `scripts/ui/gold_display.gd` 创建成功
- [ ] 按 I 键开关背包
- [ ] 按 B 键开关商店
- [ ] 金币显示正常（初始 50）
- [ ] UI 打开时玩家无法移动

#### ✅ Prompt 5: 主控制器
- [ ] `scripts/systems/game_manager.gd` 单例创建成功
- [ ] `scripts/main.gd` 主控制器创建成功
- [ ] `scenes/main.tscn` 主场景创建成功
- [ ] 6×6=36 块地正确生成
- [ ] GameManager 存储金币和背包数据
- [ ] 所有信号正确连接

#### ✅ Prompt 6: 玩家交互桥接
- [ ] `scripts/player/player_input_bridge.gd` 创建成功
- [ ] 按 E 键可交互地块
- [ ] 智能动作推断正常（锄头开垦、水壶浇水、镰刀收获）
- [ ] Q/F 键切换工具
- [ ] 交互反馈提示显示正常

#### ✅ Prompt 7: 占位符资源
- [ ] `scripts/tools/texture_generator.gd` 创建成功
- [ ] `scripts/resources/color_palette.gd` 创建成功
- [ ] `resources/config/placeholder_colors.tres` 创建成功
- [ ] 在 Godot 编辑器中运行生成器脚本
- [ ] `assets/sprites/placeholder/` 中生成所有贴图（20+ 张）
- [ ] 玩家、地块、作物、工具图标全部生成

---

## ⚠️ 常见问题

### Q1: CODEX 生成的代码不完整怎么办？
**A**: 要求 CODEX "继续生成上一段的剩余部分" 或 "补全 XXX 函数"

### Q2: Godot 报错 "找不到节点" 怎么办？
**A**: 检查场景树中的节点名是否与脚本中的 `@onready` 变量一致

### Q3: 移动时斜向加速怎么办？
**A**: 确认 `_handle_movement()` 中调用了 `input_dir.normalized()`

### Q4: 交互串地（同时触发多个地块）怎么办？
**A**: 检查 `FarmManager.get_plot_at_world_position()` 的距离阈值是否超过 32px

### Q5: UI 打开后仍能移动怎么办？
**A**: 确认 `GameManager` 的 `ui_opened` 信号被正确监听，玩家输入被禁用

### Q6: 地块定时器不工作怎么办？
**A**: 
- 检查 Timer 节点的 `wait_time` 是否为 5.0
- 确认 `watered` 状态下才启动 Timer
- 验证 `timeout` 信号已连接

### Q7: 贴图生成失败怎么办？
**A**: 
- 确认脚本有 `@tool` 标记
- 在 Godot **编辑器**中运行（不是运行游戏）
- 检查 `OUTPUT_DIR` 路径是否正确

---

## 🎯 架构特点

### 1. 协议式交互
工具和地块之间通过**协议**通信：
- 工具声明 `allowed_actions`（能做什么）
- 地块实现 `can_perform_action()`（允不允许做）
- `FarmInteractionSystem` 作为中介验证双方权限

### 2. 单例模式
三个核心单例贯穿全局：
- **FarmManager**: 地块注册表，O(1) 查找
- **FarmInteractionSystem**: 工具 - 地块交互仲裁者
- **FarmRenderSystem**: 监听信号更新贴图（逻辑与渲染分离）
- **GameManager**: 全局状态（金币、背包、存档）

### 3. 信号驱动
所有系统通过信号解耦：
```
地块状态变更 → emit_signal("state_changed")
              ↓
FarmRenderSystem 监听 → 更新贴图
UI 监听 → 更新提示文本
GameManager 监听 → 记录统计
```

### 4. 智能动作推断
玩家不需要手动选择动作，系统根据**工具 + 地块状态**自动判断：
- 拿锄头对荒地 → 开垦
- 拿种子对熟地 → 播种
- 拿水壶对已播种 → 浇水
- 拿镰刀对成熟作物 → 收获

---

## 📊 预期时间线

| 阶段 | 内容 | 累计时间 |
|------|------|----------|
| 准备 | 安装 Godot、配置环境 | 10 分钟 |
| Prompt 1 | 项目初始化 | +2 分钟 = 12 分钟 |
| Prompt 2 | 玩家系统 | +5 分钟 = 17 分钟 |
| Prompt 3 | 地块系统 | +8 分钟 = 25 分钟 |
| Prompt 4 | UI 系统 | +10 分钟 = 35 分钟 |
| Prompt 5 | 主控制器 | +8 分钟 = 43 分钟 |
| Prompt 6 | 交互桥接 | +5 分钟 = 48 分钟 |
| Prompt 7 | 贴图生成 | +3 分钟 = 51 分钟 |
| 总测试 | 完整流程测试 | +15 分钟 = 66 分钟 |

**总计**: 约 1-1.5 小时完成整个项目

---

## 🎉 最终成果

完成后您将拥有：

```
e:\FarmDemo\
├── project.godot              # 可双击运行的项目
├── scenes/
│   ├── main.tscn             # 主场景（6×6 地块网格）
│   ├── player.tscn           # 玩家场景
│   └── plot/crop_plot.tscn   # 地块预制体
├── scripts/
│   ├── systems/
│   │   ├── farm_manager.gd         # 单例：地块管理器
│   │   ├── farm_interaction_system.gd  # 单例：交互仲裁
│   │   ├── farm_render_system.gd   # 单例：渲染系统
│   │   └── game_manager.gd         # 单例：全局状态
│   ├── plot/
│   │   ├── plot.gd                # 地块基类
│   │   └── crop_plot.gd           # 地块子类
│   ├── player/
│   │   ├── player.gd              # 玩家控制
│   │   └── player_input_bridge.gd # 输入桥接
│   ├── ui/
│   │   ├── interaction_prompt.gd  # 交互提示
│   │   ├── inventory_ui.gd        # 背包
│   │   ├── shop_ui.gd             # 商店
│   │   └── gold_display.gd        # 金币显示
│   ├── main.gd                    # 主控制器
│   └── tools/
│       └── texture_generator.gd   # 贴图生成器
├── resources/
│   ├── config/
│   │   ├── crops/wheat_config.tres    # 小麦配置
│   │   ├── tools/*.tres               # 工具配置
│   │   └── placeholder_colors.tres    # 配色方案
│   └── color_palette.gd          # 配色资源类
├── assets/sprites/placeholder/
│   ├── player/*.png              # 玩家贴图（8 张）
│   ├── tiles/*.png               # 地块贴图（5 张）
│   ├── crops/*.png               # 作物贴图（4 张）
│   ├── items/*.png               # 物品图标（5 张）
│   └── ui/*.png                  # UI 元素（4 张）
└── prompts/                      # 提示词文件夹
    ├── prompt-01~07.md           # 7 个提示词文件
    ├── README.md                 # 本文件
    ├── 00-PROJECT-OVERVIEW.md    # 项目总览
    └── RESTART-TEMPLATE.md       # 新 Chat 同步模板
```

---

## 🔄 核心玩法流程

### 完整种植循环
```
1. 走到荒地旁，按 E 开垦（消耗：无）
   ↓
2. 切换到种子，按 E 播种（消耗：1 种子）
   ↓
3. 切换到水壶，按 E 浇水（消耗：无）
   ↓
4. 等待 15 秒（3 阶段 × 5 秒）
   ↓
5. 切换到镰刀，按 E 收获（获得：3 小麦）
   ↓
6. 按 B 打开商店，售卖小麦（收入：15 金）
   ↓
7. 利润 10 金，购买更多种子扩大生产
```

---

## 📞 需要帮助？

如果遇到问题：

1. **检查 Godot 版本**: 必须是 4.x（推荐 4.5）
2. **查看控制台输出**: Godot 底部面板的"输出"和"调试器"标签
3. **查阅避坑指南**: 每个 prompt 都有⛔避坑检查清单
4. **运行验证步骤**: 每个 prompt 都有✅验证步骤
5. **使用 RESTART-TEMPLATE.md**: 新 Chat 时快速同步进度

---

## 🚀 开始吧！

现在打开 `prompt-01-project-init.md`，开始您的 Godot 种田游戏之旅！

祝您好运！🎮✨
