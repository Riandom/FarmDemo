# Debug 调试指南 - Godot 像素农场 Demo

## 📋 项目背景

Codex 已完成从 prompt-01 到 prompt-07 的所有代码生成工作。用户尚未在 Godot 中运行过项目，需要系统性调试以确保游戏无错误运行并验证所有核心功能。

---

## 🔴 当前紧急问题：单例系统语法错误

### 问题概述

项目启动时出现**24 个严重语法错误**，导致游戏无法运行。分为两类：

#### 第一类：单例重复定义（6 个错误）
```
ERROR: Class "FarmManager" hides an autoload singleton.
ERROR: Class "FarmInteractionSystem" hides an autoload singleton.
ERROR: Class "FarmRenderSystem" hides an autoload singleton.
ERROR: Class "GameManager" hides an autoload singleton.
ERROR: Class "ColorPalette" hides a native class.
```

**通俗解释**：就像在一个公司里，已经在董事会任命了 CEO（autoload 注册），但又给这个人发了名片说"你也可以被雇佣"（class_name 声明），Godot 不知道该怎么称呼他。

#### 第二类：单例调用方式错误（18 个错误）
```
ERROR: Cannot call non-static function "get_current_tool()" on the class "GameManager" directly.
ERROR: Cannot call non-static function "get_plot_at_world_position()" on the class "FarmManager" directly.
ERROR: Cannot call non-static function "on_tool_use()" on the class "FarmInteractionSystem" directly.
```

**通俗解释**：就像你想找某个部门的经理办事，却不通过前台预约（获取单例实例），而是直接对着部门名称喊话（调用静态方法）。Godot 说："请先找到这个经理本人，再跟他说话！"

---

## 🎯 第一阶段修复目标

1. **零语法错误** - 所有 24 个 Parse Error 必须全部清除
2. **正常启动** - 游戏能在 Godot 4.5 中成功运行
3. **日志输出** - 看到 `[Main] Game started` 和 `[Main] Spawned 36 plots`

---

## 🔧 第一阶段修复步骤

### 阶段 1: 修复单例重复定义（优先级：🔴 最高）

#### 1.1 删除单例脚本的 class_name 声明

**需要修改的文件**：
1. `res://scripts/systems/farm_manager.gd`
2. `res://scripts/systems/farm_interaction_system.gd`
3. `res://scripts/systems/farm_render_system.gd`
4. `res://scripts/systems/game_manager.gd`
5. `res://scripts/data/color_palette.gd`

**修改规则**：
```gdscript
# ❌ 错误写法（当前）
extends Node
class_name FarmManager

# ✅ 正确写法（修改后）
extends Node
# 删除 class_name 这一行
```

**详细说明**：
- 打开上述 5 个文件
- 找到第 2 行的 `class_name XXX` 语句
- **直接删除整行**（不要保留注释）
- 保存文件

**验证方法**：
修改后重新运行游戏，如果这 6 个错误消失，说明修复成功。

---

### 阶段 2: 修复单例调用方式（优先级：🔴 高）

#### 2.1 理解正确的单例访问方式

**错误示范**（当前代码）：
```gdscript
var tool = GameManager.get_current_tool()  # ❌ 直接调用类方法
```

**正确方式 1**（推荐）：
```gdscript
var game_manager = get_node("/root/GameManager")
var tool = game_manager.get_current_tool()  # ✅ 先获取实例，再调用方法
```

**正确方式 2**（简洁版）：
```gdscript
var tool = get_node("/root/GameManager").get_current_tool()  # ✅ 一行搞定
```

**正确方式 3**（缓存引用）：
```gdscript
# 在函数开始时获取一次，然后重复使用
@onready var game_manager = get_node("/root/GameManager")

func some_function():
    var tool = game_manager.get_current_tool()  # ✅ 使用缓存的引用
```

---

#### 2.2 需要修改的文件清单

**文件 1**: `res://scripts/actors/player/player_input_bridge.gd`

**需要修复的行号**（共 11 处）：
- 第 77 行：`GameManager.get_current_tool()`
- 第 99 行：`FarmManager.get_plot_at_world_position()`
- 第 131 行：`GameManager.get_current_tool()`
- 第 138 行：`FarmInteractionSystem.on_tool_use()`
- 第 154 行：`GameManager.remove_item()`
- 第 157 行：`GameManager.add_item()`
- 第 182 行：`GameManager.get_unlocked_tools()`
- 第 186 行：`GameManager.get_current_tool()`
- 第 193 行：`GameManager.set_current_tool()`
- 第 200 行：`FarmInteractionSystem.get_tool_config()`

**修复方案 A**（推荐 - 使用缓存引用）：

在文件顶部添加：
```gdscript
@onready var game_manager = get_node("/root/GameManager")
@onready var farm_manager = get_node("/root/FarmManager")
@onready var interaction_system = get_node("/root/FarmInteractionSystem")
```

然后将所有调用改为：
```gdscript
# 原来：
var current_item := GameManager.get_current_tool()

# 修改后：
var current_item := game_manager.get_current_tool()
```

**修复方案 B**（快速修复 - 逐行替换）：

将每一处 `XXX.get_xxx()` 替换为 `get_node("/root/XXX").get_xxx()`

例如：
```gdscript
# 原来第 77 行：
var current_item := GameManager.get_current_tool()

# 修改后：
var current_item := get_node("/root/GameManager").get_current_tool()
```

---

### 阶段 3: 检查其他可能的单例调用

#### 3.1 搜索全项目

请在以下文件中搜索是否还有其他单例直接调用：
- `res://scripts/ui/*.gd`
- `res://scripts/world/farm/*.gd`
- `res://scripts/app/main.gd`

**搜索关键词**：
- `GameManager.`
- `FarmManager.`
- `FarmInteractionSystem.`
- `FarmRenderSystem.`

**判断标准**：
如果看到 `XXX.get_xxx()` 或 `XXX.some_method()` 这样的调用，都需要按照阶段 2 的方法修复。

---

## ✅ 第一阶段验证标准

### 第一步验证：语法错误清零
运行游戏后，输出面板应该显示：
```
--- GDScript language server started on port 6005 ---
[Main] Game started
[Main] Spawned 36 plots
```

**不再出现**任何 `ERROR:` 开头的信息。

---

## 🎯 第二阶段：完整调试流程

**注意**：只有在第一阶段完成后（无语法错误），才能进行本阶段测试。

### 阶段 1: 环境检查（预计 2 分钟）

#### 1.1 验证 Godot 版本
```bash
godot --version
# 预期输出：4.5.x
```

#### 1.2 检查项目完整性
请验证以下文件是否存在：
- [ ] `e:\FarmDemo\project.godot`
- [ ] `e:\FarmDemo\scenes\main.tscn`
- [ ] `e:\FarmDemo\scripts\main.gd`
- [ ] `e:\FarmDemo\assets\sprites\placeholder\` 文件夹包含 32 张 PNG

#### 1.3 验证单例注册
打开 `project.godot`，确认 `[autoload]` 段包含：
```ini
[autoload]
FarmManager="*res://scenes/systems/farm_manager.tscn"
FarmInteractionSystem="*res://scenes/systems/farm_interaction_system.tscn"
FarmRenderSystem="*res://scenes/systems/farm_render_system.tscn"
GameManager="*res://scenes/systems/game_manager.tscn"
```

---

### 阶段 2: 初次运行测试（预计 5 分钟）

#### 2.1 启动 Godot 并运行项目
```bash
# 方法 1: 使用命令行运行（推荐用于捕获错误）
godot --path e:\FarmDemo --quit-after-run

# 方法 2: GUI 方式
# 1. 打开 Godot 4.5
# 2. 导入项目 e:\FarmDemo\project.godot
# 3. 按 F5 运行
```

#### 2.2 捕获输出日志
**必须记录的信息**：
1. **启动阶段的错误**（如果有）
   - 语法错误
   - 节点引用失败
   - 资源加载失败

2. **运行时的警告**（如果有）
   - 空引用警告
   - 信号连接警告
   - 材质/贴图缺失警告

3. **成功启动的标志**
   ```
   [Main] Game started
   [Main] Spawned 36 plots
   ```

#### 2.3 截图保存
请截取以下内容：
- Godot 输出面板的完整内容
- 游戏运行画面（如果能看到）
- 任何弹出的错误对话框

---

### 阶段 3: 问题诊断与修复（预计 15 分钟）

#### 3.1 常见错误模式及修复策略

**错误类型 A: 节点引用失败**
```
ERROR: Node not found: "InteractionDetector"
```
**修复方向**:
- 检查场景中该节点是否存在
- 检查节点名称拼写是否正确
- 检查节点层级关系是否符合预期
- 考虑使用 `get_node_or_null()` 进行安全访问

**错误类型 B: 资源加载失败**
```
ERROR: Failed loading resource: res://assets/sprites/placeholder/xxx.png
```
**修复方向**:
- 确认文件路径是否正确
- 确认文件是否真实存在
- 检查文件名大小写是否匹配（Windows 不敏感但 Godot 可能敏感）

**错误类型 C: 脚本语法错误**
```
ERROR: Identifier "xxx" is not declared in the current scope
```
**修复方向**:
- 检查变量是否已声明
- 检查函数名拼写是否正确
- 检查是否缺少 `@export` 或 `@onready` 关键字

**错误类型 D: 单例未找到**
```
ERROR: Call of non-function "get_current_tool" on null instance
```
**修复方向**:
- 确认单例已在 project.godot 中注册
- 确认单例脚本没有语法错误导致加载失败
- 使用 `has_node("/root/SingletonName")` 验证单例是否存在

#### 3.2 迭代修复流程
```
1. 运行游戏 → 2. 记录第一个错误 → 3. 定位问题文件 
   ↓
6. 重新运行 ← 5. 应用修复 ← 4. 分析原因并修复
   ↓
7. 如果还有错误，回到步骤 2
```

**重要**: 一次只修复一个问题，然后立即重新运行验证。不要同时修复多个问题，否则无法确定哪个修复生效。

---

### 阶段 4: 功能验证测试（预计 10 分钟）

#### 4.1 玩家移动测试
**测试步骤**:
1. 启动游戏后，立即按 W/A/S/D 键
2. 同时按 W+D（斜向移动）
3. 松开所有按键

**验收标准**:
- [ ] 玩家蓝色方块能向 4 个方向移动
- [ ] 斜向移动速度不加快（归一化正确）
- [ ] 松开按键后立即停止
- [ ] 移动时有轻微上下抖动（走路动画）

**如果失败**：
- 不能移动 → 检查输入映射配置、player.gd 的 `_physics_process()`
- 斜向加速 → 检查是否有调用 `normalized()`
- 没有动画 → 检查 AnimationPlayer 和动画库

#### 4.2 交互提示测试
**测试步骤**:
1. 按 W 键向上移动，靠近最近的地块
2. 面向地块站立（几乎接触）
3. 观察屏幕上方

**验收标准**:
- [ ] 显示"按 E 开垦"提示框
- [ ] 提示框在屏幕顶部居中
- [ ] 背对地块或离开时提示消失

**如果失败**：
- 没有提示 → 检查 interaction_prompt.gd、FarmManager 是否有地块
- 提示不消失 → 检查 `_process()` 中的隐藏逻辑

#### 4.3 工具切换测试
**测试步骤**:
1. 按 Q 键
2. 再按 Q 键
3. 按 F 键

**验收标准**:
- [ ] 每次按键都显示切换提示
- [ ] 切换顺序：木锄头 → 小麦种子 → 木水壶 → 木镰刀 → 循环
- [ ] 提示文本显示正确的工具名称

**如果失败**：
- 没有反应 → 检查 input_map 配置、player_input_bridge.gd 的 `_unhandled_input()`
- 名称错误 → 检查 ToolConfig 的 display_name 字段

#### 4.4 开垦土地测试
**前置条件**: 手持木锄头，面前是荒地（深灰色）

**测试步骤**:
1. 面向荒地站立
2. 按 E 键
3. 观察地块颜色变化

**验收标准**:
- [ ] 地块从深灰变为棕色
- [ ] 输出面板显示 `[Interaction] ✓: 地块已开垦`
- [ ] 提示文本变为"按 E 播种"

**如果失败**：
- 没有变化 → 检查 FarmInteractionSystem.on_tool_use()、hoe_wood.tres 的 allowed_actions
- 有错误提示 → 查看具体错误信息

#### 4.5 播种测试
**前置条件**: 手持小麦种子，面前是已开垦土地（棕色）

**测试步骤**:
1. 切换到小麦种子（按 Q 直到显示"小麦种子"）
2. 面向已开垦土地
3. 按 E 键

**验收标准**:
- [ ] 地块上出现绿色小点（代表种子）
- [ ] 提示文本变为"按 E 浇水"
- [ ] 背包中的种子数量减少 1

**如果失败**：
- 不能播种 → 检查 plot.gd 的 can_perform_action("seed")、seed_wheat 配置

#### 4.6 浇水测试
**前置条件**: 手持木水壶，面前是已播种土地（棕色 + 绿点）

**测试步骤**:
1. 切换到木水壶
2. 面向已播种土地
3. 按 E 键

**验收标准**:
- [ ] 地块颜色变深（已浇水状态）
- [ ] 提示文本变为"生长中..."
- [ ] 开始计时（5 秒后进入下一阶段）

**如果失败**：
- 不能浇水 → 检查 watering_can_wood.tres、plot.gd 的 water 动作
- 不生长 → 检查 GrowTimer 是否启动、crop_config 配置

#### 4.7 作物生长测试
**前置条件**: 已完成浇水

**测试步骤**:
1. 站在原地等待 15 秒
2. 每 5 秒观察一次作物外观

**验收标准**:
- [ ] 5 秒后：作物稍微变大（阶段 1）
- [ ] 10 秒后：作物更大（阶段 2）
- [ ] 15 秒后：作物成熟，呈金黄色
- [ ] 提示文本变为"按 E 收获"

**如果失败**：
- 不生长 → 检查 Timer 是否 running、_on_grow_timer_timeout() 是否触发
- 贴图不变 → 检查 FarmRenderSystem、crop_plot.gd 的 _apply_visual_state()

#### 4.8 收获测试
**前置条件**: 手持木镰刀，面前是成熟作物（金黄色）

**测试步骤**:
1. 切换到木镰刀
2. 面向成熟作物
3. 按 E 键

**验收标准**:
- [ ] 作物消失，地块变回棕色（已开垦）
- [ ] 输出面板显示收获成功
- [ ] GameManager 的 inventory 中增加 3 个 crop_wheat

**如果失败**：
- 不能收获 → 检查 sickle_wood.tres、plot.gd 的 harvest 动作
- 没有物品 → 检查 _execute_harvest() 的 created_items 返回值

#### 4.9 背包界面测试
**测试步骤**:
1. 按 I 键
2. 观察界面
3. 再次按 I 键

**验收标准**:
- [ ] 第一次按 I：打开背包面板
- [ ] 显示物品网格（至少看到 seed_wheat: 4）
- [ ] 第二次按 I：关闭背包面板
- [ ] 打开背包时玩家无法移动

**如果失败**：
- 打不开 → 检查 input_map、inventory_ui.gd 的 toggle_inventory()
- 没有物品 → 检查 GameManager.inventory 初始化
- 能移动 → 检查 UI 打开时的输入锁定逻辑

#### 4.10 商店界面测试
**测试步骤**:
1. 按 B 键
2. 切换到"售卖"标签页
3. 点击出售小麦

**验收标准**:
- [ ] 第一次按 B：打开商店面板
- [ ] "购买"标签页显示小麦种子（价格 5）
- [ ] "售卖"标签页显示小麦作物（价格 15）
- [ ] 出售后金币增加，作物减少
- [ ] 打开商店时玩家无法移动

**如果失败**：
- 打不开 → 检查 shop_ui.gd、input_map
- 价格错误 → 检查 shop_config.tres
- 不能出售 → 检查 GameManager.remove_item()、交易验证逻辑

#### 4.11 经济系统验证
**前置条件**: 初始 50 金 + 5 种子

**测试流程**:
1. 查看初始金币（右上角应显示 💰 50）
2. 用 1 个种子播种→浇水→收获（得到 3 个小麦）
3. 打开商店，卖掉 3 个小麦（3 × 15 = 45 金）
4. 查看最终金币

**验收标准**:
- [ ] 初始金币：50
- [ ] 最终金币：50 - 5 + 45 = 90（允许±5 误差，如果有其他消耗）
- [ ] 剩余种子：4 个

**如果失败**：
- 金币计算错误 → 检查 GameManager.add_gold()、remove_gold()、shop_ui 的交易逻辑

#### 4.12 性能测试
**测试步骤**:
1. 运行游戏 1 分钟
2. 打开 Godot 的性能监视器
3. 观察各项指标

**验收标准**:
- [ ] FPS ≥ 55（接近 60）
- [ ] 内存占用 < 50 MB
- [ ] CPU 占用 < 10%
- [ ] 无明显卡顿

---

### 阶段 5: 回归测试（预计 3 分钟）

#### 5.1 完整种植循环
**测试流程**:
```
荒地 → 开垦 → 播种 → 浇水 → 等待 15 秒 → 收获 → 回到已开垦
```
重复上述循环 3 次，确保每次都能正常完成。

#### 5.2 UI 开关循环
**测试流程**:
```
按 I 开背包 → 按 I 关背包 → 按 B 开商店 → 按 B 关商店
```
重复 3 次，确保 UI 开关正常，输入锁定正确。

#### 5.3 工具切换循环
**测试流程**:
```
木锄头 → 种子 → 水壶 → 镰刀 → 木锄头（循环）
```
按 Q 键循环切换，再按 F 键反向切换。

---

## 📊 交付成果

### 必须提交的内容

#### 1. 调试日志文件
创建 `debug-log.txt`，包含：
```
=== 第一次运行 ===
时间：[填写时间]
Godot 版本：[填写版本号]

启动错误：
[复制粘贴所有错误信息]

修复步骤：
1. [做了什么修改]
2. [又做了什么修改]

结果：[成功/失败，如果失败还有什么错误]

=== 第二次运行 ===
...
```

#### 2. 功能验证清单
创建 `verification-checklist.md`，包含：
```markdown
# 功能验证清单

## 基础功能
- [ ] 玩家移动正常
- [ ] 动画播放正常
- [ ] 交互提示正常
- [ ] 工具切换正常

## 核心玩法
- [ ] 开垦功能正常
- [ ] 播种功能正常
- [ ] 浇水功能正常
- [ ] 作物生长正常
- [ ] 收获功能正常

## UI 系统
- [ ] 背包界面正常
- [ ] 商店界面正常
- [ ] 金币显示正常

## 经济系统
- [ ] 初始金币正确（50）
- [ ] 购买扣钱正确
- [ ] 售卖加钱正确
- [ ] 利润计算正确

## 性能
- [ ] FPS ≥ 55
- [ ] 内存 < 50MB
- [ ] 无卡顿
```

#### 3. 最终运行截图
至少包含以下 5 张截图：
1. 游戏启动画面（显示玩家和 36 块地）
2. 交互提示显示（"按 E 开垦"）
3. 成熟作物画面（金黄色）
4. 背包界面
5. 商店界面

---

## ⚠️ 注意事项

### 禁止事项
- ❌ 不要一次性修改多个文件后再运行（无法定位哪个修复有效）
- ❌ 不要忽略任何警告（警告可能是严重问题的前兆）
- ❌ 不要手动修改二进制文件（.tscn、.godot 等）
- ❌ 不要在修复后不做验证就继续下一步
- ❌ 不要修改 project.godot 中的 autoload 配置（单例注册是正确的）
- ❌ 不要删除单例脚本文件本身
- ❌ 不要修改非单例脚本的 class_name（如 Plot、CropPlot、Main 等）

### 推荐做法
- ✅ 每次只修复一个问题
- ✅ 每次修复后立即重新运行
- ✅ 详细记录每个错误和对应的修复方案
- ✅ 使用版本控制（git）保存每个修复节点
- ✅ 优先使用 `@onready` 缓存单例引用（性能更好，代码更清晰）
- ✅ 遇到问题先查阅本文档的常见问题排查部分

---

## 🎯 成功标准

当满足以下所有条件时，调试阶段才算完成：

1. ✅ **零错误** - 输出面板无任何 ERROR 级别信息
2. ✅ **零警告** - 输出面板无任何 WARNING 级别信息
3. ✅ **12 项功能测试全部通过** - verification-checklist.md 全勾选
4. ✅ **性能达标** - FPS ≥ 55, 内存 < 50MB
5. ✅ **文档完整** - debug-log.txt、verification-checklist.md、截图齐全

---

## 📞 如需协助

如果遇到无法解决的问题，请提供：

1. **完整的错误堆栈**（从输出面板复制）
2. **问题复现步骤**（详细说明如何操作会出现错误）
3. **已尝试的修复方法**（你已经做过哪些尝试）
4. **相关代码片段**（出错的文件和行号）
5. **截图**（游戏画面 + 输出面板）

---

## 📊 修复优先级总览

| 优先级 | 任务 | 文件数 | 错误数 | 预计耗时 |
|--------|------|--------|--------|----------|
| 🔴 P0 | 删除单例 class_name | 5 | 6 | 5 分钟 |
| 🔴 P0 | 修复单例调用方式 | 1 | 11 | 5 分钟 |
| 🟡 P1 | 环境检查 | - | - | 2 分钟 |
| 🟡 P1 | 初次运行测试 | - | - | 5 分钟 |
| 🟡 P1 | 问题诊断与修复 | 不定 | 不定 | 15 分钟 |
| 🟢 P2 | 功能验证测试 | - | - | 10 分钟 |
| 🟢 P3 | 回归测试 | - | - | 3 分钟 |

**总预计时间**: 40-45 分钟（含弹性时间）

---

**文档版本**: 1.0  
**创建时间**: 2026-04-02  
**适用工具**: Codex  
**文档位置**: `e:\FarmDemo\debugs\README.md`  
**紧急程度**: 🔴 最高优先级（阻塞项目运行）
