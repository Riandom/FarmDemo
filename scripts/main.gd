extends Node2D
class_name Main

## 主角节点
@onready var player = $Player

## 地块父节点
@onready var farm_tiles_parent: Node2D = $FarmTiles
@onready var furniture_parent: Node2D = $Furniture

## UI 根节点
@onready var ui_root: UIRoot = $UI
@onready var farm_manager = get_node_or_null("/root/FarmManager")
@onready var game_manager = get_node_or_null("/root/GameManager")

## 地块预制体
@export var crop_plot_scene: PackedScene = preload("res://scenes/plot/crop_plot.tscn")
@export var bed_scene: PackedScene = preload("res://scenes/furniture/bed.tscn")

## 农场行数
@export var farm_rows: int = 6

## 农场列数
@export var farm_cols: int = 6

## 地块间距
@export var tile_spacing: float = 32.0

## 农场整体偏移
@export var farm_offset: Vector2 = Vector2(64.0, 48.0)

const _DEFAULT_FARM_OFFSET: Vector2 = Vector2(304.0, 204.0)
const _DEFAULT_PLAYER_OFFSET: Vector2 = Vector2(96.0, 240.0)
const _DEFAULT_BED_POSITION: Vector2 = Vector2(200.0, 400.0)


func _ready() -> void:
	"""等待一帧后再初始化，确保视口尺寸有效。"""
	call_deferred("_initialize_scene")


func _initialize_scene() -> void:
	"""初始化主场景、生成地块并连接系统。"""
	_position_farm_and_player()
	spawn_farm_tiles(farm_rows, farm_cols)
	spawn_furniture()
	ui_root.set_player(player)
	if player.has_method("set_ui_open"):
		player.set_ui_open(false)
	player.z_index = 10
	connect_all_signals()


## 生成农场地块网格
func spawn_farm_tiles(rows: int, cols: int) -> void:
	for child in farm_tiles_parent.get_children():
		child.queue_free()

	for row in range(rows):
		for col in range(cols):
			var plot_instance: Plot = crop_plot_scene.instantiate() as Plot
			if plot_instance == null:
				continue

			plot_instance.grid_position = Vector2i(col, row)
			plot_instance.global_position = farm_offset + Vector2(col * tile_spacing, row * tile_spacing)
			farm_tiles_parent.add_child(plot_instance)
			_connect_plot_signals(plot_instance)


## 连接主场景所需信号
func connect_all_signals() -> void:
	if not player.ui_interaction_requested.is_connected(_on_ui_interaction_requested):
		player.ui_interaction_requested.connect(_on_ui_interaction_requested)

	if not ui_root.ui_opened.is_connected(_on_ui_opened):
		ui_root.ui_opened.connect(_on_ui_opened)

	if not ui_root.ui_closed.is_connected(_on_ui_closed):
		ui_root.ui_closed.connect(_on_ui_closed)

	if game_manager != null and not game_manager.gold_changed.is_connected(_on_gold_changed):
		game_manager.gold_changed.connect(_on_gold_changed)

	if game_manager != null and not game_manager.inventory_changed.is_connected(_on_inventory_updated):
		game_manager.inventory_changed.connect(_on_inventory_updated)


## 监听地块状态变更
func _on_tile_state_changed(old_state: String, new_state: String) -> void:
	pass


## 监听作物收获事件
func _on_crop_harvested(plot: Plot) -> void:
	if game_manager != null:
		game_manager.total_harvest_count += 1


## UI 打开时的轻量回调
func _on_ui_opened(ui_type: String) -> void:
	pass


## UI 关闭时的轻量回调
func _on_ui_closed(ui_type: String) -> void:
	pass


## 接收玩家脚本的 UI 打开请求并转交给 UIRoot 统一处理
func _on_ui_interaction_requested(ui_type: String) -> void:
	match ui_type:
		"inventory":
			ui_root.toggle_inventory()
		"shop":
			ui_root.toggle_shop()
		"pause_menu":
			ui_root.toggle_pause_menu()
		_:
			push_warning("[Main] Unknown UI request: %s" % ui_type)


## 金币变化时的轻量回调
func _on_gold_changed(new_amount: int) -> void:
	pass


## 背包变化时的轻量回调
func _on_inventory_updated(items: Dictionary) -> void:
	pass


func _position_farm_and_player() -> void:
	"""使用固定布局，避免运行早期视口尺寸未就绪导致出生点漂到左上角。"""
	farm_offset = _DEFAULT_FARM_OFFSET
	player.position = _DEFAULT_PLAYER_OFFSET


func spawn_furniture() -> void:
	for child in furniture_parent.get_children():
		child.queue_free()

	if bed_scene == null:
		return

	var bed: Node = bed_scene.instantiate()
	if bed == null:
		return

	furniture_parent.add_child(bed)
	if bed is Node2D:
		bed.position = _DEFAULT_BED_POSITION


func _connect_plot_signals(plot: Plot) -> void:
	"""连接单个地块的关键逻辑信号。"""
	if not plot.state_changed.is_connected(_on_tile_state_changed):
		plot.state_changed.connect(_on_tile_state_changed)

	if not plot.crop_harvested.is_connected(_on_crop_harvested):
		plot.crop_harvested.connect(_on_crop_harvested)
