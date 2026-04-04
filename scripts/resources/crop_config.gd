extends Resource
class_name CropConfig

## 作物唯一标识，例如 "crop_wheat"
@export var crop_id: String = ""

## 作物显示名称
@export var display_name: String = ""

## 总生长阶段数，Demo 默认 3 阶段
@export var growth_stages: int = 3

## 单个阶段的基础时长（秒）
@export var stage_base_duration: float = 5.0

## 基础产量
@export var yield_base: int = 3

## 基础售价
@export var sell_price_base: int = 15

## 每个阶段对应的贴图路径列表
@export var sprites_per_stage: Array[String] = []

## 可播种的季节列表，供 TimeManager 和 Plot 做季节限制判断
@export var suitable_seasons: PackedStringArray = PackedStringArray(["spring", "summer", "autumn"])
