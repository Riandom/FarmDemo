extends PanelContainer
class_name CombatHealthDisplay

var _player: Node = null

@onready var label: Label = $Label
@onready var game_manager = get_node_or_null("/root/GameManager")


func _ready() -> void:
	_apply_ui_theme()
	_connect_game_manager()
	_update_area_visibility()


func set_player(player: Node) -> void:
	if _player != null and _player.has_signal("health_changed") and _player.is_connected("health_changed", Callable(self, "_on_player_health_changed")):
		_player.disconnect("health_changed", Callable(self, "_on_player_health_changed"))

	_player = player
	if _player != null and _player.has_signal("health_changed") and not _player.is_connected("health_changed", Callable(self, "_on_player_health_changed")):
		_player.connect("health_changed", Callable(self, "_on_player_health_changed"))

	if _player != null:
		_on_player_health_changed(int(_player.get("current_health")), int(_player.get("max_health")))


func _connect_game_manager() -> void:
	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return

	if game_manager.has_signal("world_area_changed") and not game_manager.is_connected("world_area_changed", Callable(self, "_on_world_area_changed")):
		game_manager.connect("world_area_changed", Callable(self, "_on_world_area_changed"))

	_update_area_visibility()


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	label.text = "洞窟生命 %d/%d" % [current_health, max_health]


func _on_world_area_changed(_area_id: String) -> void:
	_update_area_visibility()


func _update_area_visibility() -> void:
	if game_manager == null:
		visible = false
		return
	visible = String(game_manager.get("current_world_area")) == "cave"


func _apply_ui_theme() -> void:
	var texture_path := "res://assets/sprites/placeholder/ui/panel_background.png"
	if not ResourceLoader.exists(texture_path):
		return

	var texture := load(texture_path)
	if not (texture is Texture2D):
		return

	var style_box := StyleBoxTexture.new()
	style_box.texture = texture
	style_box.texture_margin_left = 6
	style_box.texture_margin_top = 6
	style_box.texture_margin_right = 6
	style_box.texture_margin_bottom = 6
	style_box.content_margin_left = 8
	style_box.content_margin_top = 6
	style_box.content_margin_right = 8
	style_box.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style_box)
