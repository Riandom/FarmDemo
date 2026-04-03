extends PanelContainer
class_name GoldDisplay

const _FALLBACK_GOLD: int = 50
const _PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"
const _ICON_TEXTURE_PATH: String = "res://assets/sprites/placeholder/items/crop_wheat.png"

var _warned_missing_game_manager: bool = false

@onready var icon_rect: TextureRect = $HBoxContainer/Icon
@onready var gold_label: Label = $HBoxContainer/GoldLabel


func _ready() -> void:
	"""初始化金币显示并连接 GameManager。"""
	_apply_ui_theme()
	call_deferred("_connect_game_manager")
	update_gold(_get_current_gold())


## 更新金币文本
func update_gold(new_amount: int) -> void:
	gold_label.text = "💰 %d" % new_amount


func _connect_game_manager() -> void:
	"""监听未来 GameManager 的金币变化信号。"""
	var game_manager := _get_game_manager()
	if game_manager == null:
		if not _warned_missing_game_manager:
			push_warning("[GoldDisplay] GameManager not ready, using fallback gold")
			_warned_missing_game_manager = true
		return

	if game_manager.has_signal("gold_changed") and not game_manager.is_connected("gold_changed", Callable(self, "_on_gold_changed")):
		game_manager.connect("gold_changed", Callable(self, "_on_gold_changed"))

	update_gold(_get_current_gold())


func _get_current_gold() -> int:
	var game_manager := _get_game_manager()
	if game_manager != null:
		return int(game_manager.get("gold"))

	if not _warned_missing_game_manager:
		push_warning("[GoldDisplay] GameManager not ready, using fallback gold")
		_warned_missing_game_manager = true

	return _FALLBACK_GOLD


func _get_game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _on_gold_changed(new_amount: int) -> void:
	update_gold(new_amount)


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

	if ResourceLoader.exists(_ICON_TEXTURE_PATH):
		var icon_texture := load(_ICON_TEXTURE_PATH)
		if icon_texture is Texture2D:
			icon_rect.texture = icon_texture
