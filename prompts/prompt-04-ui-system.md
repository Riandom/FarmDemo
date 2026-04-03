# 提示词 4: UI 系统（交互提示、背包、商店、金币显示）

## 项目上下文

这是 Godot 4.5 种田游戏的 UI 系统模块。当前目标是**快速完成 Demo**，但架构设计要**预留扩展接口**以支持未来成为完整独立游戏。

**已完成模块**：
- 项目初始化（project.godot, 800×600, 输入映射）
- 玩家控制系统（移动、朝向、交互检测）
- 地块系统（5 状态流转、生长定时器、基础交互）
- 系统单例（FarmManager, FarmInteractionSystem, FarmRenderSystem）

**本模块核心职责**：提供玩家与游戏系统的可视化交互界面，包括交互提示、背包管理、商店交易、金币显示。

**扩展性要求**：使用 Control 节点为基础，支持动态布局、多语言、主题切换，但不实现具体逻辑。

---

## 第 1 章：系统架构

### 1.1 设计原则

**核心原则**：
1. **信号驱动** - UI 仅监听信号并更新显示，不修改游戏数据
2. **开关互斥** - 同一时间只能打开一个 UI（背包/商店）
3. **自动隐藏** - 交互提示在玩家离开后自动消失
4. **数据分离** - UI 显示数据与实际数据存储分离

### 1.2 UI 层级结构

```
CanvasLayer (UI_Root)
├── InteractionPrompt (PanelContainer)
│   └── Label (提示文本："按 E 开垦")
├── InventoryUI (Control)
│   ├── Background (ColorRect)
│   ├── Title (Label: "背包")
│   ├── CloseButton (Button: "×")
│   └── ItemGrid (GridContainer)
│       └── [动态生成的物品槽]
├── ShopUI (Control)
│   ├── Background (ColorRect)
│   ├── Title (Label: "商店")
│   ├── CloseButton (Button: "×")
│   ├── BuyTab (VBoxContainer)
│   │   └── ItemList (可购买列表)
│   └── SellTab (VBoxContainer)
│       └── ItemList (可售卖列表)
└── GoldDisplay (HBoxContainer)
    ├── Icon (TextureRect)
    └── Label (金币数量："💰 50")
```

### 1.3 单例注册

UI 系统不需要额外的单例，所有 UI 组件由 Main 场景统一管理。

---

## 第 2 章：交互提示系统

### 2.1 InteractionPrompt 属性表

| 字段名 | 类型 | 说明 | 必填 | Demo 阶段 |
|--------|------|------|------|----------|
| prompt_label | Label | 显示提示文本的控件 | ✅ | 使用 |
| current_action | String | 当前可执行动作 | ❌ | 使用 |
| is_visible | bool | 是否显示 | ❌ | 使用 |
| fade_speed | float | 淡入淡出速度 | ❌ | **预留接口** |
| position_offset | Vector2 | 相对玩家的偏移 | ❌ | **预留接口** |

### 2.2 核心函数清单

| 函数名 | 参数 | 返回 | 说明 | Demo 阶段 |
|--------|------|------|------|----------|
| show_prompt | action_name: String | void | 显示指定动作提示 | 使用 |
| hide_prompt | 无 | void | 隐藏提示 | 使用 |
| update_position | player_pos: Vector2 | void | 更新位置跟随玩家 | 使用 |
| _on_player_interacted | pos: Vector2, dir: Vector2 | void | 监听玩家交互信号 | 使用 |
| _on_ui_opened | ui_type: String | void | UI 打开时自动隐藏 | 使用 |

### 2.3 交互提示逻辑

```
步骤 1: 玩家靠近可交互地块
         ↓
步骤 2: FarmInteractionSystem 检测到有效目标
         ↓
步骤 3: 调用 InteractionPrompt.show_prompt("开垦")
         ↓
步骤 4: 提示框显示在玩家头顶上方
         ↓
步骤 5: 玩家按下 E 键或离开范围
         ↓
步骤 6: 调用 InteractionPrompt.hide_prompt()
```

### 2.4 扩展接口预留

#### 多语言支持接口
```
未来实现（暂不实现）：
- localization_key: String  # 本地化键值
- language_code: String     # 当前语言代码
- func translate(key: String) -> String
```

#### 动态定位接口
```
未来实现（暂不实现）：
- screen_edge_detection: bool  # 检测屏幕边缘
- auto_flip_direction: bool    # 自动翻转方向
- camera_follow: bool          # 跟随摄像机
```

---

## 第 3 章：背包系统

### 3.1 InventoryUI 属性表

| 字段名 | 类型 | 说明 | 必填 | Demo 阶段 |
|--------|------|------|------|----------|
| item_grid | GridContainer | 物品网格容器 | ✅ | 使用 |
| items | Dictionary | 物品字典 {id: count} | ✅ | 使用 |
| slot_scene | PackedScene | 物品槽预制体 | ❌ | 使用 |
| max_slots | int | 最大格子数 | ❌ | **预留接口** |
| drag_drop_enabled | bool | 拖拽功能开关 | ❌ | **预留接口** |

### 3.2 物品数据结构

```gdscript
# 物品数据存储在 GameManager 中，UI 只负责显示
{
    "seed_wheat": 5,      # 小麦种子 ×5
    "crop_wheat": 0,      # 成熟小麦 ×0
    "tool_hoe": 1,        # 锄头 ×1
    "tool_watering_can": 1 # 水壶 ×1
}
```

### 3.3 核心函数清单

| 函数名 | 参数 | 返回 | 说明 | Demo 阶段 |
|--------|------|------|------|----------|
| _ready | 无 | void | 初始化连接信号 | 使用 |
| toggle_inventory | 无 | void | 开关背包界面 | 使用 |
| update_item_display | 无 | void | 刷新物品显示 | 使用 |
| create_item_slot | item_id: String, count: int | Control | 创建物品槽 | 使用 |
| _on_close_button_pressed | 无 | void | 关闭按钮回调 | 使用 |
| _on_gold_changed | new_amount: int | void | 监听金币变更 | 使用 |

### 3.4 背包开关逻辑

```
步骤 1: 玩家按下 I 键
         ↓
步骤 2: 检查当前是否有 UI 已打开
         ↓
步骤 3: 如果没有 UI 打开 → 打开背包
         ↓
步骤 4: 发送 ui_opened("inventory") 信号
         ↓
步骤 5: 玩家控制系统禁用输入
         ↓
步骤 6: 玩家再次按 I 键或点击关闭按钮
         ↓
步骤 7: 发送 ui_closed() 信号
         ↓
步骤 8: 玩家控制系统恢复输入
```

### 3.5 扩展接口预留

#### 物品堆叠接口
```
未来实现（暂不实现）：
- max_stack_size: int = 99  # 最大堆叠数量
- func can_stack(item_id: String) -> bool
- func split_stack(slot_index: int, amount: int) -> void
```

#### 拖拽排序接口
```
未来实现（暂不实现）：
- drag_preview: TextureRect
- drop_highlight: ColorRect
- func on_drag_begin(item_data)
- func on_drop_completed(target_slot, item_data)
```

#### 分类筛选接口
```
未来实现（暂不实现）：
- filter_tabs: TabContainer  # 全部/种子/工具/作物
- sort_options: Enum        # 按名称/数量/价值排序
```

---

## 第 4 章：商店系统

### 4.1 ShopUI 属性表

| 字段名 | 类型 | 说明 | 必填 | Demo 阶段 |
|--------|------|------|------|----------|
| buy_tab | VBoxContainer | 购买标签页 | ✅ | 使用 |
| sell_tab | VBoxContainer | 售卖标签页 | ✅ | 使用 |
| shop_items | Dictionary | 商店商品配置 | ✅ | 使用 |
| buy_price_modifier | float | 购买价格系数 | ❌ | **预留接口** |
| sell_price_modifier | float | 售卖价格系数 | ❌ | **预留接口** |

### 4.2 商店商品配置

```gdscript
# 商店配置数据
{
    "buy": {
        "seed_wheat": {"price": 5, "display_name": "小麦种子", "icon": "res://..."},
        "tool_hoe_wood": {"price": 20, "display_name": "木锄头", "icon": "res://..."}
    },
    "sell": {
        "crop_wheat": {"price": 15, "display_name": "小麦", "icon": "res://..."}
    }
}
```

### 4.3 核心函数清单

| 函数名 | 参数 | 返回 | 说明 | Demo 阶段 |
|--------|------|------|------|----------|
| _ready | 无 | void | 初始化商店商品列表 | 使用 |
| toggle_shop | 无 | void | 开关商店界面 | 使用 |
| buy_item | item_id: String | void | 购买商品 | 使用 |
| sell_item | item_id: String | void | 售卖物品 | 使用 |
| update_shop_display | 无 | void | 刷新商店显示 | 使用 |
| verify_purchase | item_id: String, gold: int | bool | 验证购买资格 | 使用 |
| verify_sale | item_id: String, inventory: Dictionary | bool | 验证售卖资格 | 使用 |

### 4.4 交易流程

**购买流程**：
```
步骤 1: 玩家点击"购买小麦种子"按钮
         ↓
步骤 2: 检查金币是否足够（5 金）
         ↓
步骤 3: 如果足够：扣 5 金 → 加 1 种子
         ↓
步骤 4: 发送 gold_changed(新金额) 信号
         ↓
步骤 5: 发送 inventory_changed(新字典) 信号
         ↓
步骤 6: 更新 UI 显示
         ↓
步骤 7: 如果金币不足：显示提示"金币不足"
```

**售卖流程**：
```
步骤 1: 玩家点击"售卖小麦"按钮
         ↓
步骤 2: 检查背包是否有小麦
         ↓
步骤 3: 如果有：扣 1 小麦 → 加 15 金
         ↓
步骤 4: 发送 gold_changed(新金额) 信号
         ↓
步骤 5: 发送 inventory_changed(新字典) 信号
         ↓
步骤 6: 更新 UI 显示
         ↓
步骤 7: 如果没有货物：显示提示"没有可售卖的物品"
```

### 4.5 扩展接口预留

#### 声望系统接口
```
未来实现（暂不实现）：
- reputation_level: int      # 声望等级
- discount_rate: float       # 折扣率
- func apply_discount(base_price: float) -> float
```

#### 限时商品接口
```
未来实现（暂不实现）：
- daily_specials: Array      # 每日特惠商品
- refresh_timer: Timer       # 刷新计时器
- func refresh_daily_specials() -> void
```

#### 批量交易接口
```
未来实现（暂不实现）：
- bulk_trade_amount: int = 10  # 批量交易数量
- func buy_bulk(item_id: String, amount: int) -> void
- func sell_bulk(item_id: String, amount: int) -> void
```

---

## 第 5 章：金币显示系统

### 5.1 GoldDisplay 属性表

| 字段名 | 类型 | 说明 | 必填 | Demo 阶段 |
|--------|------|------|------|----------|
| gold_label | Label | 显示金币数量的标签 | ✅ | 使用 |
| gold_icon | TextureRect | 金币图标 | ❌ | 使用 |
| current_gold | int | 当前金币数量 | ✅ | 使用 |
| animation_speed | float | 数字滚动速度 | ❌ | **预留接口** |

### 5.2 核心函数清单

| 函数名 | 参数 | 返回 | 说明 | Demo 阶段 |
|--------|------|------|------|----------|
| _ready | 无 | void | 初始化显示 | 使用 |
| update_gold | new_amount: int | void | 更新金币显示 | 使用 |
| animate_gold_change | delta: int | void | 播放数字变化动画 | ❌ | **预留接口** |
| _on_gold_changed | new_amount: int | void | 监听金币变更信号 | 使用 |

### 5.3 显示格式

```
默认格式："💰 50"
变化格式："+15 💰 65" 或 "-5 💰 45"（预留接口）
颜色格式：
  - 增加：绿色 #4CAF50
  - 减少：红色 #F44336
  - 不变：白色 #FFFFFF
```

### 5.4 扩展接口预留

#### 动态效果接口
```
未来实现（暂不实现）：
- particle_effect: GPUParticles2D  # 金币粒子特效
- sound_effect: AudioStreamPlayer  # 音效播放
- scale_animation: Tween           # 缩放动画
```

#### 货币多元化接口
```
未来实现（暂不实现）：
- currencies: Dictionary  # 多种货币
  {
      "gold": 50,         # 金币
      "silver": 100,      # 银币
      "gems": 5           # 宝石
  }
- func get_currency(type: String) -> int
```

---

## 第 6 章：信号定义

### 6.1 UI 系统发射的信号

| 信号名 | 参数 | 触发时机 |
|--------|------|---------|
| ui_opened | ui_type: String | 任何 UI 打开时 |
| ui_closed | ui_type: String | 任何 UI 关闭时 |
| inventory_updated | items: Dictionary | 背包内容变更时 |
| shop_transaction_completed | item_id: String, is_buy: bool, amount: int | 交易完成时 |
| gold_changed | new_amount: int | 金币数量变更时 |

### 6.2 UI 系统监听的信号

| 信号名 | 来源 | 响应行为 |
|--------|------|---------|
| player_interacted | Player | 更新交互提示 |
| tile_state_changed | Plot | 更新交互提示文本 |
| gold_changed | GameManager | 更新金币显示 |
| inventory_changed | GameManager | 更新背包显示 |
| ui_opened | 任意 UI | 关闭当前打开的 UI（互斥） |

---

## 第 7 章：视觉样式规范

### 7.1 配色方案（占位符阶段）

| UI 元素 | 背景色 | 边框色 | 文字色 |
|--------|--------|--------|--------|
| InteractionPrompt | #FFFFFF | #000000 | #000000 |
| InventoryUI | #2C2C2C | #4A4A4A | #FFFFFF |
| ShopUI | #2C2C2C | #4A4A4A | #FFFFFF |
| GoldDisplay | 透明 | 无 | #FFD700 |
| Button (Normal) | #4A4A4A | #2C2C2C | #FFFFFF |
| Button (Hover) | #5A5A5A | #3C3C3C | #FFFFFF |
| Button (Pressed) | #3A3A3A | #1C1C1C | #CCCCCC |

### 7.2 尺寸规范

| UI 元素 | 宽度 | 高度 | 边距 |
|--------|------|------|------|
| InteractionPrompt | 自动 | 自动 | 16px |
| InventoryUI | 400px | 300px | 20px |
| ShopUI | 500px | 350px | 20px |
| GoldDisplay | 自动 | 32px | 8px |
| ItemSlot | 48px | 48px | 4px |

### 7.3 字体规范

| 用途 | 字体大小 | 粗细 | 对齐 |
|------|---------|------|------|
| 标题 | 24px | Bold | 居中 |
| 正文 | 16px | Regular | 左对齐 |
| 按钮 | 18px | Medium | 居中 |
| 提示文本 | 14px | Regular | 居中 |

### 7.4 扩展接口预留

#### 主题切换接口
```
未来实现（暂不实现）：
- theme_presets: Dictionary  # 预设主题
  {
      "dark": {...},
      "light": {...},
      "autumn": {...}
  }
- func load_theme(theme_name: String) -> void
```

#### 自适应布局接口
```
未来实现（暂不实现）：
- min_resolution: Vector2i = Vector2i(800, 600)
- max_resolution: Vector2i = Vector2i(1920, 1080)
- func adapt_to_resolution(new_size: Vector2i) -> void
```

---

## 第 8 章：验证场景

### 场景 1: 交互提示测试

**前提条件**：
- 玩家站在可交互地块旁边
- 地块状态为 waste（荒地）

**操作步骤**：
1. 玩家靠近地块
2. 观察交互提示是否出现
3. 玩家转身离开
4. 观察提示是否消失

**预期结果**：
- ✅ 步骤 2: 显示"按 E 开垦"提示框
- ✅ 步骤 2: 提示框出现在玩家头顶上方
- ✅ 步骤 4: 提示框淡出或立即隐藏
- ✅ 全程无报错、无卡顿

### 场景 2: 背包开关测试

**前提条件**：
- 初始金币 50，背包有 5 个小麦种子

**操作步骤**：
1. 玩家按 I 键
2. 观察背包界面是否打开
3. 玩家再次按 I 键
4. 观察背包界面是否关闭

**预期结果**：
- ✅ 步骤 2: 背包界面打开，显示 5 个小麦种子
- ✅ 步骤 2: 玩家无法移动和交互
- ✅ 步骤 4: 背包界面关闭
- ✅ 步骤 4: 玩家恢复移动和交互

### 场景 3: 商店购买测试

**前提条件**：
- 玩家金币 50，背包有 5 个小麦种子

**操作步骤**：
1. 玩家按 B 键打开商店
2. 点击"购买小麦种子"（价格 5 金）
3. 观察金币和种子数量变化
4. 重复购买直到金币不足

**预期结果**：
- ✅ 步骤 2: 每次点击扣 5 金，加 1 种子
- ✅ 步骤 3: 金币显示实时更新
- ✅ 步骤 4: 金币不足时显示提示"金币不足"
- ✅ 步骤 4: 无法继续购买

### 场景 4: 商店售卖测试

**前提条件**：
- 玩家金币 50，背包有 3 个成熟小麦

**操作步骤**：
1. 玩家按 B 键打开商店
2. 切换到"售卖"标签
3. 点击"售卖小麦"（价格 15 金）
4. 观察金币和小麦数量变化
5. 重复售卖直到小麦耗尽

**预期结果**：
- ✅ 步骤 3: 每次点击扣 1 小麦，加 15 金
- ✅ 步骤 4: 金币显示实时更新
- ✅ 步骤 5: 小麦耗尽时显示提示"没有可售卖的物品"
- ✅ 步骤 5: 无法继续售卖

### 场景 5: UI 互斥测试

**前提条件**：
- 玩家站在空旷地带

**操作步骤**：
1. 玩家按 I 键打开背包
2. 尝试按 B 键
3. 观察商店是否打开
4. 关闭背包后再次按 B 键

**预期结果**：
- ✅ 步骤 2: 商店不会打开（背包已占用）
- ✅ 步骤 3: 或者先关闭背包再打开商店
- ✅ 步骤 4: 商店正常打开

### 场景 6: 金币显示测试

**前提条件**：
- 初始金币 50

**操作步骤**：
1. 购买 1 个小麦种子（-5 金）
2. 观察金币显示
3. 售卖 1 个成熟小麦（+15 金）
4. 观察金币显示

**预期结果**：
- ✅ 步骤 2: 显示从"💰 50"变为"💰 45"
- ✅ 步骤 3: 显示从"💰 45"变为"💰 60"
- ✅ 数字变化流畅，无闪烁
- ✅ 颜色正确（减少红色，增加绿色）

---

## 第 9 章：输出清单

### 必须交付的文件

**脚本文件**：
- [ ] scripts/ui/interaction_prompt.gd - 交互提示逻辑
- [ ] scripts/ui/inventory_ui.gd - 背包界面逻辑
- [ ] scripts/ui/shop_ui.gd - 商店界面逻辑
- [ ] scripts/ui/gold_display.gd - 金币显示逻辑

**场景文件**：
- [ ] scenes/ui/interaction_prompt.tscn - 交互提示场景
- [ ] scenes/ui/inventory_ui.tscn - 背包场景
- [ ] scenes/ui/shop_ui.tscn - 商店场景
- [ ] scenes/ui/gold_display.tscn - 金币显示场景
- [ ] scenes/ui/ui_root.tscn - UI 根场景（包含所有子 UI）

**配置文件**：
- [ ] resources/config/ui/shop_config.tres - 商店商品配置
- [ ] resources/config/ui/ui_theme_config.tres - UI 主题配置（可选）

**项目设置**：
- [ ] project.godot - 添加 UI 相关输入映射（I 键、B 键）

---

## 下一步

完成 UI 系统后，继续：
1. **提示词 5**: 主控制器（Main 游戏入口、6×6 地块网格生成、信号汇总）
2. **提示词 6**: 玩家交互桥接（连接玩家输入和 FarmInteractionSystem）
3. **提示词 7**: 占位资源生成器（动态生成像素风格贴图）
