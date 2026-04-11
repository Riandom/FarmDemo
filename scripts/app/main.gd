extends Node2D
class_name Main

@onready var player = $Player
@onready var farm_tiles_parent: Node2D = $FarmTiles
@onready var furniture_parent: Node2D = $Furniture
@onready var house_root: Node2D = $HouseRoot
@onready var town_root: Node2D = $TownRoot
@onready var explore_root: Node2D = $ExploreRoot
@onready var ui_root: UIRoot = $UI
@onready var farm_manager = get_node_or_null("/root/FarmManager")
@onready var game_manager = get_node_or_null("/root/GameManager")

@export var crop_plot_scene: PackedScene = preload("res://scenes/world/farm/crop_plot.tscn")
@export var bed_scene: PackedScene = preload("res://scenes/world/interactables/bed.tscn")
@export var storage_chest_scene: PackedScene = preload("res://scenes/world/interactables/storage_chest.tscn")
@export var cave_entrance_scene: PackedScene = preload("res://scenes/world/explore/cave_entrance.tscn")
@export var combat_vendor_scene: PackedScene = preload("res://scenes/actors/combat/combat_vendor.tscn")
@export var cave_room_scene: PackedScene = preload("res://scenes/world/explore/cave_room_01.tscn")
@export var house_scene: PackedScene = preload("res://scenes/world/house/player_house.tscn")
@export var town_scene: PackedScene = preload("res://scenes/world/town/town_square.tscn")
@export var area_transition_point_scene: PackedScene = preload("res://scenes/world/interactables/area_transition_point.tscn")

@export var farm_rows: int = 6
@export var farm_cols: int = 6
@export var tile_spacing: float = 32.0
@export var farm_offset: Vector2 = Vector2(64.0, 48.0)

const _DEFAULT_FARM_OFFSET: Vector2 = Vector2(304.0, 204.0)
const _DEFAULT_PLAYER_OFFSET: Vector2 = Vector2(96.0, 240.0)
const _DEFAULT_CAVE_ENTRANCE_POSITION: Vector2 = Vector2(1030.0, 254.0)
const _DEFAULT_COMBAT_VENDOR_POSITION: Vector2 = Vector2(1020.0, 420.0)
const _DEFAULT_FARM_RETURN_POSITION: Vector2 = Vector2(940.0, 286.0)
const _DEFAULT_HOUSE_ENTRANCE_POSITION: Vector2 = Vector2(176.0, 300.0)
const _DEFAULT_TOWN_ENTRANCE_POSITION: Vector2 = Vector2(1120.0, 360.0)
const _DEFAULT_HOUSE_SPAWN_POSITION: Vector2 = Vector2(640.0, 430.0)
const _DEFAULT_TOWN_SPAWN_POSITION: Vector2 = Vector2(512.0, 320.0)

var cave_controller: CaveController = null


func _ready() -> void:
	call_deferred("_initialize_scene")


func _initialize_scene() -> void:
	_position_farm_and_player()
	spawn_farm_tiles(farm_rows, farm_cols)
	spawn_furniture()
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

	if area_transition_point_scene != null:
		var house_entrance: AreaTransitionPoint = area_transition_point_scene.instantiate() as AreaTransitionPoint
		if house_entrance != null:
			house_entrance.prompt_text = "进入小屋"
			house_entrance.target_area_id = "house"
			house_entrance.entry_point_id = "house_from_farm"
			house_entrance.success_message = "你走进了自己的小屋"
			house_entrance.failure_message = "现在无法进入小屋"
			furniture_parent.add_child(house_entrance)
			house_entrance.position = _DEFAULT_HOUSE_ENTRANCE_POSITION

		var town_entrance: AreaTransitionPoint = area_transition_point_scene.instantiate() as AreaTransitionPoint
		if town_entrance != null:
			town_entrance.prompt_text = "前往镇子"
			town_entrance.target_area_id = "town"
			town_entrance.entry_point_id = "town_from_farm"
			town_entrance.success_message = "你来到了镇子"
			town_entrance.failure_message = "现在无法前往镇子"
			furniture_parent.add_child(town_entrance)
			town_entrance.position = _DEFAULT_TOWN_ENTRANCE_POSITION


func _ensure_area_scene_loaded(area_root: Node2D, scene: PackedScene) -> void:
	if area_root == null:
		return

	if area_root.get_child_count() > 0:
		return

	if scene == null:
		return

	var instance: Node = scene.instantiate()
	if instance == null:
		return

	area_root.add_child(instance)
	if instance is CanvasItem:
		instance.visible = true


func _ensure_cave_room_loaded() -> void:
	if cave_controller != null and is_instance_valid(cave_controller):
		return
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


func _ensure_runtime_area_loaded(area_id: String) -> void:
	match area_id:
		"house":
			_ensure_area_scene_loaded(house_root, house_scene)
		"town":
			_ensure_area_scene_loaded(town_root, town_scene)
		"cave":
			_ensure_cave_room_loaded()
		_:
			pass


func _connect_plot_signals(plot: Plot) -> void:
	if not plot.state_changed.is_connected(_on_tile_state_changed):
		plot.state_changed.connect(_on_tile_state_changed)

	if not plot.crop_harvested.is_connected(_on_crop_harvested):
		plot.crop_harvested.connect(_on_crop_harvested)


func enter_cave() -> bool:
	var area_manager = get_node_or_null("/root/WorldAreaManager")
	if area_manager == null or not area_manager.has_method("request_enter_area"):
		return false
	return bool(area_manager.call("request_enter_area", "cave", "cave_from_farm"))


func exit_cave(_keep_rewards: bool = true, defeated: bool = false) -> bool:
	if defeated:
		_apply_cave_defeat_penalty()
	var area_manager = get_node_or_null("/root/WorldAreaManager")
	if area_manager == null or not area_manager.has_method("return_to_area"):
		return false
	var success: bool = bool(area_manager.call("return_to_area", "farm", "farm_from_cave"))
	if success and player != null:
		player.restore_full_health()
	return success


func open_combat_vendor() -> bool:
	if ui_root == null or game_manager == null:
		return false
	if game_manager.current_world_area != "farm":
		return false

	ui_root.open_modal("combat_vendor")
	return true


func open_storage_chest(chest: StorageChest) -> bool:
	if ui_root == null or chest == null or not is_instance_valid(chest):
		return false
	if game_manager == null:
		return false
	if game_manager.current_world_area != "farm" and game_manager.current_world_area != "house":
		return false

	ui_root.open_storage_chest(chest)
	return true


func open_npc_interaction(npc: Node) -> bool:
	if ui_root == null or npc == null or not is_instance_valid(npc):
		return false
	if not npc.has_method("build_dialogue_payload"):
		return false

	var dialogue_data: Dictionary = npc.call("build_dialogue_payload")
	ui_root.open_dialogue(dialogue_data)
	return true


func request_npc_gift(npc_id: String) -> Dictionary:
	var npc := _find_npc_by_id(npc_id)
	if npc == null or not npc.has_method("give_gift"):
		return {
			"npc_id": npc_id,
			"npc_name": "居民",
			"text": "送礼系统未就绪",
			"affinity": 0,
			"affinity_feedback": "",
		}

	var item_id: String = ""
	if game_manager != null and game_manager.has_method("get_current_tool"):
		item_id = String(game_manager.call("get_current_tool"))

	var gift_result: Dictionary = npc.call("give_gift", item_id)
	var dialogue_data: Dictionary = npc.call("build_dialogue_payload")
	dialogue_data["text"] = String(gift_result.get("message", dialogue_data.get("text", "")))
	dialogue_data["affinity"] = int(gift_result.get("affinity", dialogue_data.get("affinity", 0)))
	dialogue_data["affinity_feedback"] = ""
	return dialogue_data


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


func enter_world_area(area_id: String, entry_point_id: String = "") -> bool:
	if not ["farm", "house", "town", "cave"].has(area_id):
		return false

	if ui_root != null:
		ui_root.close_current_ui()

	_ensure_runtime_area_loaded(area_id)
	var reset_cave: bool = area_id == "cave"
	_set_world_area(area_id, false, reset_cave)
	_position_player_for_area(area_id, entry_point_id)
	return true


func _set_world_area(area_id: String, should_reposition_player: bool, reset_cave: bool) -> void:
	_ensure_runtime_area_loaded(area_id)
	var is_cave: bool = area_id == "cave"
	var is_farm: bool = area_id == "farm"
	var is_house: bool = area_id == "house"
	var is_town: bool = area_id == "town"

	farm_tiles_parent.visible = is_farm
	furniture_parent.visible = is_farm
	house_root.visible = is_house
	town_root.visible = is_town
	explore_root.visible = is_cave

	if cave_controller != null:
		cave_controller.set_target_player(player)
		if is_cave and reset_cave:
			cave_controller.reset_room()
		cave_controller.set_cave_active(is_cave, player)

	if is_cave and should_reposition_player and cave_controller != null:
		player.global_position = cave_controller.get_player_spawn_position()


func _position_player_for_area(area_id: String, entry_point_id: String) -> void:
	if player == null:
		return

	match area_id:
		"farm":
			player.global_position = _get_farm_entry_position(entry_point_id)
		"house":
			player.global_position = _DEFAULT_HOUSE_SPAWN_POSITION
		"town":
			player.global_position = _DEFAULT_TOWN_SPAWN_POSITION
		"cave":
			if cave_controller != null:
				player.global_position = cave_controller.get_player_spawn_position()


func _get_farm_entry_position(entry_point_id: String) -> Vector2:
	match entry_point_id:
		"farm_from_house":
			return _DEFAULT_HOUSE_ENTRANCE_POSITION + Vector2(0.0, 44.0)
		"farm_from_town":
			return _DEFAULT_TOWN_ENTRANCE_POSITION + Vector2(0.0, 44.0)
		"farm_from_cave":
			return _DEFAULT_FARM_RETURN_POSITION
		_:
			return _DEFAULT_PLAYER_OFFSET


func _apply_runtime_area_from_game_state() -> void:
	if game_manager == null:
		return

	var runtime_area: String = String(game_manager.current_world_area)
	if not ["farm", "house", "town", "cave"].has(runtime_area):
		runtime_area = "farm"
	_ensure_runtime_area_loaded(runtime_area)
	_set_world_area(runtime_area, false, false)


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


func _find_npc_by_id(npc_id: String) -> Node:
	if npc_id == "":
		return null
	for npc in get_tree().get_nodes_in_group("npc_actor"):
		if npc == null or not is_instance_valid(npc):
			continue
		if not npc.has_method("get_npc_id"):
			continue
		if String(npc.call("get_npc_id")) == npc_id:
			return npc
	return null
