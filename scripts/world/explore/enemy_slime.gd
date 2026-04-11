extends Node2D
class_name EnemySlime

signal defeated(enemy_type: String)

@export var move_speed: float = 34.0
@export var chase_range: float = 220.0
@export var contact_range: float = 18.0
@export var damage: int = 1
@export var max_health: int = 2

const ENEMY_TYPE: String = "slime"

var _target_player: Node = null
var _spawn_position: Vector2 = Vector2.ZERO
var _current_health: int = 2
var _active: bool = false
var _contact_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("combat_enemy")
	_spawn_position = global_position
	_current_health = max_health
	set_combat_active(false)


func _process(delta: float) -> void:
	if _contact_cooldown > 0.0:
		_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)

	if not _active or _current_health <= 0:
		return

	if _target_player == null or not is_instance_valid(_target_player):
		return

	var to_player: Vector2 = _target_player.global_position - global_position
	var distance: float = to_player.length()
	if distance > chase_range or distance <= 0.001:
		return

	global_position += to_player.normalized() * move_speed * delta
	if distance <= contact_range and _contact_cooldown <= 0.0 and _target_player.has_method("receive_damage"):
		var did_damage: bool = bool(_target_player.call("receive_damage", damage))
		if did_damage:
			_contact_cooldown = 0.75


func set_target_player(player: Node) -> void:
	_target_player = player


func set_combat_active(is_active: bool) -> void:
	_active = is_active and _current_health > 0
	set_process(_active)
	visible = _current_health > 0 and is_active


func receive_damage(amount: int) -> bool:
	if amount <= 0 or _current_health <= 0:
		return false

	_current_health = maxi(_current_health - amount, 0)
	modulate = Color(1.0, 0.7, 0.7)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	if _current_health <= 0:
		_active = false
		set_process(false)
		visible = false
		emit_signal("defeated", ENEMY_TYPE)
	return true


func reset_enemy() -> void:
	_current_health = max_health
	global_position = _spawn_position
	modulate = Color.WHITE
	set_combat_active(true)


func is_alive() -> bool:
	return _current_health > 0
