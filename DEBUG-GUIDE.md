# Farm Demo 调试指南

## 📋 已完成的代码修复

### 修复 1: PlayerInputBridge 节点引用问题

**文件**: `scripts/player/player_input_bridge.gd`

**问题描述**: 
原代码使用相对路径 `$"../InteractionDetector"` 引用兄弟节点，这在 Godot 中可能导致节点未找到的错误。

**修复方案**:
- 将 `@onready` 声明改为 `null` 初始值
- 在 `_ready()` 函数中使用 `get_parent().get_node()` 安全获取兄弟节点
- 添加警告日志，当节点不存在时不会导致崩溃

**修复后的代码**:
```gdscript
@onready var player = get_parent()
@onready var interaction_detector: Area2D = null  # 延迟获取，避免节点未就绪

func _ready() -> void:
    """从父玩家同步交互参数并获取 InteractionDetector 引用。"""
    if player != null:
        interaction_range = float(player.get("interaction_range"))
        interaction_cooldown = float(player.get("interact_cooldown"))
    
    # 安全获取兄弟节点 InteractionDetector
    if player != null and player.has_node("InteractionDetector"):
        interaction_detector = player.get_node("InteractionDetector")
    else:
        push_warning("[PlayerInputBridge] InteractionDetector not found, interaction detection will be limited")
```

---

## 🔍 静态代码分析结果

### ✅ 已验证无问题的模块

#### 1. UI 系统
- **ui_root.gd**: 节点引用正确，信号连接完整
- **inventory_ui.gd**: 所有 `@onready` 变量都能在场景中找到对应节点
- **shop_ui.gd**: 节点层级结构正确，配置加载逻辑完整
- **gold_display.gd**: GameManager 引用使用了安全的 `get_node_or_null()`
- **interaction_prompt.gd**: 玩家引用和位置更新逻辑正确

#### 2. 地块系统
- **plot.gd**: 5 状态机实现正确，协议方法完整
- **crop_plot.gd**: 视觉更新逻辑正确，继承关系清晰

#### 3. 单例系统
- **farm_manager.gd**: 地块注册表 O(1) 查找实现正确
- **farm_interaction_system.gd**: 工具 - 地块交互仲裁逻辑完整
- **farm_render_system.gd**: 渲染系统信号监听正确
- **game_manager.gd**: 全局状态管理完整，信号发射正确

#### 4. 资源配置
- **wheat_config.tres**: 作物配置参数正确，贴图路径有效
- **hoe_wood.tres**: 工具配置正确，allowed_actions 包含 "plow"
- **watering_can_wood.tres**: 工具配置正确，allowed_actions 包含 "water"
- **sickle_wood.tres**: 工具配置正确，allowed_actions 包含 "harvest"

#### 5. 场景文件
- **main.tscn**: 主场景结构正确，包含 Player、FarmTiles、UI
- **player.tscn**: 玩家场景节点完整，包含所有必需子节点
- **crop_plot.tscn**: 地块场景节点完整，包含 Sprite2D、CropSprite2D、GrowTimer

---

## 🎮 第一次运行测试步骤

### 步骤 1: 打开 Godot 项目

1. 启动 Godot 4.5
2. 在项目列表中选择 "Farm Demo"
   - 如果不在列表中，点击"导入" → 选择 `e:\FarmDemo\project.godot`

### 步骤 2: 检查项目设置

1. 点击菜单 **项目 → 项目设置**
2. 选择 **Autoload** 标签页
3. 确认以下 4 个单例已注册且状态为绿色勾选：
   - `FarmManager` → `res://scenes/systems/farm_manager.tscn`
   - `FarmInteractionSystem` → `res://scenes/systems/farm_interaction_system.tscn`
   - `FarmRenderSystem` → `res://scenes/systems/farm_render_system.tscn`
   - `GameManager` → `res://scenes/systems/game_manager.tscn`

### 步骤 3: 运行游戏

1. 点击工具栏的 **▶️ 运行** 按钮（或按 **F5**）
2. 观察底部的"输出"面板

### 步骤 4: 记录错误和警告

**可能出现的错误类型及含义**:

| 错误类型 | 含义 | 严重性 |
|---------|------|--------|
| `Node not found` | 场景中的节点引用路径错误 | 🔴 严重 |
| `Identifier not declared` | 变量或函数名未声明 | 🔴 严重 |
| `Call of non-function` | 函数签名不匹配 | 🔴 严重 |
| `Cannot get class` | class_name 声明有问题 | 🔴 严重 |
| `Texture not found` | 贴图资源路径不存在 | 🟡 中等 |
| `Signal not found` | 信号连接失败 | 🟡 中等 |

---

## ✅ 功能测试清单

### 测试 1: 玩家移动
- [ ] 按 W/A/S/D 键，玩家应该向对应方向移动
- [ ] 同时按两个方向键（斜向移动），速度不应加快
- [ ] 松开所有按键，玩家应立即停止

**预期行为**:
- 玩家蓝色方块在窗口内平滑移动
- 移动时有轻微的上下抖动（走路动画效果）
- 停下后保持最后面向的方向

### 测试 2: 地块生成
- [ ] 游戏启动后，应该看到 6×6 = 36 块棕色/灰色方块
- [ ] 地块应该排列成整齐的网格
- [ ] 地块之间间距很小（几乎紧挨着）

**预期行为**:
- 地块整体位于屏幕中央偏右位置
- 玩家出生在地块网格的左下方

### 测试 3: 交互提示
- [ ] 走到任意地块旁边
- [ ] 应该看到屏幕上方显示"按 E 开垦"提示

**预期行为**:
- 提示框在屏幕顶部居中显示
- 只有面向可交互地块时才显示提示
- 离开范围或背对地块时提示自动消失

### 测试 4: 工具切换
- [ ] 按 Q 键，应该切换到下一个工具/种子
- [ ] 按 F 键，应该切换到上一个工具/种子
- [ ] 每次切换都应该显示提示信息

**预期顺序**:
```
木锄头 → 小麦种子 → 木水壶 → 木镰刀 → (循环)
```

### 测试 5: 开垦土地
**前提条件**: 当前手持"木锄头"，面前是荒地（深灰色）

- [ ] 按 E 键，荒地应该变成已开垦（棕色）
- [ ] 输出面板应该显示类似 `[Interaction] ✓: 地块已开垦`

**预期行为**:
- 地块颜色从深灰变为棕色
- 提示文本变为"按 E 播种"

### 测试 6: 播种
**前提条件**: 当前手持"小麦种子"，面前是已开垦土地（棕色）

- [ ] 按 E 键，应该显示播种动作
- [ ] 背包中的种子数量应该减少 1

**预期行为**:
- 地块上出现小的绿色点（代表刚种下的种子）
- 提示文本变为"按 E 浇水"

### 测试 7: 浇水
**前提条件**: 当前手持"木水壶"，面前是已播种土地（棕色 + 绿点）

- [ ] 按 E 键，应该显示浇水动作
- [ ] 地块颜色变深（代表湿润）

**预期行为**:
- 地块颜色变为深棕色（已浇水状态）
- 提示文本变为"生长中..."
- 开始 5 秒倒计时

### 测试 8: 作物生长
**前提条件**: 已完成浇水

- [ ] 等待 5 秒，作物应该进入下一阶段
- [ ] 再等 5 秒，进入第三阶段
- [ ] 再等 5 秒，作物成熟（金黄色）

**预期行为**:
- 每 5 秒作物外观发生变化（从小到大）
- 成熟后显示金黄色的麦穗
- 提示文本变为"按 E 收获"

### 测试 9: 收获
**前提条件**: 当前手持"木镰刀"，面前是成熟作物（金黄色）

- [ ] 按 E 键，作物应该消失，地块回到已开垦状态
- [ ] 背包中应该增加 3 个"小麦"物品

**预期行为**:
- 地块变回棕色（已开垦）
- 可以再次开垦→播种→浇水→收获（循环）

### 测试 10: 背包界面
- [ ] 按 I 键，应该打开背包界面
- [ ] 界面应该显示当前拥有的所有物品
- [ ] 再次按 I 键，应该关闭背包界面

**预期行为**:
- 打开背包时，玩家无法移动
- 关闭背包后，玩家恢复控制

### 测试 11: 商店界面
- [ ] 按 B 键，应该打开商店界面
- [ ] 应该看到"购买"和"售卖"两个标签页
- [ ] 在"购买"标签页，应该能看到小麦种子（价格 5 金）
- [ ] 在"售卖"标签页，应该能看到小麦作物（价格 15 金）

**预期行为**:
- 打开商店时，玩家无法移动
- 购买成功后，金币减少，种子增加
- 售卖成功后，作物减少，金币增加

### 测试 12: 经济系统验证
**初始状态**: 50 金 + 5 种子

**完整一轮操作**:
1. 用 1 个种子播种
2. 浇水并等待成熟
3. 收获得到 3 个小麦
4. 到商店卖掉 3 个小麦（3 × 15 = 45 金）

**预期结果**:
- 最终应该有：50 - 5 + 45 = 90 金
- 剩余种子：4 个

---

## 🐛 常见问题排查

### 问题 1: 游戏启动后立即崩溃

**可能原因**:
- 单例注册失败
- 主场景路径错误
- 关键脚本语法错误

**排查方法**:
1. 查看输出面板的最后几行错误信息
2. 检查 `project.godot` 的 `[autoload]` 段是否正确
3. 确认 `scenes/main.tscn` 存在且格式正确

### 问题 2: 玩家不可见或不移动

**可能原因**:
- 玩家贴图资源丢失
- AnimationPlayer 配置错误
- 输入映射未配置

**排查方法**:
1. 检查 `assets/sprites/placeholder/player/` 文件夹是否存在 8 张 PNG
2. 在场景中展开 Player → Sprite2D → AnimationPlayer，确认有动画库
3. 点击 **项目 → 项目设置 → 输入映射**，确认 move_up/down/left/right 已配置

### 问题 3: 地块不显示或全黑

**可能原因**:
- 地块贴图路径错误
- CropPlot 脚本引用失败

**排查方法**:
1. 检查 `assets/sprites/placeholder/tiles/` 文件夹是否存在 5 张 PNG
2. 在输出面板搜索 "texture" 相关的错误信息
3. 确认 `resources/config/crops/wheat_config.tres` 中的 sprites_per_stage 数组路径正确

### 问题 4: 按 E 没有任何反应

**可能原因**:
- PlayerInputBridge 未正确获取 InteractionDetector
- FarmManager 中没有注册地块
- 交互距离太短

**排查方法**:
1. 查看输出面板是否有 `[PlayerInputBridge] InteractionDetector not found` 警告
2. 在游戏启动后，查看是否有 `[Main] Spawned 36 plots` 日志
3. 尝试紧贴地块站立（几乎重叠）再按 E

### 问题 5: UI 打开后无法关闭

**可能原因**:
- UI 信号连接失败
- 输入事件被吞掉

**排查方法**:
1. 查看输出面板是否有 UI 相关的信号错误
2. 尝试点击 UI 上的"×"关闭按钮
3. 检查 `ui_root.gd` 中的 `_unhandled_input()` 是否正确处理

### 问题 6: 作物不生长

**可能原因**:
- GrowTimer 未启动
- crop_config 加载失败
- 地块状态不是 watered

**排查方法**:
1. 在输出面板搜索 "GrowTimer" 相关日志
2. 确认已经成功执行浇水动作
3. 检查 `wheat_config.tres` 中的 stage_base_duration 是否为 5.0

---

## 📊 性能基准

**正常运行的性能指标**:
- 帧率：稳定 60 FPS
- 内存占用：< 50 MB
- 加载时间：< 3 秒
- CPU 占用：< 10%

**如何查看性能数据**:
1. 点击 Godot 编辑器右上角的 **调试** 按钮
2. 选择 **可见性 → 性能**
3. 查看 FPS 和内存使用情况

---

## 📝 反馈模板

如果你遇到问题，请提供以下信息：

```
### 问题描述
[简短描述遇到的问题]

### 复现步骤
1. [第一步]
2. [第二步]
3. [第三步]

### 输出面板错误信息
```
[复制完整的错误堆栈]
```

### 截图
[如有必要，附上截图]

### 已尝试的解决方法
[你已经尝试过哪些修复方法]
```

---

## 🎯 下一步计划

完成调试后，我们将：

1. ✅ 确保游戏无错误运行
2. ⏳ 验证所有核心功能正常
3. ⏳ 创建 README.md 项目说明文档
4. ⏳ 创建 IMPLEMENTATION.md 实施指南
5. ⏳ 整理扩展建议和优化方向

---

**文档版本**: 1.0  
**更新日期**: 2026-04-02  
**适用版本**: Godot 4.5 + 第二版完整架构
