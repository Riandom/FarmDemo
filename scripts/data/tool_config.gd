extends Resource
class_name ToolConfig

## 工具唯一标识，例如 "hoe_wood"
@export var tool_id: String = ""

## 工具显示名称
@export var display_name: String = ""

## 当前工具允许执行的动作列表
@export var allowed_actions: Array[String] = []

## 使用工具的体力消耗
@export var energy_cost: int = 0

## 工具图标路径
@export var icon_path: String = ""
