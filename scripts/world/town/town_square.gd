extends Node2D
class_name TownSquare

const _GENERAL_STORE_NPC_SCENE: PackedScene = preload("res://scenes/world/npc/npc_general_store.tscn")
const _CRAFTER_NPC_SCENE: PackedScene = preload("res://scenes/world/npc/npc_crafter.tscn")
const _RESIDENT_NPC_SCENE: PackedScene = preload("res://scenes/world/npc/npc_resident.tscn")

@onready var npc_layer: Node2D = $NpcLayer
@onready var merchant_npc_point: Marker2D = $MerchantNpcPoint
@onready var crafter_npc_point: Marker2D = $CrafterNpcPoint
@onready var resident_npc_point: Marker2D = $ResidentNpcPoint
@onready var general_store_entrance_point: Marker2D = $GeneralStoreEntrancePoint
@onready var workshop_entrance_point: Marker2D = $WorkshopEntrancePoint
@onready var request_board_point: Marker2D = $RequestBoardPoint


func _ready() -> void:
	_spawn_npcs()


func get_npc_anchor(anchor_name: String) -> Node2D:
	match anchor_name:
		"merchant":
			return merchant_npc_point
		"crafter":
			return crafter_npc_point
		"resident":
			return resident_npc_point
		_:
			return null


func get_function_anchor(anchor_name: String) -> Node2D:
	match anchor_name:
		"general_store":
			return general_store_entrance_point
		"workshop":
			return workshop_entrance_point
		"request_board":
			return request_board_point
		_:
			return null


func get_named_anchor(anchor_name: String) -> Node2D:
	var npc_anchor: Node2D = get_npc_anchor(anchor_name)
	if npc_anchor != null:
		return npc_anchor
	return get_function_anchor(anchor_name)


func _spawn_npcs() -> void:
	for child in npc_layer.get_children():
		child.queue_free()

	_spawn_npc(_GENERAL_STORE_NPC_SCENE)
	_spawn_npc(_CRAFTER_NPC_SCENE)
	_spawn_npc(_RESIDENT_NPC_SCENE)


func _spawn_npc(scene: PackedScene) -> void:
	if scene == null:
		return
	var npc_instance: Node = scene.instantiate()
	if npc_instance == null:
		return
	npc_layer.add_child(npc_instance)
