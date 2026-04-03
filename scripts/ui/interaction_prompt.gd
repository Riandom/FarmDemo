extends PanelContainer
class_name InteractionPromptUI

const _WARNING_INTERVAL: float = 2.0

var _player: Node = null
var _ui_root: UIRoot = null
var _null_player_warning_timer: float = 0.0

@onready var prompt_label: Label = $Label
@onready var game_manager = get_node_or_null("/root/GameManager")
@onready var player_input_bridge: PlayerInputBridge = null


func _ready() -> void:
	"""默认隐藏提示框，等待绑定玩家后再开始查询。"""
	_apply_ui_theme()
	hide_prompt()


func _process(delta: float) -> void:
	"""每帧查询玩家前方的可交互地块，并维护提示文本。"""
	if _player == null:
		_null_player_warning_timer += delta
		if _null_player_warning_timer >= _WARNING_INTERVAL:
			push_warning("[InteractionPrompt] player is null")
			_null_player_warning_timer = 0.0
		hide_prompt()
		return

	_null_player_warning_timer = 0.0
	if player_input_bridge == null and _player != null and _player.has_node("PlayerInputBridge"):
		player_input_bridge = _player.get_node("PlayerInputBridge") as PlayerInputBridge

	if _ui_root != null and _ui_root.is_any_modal_open():
		hide_prompt()
		return

	var target_plot := _get_target_plot()
	if target_plot == null:
		hide_prompt()
		return

	if not target_plot.has_method("get_interaction_hint"):
		hide_prompt()
		return

	var current_tool_id := ""
	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager != null and game_manager.has_method("get_current_tool"):
		current_tool_id = String(game_manager.get_current_tool())

	var hint := String(target_plot.call("get_interaction_hint", current_tool_id))
	if hint.strip_edges() == "":
		hide_prompt()
		return

	show_prompt(hint)
	update_position(_player.global_position)


## 注入玩家引用
func set_player(player: Node) -> void:
	_player = player
	_null_player_warning_timer = 0.0
	player_input_bridge = null


## 注入 UI 根节点引用
func set_ui_root(ui_root: UIRoot) -> void:
	_ui_root = ui_root


## 显示指定动作提示
func show_prompt(action_name: String) -> void:
	prompt_label.text = action_name
	visible = true


## 隐藏提示框
func hide_prompt() -> void:
	visible = false


## 更新提示框位置
func update_position(_player_pos: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	position = Vector2((viewport_size.x - size.x) * 0.5, 48.0)


func _get_target_plot() -> Node:
	"""优先复用 PlayerInputBridge 的目标检测，避免提示与实际交互目标不一致。"""
	if player_input_bridge != null and player_input_bridge.has_method("get_current_interaction_target"):
		return player_input_bridge.get_current_interaction_target()
	return null


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
	style_box.content_margin_top = 4
	style_box.content_margin_right = 8
	style_box.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style_box)
