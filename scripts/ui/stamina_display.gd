extends PanelContainer
class_name StaminaDisplay

const _FALLBACK_STAMINA: int = 100
const _FALLBACK_MAX_STAMINA: int = 100
const _PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"

var _warned_missing_game_manager: bool = false

@onready var stamina_label: Label = $HBoxContainer/StaminaLabel


func _ready() -> void:
	_apply_ui_theme()
	call_deferred("_connect_game_manager")
	update_stamina(_get_current_stamina(), _get_current_max_stamina())


func update_stamina(current_stamina: int, max_stamina: int) -> void:
	stamina_label.text = "体力 %d/%d" % [current_stamina, max(max_stamina, 1)]


func _connect_game_manager() -> void:
	var game_manager := _get_game_manager()
	if game_manager == null:
		if not _warned_missing_game_manager:
			push_warning("[StaminaDisplay] GameManager not ready, using fallback stamina")
			_warned_missing_game_manager = true
		return

	if game_manager.has_signal("stamina_changed") and not game_manager.is_connected("stamina_changed", Callable(self, "_on_stamina_changed")):
		game_manager.connect("stamina_changed", Callable(self, "_on_stamina_changed"))

	update_stamina(_get_current_stamina(), _get_current_max_stamina())


func _get_current_stamina() -> int:
	var game_manager := _get_game_manager()
	if game_manager != null:
		return int(game_manager.get("stamina"))

	if not _warned_missing_game_manager:
		push_warning("[StaminaDisplay] GameManager not ready, using fallback stamina")
		_warned_missing_game_manager = true

	return _FALLBACK_STAMINA


func _get_current_max_stamina() -> int:
	var game_manager := _get_game_manager()
	if game_manager != null:
		return int(game_manager.get("max_stamina"))

	return _FALLBACK_MAX_STAMINA


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _on_stamina_changed(current_stamina: int, max_stamina: int) -> void:
	update_stamina(current_stamina, max_stamina)


func _apply_ui_theme() -> void:
	var style_box := StyleBoxTexture.new()
	if ResourceLoader.exists(_PANEL_TEXTURE_PATH):
		var texture := load(_PANEL_TEXTURE_PATH)
		if texture is Texture2D:
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
