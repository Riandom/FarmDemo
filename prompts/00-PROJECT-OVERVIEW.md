# Godot 4.5 像素农场 Demo - 项目总览（第二版 - 完整架构）

## 🎯 项目目标

创建一个完整的 2D 像素风格种田模拟经营游戏 Demo，实现核心玩法闭环：**开垦→播种→浇水→生长→收获→售卖**。

**架构特点**：协议式交互、单例模式、信号驱动、智能动作推断。

---

## 📋 核心参数速查

| 参数项 | 值 |
|--------|-----|
| **引擎** | Godot 4.5 |
| **语言** | GDScript |
| **分辨率** | 800×600 |
| **地块规模** | 6×6 = 36 块 |
| **作物种类** | 小麦（1 种） |
| **生长时间** | 5 秒/阶段 × 3 阶段 = 15 秒成熟 |
| **初始资源** | 50 金 + 5 种子 + 3 工具 |
| **价格体系** | 种子 5 金 → 售价 15 金（利润 10 金） |
| **操作键位** | WASD 移动，E 交互，I 背包，B 商店，Q/F 切换工具 |

---

## 🏗️ 系统架构（新版）

```
┌──────────────────────────────────────────────────┐
│              Main (主场景)                        │
│  - 生成 6×6 地块网格                               │
│  - 连接所有信号                                   │
│  - 玩家出生点管理                                 │
└───────────┬──────────────────────────────────────┘
            │
    ┌───────┼────────┬────────────┬───────────────┐
    │       │        │            │               │
┌───▼───┐ ┌▼────┐ ┌▼────────┐ ┌▼──────┐   ┌────▼────────┐
│Player │ │Tile │ │FarmInter│ │  UI   │   │ GameManager │
│玩家控 │ │地块 │ │actionSys│ │ 系统  │   │  全局状态   │
│制系统 │ │系统 │ │ 交互仲裁 │ │       │   │ (单例)      │
└───────┘ └─────┘ └─────────┘ └───────┘   └─────────────┘
                │             │
         ┌──────┴──────┐ ┌────┴──────┐
         │             │ │           │
    ┌────▼────┐  ┌────▼▼┐   ┌─────▼──────┐
    │FarmMgr  │  │FarmRend│  │PlayerInput │
    │地块注册表│  │erSystem│  │Bridge      │
    │(单例)   │  │渲染系统│  │输入桥接    │
    │         │  │(单例)  │  │            │
    └─────────┘  └────────┘  └────────────┘
```

### 关键设计原则

1. **协议式交互** - 工具声明能力，地块验证权限，中介系统仲裁
2. **逻辑与渲染分离** - 地块只发射信号，不关心贴图如何更新
3. **集中化管理** - 4 个单例贯穿全局（FarmManager、FarmInteractionSystem、FarmRenderSystem、GameManager）
4. **数据驱动** - 作物配置、工具配置使用 Resource，便于扩展和平衡调整
5. **智能动作推断** - 玩家无需手动选择动作，系统根据工具 + 地块状态自动判断

---

## 📁 文件结构（新版）

```
e:\FarmDemo/
├── project.godot                 # 项目配置（4 单例注册）
├── scenes/                       # 场景文件
│   ├── main.tscn                # 主场景（6×6 地块网格）
│   ├── player.tscn              # 玩家场景
│   └── plot/crop_plot.tscn      # 地块预制体
├── scripts/                      # 脚本文件
│   ├── systems/                 # 【单例模块】
│   │   ├── farm_manager.gd            # 单例：地块注册表 O(1) 查找
│   │   ├── farm_interaction_system.gd # 单例：工具 - 地块交互仲裁
│   │   ├── farm_render_system.gd      # 单例：监听信号更新贴图
│   │   └── game_manager.gd            # 单例：全局状态（金币/背包/存档）
│   ├── plot/                    # 【地块模块】
│   │   ├── plot.gd                    # 地块基类（5 状态机 + 协议方法）
│   │   └── crop_plot.gd               # 地块子类（监听信号更新 Sprite）
│   ├── player/                  # 【玩家模块】
│   │   ├── player.gd                  # 玩家控制（移动 + 朝向 + 动画）
│   │   └── player_input_bridge.gd     # 输入桥接（智能动作推断）
│   ├── ui/                      # 【UI 模块】
│   │   ├── interaction_prompt.gd        # 交互提示（"按 E 开垦"）
│   │   ├── inventory_ui.gd              # 背包界面
│   │   ├── shop_ui.gd                   # 商店界面（买卖双标签）
│   │   └── gold_display.gd              # 金币显示
│   ├── main.gd                  # 主控制器（游戏入口）
│   └── tools/                   # 【工具模块】
│       └── texture_generator.gd       # 贴图生成器（程序化生成）
├── resources/                    # 资源配置
│   ├── config/                  # 配置目录
│   │   ├── crops/wheat_config.tres    # 小麦配置（3 阶段，15 秒成熟）
│   │   ├── tools/                       # 工具配置
│   │   │   ├── hoe_wood.tres          # 木锄头（允许：plow）
│   │   │   ├── watering_can_wood.tres # 木水壶（允许：water）
│   │   │   └── sickle_wood.tres       # 木镰刀（允许：harvest）
│   │   └── placeholder_colors.tres    # 占位符配色方案
│   └── color_palette.gd          # 配色资源类
├── assets/sprites/placeholder/   # 占位贴图（程序化生成）
│   ├── player/*.png              # 玩家贴图（8 张：idle/walk × 4 方向）
│   ├── tiles/*.png               # 地块贴图（5 张：5 状态）
│   ├── crops/*.png               # 作物贴图（4 张：4 生长阶段）
│   ├── items/*.png               # 物品图标（5 张：种子/作物/工具）
│   └── ui/*.png                  # UI 元素（4 张：按钮三态 + 背景）
└── prompts/                      # 提示词文件夹
    ├── prompt-01~07.md           # 7 个提示词文件（新版架构）
    ├── README.md                 # 使用指南
    ├── 00-PROJECT-OVERVIEW.md    # 本文件
    └── RESTART-TEMPLATE.md       # 新 Chat 同步模板
```

---

## 🔧 子系统详细职责

### 1. 玩家控制系统（scripts/player/）

#### player.gd - 玩家基础控制
- **移动**: WASD/方向键，100px/s，斜向归一化
- **朝向**: 4 方向（上/下/左/右），根据最后移动方向
- **动画**: AnimationPlayer 播放 idle_方向/walk_方向
- **交互检测**: 发射 `player_interacted(position, direction)` 信号

#### player_input_bridge.gd - 输入桥接 ⭐新增
- **输入捕获**: 监听 E 键交互、Q/F 切换工具
- **智能推断**: 根据工具类型 + 地块状态自动判断动作
  - 拿锄头对荒地 → plow（开垦）
  - 拿种子对熟地 → seed（播种）
  - 拿水壶对已播种 → water（浇水）
  - 拿镰刀对成熟作物 → harvest（收获）
- **交互执行**: 调用 FarmInteractionSystem.on_tool_use()
- **反馈显示**: 成功/失败立即通过 UI 提示玩家

### 2. 农场地块系统（scripts/systems/ + scripts/plot/）

#### FarmManager（单例）⭐新增
- **地块注册表**: Dictionary 存储所有地块，O(1) 查找
- **坐标映射**: grid_position → Plot 实例
- **信号通知**: plot_registered / plot_unregistered

#### FarmInteractionSystem（单例）⭐新增
- **工具注册**: 加载 ToolConfig 资源
- **权限仲裁**: 
  1. 验证工具是否有此能力（allowed_actions）
  2. 验证地块是否允许此动作（can_perform_action）
  3. 执行动作（execute_action）
- **结果返回**: ActionResult 字典（success/consumed_items/created_items）

#### FarmRenderSystem（单例）⭐新增
- **信号监听**: 监听所有地块的 visual_update_requested
- **贴图更新**: 根据 base_state 和 growth_stage 设置 Sprite2D.texture
- **逻辑解耦**: 地块本身不引用任何贴图资源

#### plot.gd - 地块基类
- **5 状态机**: waste → plowed → seeded → watered → mature → plowed（循环）
- **协议方法**: can_perform_action(action_id), execute_action(action_id)
- **生长定时器**: Timer 节点，仅 watered 状态启动，5 秒超时
- **信号发射**: state_changed, visual_update_requested, crop_harvested

#### crop_plot.gd - 地块子类
- **Sprite 更新**: 监听 state_changed 信号，调用 FarmRenderSystem.request_visual_update()
- **Timer 管理**: 连接 timeout 信号到 _on_grow_timer_timeout()

### 3. UI 系统（scripts/ui/）

#### interaction_prompt.gd
- **动态提示**: 根据地块状态显示"按 E 开垦/播种/浇水/收获"
- **位置跟随**: 显示在玩家头顶上方
- **自动隐藏**: 玩家离开范围或 UI 打开时隐藏

#### inventory_ui.gd
- **网格布局**: GridContainer 动态生成物品槽
- **开关控制**: I 键切换 visible
- **互斥锁定**: 打开时发送 ui_opened 信号，禁用玩家输入

#### shop_ui.gd
- **双标签页**: TabContainer 切换购买/售卖
- **交易验证**: 检查金币足够/物品足够
- **信号通知**: 交易成功后发送 gold_changed / inventory_changed

#### gold_display.gd
- **实时更新**: 监听 GameManager.gold_changed 信号
- **格式显示**: "💰 50"
- **变化反馈**: 增加绿色/减少红色（预留接口）

### 4. 主控制器（scripts/main.gd）

- **游戏入口**: _ready() 初始化所有系统
- **地块生成**: 6×6 网格，居中排列，实例化 CropPlot 场景
- **信号汇总**: 连接所有子系统的信号到对应回调
- **交互处理**: 
  - 接收 player_interacted 信号
  - 调用 FarmManager.get_plot_at_world_position()
  - 调用 FarmInteractionSystem.on_tool_use()
  - 处理 ActionResult 更新 GameManager 状态

### 5. GameManager（单例）⭐新增

- **全局状态**:
  ```gdscript
  {
      "gold": 50,
      "inventory": {"seed_wheat": 5, "crop_wheat": 0, ...},
      "current_tool": "hoe_wood",
      "unlocked_tools": ["hoe_wood", "watering_can_wood", "sickle_wood"]
  }
  ```
- **物品管理**: add_item(), remove_item(), has_item()
- **金币管理**: add_gold(), remove_gold()
- **工具切换**: set_current_tool(), get_current_tool()
- **信号发射**: gold_changed, inventory_changed, item_added, item_removed

---

## 🔄 核心流程详解

### 流程 1: 完整种植循环

```
1. 玩家走到荒地旁
   ↓
2. PlayerInputBridge 检测到前方有地块
   ↓
3. 玩家按 E 键
   ↓
4. PlayerInputBridge 推断动作：当前工具是锄头 → plow
   ↓
5. 调用 FarmInteractionSystem.on_tool_use("hoe_wood", plot, context)
   ↓
6. FarmInteractionSystem 验证：
   - 锄头的 allowed_actions 包含 "plow" ✅
   - 地块.can_perform_action("plow") 返回 true ✅
   ↓
7. 调用 plot.execute_action("plow")
   ↓
8. 地块状态 waste → plowed
   ↓
9. 发射 state_changed("waste", "plowed")
   ↓
10. FarmRenderSystem 监听到信号，更新贴图为 plowed
    ↓
11. InteractionPrompt 更新提示文本为"按 E 播种"
```

### 流程 2: 作物生长

```
1. 玩家使用水壶浇水
   ↓
2. 地块状态 seeded → watered
   ↓
3. 启动 GrowTimer.start()
   ↓
4. 5 秒后 timeout 信号触发
   ↓
5. growth_stage 从 0 → 1
   ↓
6. 发射 visual_update_requested(growth_stage)
   ↓
7. FarmRenderSystem 更新贴图为 stage_1
   ↓
8. 重复步骤 4-7，直到 growth_stage >= 3
   ↓
9. 地块状态 watered → mature
   ↓
10. 停止 Timer，发射 crop_harvested
```

### 流程 3: UI 互斥锁

```
1. 玩家按 I 键
   ↓
2. InventoryUI.toggle_inventory()
   ↓
3. inventory_panel.visible = true
   ↓
4. 发送 ui_opened("inventory")
   ↓
5. PlayerInputBridge 监听到，设置 input_enabled = false
   ↓
6. 玩家无法移动和交互
   ↓
7. 玩家再次按 I 键
   ↓
8. InventoryUI 关闭，发送 ui_closed("inventory")
   ↓
9. PlayerInputBridge 恢复 input_enabled = true
   ↓
10. 玩家恢复正常控制
```

---

## ⛔ 关键避坑点

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

### 经济系统
- ✅ 金币不能为负数
- ✅ 购买时先扣钱再加物品
- ✅ 售卖时先扣物品再加钱

---

## ✅ 验证清单

### 功能验证
- [ ] 玩家可 WASD 移动，斜向不加速
- [ ] 4 方向朝向正确，动画流畅
- [ ] 按 E 仅交互前方 1 格地块（不串地）
- [ ] 5 状态正确流转（waste→plowed→seeded→watered→mature）
- [ ] 作物 15 秒成熟（3 阶段×5 秒）
- [ ] 背包 I 键开关，显示物品网格
- [ ] 商店 B 键开关，买卖正常
- [ ] Q/F 键切换工具，显示提示
- [ ] 智能动作推断正常（锄头开垦、水壶浇水、镰刀收获）
- [ ] 经济系统正确（利润 10 金/轮）
- [ ] UI 打开时禁用玩家输入

### 代码质量
- [ ] 无语法错误
- [ ] 无缩进警告
- [ ] 无节点引用错误
- [ ] 所有函数有中文注释
- [ ] 命名见名知意（动词 + 名词）
- [ ] 单例在 autoload 正确注册

### 性能验证
- [ ] 运行帧率稳定 60 FPS
- [ ] 内存占用 < 50 MB
- [ ] 加载时间 < 3 秒
- [ ] 36 块地同时存在无卡顿

---

## 🎨 占位贴图配色方案

| 元素 | 颜色代码 | RGB | 说明 |
|------|----------|-----|------|
| **玩家** | #4169e1 | rgb(65,105,225) | 皇家蓝 |
| **荒地** | #3a3a3a | rgb(58,58,58) | 深灰色 |
| **已开垦** | #8b4513 | rgb(139,69,19) | 棕色 |
| **已播种** | #cd853f | rgb(205,133,63) | 浅棕色 + 绿点 |
| **已浇水** | #654320 | rgb(101,67,32) | 深棕色 + 水光 |
| **成熟** | #daa520 | rgb(218,165,32) | 金黄色 |
| **发芽期** | #90ee90 | rgb(144,238,144) | 浅绿色 |
| **生长期** | #228b22 | rgb(34,139,34) | 森林绿 |
| **种子物品** | #ffd700 | rgb(255,215,0) | 金色 |
| **小麦物品** | #daa520 | rgb(218,165,32) | 金黄色 |
| **木柄** | #c29b40 | rgb(194,155,64) | 浅棕色 |
| **金属** | #999999 | rgb(153,153,153) | 灰色 |

---

## 🚀 开发顺序（新版）

1. **项目初始化** → project.godot + 文件夹 + 输入映射 + 4 单例注册
2. **玩家系统** → player.tscn + player.gd + player_input_bridge.gd
3. **地块系统** → 4 单例脚本 + plot.gd + crop_plot.gd + crop_plot.tscn
4. **UI 系统** → 4 个 UI 脚本 + 4 个 UI 场景
5. **主控制器** → main.gd + main.tscn + GameManager 单例
6. **交互桥接** → 完善 player_input_bridge.gd 的智能推断逻辑
7. **贴图生成** → texture_generator.gd + color_palette.gd + 配置文件

---

## 📊 预期性能

- **帧率**: 60 FPS 稳定
- **内存**: < 50 MB
- **加载时间**: < 3 秒
- **地块数量**: 36 块（可通过配置扩展）
- **同屏物体**: < 100 个节点
- **输入响应**: < 16ms（1 帧内）

---

## 🔮 后续扩展方向

### 短期（保持 Demo 规模）
1. **新作物**: 复制 wheat_config.tres，修改生长时间和售价
2. **新工具**: 创建新 ToolConfig，扩展 allowed_actions
3. **成就系统**: 统计种植数量、收获次数、总收入

### 中期（小型独立游戏）
4. **季节系统**: 春夏秋冬影响生长速度（春×1.2、夏×0.8、秋×1.0、冬×1.5）
5. **土壤等级**: 普通→肥沃→优质，影响产量（+0%/+20%/+50%）
6. ** Buff/Debuff**: 施肥（+生长速度）、害虫（-产量）、干旱（停止生长）

### 长期（完整商业游戏）
7. **存档读档**: JSON 序列化所有状态
8. **多场景**: 农场→城镇→地下城
9. **NPC 系统**: 对话树、好感度、任务链
10. **建筑系统**: 温室、仓库、自动化灌溉

---

## 💡 给 AI 助手的建议

当您收到这个项目的代码生成请求时，请：

1. **严格遵循 Godot 4.5 语法**（@export, @onready, class_name）
2. **使用 Tab 缩进**，不要混用空格
3. **所有函数添加中文注释**
4. **优先使用信号通信**，避免硬编码引用
5. **单例模式统一注册**到 project.godot 的 autoload
6. **每个模块独立测试**后再集成
7. **提供详细的验证步骤**
8. **标注所有避坑点**（用⛔符号）
9. **协议式交互**：工具声明能力，地块验证权限
10. **逻辑与渲染分离**：地块发射信号，渲染系统监听更新

---

## 📞 快速参考

### 常用命令
```gdscript
# 打印调试
print("[系统名] 消息内容：", 变量)

# 获取单例
var manager = get_node("/root/FarmManager")

# 发射信号
emit_signal("signal_name", 参数 1, 参数 2)

# 连接信号
node.signal_name.connect(_on_signal_handler)

# 实例化场景
var instance = preload("res://scenes/xxx.tscn").instantiate()

# 定时器
$Timer.start()
$Timer.stop()
$Timer.time_left  # 剩余时间

# 单例访问
GameManager.add_gold(50)
FarmManager.get_plot_at_grid_position(Vector2i(0, 0))
FarmInteractionSystem.on_tool_use(tool_id, plot, context)
```

### 输入映射
```gdscript
# 检测按键按下
if Input.is_action_pressed("move_up"):
    input_dir.y -= 1

# 检测按键按下（事件）
if event.is_action_pressed("interact"):
    _handle_interaction()

# 检测按键松开
if event.is_action_released("toggle_inventory"):
    toggle_inventory()
```

### 信号定义示例
```gdscript
# 地块信号
signal state_changed(old_state: String, new_state: String)
signal visual_update_requested(stage: int)
signal crop_harvested(plot: Plot, yield_count: int)

# GameManager 信号
signal gold_changed(new_amount: int)
signal inventory_changed(items: Dictionary)
signal item_added(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
```

---

## 🎯 核心优势总结

相比第一版简单架构，新版架构的优势：

1. **可扩展性**: 新增作物/工具只需添加配置文件，无需修改核心逻辑
2. **可维护性**: 单例模式集中管理，信号驱动解耦各系统
3. **用户体验**: 智能动作推断减少操作步骤，交互反馈及时清晰
4. **测试友好**: 每个系统独立验证，问题定位快速准确
5. **面向未来**: 预留 buff/debuff、存档读档、多场景切换接口

---

**这就是整个项目的全貌！** 接下来请按顺序发送 prompt-01 ~ prompt-07，我会逐步生成每个模块的详细代码。
