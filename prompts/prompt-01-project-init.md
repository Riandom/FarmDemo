# 提示词 1: Godot 4.5 项目初始化

## 任务目标
创建一个完整的 Godot 4.5 项目框架，包含项目配置、文件夹结构、输入映射和占位贴图生成工具。

---

## 项目基础信息

- **引擎版本**: Godot 4.5
- **开发语言**: GDScript
- **窗口分辨率**: 800×600
- **美术规格**: 32×32 像素单位
- **项目类型**: 2D 像素风格种田模拟经营游戏

---

## 必须完成的任务

### 1. 创建 project.godot 配置文件

**关键配置项**:
```ini
[application]
config/name="Farm Demo"
run/main_scene="res://scenes/app/main.tscn"
config/features=PackedStringArray("4.5", "Forward Plus")

[display]
window/size/viewport_width=800
window/size/viewport_height=600
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[input]
move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194320,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194322,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"echo":false,"script":null)
]
}
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"echo":false,"script":null)
]
}
open_inventory={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":73,"key_label":0,"unicode":105,"echo":false,"script":null)
]
}
open_shop={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":66,"key_label":0,"unicode":98,"echo":false,"script":null)
]
}
```

### 2. 创建文件夹结构

在 `e:\FarmDemo\` 下创建以下文件夹：
```
e:\FarmDemo/
├── scenes/           # 场景文件
│   └── ui/          # UI 场景
├── scripts/          # 脚本文件
│   └── ui/          # UI 脚本
├── resources/        # 资源配置
│   ├── crops/       # 作物配置
│   └── items/       # 物品配置
├── assets/           # 资源文件
│   └── sprites/     # 精灵贴图
│       └── placeholder/  # 占位贴图
└── docs/             # 文档
```

### 3. 创建占位贴图生成工具

**文件路径**: `tools/generate_placeholders.gd`

**要求**:
- 使用 GDScript 动态生成彩色矩形 Texture
- 生成以下占位贴图并保存为 PNG：
  - `player.png`: 蓝色矩形 (#4169e1), 32×32
  - `tile_plowed.png`: 棕色 (#8b4513), 32×32
  - `tile_seeded.png`: 浅棕色 + 绿色小点 (#cd853f + #228b22), 32×32
  - `tile_watered.png`: 深棕色 + 水光效果 (#654320 + #4682b4), 32×32
  - `tile_mature.png`: 金黄色麦穗 (#daa520), 32×32
  - `tile_waste.png`: 深灰色荒地 (#3a3a3a), 32×32

**示例代码框架**:
```gdscript
extends EditorScript

func _run() -> void:
    _generate_player_texture()
    _generate_tile_textures()
    print("占位贴图生成完成!")

func _generate_player_texture() -> void:
    var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
    image.fill(Color("#4169e1"))
    image.save_png("res://assets/sprites/placeholder/player.png")

# ... 其他贴图生成函数
```

### 4. 创建项目说明文档

**文件路径**: `docs/README.md`

**内容要求**:
- 项目名称和简介
- Godot 版本要求 (4.5)
- 基本操作说明（WASD 移动，E 交互，I 背包，B 商店）
- 核心玩法循环（开垦→播种→浇水→收获→售卖）

---

## ⛔ 避坑检查清单

### Godot 4.x 语法规范
- ✅ 使用 `@export` 而非 `export`
- ✅ 使用 `@onready` 而非 `onready var`
- ✅ 使用 `@signal` 声明信号（如果在类顶层）
- ✅ 路径使用 `res://` 前缀

### 缩进规范
- ✅ 全项目统一使用 **Tab** 缩进
- ✅ Tab 大小设置为 4
- ⛔ 禁止 Tab 和空格混用

### 命名规范
- ✅ 使用蛇形命名法（snake_case）：`player_speed`, `tile_state`
- ✅ 文件名使用小写，单词间用下划线分隔
- ⛔ 禁止拼音命名、无意义缩写

---

## ✅ 验证步骤

完成后请运行以下检查：

1. **项目可打开**: 双击 `project.godot` 能在 Godot 4.5 中打开
2. **文件夹完整**: 所有上述文件夹已创建
3. **输入映射正确**: 在 Project Settings → Input Map 中看到 7 个输入动作
4. **占位贴图生成**: 运行 `tools/generate_placeholders.gd` 后，`assets/sprites/placeholder/` 中出现 6 个 PNG 文件
5. **无报错警告**: Godot 编辑器底部面板无红色错误和黄色警告

---

## 📝 输出清单

完成后应该有以下文件：
- [ ] `project.godot` - 项目配置文件
- [ ] `scenes/` - 空文件夹
- [ ] `scripts/` - 空文件夹
- [ ] `resources/crops/` - 空文件夹
- [ ] `resources/items/` - 空文件夹
- [ ] `assets/sprites/placeholder/` - 包含 6 个 PNG 文件
- [ ] `tools/generate_placeholders.gd` - 占位贴图生成工具
- [ ] `docs/README.md` - 项目说明文档

---

## 下一步

完成此任务后，请等待用户确认并发送 **提示词 2: 玩家控制系统**。
