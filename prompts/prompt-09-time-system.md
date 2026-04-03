# Phase 2-B: 春季时间系统实现提示词

## 📋 任务概述

为 FarmDemo 实现基于中国传统历法的时间系统，包括二十四节气、十二时辰、四刻等概念。

**这是 Phase 2 的第二部分**，需要在 Phase 2-A（存档系统）完成后实施。

---

## ⏰ 核心需求

### 1. 时间管理器 (TimeManager)

**单例节点**，负责时间推进和状态管理。

#### 时间层级结构（比喻：俄罗斯套娃）

```
年 → 季节 → 节气 → 天 → 时辰 → 刻
 春     立春    D1    子时   初刻
 夏     雨水    D2    丑时   二刻
 秋     惊蛰    D3    寅时   三刻
 冬     春分    D4    卯时   四刻
       清明    D5
       谷雨    D6
```

#### 时间单位换算表

| 游戏单位 | 包含关系 | 现实时长 | 说明 |
|---------|---------|---------|------|
| **1 刻** | 基础单位 | 30 秒 | 最小时间流逝单位 |
| **1 时辰** | 4 刻 | 2 分钟 | 古代 2 小时制（子丑寅卯...） |
| **1 天** | 12 时辰 | 24 分钟 | 完整的一天循环 |
| **1 节气** | 7 天 | 2.8 小时 | 每个节气持续一周 |
| **1 季节** | 6 节气 | 16.8 小时 | 春季 = 立春→谷雨 |
| **1 年** | 4 季节 | 67.2 小时 | 完整四季轮回 |

#### 配置参数（time_config.tres）

需要创建配置文件，便于调整时间流速：

```gdscript
class_name TimeConfig extends Resource

@export var ke_duration_seconds: float = 30.0  # 1 刻的现实时长
@export var days_per_solar_term: int = 7       # 一个节气的天数
@export var solar_terms_per_season: int = 6    # 一个季节的节气数
@export var day_start_shi_chen: int = 3        # 一天开始的时辰（卯时=5:00）
@export var seasons: PackedStringArray = ["spring", "summer", "autumn", "winter"]
```

#### 关键 API

```gdscript
# 时间推进（在 _process 中调用）
func advance_ke() -> void      # 刻数 +1
func advance_shi_chen() -> void # 时辰 +1
func advance_day() -> void      # 天数 +1

# 跳过到第二天卯时（床互动时调用）
func skip_to_next_day_mao_hour() -> void

# 获取显示字符串
func get_time_display_string() -> String  # 返回"春季·谷雨 第 4 天\n辰时三刻"

# 注册/注销地块（用于作物生长）
func register_plot(plot: Node) -> void
func unregister_plot(plot: Node) -> void
```

#### 信号定义

```gdscript
signal time_changed(shi_chen: int, ke: int)
signal day_changed(day_in_term: int)
signal solar_term_changed(solar_term_index: int)
signal crop_growth_triggered(plot_count: int)
```

---

### 2. 床家具系统

床是一个可交互的家具，玩家与之互动可以跳过当天并自动存档。

#### 场景结构

```
Bed (Area2D)
├── Sprite2D (床的贴图)
├── CollisionShape2D (碰撞体)
└── InteractionPrompt (子节点，显示"按 E 休息")
```

#### 交互流程

```
玩家走到床边（进入 Area2D 范围）
    ↓
显示交互提示："按 E 休息"
    ↓
玩家按下 E 键
    ↓
调用 SaveManager.save_game_auto()  # 自动存档
    ↓
调用 TimeManager.skip_to_next_day_mao_hour()  # 跳到次日卯时
    ↓
屏幕淡出效果（黑色矩形透明度 0→255→0）
    ↓
等待 0.3 秒
    ↓
屏幕淡入
    ↓
显示提示："新的一天开始了！卯时"
    ↓
刷新 UI 时间显示
```

#### 时间跳跃规则

| 输入条件 | 输出结果 |
|---------|---------|
| 任何时辰与床互动 | 第二天卯时（时辰=3, 刻=0） |
| 日期变化 | 天数 + 1（节气内天数推进） |
| 节气变化检测 | 如果天数>=7，进入下一节气 |
| 作物生长触发 | 在卯时统一计算生长进度 |

#### 放置位置

- **坐标**: `(200, 400)`（露天放置，农场旁边）
- **朝向**: 面向右侧或下侧
- **交互范围**: 半径 50px

---

### 3. 时间 UI 显示

#### 时间显示面板 (TimeDisplay)

**位置**：屏幕右上角（不遮挡农场和玩家）

**显示内容**：
```
┌─────────────────┐
│ 春季·谷雨 第 4 天 │
│     辰时三刻     │
└─────────────────┘
```

**字段说明**：
- 第一行：`{季节名}·{节气名} 第{N}天`
- 第二行：`{时辰名}{刻名}`（刻名：初刻/二刻/三刻/四刻）

**刷新频率**：每当刻数变化时刷新（每 30 秒现实时间）

#### 节气提示弹窗 (SolarTermPopup)

**触发条件**：进入新节气时（day_in_term == 0）

**显示效果**：
```
┌──────────────────────┐
│                      │
│    今日谷雨          │
│   春季第 1 天         │
│                      │
└──────────────────────┘
```

**持续时间**：3 秒后自动消失

**动画**：从屏幕顶部滑入 → 停留 3 秒 → 向上滑出

---

### 4. 作物生长与时间整合

#### 生长触发时机

```gdscript
# 每个卯时（5:00 AM）到来时触发
func trigger_crop_growth() -> void:
    var farm_manager = get_node_or_null("/root/FarmManager")
    
    for plot in farm_manager.plots.values():
        if plot.base_state == "watered":
            plot.growth_progress += 1.0 / plot.get_growth_stages()
            
            if plot.growth_progress >= 1.0:
                plot.growth_progress = 0.0
                plot.growth_stage += 1
                
                if plot.growth_stage >= plot.max_growth_stage:
                    plot.set_state("mature")
```

#### 小麦生长速率

- **成熟所需时间**：游戏时间 3 天 = 现实时间 72 分钟
- **生长阶段**：4 个阶段（种子→幼苗→成长→成熟）
- **每阶段进度**：每次卯时增加 `1/3 ≈ 0.333`

---

## 📁 需要创建的文件

### 代码文件

```
scripts/systems/
├── time_manager.gd          # 新增：时间管理器单例

scripts/
├── bed_interactive.gd       # 新增：床交互逻辑

ui/
├── time_display.gd          # 新增：时间显示 UI 逻辑
└── solar_term_popup.gd      # 新增：节气弹窗逻辑

scenes/
├── systems/time_manager.tscn
├── furniture/bed.tscn
├── ui/time_display.tscn
└── ui/solar_term_popup.tscn

resources/config/
└── time_config.tres         # 新增：时间流速配置
```

### 配置文件修改

**project.godot**：
```ini
[autoload]
TimeManager="*res://scenes/systems/time_manager.tscn"
```

---

## 🔧 技术实现细节

### 1. 时间推进逻辑

```gdscript
var ke_timer: float = 0.0
var ke_duration: float = 30.0  # 从 time_config 读取

func _process(delta: float) -> void:
    ke_timer += delta
    
    if ke_timer >= ke_duration:
        ke_timer = 0.0
        advance_ke()

func advance_ke() -> void:
    ke += 1
    
    if ke >= 4:
        ke = 0
        advance_shi_chen()
    
    emit_signal("time_changed", shi_chen, ke)

func advance_shi_chen() -> void:
    shi_chen += 1
    
    if shi_chen >= 12:
        shi_chen = 0
        advance_day()
    
    emit_signal("time_changed", shi_chen, ke)

func advance_day() -> void:
    day_in_term += 1
    
    if day_in_term >= 7:
        day_in_term = 0
        solar_term += 1
        
        if solar_term >= 6:
            solar_term = 0
            # 切换季节（Phase 2 暂不实现）
        
        emit_signal("solar_term_changed", solar_term)
    
    emit_signal("day_changed", day_in_term)
    
    # 卯时 0 刻触发作物生长
    if shi_chen == 3 and ke == 0:
        trigger_crop_growth()
```

### 2. 时辰名称映射

```gdscript
var shi_chen_names = [
    "子时", "丑时", "寅时", "卯时", "辰时", "巳时",
    "午时", "未时", "申时", "酉时", "戌时", "亥时"
]

# 关键时间点：
# - 卯时 (索引 3): 5:00-7:00, 天亮，一天开始
# - 酉时 (索引 9): 17:00-19:00, 日落，天黑
```

### 3. 节气名称映射

```gdscript
var solar_term_names = [
    "立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
    "立夏", "小满", "芒种", "夏至", "小暑", "大暑",
    "立秋", "处暑", "白露", "秋分", "寒露", "霜降",
    "立冬", "小雪", "大雪", "冬至", "小寒", "大寒"
]

# Phase 2 只实现春季 6 个节气（索引 0-5）
```

### 4. 床的淡出效果

```gdscript
# 使用 CanvasLayer + ColorRect 实现
var fade_overlay: ColorRect

func fade_out(duration: float = 0.3):
    var tween = create_tween()
    tween.tween_property(fade_overlay, "modulate:a", 1.0, duration)
    await tween.finished
    await get_tree().create_timer(0.3).timeout
    tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)
```

---

## ✅ 验证清单

### 时间推进测试
- [ ] 等待 30 秒现实时间，刻数 +1，UI 刷新
- [ ] 等待 2 分钟（4 刻），时辰 +1，UI 刷新
- [ ] 等待 24 分钟（12 时辰），天数 +1
- [ ] 修改日期到节气最后一天，次日进入新节气并弹出提示
- [ ] UI 显示"辰时三刻"格式，而非数字时间

### 床系统测试
- [ ] 走到床边显示"按 E 休息"提示
- [ ] 按 E 键后立即跳到次日卯时
- [ ] 跳天后自动存档（重启游戏能读取）
- [ ] 等到酉时（17:00）与床互动，直接到次日卯时（05:00）
- [ ] 设置到节气最后一天，与床互动进入新节气
- [ ] 连续使用 3 天，每次都正常跳转无错误

### 作物生长测试
- [ ] 播种→浇水，等待到卯时，生长进度增加
- [ ] 等待 3 个卯时（游戏 3 天），小麦成熟
- [ ] 成熟后可用镰刀收获
- [ ] 收获后地块回到已开垦状态

### 集成测试
- [ ] 播种→浇水→等 1 天→收获，完整循环正常
- [ ] 等到未时（13:00）存档，读档后时间恢复到未时
- [ ] 设置到谷雨第 6 天亥时，与床互动进入立夏日第 1 天卯时

---

## 📝 注意事项

### ⚠️ 必须遵守的规范

1. **配置分离**：时间流速参数写在 `time_config.tres` 中，不要硬编码
2. **信号解耦**：TimeManager 通过信号与 UI 通信
3. **向后兼容**：预留夏季、秋季、冬季的扩展接口
4. **性能优化**：地块遍历使用 FarmManager 的 plots 字典，O(1) 查找

### 🎨 UI 设计建议

- 时间显示面板：右上角 (690, 10)，白色文字，半透明黑色背景
- 节气弹窗：屏幕顶部中央，从上方滑入，3 秒后向上滑出
- 字体大小：16-20px，清晰可读

### 🐛 常见问题

**Q: 时间推进卡顿？**  
A: 检查 `_process` 中是否有耗时操作，确保只做简单的计时和信号发射

**Q: 作物不生长？**  
A: 确认卯时（索引 3）0 刻时调用了 `trigger_crop_growth()`，且地块状态是 `watered`

**Q: 床互动后时间不对？**  
A: 检查 `skip_to_next_day_mao_hour()` 是否正确设置了 `shi_chen=3, ke=0`

---

## 🚀 下一步

完成 Phase 2-B 后，整个 Phase 2（存档系统 + 时间系统）就全部实现了！

接下来可以：
1. 运行完整的测试流程
2. 收集反馈并优化细节
3. 准备 Phase 3（夏季、天气系统等）

---

**文档版本**: v1.0  
**创建日期**: 2026-04-03  
**适用阶段**: Demo 0.2 - 春季时间系统  
**前置条件**: Phase 2-A（存档系统）已完成  
**下一步**: 将此文档交给 Codex 执行实现
