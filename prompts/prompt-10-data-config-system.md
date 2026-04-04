# Phase 3-A: 数据配置系统实现提示词

## 任务概述

为 FarmDemo 建立统一的、面向未来的数据配置系统架构，但采用**增量接管**而不是一次性重构。  
本阶段是 Demo 0.3.0 的地基，目标是让作物、工具、季节、时间规则都可以通过统一入口访问，同时**不破坏 Demo 0.2 已验证通过的链路**。

---

## 核心目标

### 1. 新增统一配置入口

新增 `ConfigManager` 单例，负责：

- 预加载所有配置资源到内存
- 提供统一查询接口
- 对缺失配置给出 warning，而不是让游戏直接崩溃
- 为未来联网同步预留接口，但本阶段不实现联网能力

### 2. 新增季节与时间配置资源

新增两个 Resource 类：

- `SeasonConfig`
- `TimeSystemConfig`

同时创建对应 `.tres` 资源：

- `resources/config/seasons/spring_config.tres`
- `resources/config/seasons/summer_config.tres`
- `resources/config/seasons/autumn_config.tres`
- `resources/config/seasons/winter_config.tres`
- `resources/config/time_system_config.tres`

### 3. 保留旧链路的兼容回退

本阶段**不立即删除**现有 `time_config.tres`，也不要求所有系统瞬间切到新配置源。

要求：

- `TimeManager` 优先读 `ConfigManager.get_time_config()`，如失败再回退旧 `time_config.tres`
- `FarmInteractionSystem` 优先通过 `ConfigManager` 取工具配置，如失败保留旧加载路径
- `Plot` 优先通过 `ConfigManager` 取作物配置，如失败保留旧加载路径

### 4. 扩展现有 CropConfig

为 `CropConfig` 新增：

```gdscript
@export var suitable_seasons: PackedStringArray = PackedStringArray(["spring", "summer", "autumn"])
```

作用：

- 让播种合法性可以基于季节配置判断
- 为 Phase 3-B 的四季逻辑提供数据基础

---

## 文件与结构要求

### 新增代码文件

```text
scripts/systems/config_manager.gd
scripts/resources/season_config.gd
scripts/resources/time_system_config.gd
scenes/systems/config_manager.tscn
```

### 新增配置资源

```text
resources/config/time_system_config.tres
resources/config/seasons/spring_config.tres
resources/config/seasons/summer_config.tres
resources/config/seasons/autumn_config.tres
resources/config/seasons/winter_config.tres
```

### 修改现有文件

```text
project.godot
scripts/resources/crop_config.gd
scripts/systems/time_manager.gd
scripts/systems/farm_interaction_system.gd
scripts/plot/plot.gd
resources/config/crops/wheat_config.tres
```

---

## ConfigManager 设计要求

### 单例注册

`ConfigManager` 必须注册为 autoload，并且顺序上位于：

- `TimeManager` 之前
- `FarmInteractionSystem` 之前

### 必须提供的 API

```gdscript
func preload_all_configs() -> void

func get_crop_config(crop_id: String) -> CropConfig
func get_all_crops() -> Array[CropConfig]

func get_tool_config(tool_id: String) -> ToolConfig
func get_all_tools() -> Array[ToolConfig]

func get_season_config(season_id: String) -> SeasonConfig
func get_all_seasons() -> Array[SeasonConfig]
func get_current_season_config() -> SeasonConfig

func get_time_config() -> TimeSystemConfig

func sync_configs_from_server(server_url: String) -> bool
func update_crop_config(crop_id: String, new_data: Dictionary) -> void
```

### 加载策略

- 游戏启动时一次性扫描并缓存配置
- 使用字典映射，访问复杂度为 O(1)
- 找不到资源时只 `push_warning(...)`
- 不允许因为单个配置损坏而让整个主场景无法进入

---

## SeasonConfig 要求

```gdscript
extends Resource
class_name SeasonConfig

@export var season_id: String = ""
@export var display_name: String = ""
@export var solar_terms: PackedStringArray = PackedStringArray()
@export var growth_rate_multiplier: float = 1.0
@export var background_color: Color = Color.WHITE
@export var season_summary: String = ""
```

---

## TimeSystemConfig 要求

```gdscript
extends Resource
class_name TimeSystemConfig

@export var ke_duration_seconds: float = 30.0
@export var days_per_solar_term: int = 7
@export var solar_terms_per_season: int = 6
@export var day_start_shi_chen: int = 3
@export var seasons_order: PackedStringArray = PackedStringArray(["spring", "summer", "autumn", "winter"])
@export var shi_chen_names: PackedStringArray = PackedStringArray([...12 个时辰...])
@export var ke_names: PackedStringArray = PackedStringArray(["初刻", "二刻", "三刻", "四刻"])
```

说明：

- 时间系统总规则放在这里，不再继续堆在 `TimeManager` 常量里
- 本阶段不删除旧 `TimeConfig` 类，保留兼容过渡

---

## 四季资源要求

- 春季：倍率 `1.0`，摘要 `作物生长速度正常`
- 夏季：倍率 `1.2`，摘要 `作物生长速度 +20%`
- 秋季：倍率 `0.9`，摘要 `作物生长速度 -10%`
- 冬季：倍率 `0.0`，摘要 `室外作物停止自然生长`

四季节气列表必须完整，背景色必须可用于轻量季节 UI。

---

## 范围边界

### 本阶段必须做

- 统一配置读取入口
- 四季与时间规则资源化
- `CropConfig` 扩展适种季节字段
- 旧系统接入 `ConfigManager` 的兼容改造

### 本阶段不做

- 完整新作物玩法链
- 粒子系统
- 联机同步
- 删除旧 `time_config.tres`

---

## 验证标准

- `ConfigManager` 启动成功并注册为 autoload
- 作物、工具、季节、时间配置都能通过统一入口读取
- Demo 0.2 的移动、种植、浇水、收获、存读档链路不退化
- 单个配置缺失时给出 warning，但主场景仍能进入
- 旧 `time_config.tres` 仍可作为回退来源存在

---

**文档版本**：v2.0  
**适用阶段**：Demo 0.3.0 / Prompt 10  
**前置条件**：Demo 0.2 已稳定  
**后续阶段**：Prompt 11 完整四季循环
