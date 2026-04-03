# Phase 2-A: 存档系统实现提示词

## 📋 任务概述

为 FarmDemo 实现完整的 JSON 格式存档/读档系统，支持 5 个手动存档位 + 1 个自动存档位。

**这是 Phase 2 的第一部分**，专注于存档功能。时间系统将在 Phase 2-B 中实现。

---

## 🎯 核心需求

### 1. 存档管理器 (SaveManager)

**单例节点**，负责所有存档相关操作。

#### 功能要求

- ✅ **JSON 格式存档**：人类可读，便于调试
- ✅ **6 个存档位**：
  - 5 个手动存档位 (`save_01.json` ~ `save_05.json`)
  - 1 个自动存档位 (`save_auto.json`)
- ✅ **版本管理**：存档包含 version 字段（当前 `"0.2.0"`）
- ✅ **错误处理**：损坏存档、文件不存在、写入失败等情况
- ✅ **信号系统**：存档完成/读档完成时发出信号

#### 存档数据结构

```json
{
  "version": "0.2.0",
  "save_timestamp": "2026-04-03T15:30:00Z",
  "game_state": {
    "player": {
      "position_x": 128.5,
      "position_y": 256.0,
      "gold": 150,
      "inventory": {"seed_wheat": 10, "crop_wheat": 5},
      "unlocked_tools": ["hoe_wood", "watering_can_basic"],
      "current_tool": "hoe_wood"
    },
    "farm": {
      "plots": [
        {
          "grid_x": 0,
          "grid_y": 0,
          "base_state": "plowed",
          "growth_stage": 2,
          "growth_progress": 0.65,
          "crop_config_id": "crop_wheat"
        }
      ]
    }
  }
}
```

#### 关键 API

```gdscript
# 自动存档（床互动时调用）
func save_game_auto() -> void

# 手动存档（指定槽位 0-4）
func save_game_manual(slot_index: int) -> void

# 自动读档
func load_game_auto() -> void

# 手动读档（指定槽位 0-4）
func load_game_manual(slot_index: int) -> void

# 获取存档信息（用于 UI 显示）
func get_save_file_info(file_path: String) -> Dictionary
```

---

### 2. 存档/读档 UI (SaveLoadUI)

**Esc 菜单集成**，玩家按 ESC 打开暂停菜单，可选择存档或读档。

#### UI 场景结构

```
SaveLoadUI (Control)
├── PanelContainer
│   ├── TitleLabel (Label) - "保存存档" 或 "加载存档"
│   ├── SaveSlotsContainer (VBoxContainer)
│   │   ├── SlotButton1 (Button) - "存档 1 - 春季·谷雨 第 4 天 (120 分钟)"
│   │   ├── SlotButton2 (Button) - "存档 2 - 空"
│   │   └── ... (共 5 个手动存档按钮 + 1 个自动存档按钮)
│   └── CloseButton (Button)
```

#### 交互流程

**存档流程**：
```
玩家按 ESC → 打开暂停菜单
    ↓
点击"保存游戏" → 显示存档位列表
    ↓
选择存档位 → 调用 SaveManager.save_game_manual(slot_index)
    ↓
显示"已存档"提示 → 关闭 UI
```

**读档流程**：
```
玩家按 ESC → 打开暂停菜单
    ↓
点击"加载游戏" → 显示存档位列表
    ↓
选择存档位 → 调用 SaveManager.load_game_manual(slot_index)
    ↓
恢复游戏状态 → 刷新 UI → 关闭 UI
```

---

### 3. GameManager 扩展

在现有 `GameManager` 中添加存档相关接口：

```gdscript
# 预留的存档/读档方法（由 SaveManager 调用）
func save_game() -> bool
func load_game() -> bool

# 已有字段需要保存：
# - gold: int
# - inventory: Dictionary
# - unlocked_tools: PackedStringArray
# - current_tool: String
```

---

## 📁 需要创建的文件

### 代码文件

```
scripts/systems/
└── save_manager.gd          # 新增：存档管理器单例

scenes/
└── systems/
    └── save_manager.tscn    # 新增：存档管理器场景

ui/
└── save_load_ui.gd          # 新增：存档/读档 UI 逻辑

scenes/ui/
└── save_load_ui.tscn        # 新增：存档/读档 UI 场景
```

### 配置文件修改

**project.godot**：
```ini
[autoload]
SaveManager="*res://scenes/systems/save_manager.tscn"
```

---

## 🔧 技术实现细节

### 1. 存档文件路径

```gdscript
const SAVE_DIR = "user://"
const AUTO_SAVE_FILE = "user://save_auto.json"
const MANUAL_SAVE_FILES = [
    "user://save_01.json",
    "user://save_02.json",
    "user://save_03.json",
    "user://save_04.json",
    "user://save_05.json"
]
```

### 2. 存档写入策略（防止损坏）

```gdscript
# 1. 先写入临时文件
var temp_file_path = file_path + ".tmp"
var file = FileAccess.open(temp_file_path, FileAccess.WRITE)
file.store_string(json_string)
file.close()

# 2. 删除旧存档
if FileAccess.file_exists(file_path):
    DirAccess.remove_absolute(file_path)

# 3. 重命名临时文件为正式文件
var dir = DirAccess.open("user://")
dir.rename(temp_file_path, file_path)
```

### 3. 读档错误处理

```gdscript
# 检查文件是否存在
if not FileAccess.file_exists(file_path):
    emit_signal("load_completed", false, "Save file not found")
    return

# 解析 JSON
var json = JSON.new()
var parse_result = json.parse(json_string)
if parse_result != OK:
    emit_signal("load_completed", false, "Invalid JSON format")
    return

# 校验 version 字段
if not save_data.has("version"):
    emit_signal("load_completed", false, "Invalid save data: missing version")
    return
```

### 4. 信号定义

**SaveManager 信号**：
```gdscript
signal save_started(save_type: String, slot_index: int)
signal save_completed(success: bool, file_path: String)
signal load_started(save_type: String, slot_index: int)
signal load_completed(success: bool, error_message: String)
```

---

## ✅ 验证清单

完成后请逐项测试：

### 基础功能测试
- [ ] 按 ESC 打开暂停菜单
- [ ] 点击"保存游戏"显示 5 个存档位 + 自动存档
- [ ] 选择存档位后成功保存
- [ ] 再次打开能看到存档信息（游戏时间、游玩时长）
- [ ] 点击"加载游戏"能读取存档
- [ ] 读档后金币、背包、位置完全恢复

### 错误处理测试
- [ ] 读取不存在的存档位不会崩溃
- [ ] 手动修改 JSON 使其损坏，读取时提示错误
- [ ] 存档覆盖 5 次后，每次都是最新状态

### 集成测试
- [ ] 播种→浇水→存档→读档，地块状态一致
- [ ] 改变金币数量→存档→重启游戏读档，金币数量正确
- [ ] 连续存档 5 次，无数据残留或冲突

---

## 📝 注意事项

### ⚠️ 必须遵守的规范

1. **使用 Godot 用户数据目录** (`user://`)，不要使用绝对路径
2. **临时文件策略**：先写 `.tmp` 再重命名，防止存档损坏
3. **向后兼容**：如果未来添加新字段，旧存档要用默认值填充
4. **信号解耦**：SaveManager 通过信号与 UI 通信，不要直接耦合

### 🎨 UI 设计建议

- 存档位按钮显示格式：`"存档 X - {季节名}·{节气名} 第 N 天 ({游玩分钟}分钟)"`
- 空存档位显示：`"存档 X - 空"`
- 自动存档按钮显示：`"自动存档 - {游戏时间}"` 或 `"自动存档 - 无"`

---

## 🚀 下一步

完成 Phase 2-A 后，将继续实现 **Phase 2-B：春季时间系统**，包括：
- TimeManager 单例（刻→时辰→天→节气推进）
- 床家具（跳过当天 + 自动存档）
- 时间 UI 显示（右上角面板）
- 节气变化弹窗

---

**文档版本**: v1.0  
**创建日期**: 2026-04-03  
**适用阶段**: Demo 0.2 - 存档系统  
**下一步**: 将此文档交给 Codex 执行实现
