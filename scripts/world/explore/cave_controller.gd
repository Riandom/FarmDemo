extends Node2D
class_name CaveController

signal drop_awarded(item_id: String, count: int)

@export var projectile_scene: PackedScene

var _target_player: Node = null
var _is_active: bool = false

@onready var player_spawn_marker: Marker2D = $PlayerSpawn
@onready var projectile_root: Node2D = $Projectiles
@onready var enemy_root: Node2D = $Enemies


func _ready() -> void:
	randomize()
	_connect_enemy_signals()
	set_cave_active(false, null)


func set_cave_active(is_active: bool, player: Node = null) -> void:
	_is_active = is_active
	visible = is_active
	if player != null:
		_target_player = player

	for enemy in enemy_root.get_children():
		if enemy.has_method("set_target_player"):
			enemy.call("set_target_player", _target_player)
		if enemy.has_method("set_combat_active"):
			enemy.call("set_combat_active", is_active)

	if not is_active:
		_clear_projectiles()


func set_target_player(player: Node) -> void:
	_target_player = player
	for enemy in enemy_root.get_children():
		if enemy.has_method("set_target_player"):
			enemy.call("set_target_player", player)


func get_player_spawn_position() -> Vector2:
	return player_spawn_marker.global_position


func reset_room() -> void:
	_clear_projectiles()
	for enemy in enemy_root.get_children():
		if enemy.has_method("reset_enemy"):
			enemy.call("reset_enemy")
			if enemy.has_method("set_target_player"):
				enemy.call("set_target_player", _target_player)


func spawn_dart(origin: Vector2, direction: Vector2) -> bool:
	if not _is_active or projectile_scene == null:
		return false

	var projectile: ProjectileDart = projectile_scene.instantiate() as ProjectileDart
	if projectile == null:
		return false

	projectile_root.add_child(projectile)
	projectile.setup(origin, direction)
	return true


func _connect_enemy_signals() -> void:
	for enemy in enemy_root.get_children():
		if enemy.has_signal("defeated") and not enemy.is_connected("defeated", Callable(self, "_on_enemy_defeated")):
			enemy.connect("defeated", Callable(self, "_on_enemy_defeated"))


func _on_enemy_defeated(enemy_type: String) -> void:
	match enemy_type:
		"slime":
			emit_signal("drop_awarded", "ore_fragment", 1)
			if randf() < 0.45:
				emit_signal("drop_awarded", "cave_essence", 1)
		"bat":
			emit_signal("drop_awarded", "cave_essence", 1)
			if randf() < 0.35:
				emit_signal("drop_awarded", "ore_fragment", 1)


func _clear_projectiles() -> void:
	for child in projectile_root.get_children():
		child.queue_free()
