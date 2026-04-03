# 🚀 CODEX 新对话重启模板（第二版 - 完整架构）

## 使用方法
复制下方「📋 完整重启消息」的全部内容，在新建 Chat 后第一条发送。

---

## 📋 完整重启消息（直接复制）

```markdown
【Godot 4.5 种田游戏 Demo - 项目进度同步（第二版 - 完整架构）】

你好！我正在开发一个 Godot 4.5 的 2D 像素种田模拟经营游戏，前一个对话已经完成了 7 个提示词文档的创建，现在需要继续生成代码。

---

## ✅ 已完成的提示词文档（7/7）

### Prompt 1: 项目初始化 ✓
- project.godot 配置（800×600 窗口，Godot 4.5）
- 输入映射：move_up/down/left/right, interact, toggle_inventory, toggle_shop, tool_next, tool_previous
- 文件夹结构：scenes/, scripts/, resources/, assets/, prompts/
- 单例注册占位（4 个单例待实现）

### Prompt 2: 玩家控制系统 ✓
- 场景：scenes/player.tscn（CharacterBody2D + Sprite2D + AnimationPlayer）
- 脚本：scripts/player.gd
- 功能：
  * WASD 移动，100px/s，斜向归一化
  * 4 方向朝向（up/down/left/right）
  * 动画状态机：idle_down/up/left/right, walk_down/up/left/right
  * E 键交互，发射 player_interacted 信号
  * UI 打开时禁用移动和交互

### Prompt 3: 地块系统 ✓（核心模块）
- 单例：FarmManager, FarmInteractionSystem, FarmRenderSystem
- 地块类：scripts/plot/plot.gd（基类）+ crop_plot.gd（子类）
- 场景：scenes/plot/crop_plot.tscn（Area2D + Sprite2D + Timer）
- 功能：
  * 5 状态机：waste → plowed → seeded → watered → mature → plowed（循环）
  * 协议式交互：can_perform_action(action_id), execute_action(action_id)
  * Timer 定时生长：仅 watered 状态启动，5 秒/阶段 × 3 阶段 = 15 秒成熟
  * 信号：state_changed, visual_update_requested, crop_harvested
  * O(1) 查找：FarmManager 按 grid_position 快速查询

### Prompt 4: UI 系统 ✓
- 脚本：scripts/ui/interaction_prompt.gd, inventory_ui.gd, shop_ui.gd, gold_display.gd
- 场景：对应 4 个 UI 场景
- 功能：
  * 交互提示：动态显示"按 E 开垦/播种/浇水/收获"
  * 背包界面：I 键开关，GridContainer 网格布局
  * 商店界面：B 键开关，TabContainer 买卖双标签
  * 金币显示：常驻顶部，实时更新
  * UI 互斥：同一时间只能打开一个 UI

### Prompt 5: 主控制器 ✓
- 单例：GameManager（全局状态管理）
- 脚本：scripts/main.gd
- 场景：scenes/main.tscn
- 功能：
  * 生成 6×6=36 块地块网格，居中排列
  * 连接所有子系统信号
  * 经济管理：金币、背包物品的增删
  * 游戏入口：_ready() 初始化所有系统

### Prompt 6: 玩家交互桥接 ✓
- 脚本：scripts/player/player_input_bridge.gd
- 功能：
  * 智能动作推断：根据工具 + 地块状态自动判断动作
  * 工具切换：Q/F 键切换下一个/上一个工具
  * 交互执行：调用 FarmInteractionSystem.on_tool_use()
  * 反馈显示：成功/失败立即通过 UI 提示
  * 交互冷却：0.3 秒防止误触

### Prompt 7: 占位符资源 ✓
- 脚本：scripts/tools/texture_generator.gd
- 配置：scripts/resources/color_palette.gd + placeholder_colors.tres
- 功能：
  * 程序化生成所有贴图（20+ 张）
  * 玩家贴图：8 张（idle/walk × 4 方向）
  * 地块贴图：5 张（5 状态）
  * 作物贴图：4 张（4 生长阶段）
  * 物品图标：5 张（种子/作物/工具）
  * UI 元素：4 张（按钮三态 + 背景）

---

## 🏗️ 项目架构特点

### 4 个核心单例
1. **FarmManager**: 地块注册表，O(1) 查找
2. **FarmInteractionSystem**: 工具 - 地块交互仲裁者
3. **FarmRenderSystem**: 监听信号更新贴图（逻辑与渲染分离）
4. **GameManager**: 全局状态（金币/背包/存档）

### 协议式交互
- 工具声明 `allowed_actions`（能做什么）
- 地块实现 `can_perform_action()`（允不允许做）
- FarmInteractionSystem 作为中介验证双方权限

### 智能动作推断
- 拿锄头对荒地 → plow（开垦）
- 拿种子对熟地 → seed（播种）
- 拿水壶对已播种 → water（浇水）
- 拿镰刀对成熟作物 → harvest（收获）

### 信号驱动
- 地块状态变更 → emit_signal("state_changed")
- FarmRenderSystem 监听 → 更新贴图
- UI 监听 → 更新提示文本
- GameManager 监听 → 记录统计

---

## 📊 关键项目参数

| 参数 | 值 |
|------|-----|
| 引擎版本 | Godot 4.5 |
| 语言 | GDScript |
| 分辨率 | 800×600 |
| 地块规模 | 6×6 = 36 块 |
| 作物种类 | 小麦（1 种） |
| 生长时间 | 5 秒/阶段 × 3 阶段 = 15 秒成熟 |
| 初始资源 | 50 金 + 5 种子 + 3 工具 |
| 价格体系 | 种子 5 金 → 售价 15 金（利润 10 金） |
| 操作键位 | WASD 移动，E 交互，I 背包，B 商店，Q/F 切换工具 |

---

## 📁 项目文件结构

```
e:\FarmDemo/
├── project.godot                 # 项目配置（4 单例注册）
├── scenes/
│   ├── main.tscn                # 主场景（待生成）
│   ├── player.tscn              # 玩家场景（待生成）
│   └── plot/crop_plot.tscn      # 地块预制体（待生成）
├── scripts/
│   ├── systems/                 # 【单例模块 - 待生成】
│   │   ├── farm_manager.gd
│   │   ├── farm_interaction_system.gd
│   │   ├── farm_render_system.gd
│   │   └── game_manager.gd
│   ├── plot/                    # 【地块模块 - 待生成】
│   │   ├── plot.gd
│   │   └── crop_plot.gd
│   ├── player/                  # 【玩家模块 - 待生成】
│   │   ├── player.gd
│   │   └── player_input_bridge.gd
│   ├── ui/                      # 【UI 模块 - 待生成】
│   │   ├── interaction_prompt.gd
│   │   ├── inventory_ui.gd
│   │   ├── shop_ui.gd
│   │   └── gold_display.gd
│   ├── main.gd                  # 主控制器（待生成）
│   └── tools/                   # 【工具模块 - 待生成】
│       └── texture_generator.gd
├── resources/
│   ├── config/
│   │   ├── crops/wheat_config.tres    # 小麦配置（待生成）
│   │   ├── tools/*.tres               # 工具配置（待生成）
│   │   └── placeholder_colors.tres    # 配色方案（待生成）
│   └── color_palette.gd          # 配色资源类（待生成）
└── prompts/                      # 提示词文件夹
    ├── prompt-01~07.md           # 7 个提示词文档（已完成）
    ├── README.md                 # 使用指南
    ├── 00-PROJECT-OVERVIEW.md    # 项目总览
    └── RESTART-TEMPLATE.md       # 本文件
```

---

## ⛔ 关键避坑点（必须遵守）

### 语法规范
- ✅ 使用 `@export` 而非 `export`
- ✅ 使用 `@onready` 而非 `onready var`
- ✅ if 语句必须有完整条件表达式
- ✅ Tab 缩进，Tab size = 4
- ✅ 单例使用 class_name 声明

### 单例注册
- ✅ project.godot 的 [autoload] 段注册 4 个单例
- ✅ 顺序：FarmManager → FarmInteractionSystem → FarmRenderSystem → GameManager
- ✅ 路径使用 res://scripts/systems/xxx.gd

### 协议式交互
- ✅ 工具必须有 allowed_actions 数组
- ✅ 地块必须实现 can_perform_action() 和 execute_action()
- ✅ FarmInteractionSystem 必须先验证再执行

### 信号驱动
- ✅ 地块不直接引用贴图资源
- ✅ 地块状态变更后立即发射 signal
- ✅ FarmRenderSystem 监听 signal 并更新 Sprite

### 智能动作推断
- ✅ 根据工具 allowed_actions 和地块 base_state 推断
- ✅ 推断失败时显示清晰提示
- ✅ 不消耗资源（种子/工具耐久）

---

## 🎯 接下来需要的操作

请按照以下顺序生成代码：

1. **运行 Prompt 1** → 创建项目框架和配置文件
2. **运行 Prompt 2** → 生成玩家场景和脚本
3. **运行 Prompt 3** → 生成 4 个单例 + 地块系统
4. **运行 Prompt 4** → 生成 UI 系统
5. **运行 Prompt 5** → 生成主控制器和 GameManager
6. **运行 Prompt 6** → 生成玩家输入桥接
7. **运行 Prompt 7** → 生成贴图生成器并运行

每个 Prompt 生成后我会立即测试验证，确认无误后再继续下一个。

---

## 💬 协作方式

我们的协作流程：
1. 我发送对应的 Prompt 文档内容
2. 你根据 Prompt 生成所有代码和文件
3. 我在 Godot 中测试验证
4. 如有问题立即修复
5. 确认无误后继续下一个 Prompt

准备好了吗？如果理解了项目背景和进度，请回复"已理解项目进度（第二版完整架构）"，然后我会发送 **Prompt 1: 项目初始化**。
```

---

## 📝 简化版（快速同步）

```markdown
【项目重启】Godot 4.5 种田游戏 Demo（第二版 - 完整架构）

✅ 已完成：7 个提示词文档（prompt-01~07.md）

🏗️ 架构特点：
- 4 单例：FarmManager, FarmInteractionSystem, FarmRenderSystem, GameManager
- 协议式交互：工具声明能力，地块验证权限
- 智能动作推断：根据工具 + 地块状态自动判断
- 信号驱动：逻辑与渲染分离

📊 核心参数：
- 6×6=36 块地，5 状态流转，15 秒成熟
- 初始 50 金 + 5 种子，利润 10 金/轮
- WASD 移动，E 交互，Q/F 切换工具

请从 Prompt 1 开始生成代码。
```

---

## 💡 使用建议

### 最佳实践：
1. **首次同步**：使用完整版（让 AI 充分了解项目架构）
2. **后续继续**：使用简化版（节省 token）
3. **遇到问题**：附加错误信息和控制台输出

### 提示技巧：
- 如果 AI 忘记了代码风格，可以说："参考 prompt-XX.md 中的代码规范"
- 如果需要保持一致性，可以说："延续之前模块的信号命名和注释格式"
- 如果 AI 开始胡言乱语，立即新建对话并重新发送重启模板

---

现在您可以：
1. 复制上方的「完整重启消息」
2. 在 CODEX/GPT-4 中新建 Chat
3. 粘贴发送
4. 等待回复"已理解"
5. 发送 Prompt 1 开始生成代码
