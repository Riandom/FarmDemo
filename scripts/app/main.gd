extends Node2D
class_name Main

@onready var player = $Player
@onready var farm_tiles_parent: Node2D = $FarmTiles
@onready var furniture_parent: Node2D = $Furniture
@onready var explore_root: Node2D = $ExploreRoot
@onready var ui_root: UIRoot = $UI
@onready var farm_manager = get_node_or_null("/root/FarmManager")
@onready var game_manager = get_node_or_null("/root/GameManager")

@export var crop_plot_scene: PackedScene = preload("res://scenes/world/farm/crop_plot.tscn")
@export var bed_scene: PackedScene = preload("res://scenes/world/interactables/bed.tscn")
@export var cave_entrance_scene: PackedScene = preload("res://scenes/world/explore/cave_entrance.tscn")
@export var combat_vendor_scene: PackedScene = preload("res://scenes/actors/combat/combat_vendor.tscn")
@export var cave_room_scene: PackedScene = preload("res://scenes/world/explore/cave_room_01.tscn")

@export var farm_rows: int = 6
@export var farm_cols: int = 6
@export var tile_spacing: float = 32.0
@export var farm_offset: Vector2 = Vector2(64.0, 48.0)

const _DEFAULT_FARM_OFFSET: Vector2 = Vector2(304.0, 204.0)
const _DEFAULT_PLAYER_OFFSET: Vector2 = Vector2(96.0, 240.0)
const _DEFAULT_BED_POSITION: Vector2 = Vector2(200.0, 400.0)
const _DEFAULT_CAVE_ENTRANCE_POSITION: Vector2 = Vector2(1030.0, 254.0)
const _DEFAULT_COMBAT_VENDOR_POSITION: Vector2 = Vector2(1020.0, 420.0)
const _DEFAULT_FARM_RETURN_POSITION: Vector2 = Vector2(940.0, 286.0)

var cave_controller: CaveController = null


func _ready() -> void:
	call_deferred("_initialize_scene")


func _initialize_scene() -> void:
	_position_farm_and_player()
	spawn_farm_tiles(farm_rows, farm_cols)
	spawn_furniture()
	spawn_explore_room()
	ui_root.set_player(player)
	if player.has_method("set_ui_open"):
		player.set_ui_open(false)
	player.z_index = 10
	connect_all_signals()
	call_deferred("_apply_runtime_area_from_game_state")


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

	if player != null and not player.player_defeated.is_connected(_on_player_defeated):
		player.player_defeated.connect(_on_player_defeated)

	if game_manager != null and not game_manager.game_loaded.is_connected(_on_game_loaded):
		game_manager.game_loaded.connect(_on_game_loaded)


func _on_tile_state_changed(_old_state: String, _new_state: String) -> void:
	pass


func _on_crop_harvested(_plot: Plot) -> void:
	if game_manager != null:
		game_manager.total_harvest_count += 1


func _on_ui_opened(_ui_type: String) -> void:
	pass


func _on_ui_closed(_ui_type: String) -> void:
	pass


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


func _on_gold_changed(_new_amount: int) -> void:
	pass


func _on_inventory_updated(_items: Dictionary) -> void:
	pass


func _position_farm_and_player() -> void:
	farm_offset = _DEFAULT_FARM_OFFSET
	player.position = _DEFAULT_PLAYER_OFFSET


func spawn_furniture() -> void:
	for child in furniture_parent.get_children():
		child.queue_free()

	if bed_scene != null:
		var bed: Node = bed_scene.instantiate()
		if bed != null:
			furniture_parent.add_child(bed)
			if bed is Node2D:
				bed.position = _DEFAULT_BED_POSITION

	if cave_entrance_scene != null:
		var entrance: Node = cave_entrance_scene.instantiate()
		if entrance != null:
			furniture_parent.add_child(entrance)
			if entrance is Node2D:
				entrance.position = _DEFAULT_CAVE_ENTRANCE_POSITION

	if combat_vendor_scene != null:
		var vendor: Node = combat_vendor_scene.instantiate()
		if vendor != null:
			furniture_parent.add_child(vendor)
			if vendor is Node2D:
				vendor.position = _DEFAULT_COMBAT_VENDOR_POSITION


func spawn_explore_room() -> void:
	for child in explore_root.get_children():
		child.queue_free()

	if cave_room_scene == null:
		cave_controller = null
		return

	var room: CaveController = cave_room_scene.instantiate() as CaveController
	if room == null:
		cave_controller = null
		return

	explore_root.add_child(room)
	cave_controller = room
	if not cave_controller.drop_awarded.is_connected(_on_cave_drop_awarded):
		cave_controller.drop_awarded.connect(_on_cave_drop_awarded)
	cave_controller.set_target_player(player)
	cave_controller.set_cave_active(false, player)


func _connect_plot_signals(plot: Plot) -> void:
	if not plot.state_changed.is_connected(_on_tile_state_changed):
		plot.state_changed.connect(_on_tile_state_changed)

	if not plot.crop_harvested.is_connected(_on_crop_harvested):
		plot.crop_harvested.connect(_on_crop_harvested)


func enter_cave() -> bool:
	if cave_controller == null:
		return false

	if ui_root != null:
		ui_root.close_current_ui()

	_set_world_area("cave", true, true)
	return true


func exit_cave(_keep_rewards: bool = true, defeated: bool = false) -> bool:
	if game_manager == null:
		return false

	if defeated:
		_apply_cave_defeat_penalty()

	if ui_root != null:
		ui_root.close_current_ui()

	_set_world_area("farm", true, false)
	if player != null:
		player.global_position = _DEFAULT_FARM_RETURN_POSITION
		player.restore_full_health()

	return true


func open_combat_vendor() -> bool:
	if ui_root == null or game_manager == null:
		return false
	if game_manager.current_world_area != "farm":
		return false

	ui_root.open_modal("combat_vendor")
	return true


func player_use_combat_item(item_id: String, player_node: Node2D, facing_direction: Vector2) -> bool:
	if game_manager == null or cave_controller == null:
		return false
	if game_manager.current_world_area != "cave":
		return false
	if item_id != "dart_basic":
		return false
	if not game_manager.has_item("dart_basic", 1):
		return false

	var direction: Vector2 = facing_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT

	var spawn_origin: Vector2 = player_node.global_position + direction * 18.0
	if not cave_controller.spawn_dart(spawn_origin, direction):
		return false

	game_manager.remove_item("dart_basic", 1)
	return true


func _set_world_area(area_id: String, should_reposition_player: bool, reset_cave: bool) -> void:
	var is_cave: bool = area_id == "cave"
	farm_tiles_parent.visible = not is_cave
	furniture_parent.visible = not is_cave

	if cave_controller != null:
		cave_controller.set_target_player(player)
		if is_cave and reset_cave:
			cave_controller.reset_room()
		cave_controller.set_cave_active(is_cave, player)

	if game_manager != null:
		game_manager.set_current_world_area(area_id)

	if is_cave and should_reposition_player and cave_controller != null:
		player.global_position = cave_controller.get_player_spawn_position()


func _apply_runtime_area_from_game_state() -> void:
	if game_manager == null:
		return

	if game_manager.current_world_area == "cave":
		_set_world_area("cave", false, false)
	else:
		_set_world_area("farm", false, false)


func _on_player_defeated() -> void:
	if game_manager == null or game_manager.current_world_area != "cave":
		return
	exit_cave(false, true)


func _apply_cave_defeat_penalty() -> void:
	if game_manager == null:
		return

	var gold_penalty: int = maxi(int(floor(float(game_manager.gold) * 0.25)), 0)
	if gold_penalty > 0:
		game_manager.remove_gold(gold_penalty)


func _on_cave_drop_awarded(item_id: String, count: int) -> void:
	if game_manager == null or item_id == "" or count <= 0:
		return
	game_manager.add_item(item_id, count)


func _on_game_loaded(_data: Dictionary) -> void:
	call_deferred("_apply_runtime_area_from_game_state")
