extends Node2D
class_name ProjectileDart

@export var speed: float = 360.0
@export var max_distance: float = 300.0
@export var damage: int = 1
@export var hit_radius: float = 18.0

var _direction: Vector2 = Vector2.RIGHT
var _distance_travelled: float = 0.0
var _active: bool = false


func setup(origin: Vector2, direction: Vector2) -> void:
	global_position = origin
	_direction = direction.normalized()
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT
	rotation = _direction.angle()
	_distance_travelled = 0.0
	_active = true


func _physics_process(delta: float) -> void:
	if not _active:
		return

	var step: Vector2 = _direction * speed * delta
	global_position += step
	_distance_travelled += step.length()
	if _distance_travelled >= max_distance:
		queue_free()
		return

	for node in get_tree().get_nodes_in_group("combat_enemy"):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		if global_position.distance_to((node as Node2D).global_position) > hit_radius:
			continue
		if node.has_method("receive_damage"):
			node.call("receive_damage", damage)
			queue_free()
			return
