# 提示词 7: 占位符资源生成器（动态生成像素风格贴图）

## 项目上下文

这是 Godot 4.5 种田游戏的美术资源生成模块。当前目标是**快速完成 Demo**，使用程序生成的占位符贴图替代手绘美术资源，让游戏可立即运行测试。

**已完成模块**：
- 项目初始化（project.godot, 800×600, 输入映射）
- 玩家控制系统（移动、朝向、交互检测）
- 地块系统（5 状态流转、生长定时器、基础交互）
- UI 系统（交互提示、背包、商店、金币显示）
- 主控制器（Main 场景、6×6 地块网格生成、GameManager 单例）
- 玩家交互桥接（输入处理、智能动作推断、工具切换）
- 系统单例（FarmManager, FarmInteractionSystem, FarmRenderSystem）

**本模块核心职责**：使用 GDScript 动态生成所有必需的占位符贴图资源，包括玩家、地块、作物、工具图标等。

**扩展性要求**：支持自定义配色方案、批量导出 PNG、纹理图集打包，但不实现具体逻辑。

---

## 第 1 章：生成器架构

### 1.1 设计原则

**核心原则**：
1. **一键生成** - 运行工具脚本自动生成所有资源
2. **配置驱动** - 配色方案外部化为配置文件
3. **可替换性** - 占位符资源与正式美术资源接口一致
4. **调试友好** - 生成失败时提供清晰错误提示

### 1.2 资源清单

**必须生成的贴图**：

| 资源类型 | 数量 | 尺寸 | 说明 |
|---------|------|------|------|
| 玩家贴图 | 8 张 | 32×32 | 4 方向×2 状态（idle/walk） |
| 地块贴图 | 5 张 | 32×32 | 5 状态各 1 张 |
| 作物贴图 | 4 张 | 32×32 | 生长阶段 0-3 |
| 工具图标 | 3 张 | 32×32 | 锄头、水壶、镰刀 |
| 物品图标 | 2 张 | 32×32 | 种子、成熟作物 |
| UI 元素 | 若干 | 可变 | 按钮、边框、背景 |

### 1.3 生成器文件结构

```
scripts/tools/
├── texture_generator.gd      # 主生成器脚本
├── color_palette.gd          # 配色方案配置
└── export_helper.gd          # 导出辅助工具（可选）

resources/config/
└── placeholder_colors.tres   # 占位符配色配置文件

assets/sprites/placeholder/
├── player/
│   ├── idle_down.png
│   ├── idle_up.png
│   ├── idle_left.png
│   ├── idle_right.png
│   ├── walk_down.png
│   └── ...
├── tiles/
│   ├── waste.png
│   ├── plowed.png
│   ├── seeded.png
│   ├── watered.png
│   └── mature.png
├── crops/
│   ├── wheat_stage_0.png
│   ├── wheat_stage_1.png
│   ├── wheat_stage_2.png
│   └── wheat_stage_3.png
├── items/
│   ├── seed_wheat.png
│   ├── crop_wheat.png
│   ├── tool_hoe_wood.png
│   ├── tool_watering_can_wood.png
│   └── tool_sickle_wood.png
└── ui/
    ├── button_normal.png
    ├── button_hover.png
    └── button_pressed.png
```

---

## 第 2 章：配色方案配置

### 2.1 ColorPalette 资源配置

```gdscript
# resources/color_palette.gd
extends Resource
class_name ColorPalette

@export_group("玩家颜色")
@export var player_idle_color: Color = Color(0.2, 0.4, 0.8)  # 蓝色
@export var player_walk_color: Color = Color(0.3, 0.5, 0.9)  # 亮蓝色
@export var player_outline: Color = Color(0.1, 0.2, 0.4)     # 深蓝轮廓

@export_group("地块颜色")
@export var waste_color: Color = Color(0.23, 0.23, 0.23)     # 深灰（荒地）
@export var plowed_color: Color = Color(0.55, 0.27, 0.07)    # 棕色（已开垦）
@export var seeded_color: Color = Color(0.8, 0.52, 0.25)     # 浅棕 + 绿点
@export var watered_color: Color = Color(0.4, 0.26, 0.13)    # 深棕 + 水光
@export var mature_color: Color = Color(0.85, 0.65, 0.13)    # 金黄色

@export_group("作物颜色")
@export var wheat_stage_0: Color = Color(0.8, 0.8, 0.2)      # 嫩黄色
@export var wheat_stage_1: Color = Color(0.7, 0.85, 0.2)     # 黄绿色
@export var wheat_stage_2: Color = Color(0.5, 0.9, 0.2)      # 绿色
@export var wheat_stage_3: Color = Color(0.9, 0.75, 0.15)    # 成熟金黄

@export_group("工具颜色")
@export var wood_handle: Color = Color(0.76, 0.6, 0.42)      # 木柄棕色
@export var metal_head: Color = Color(0.6, 0.6, 0.65)        # 金属灰色
@export var stone_head: Color = Color(0.5, 0.45, 0.4)        # 石头褐色

@export_group("UI 颜色")
@export var ui_background: Color = Color(0.17, 0.17, 0.17)   # 深灰背景
@export var ui_border: Color = Color(0.29, 0.29, 0.29)       # 边框灰色
@export var ui_text: Color = Color(1.0, 1.0, 1.0)            # 白色文字
@export var ui_button_normal: Color = Color(0.29, 0.29, 0.29)
@export var ui_button_hover: Color = Color(0.35, 0.35, 0.35)
@export var ui_button_pressed: Color = Color(0.23, 0.23, 0.23)
```

### 2.2 配色配置文件

```gdscript
# resources/config/placeholder_colors.tres
# 通过 Godot 编辑器创建 Resource 文件

{
    "player_idle_color": Color(0.2, 0.4, 0.8),
    "player_walk_color": Color(0.3, 0.5, 0.9),
    "waste_color": Color(0.23, 0.23, 0.23),
    "plowed_color": Color(0.55, 0.27, 0.07),
    "seeded_color": Color(0.8, 0.52, 0.25),
    "watered_color": Color(0.4, 0.26, 0.13),
    "mature_color": Color(0.85, 0.65, 0.13),
    ...
}
```

---

## 第 3 章：纹理生成器核心逻辑

### 3.1 TextureGenerator 主脚本

```gdscript
# scripts/tools/texture_generator.gd
extends Node
class_name TextureGenerator

const OUTPUT_DIR = "res://assets/sprites/placeholder/"
const PALETTE_PATH = "res://resources/config/placeholder_colors.tres"

var palette: ColorPalette


func _ready() -> void:
    # 加载配色方案
    if ResourceLoader.exists(PALETTE_PATH):
        palette = load(PALETTE_PATH) as ColorPalette
    else:
        palette = ColorPalette.new()  # 使用默认配色
    
    # 开始生成
    generate_all_textures()


func generate_all_textures() -> void:
    """生成所有必需的贴图资源"""
    print("[TextureGenerator] 开始生成占位符贴图...")
    
    # 步骤 1: 创建输出目录
    _create_output_directories()
    
    # 步骤 2: 生成玩家贴图
    generate_player_textures()
    
    # 步骤 3: 生成地块贴图
    generate_tile_textures()
    
    # 步骤 4: 生成作物贴图
    generate_crop_textures()
    
    # 步骤 5: 生成工具图标
    generate_tool_icons()
    
    # 步骤 6: 生成物品图标
    generate_item_icons()
    
    # 步骤 7: 生成 UI 元素
    generate_ui_elements()
    
    print("[TextureGenerator] ✓ 所有贴图生成完成！")


func _create_output_directories() -> void:
    """创建输出目录结构"""
    var dirs = ["player", "tiles", "crops", "items", "ui"]
    for dir_name in dirs:
        var dir_path = OUTPUT_DIR.path_join(dir_name)
        DirAccess.make_dir_recursive_absolute(dir_path)
```

### 3.2 玩家贴图生成

```gdscript
func generate_player_textures() -> void:
    """生成 8 张玩家贴图（4 方向 × 2 状态）"""
    print("[TextureGenerator] 生成玩家贴图...")
    
    var directions = ["down", "up", "left", "right"]
    var states = ["idle", "walk"]
    
    for direction in directions:
        for state in states:
            var image = _create_player_image(direction, state)
            var filename = "%s_%s.png" % [state, direction]
            _save_image(image, "player/" + filename)


func _create_player_image(direction: String, state: String) -> Image:
    """创建单张玩家贴图"""
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    var base_color = palette.player_idle_color if state == "idle" else palette.player_walk_color
    var outline_color = palette.player_outline
    
    # 填充基础色（矩形身体）
    _fill_rect(image, Rect2i(8, 8, 16, 16), base_color)
    
    # 绘制轮廓
    _draw_rect_outline(image, Rect2i(8, 8, 16, 16), outline_color, 2)
    
    # 根据朝向添加细节
    match direction:
        "down":
            # 正面：添加眼睛
            _fill_rect(image, Rect2i(12, 12, 3, 3), Color.WHITE)
            _fill_rect(image, Rect2i(17, 12, 3, 3), Color.WHITE)
        "up":
            # 背面：添加头发
            _fill_rect(image, Rect2i(8, 8, 16, 6), outline_color)
        "left":
            # 左侧：添加侧脸轮廓
            _fill_rect(image, Rect2i(10, 12, 8, 6), Color(0.9, 0.75, 0.6))
        "right":
            # 右侧：添加侧脸轮廓
            _fill_rect(image, Rect2i(14, 12, 8, 6), Color(0.9, 0.75, 0.6))
    
    # 行走状态：添加腿部动画偏移
    if state == "walk":
        _add_walk_animation_offset(image, direction)
    
    return image


func _add_walk_animation_offset(image: Image, direction: String) -> void:
    """添加行走动画的轻微偏移"""
    # 简化版：整体下移 1 像素模拟迈步
    var offset = 1
    for y in range(image.get_height() - 1, offset, -1):
        for x in range(image.get_width()):
            var src_color = image.get_pixel(x, y - offset)
            if src_color.a > 0:
                image.set_pixel(x, y, src_color)
```

### 3.3 地块贴图生成

```gdscript
func generate_tile_textures() -> void:
    """生成 5 张地块状态贴图"""
    print("[TextureGenerator] 生成地块贴图...")
    
    var states = {
        "waste": palette.waste_color,
        "plowed": palette.plowed_color,
        "seeded": palette.seeded_color,
        "watered": palette.watered_color,
        "mature": palette.mature_color
    }
    
    for state_name in states.keys():
        var color = states[state_name]
        var image = _create_tile_image(color, state_name)
        _save_image(image, "tiles/%s.png" % state_name)


func _create_tile_image(base_color: Color, state_name: String) -> Image:
    """创建单张地块贴图"""
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    
    # 填充基础色（泥土质感）
    _fill_with_noise(image, base_color, 0.15)  # 15% 噪点
    
    # 根据状态添加特征
    match state_name:
        "seeded":
            # 添加绿色小点（种子发芽）
            _draw_random_dots(image, Color(0.2, 0.8, 0.2), 8)
        "watered":
            # 添加水光效果（深蓝色斑点）
            _draw_water_gleam(image, Color(0.3, 0.5, 0.7))
        "mature":
            # 添加金黄色麦穗图案
            _draw_wheat_pattern(image, palette.mature_color)
    
    # 添加边框（32×32 网格线）
    _draw_grid_border(image, Color.BLACK, 1)
    
    return image
```

### 3.4 作物贴图生成

```gdscript
func generate_crop_textures() -> void:
    """生成 4 张小麦生长阶段贴图"""
    print("[TextureGenerator] 生成作物贴图...")
    
    var stages = {
        0: palette.wheat_stage_0,
        1: palette.wheat_stage_1,
        2: palette.wheat_stage_2,
        3: palette.wheat_stage_3
    }
    
    for stage in stages.keys():
        var color = stages[stage]
        var image = _create_wheat_image(stage, color)
        _save_image(image, "crops/wheat_stage_%d.png" % stage)


func _create_wheat_image(stage: int, color: Color) -> Image:
    """创建单张小麦贴图"""
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    
    # 茎干（绿色细线）
    var stem_color = Color(0.2, 0.6, 0.2)
    var stem_height = 8 + stage * 4  # 随阶段增高
    _fill_rect(image, Rect2i(15, 32 - stem_height, 2, stem_height), stem_color)
    
    # 麦穗（随阶段变大变金黄）
    var ear_size = 4 + stage * 2
    var ear_y = 32 - stem_height - ear_size / 2
    _fill_ellipse(image, Rect2i(16 - ear_size/2, ear_y, ear_size, ear_size), color)
    
    # 阶段 3（成熟）：添加麦芒细节
    if stage >= 3:
        _draw_wheat_awns(image, ear_y, Color(0.95, 0.85, 0.2))
    
    return image
```

### 3.5 工具图标生成

```gdscript
func generate_tool_icons() -> void:
    """生成 3 张工具图标"""
    print("[TextureGenerator] 生成工具图标...")
    
    # 木锄头
    var hoe_image = _create_hoe_icon()
    _save_image(hoe_image, "items/tool_hoe_wood.png")
    
    # 木水壶
    var watering_can_image = _create_watering_can_icon()
    _save_image(watering_can_image, "items/tool_watering_can_wood.png")
    
    # 木镰刀
    var sickle_image = _create_sickle_icon()
    _save_image(sickle_image, "items/tool_sickle_wood.png")


func _create_hoe_icon() -> Image:
    """创建锄头图标"""
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    
    # 木柄（斜向棕色矩形）
    var handle_color = palette.wood_handle
    _draw_rotated_rect(image, Vector2(16, 16), Vector2(4, 20), 45, handle_color)
    
    # 金属头（L 形灰色）
    var metal_color = palette.metal_head
    _fill_rect(image, Rect2i(10, 8, 12, 4), metal_color)  # 横向
    _fill_rect(image, Rect2i(10, 8, 4, 8), metal_color)   # 纵向
    
    return image


func _create_watering_can_icon() -> Image:
    """创建水壶图标"""
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    
    # 壶身（梯形蓝色）
    var body_color = Color(0.3, 0.5, 0.8)
    _fill_trapezoid(image, Rect2i(8, 12, 16, 12), body_color)
    
    # 壶嘴（细长管）
    _draw_line(image, Vector2(24, 14), Vector2(28, 10), body_color, 3)
    
    # 把手（半圆形）
    _draw_arc(image, Vector2(12, 16), 6, PI, 2 * PI, Color(0.4, 0.3, 0.2))
    
    return image


func _create_sickle_icon() -> Image:
    """创建镰刀图标"""
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    
    # 木柄
    var handle_color = palette.wood_handle
    _draw_rotated_rect(image, Vector2(14, 20), Vector2(4, 16), 30, handle_color)
    
    # 弯刃（新月形灰色）
    var blade_color = palette.metal_head
    _draw_crescent(image, Vector2(18, 14), 8, 4, blade_color)
    
    return image
```

### 3.6 物品图标生成

```gdscript
func generate_item_icons() -> void:
    """生成物品图标"""
    print("[TextureGenerator] 生成物品图标...")
    
    # 小麦种子（小颗粒）
    var seed_image = _create_seed_icon()
    _save_image(seed_image, "items/seed_wheat.png")
    
    # 成熟小麦（麦穗束）
    var crop_image = _create_wheat_bundle_icon()
    _save_image(ccrop_image, "items/crop_wheat.png")


func _create_seed_icon() -> Image:
    """创建种子图标"""
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    
    # 3-4 颗小种子（椭圆形淡黄色）
    var seed_color = Color(0.9, 0.85, 0.6)
    _fill_ellipse(image, Rect2i(12, 14, 4, 3), seed_color)
    _fill_ellipse(image, Rect2i(17, 15, 4, 3), seed_color)
    _fill_ellipse(image, Rect2i(14, 19, 4, 3), seed_color)
    
    return image


func _create_wheat_bundle_icon() -> Image:
    """创建小麦束图标"""
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    
    # 3 根麦穗聚拢
    var wheat_color = palette.mature_color
    for i in range(3):
        var offset_x = (i - 1) * 4
        _draw_wheat_stalk(image, Vector2(16 + offset_x, 20), wheat_color)
    
    # 用绳子捆绑（棕色横线）
    _fill_rect(image, Rect2i(12, 22, 8, 3), Color(0.6, 0.4, 0.2))
    
    return image
```

### 3.7 UI 元素生成

```gdscript
func generate_ui_elements() -> void:
    """生成 UI 按钮和背景"""
    print("[TextureGenerator] 生成 UI 元素...")
    
    # 按钮三种状态
    var btn_states = ["normal", "hover", "pressed"]
    var colors = [
        palette.ui_button_normal,
        palette.ui_button_hover,
        palette.ui_button_pressed
    ]
    
    for i in range(btn_states.size()):
        var image = _create_button_image(colors[i])
        _save_image(image, "ui/button_%s.png" % btn_states[i])
    
    # 背包背景
    var bg_image = _create_ui_background()
    _save_image(bg_image, "ui/inventory_background.png")


func _create_button_image(color: Color) -> Image:
    """创建按钮贴图"""
    var image = Image.create(64, 32, false, Image.FORMAT_RGBA8)
    
    # 填充背景色
    _fill_rect(image, Rect2i(0, 0, 64, 32), color)
    
    # 添加边框
    _draw_rect_outline(image, Rect2i(0, 0, 64, 32), Color.WHITE, 2)
    
    # 添加内阴影（按下状态）
    if color == palette.ui_button_pressed:
        _add_inner_shadow(image, Color.BLACK, 2)
    
    return image


func _create_ui_background() -> Image:
    """创建 UI 背景贴图"""
    var image = Image.create(400, 300, false, Image.FORMAT_RGBA8)
    
    # 填充深色背景
    _fill_rect(image, Rect2i(0, 0, 400, 300), palette.ui_background)
    
    # 添加边框
    _draw_rect_outline(image, Rect2i(0, 0, 400, 300), palette.ui_border, 4)
    
    # 添加圆角效果（简化版：四角各画一个小圆弧）
    _fill_circle(image, Vector2i(4, 4), 4, palette.ui_border)
    _fill_circle(image, Vector2i(396, 4), 4, palette.ui_border)
    _fill_circle(image, Vector2i(4, 296), 4, palette.ui_border)
    _fill_circle(image, Vector2i(396, 296), 4, palette.ui_border)
    
    return image
```

---

## 第 4 章：基础绘图工具函数

### 4.1 绘图辅助函数

```gdscript
# 以下函数作为 TextureGenerator 的内部方法或独立工具类

func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
    """填充矩形区域"""
    for y in range(rect.position.y, rect.position.y + rect.size.y):
        for x in range(rect.position.x, rect.position.x + rect.size.x):
            if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
                image.set_pixel(x, y, color)


func _draw_rect_outline(image: Image, rect: Rect2i, color: Color, thickness: int) -> void:
    """绘制矩形边框"""
    var w = rect.size.x
    var h = rect.size.y
    var x0 = rect.position.x
    var y0 = rect.position.y
    
    # 上下边框
    for t in range(thickness):
        _fill_rect(image, Rect2i(x0, y0 + t, w, 1), color)
        _fill_rect(image, Rect2i(x0, y0 + h - 1 - t, w, 1), color)
    
    # 左右边框
    for t in range(thickness):
        _fill_rect(image, Rect2i(x0 + t, y0, 1, h), color)
        _fill_rect(image, Rect2i(x0 + w - 1 - t, y0, 1, h), color)


func _fill_ellipse(image: Image, rect: Rect2i, color: Color) -> void:
    """填充椭圆区域"""
    var cx = rect.position.x + rect.size.x / 2
    var cy = rect.position.y + rect.size.y / 2
    var rx = rect.size.x / 2
    var ry = rect.size.y / 2
    
    for y in range(rect.position.y, rect.position.y + rect.size.y):
        for x in range(rect.position.x, rect.position.x + rect.size.x):
            var dx = (x - cx) / float(rx)
            var dy = (y - cy) / float(ry)
            if dx * dx + dy * dy <= 1.0:
                image.set_pixel(x, y, color)


func _fill_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
    """填充圆形区域"""
    for y in range(center.y - radius, center.y + radius + 1):
        for x in range(center.x - radius, center.x + radius + 1):
            var dx = x - center.x
            var dy = y - center.y
            if dx * dx + dy * dy <= radius * radius:
                if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
                    image.set_pixel(x, y, color)


func _draw_line(image: Image, start: Vector2, end: Vector2, color: Color, thickness: int = 1) -> void:
    """绘制直线（Bresenham 算法）"""
    var x0 = int(start.x)
    var y0 = int(start.y)
    var x1 = int(end.x)
    var y1 = int(end.y)
    
    var dx = abs(x1 - x0)
    var dy = abs(y1 - y0)
    var sx = 1 if x0 < x1 else -1
    var sy = 1 if y0 < y1 else -1
    var err = dx - dy
    
    while true:
        _fill_circle(image, Vector2i(x0, y0), thickness / 2, color)
        if x0 == x1 and y0 == y1:
            break
        var e2 = 2 * err
        if e2 > -dy:
            err -= dy
            x0 += sx
        if e2 < dx:
            err += dx
            y0 += sy


func _draw_rotated_rect(image: Image, center: Vector2, size: Vector2, angle_degrees: float, color: Color) -> void:
    """绘制旋转矩形"""
    var angle_rad = deg_to_rad(angle_degrees)
    var cos_a = cos(angle_rad)
    var sin_a = sin(angle_rad)
    
    # 计算四个顶点
    var half_w = size.x / 2
    var half_h = size.y / 2
    var corners = [
        Vector2(-half_w, -half_h),
        Vector2(half_w, -half_h),
        Vector2(half_w, half_h),
        Vector2(-half_w, half_h)
    ]
    
    var rotated_corners = []
    for corner in corners:
        var rotated = Vector2(
            corner.x * cos_a - corner.y * sin_a,
            corner.x * sin_a + corner.y * cos_a
        )
        rotated_corners.append(center + rotated)
    
    # 填充四边形（简化版：扫描线算法）
    _fill_quadrilateral(image, rotated_corners, color)


func _fill_quadrilateral(image: Image, corners: Array, color: Color) -> void:
    """填充四边形区域"""
    # 简化实现：遍历包围盒内的所有像素，判断是否在四边形内
    var min_x = mini(corners[0].x, corners[1].x, corners[2].x, corners[3].x)
    var max_x = maxi(corners[0].x, corners[1].x, corners[2].x, corners[3].x)
    var min_y = mini(corners[0].y, corners[1].y, corners[2].y, corners[3].y)
    var max_y = maxi(corners[0].y, corners[1].y, corners[2].y, corners[3].y)
    
    for y in range(int(min_y), int(max_y) + 1):
        for x in range(int(min_x), int(max_x) + 1):
            if _point_in_polygon(Vector2(x, y), corners):
                if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
                    image.set_pixel(x, y, color)


func _point_in_polygon(point: Vector2, polygon: Array) -> bool:
    """判断点是否在多边形内（射线法）"""
    var inside = false
    var n = polygon.size()
    var j = n - 1
    
    for i in range(n):
        var pi = polygon[i]
        var pj = polygon[j]
        
        if ((pi.y > point.y) != (pj.y > point.y)) and \
           (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
            inside = !inside
        
        j = i
    
    return inside


func _draw_arc(image: Image, center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
    """绘制圆弧"""
    var step = 0.1  # 弧度步长
    var prev_point = Vector2(
        center.x + radius * cos(start_angle),
        center.y + radius * sin(start_angle)
    )
    
    var angle = start_angle + step
    while angle < end_angle:
        var curr_point = Vector2(
            center.x + radius * cos(angle),
            center.y + radius * sin(angle)
        )
        _draw_line(image, prev_point, curr_point, color, 2)
        prev_point = curr_point
        angle += step


func _draw_crescent(image: Image, center: Vector2, outer_radius: float, inner_radius: float, color: Color) -> void:
    """绘制新月形"""
    # 外圆
    for y in range(int(center.y - outer_radius), int(center.y + outer_radius) + 1):
        for x in range(int(center.x - outer_radius), int(center.x + outer_radius) + 1):
            var dist = Vector2(x, y).distance_to(center)
            if dist <= outer_radius and dist >= inner_radius:
                if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
                    image.set_pixel(x, y, color)


func _fill_with_noise(image: Image, base_color: Color, noise_amount: float) -> void:
    """填充带噪点的颜色"""
    randomize()
    for y in range(image.get_height()):
        for x in range(image.get_width()):
            var noise = randf_range(-noise_amount, noise_amount)
            var noisy_color = base_color.lightened(noise)
            image.set_pixel(x, y, noisy_color)


func _draw_random_dots(image: Image, color: Color, count: int) -> void:
    """随机绘制小点"""
    randomize()
    for i in range(count):
        var x = randi() % image.get_width()
        var y = randi() % image.get_height()
        var size = randi_range(1, 2)
        _fill_circle(image, Vector2i(x, y), size, color)


func _draw_water_gleam(image: Image, color: Color) -> void:
    """绘制水光效果"""
    # 在图像上半部分绘制几个蓝色椭圆
    _fill_ellipse(image, Rect2i(6, 6, 8, 4), color)
    _fill_ellipse(image, Rect2i(18, 10, 6, 3), color)
    _fill_ellipse(image, Rect2i(10, 18, 7, 4), color)


func _draw_wheat_pattern(image: Image, color: Color) -> void:
    """绘制麦穗图案"""
    # 绘制 V 字形麦穗纹理
    for i in range(4):
        var y = 8 + i * 6
        _draw_line(image, Vector2(8, y), Vector2(16, y + 4), color, 2)
        _draw_line(image, Vector2(24, y), Vector2(16, y + 4), color, 2)


func _draw_wheat_awns(image: Image, ear_y: int, color: Color) -> void:
    """绘制麦芒细节"""
    # 从麦穗顶部伸出几条细线
    _draw_line(image, Vector2(16, ear_y), Vector2(14, ear_y - 4), color, 1)
    _draw_line(image, Vector2(16, ear_y), Vector2(16, ear_y - 5), color, 1)
    _draw_line(image, Vector2(16, ear_y), Vector2(18, ear_y - 4), color, 1)


func _draw_wheat_stalk(image: Image, base_pos: Vector2, color: Color) -> void:
    """绘制单根麦穗"""
    # 茎
    _draw_line(image, base_pos, base_pos + Vector2(0, -12), Color(0.2, 0.6, 0.2), 2)
    # 穗
    _fill_ellipse(image, Rect2i(int(base_pos.x) - 3, int(base_pos.y) - 16, 6, 8), color)


func _add_inner_shadow(image: Image, shadow_color: Color, thickness: int) -> void:
    """添加内阴影效果"""
    var w = image.get_width()
    var h = image.get_height()
    
    # 上边和左边
    for i in range(thickness):
        for x in range(i, w - i):
            var top_color = image.get_pixel(x, i)
            image.set_pixel(x, i, top_color.darkened(0.2))
        for y in range(i, h - i):
            var left_color = image.get_pixel(i, y)
            image.set_pixel(i, y, left_color.darkened(0.2))


func _save_image(image: Image, relative_path: String) -> void:
    """保存图像到文件"""
    var full_path = OUTPUT_DIR.path_join(relative_path)
    var error = image.save_png(full_path)
    if error == OK:
        print("  ✓ 生成：%s" % relative_path)
    else:
        print("  ✗ 失败：%s (错误码：%d)" % [relative_path, error])


func mini(a: float, b: float, c: float, d: float) -> float:
    return min(a, min(b, min(c, d)))


func maxi(a: float, b: float, c: float, d: float) -> float:
    return max(a, max(b, max(c, d)))
```

---

## 第 5 章：验证场景

### 场景 1: 一键生成测试

**前提条件**：
- 项目中无现有贴图资源

**操作步骤**：
1. 在 Godot 中打开项目
2. 右键点击 `scripts/tools/texture_generator.gd`
3. 选择"运行"或按 Ctrl+F6
4. 观察控制台输出
5. 检查 `assets/sprites/placeholder/` 目录

**预期结果**：
- ✅ 步骤 4: 控制台打印"[TextureGenerator] 开始生成..."
- ✅ 步骤 4: 逐个显示"✓ 生成：player/idle_down.png"等
- ✅ 步骤 5: 目录包含所有必需贴图（约 20+ 张）
- ✅ 所有 PNG 文件可正常打开查看

### 场景 2: 玩家贴图验证

**前提条件**：
- 已生成玩家贴图

**操作步骤**：
1. 打开 `assets/sprites/placeholder/player/` 目录
2. 查看 8 张贴图
3. 在 Godot 中导入并赋值给 Player 的 Sprite2D

**预期结果**：
- ✅ 步骤 2: 8 张文件存在：idle_down/up/left/right, walk_down/up/left/right
- ✅ 步骤 2: idle 和 walk 颜色有差异（walk 更亮）
- ✅ 步骤 2: 4 方向可辨识（正面有眼睛，背面有头发）
- ✅ 步骤 3: 游戏中玩家显示为蓝色矩形小人

### 场景 3: 地块贴图验证

**前提条件**：
- 已生成地块贴图

**操作步骤**：
1. 打开 `assets/sprites/placeholder/tiles/` 目录
2. 查看 5 张贴图
3. 在游戏中观察 5 状态地块外观

**预期结果**：
- ✅ 步骤 2: 5 张文件存在：waste.png, plowed.png, seeded.png, watered.png, mature.png
- ✅ 步骤 2: 颜色渐变明显（深灰→棕色→浅棕→深棕→金黄）
- ✅ 步骤 2: seeded 有绿色小点，watered 有蓝色水光，mature 有麦穗图案
- ✅ 步骤 3: 游戏中地块状态变化时贴图正确更新

### 场景 4: 作物贴图验证

**前提条件**：
- 已生成作物贴图

**操作步骤**：
1. 打开 `assets/sprites/placeholder/crops/` 目录
2. 查看 4 张小麦贴图
3. 观察生长阶段变化

**预期结果**：
- ✅ 步骤 2: 4 张文件存在：wheat_stage_0/1/2/3.png
- ✅ 步骤 2: 阶段 0 最矮（嫩黄色），阶段 3 最高（金黄色）
- ✅ 步骤 2: 每阶段增高约 4 像素，颜色逐渐变黄
- ✅ 步骤 3: 游戏中作物随时间逐渐长高

### 场景 5: 工具图标验证

**前提条件**：
- 已生成工具图标

**操作步骤**：
1. 打开 `assets/sprites/placeholder/items/` 目录
2. 查看 3 张工具图标
3. 在游戏中装备工具时观察 UI 显示

**预期结果**：
- ✅ 步骤 2: 3 张文件存在：tool_hoe_wood.png, tool_watering_can_wood.png, tool_sickle_wood.png
- ✅ 步骤 2: 锄头有 L 形金属头和木柄，水壶有壶身和壶嘴，镰刀有弯刃
- ✅ 步骤 3: UI 中工具图标清晰可辨

### 场景 6: 完整游戏集成测试

**前提条件**：
- 所有贴图已生成
- Main 场景已配置好所有引用

**操作步骤**：
1. 运行主场景
2. 观察玩家、地块、UI 外观
3. 执行完整种植循环
4. 观察作物生长动画

**预期结果**：
- ✅ 步骤 2: 玩家为蓝色矩形，可区分 4 方向
- ✅ 步骤 2: 地块为 32×32 彩色方块，状态分明
- ✅ 步骤 2: UI 为深灰色背景 + 白色文字
- ✅ 步骤 3: 所有交互反馈正常
- ✅ 步骤 4: 作物从矮到高，颜色从黄到金黄

---

## 第 6 章：输出清单

### 必须交付的文件

**脚本文件**：
- [ ] scripts/tools/texture_generator.gd - 主生成器脚本
- [ ] scripts/resources/color_palette.gd - 配色方案资源类

**配置文件**：
- [ ] resources/config/placeholder_colors.tres - 占位符配色配置

**生成的贴图文件**（运行生成器后自动创建）：
- [ ] assets/sprites/placeholder/player/*.png (8 张)
- [ ] assets/sprites/placeholder/tiles/*.png (5 张)
- [ ] assets/sprites/placeholder/crops/*.png (4 张)
- [ ] assets/sprites/placeholder/items/*.png (5 张)
- [ ] assets/sprites/placeholder/ui/*.png (4 张)

**项目设置**：
- [ ] project.godot - 确保贴图导入设置为像素过滤（Pixel Art）

---

## 下一步

完成占位符资源生成后：
1. **运行完整游戏** - 测试核心玩法闭环
2. **修复 Bug** - 根据测试结果调整代码
3. **优化体验** - 调整数值、添加反馈
4. **创建文档** - README.md + IMPLEMENTATION.md
