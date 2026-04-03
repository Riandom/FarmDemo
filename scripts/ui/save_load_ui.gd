extends Control
class_name SaveLoadUI

signal back_requested

const _UI_PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"
const _UI_BUTTON_NORMAL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_normal.png"
const _UI_BUTTON_HOVER_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_hover.png"
const _UI_BUTTON_PRESSED_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/button_pressed.png"

var _mode: String = "save"
var _pause_menu: PauseMenuUI = null

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var slots_container: VBoxContainer = $Panel/VBoxContainer/SaveSlotsContainer
@onready var feedback_label: Label = $Panel/VBoxContainer/FeedbackLabel
@onready var back_button: Button = $Panel/VBoxContainer/Footer/BackButton
@onready var save_manager = get_node_or_null("/root/SaveManager")
@onready var panel: PanelContainer = $Panel


func _ready() -> void:
	visible = false
	_apply_ui_theme()
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	call_deferred("_connect_save_manager")


func set_pause_menu(pause_menu: PauseMenuUI) -> void:
	_pause_menu = pause_menu


func open_mode(mode: String) -> void:
	_mode = mode if mode in ["save", "load"] else "save"
	title_label.text = "保存存档" if _mode == "save" else "加载存档"
	feedback_label.text = ""
	visible = true
	_rebuild_slot_buttons()


func close_ui() -> void:
	visible = false


func _connect_save_manager() -> void:
	if save_manager == null:
		save_manager = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	if not save_manager.save_completed.is_connected(_on_save_completed):
		save_manager.save_completed.connect(_on_save_completed)
	if not save_manager.load_completed.is_connected(_on_load_completed):
		save_manager.load_completed.connect(_on_load_completed)


func _rebuild_slot_buttons() -> void:
	for child in slots_container.get_children():
		child.queue_free()

	var slot_descriptors: Array[Dictionary] = [
		{"is_auto": true, "slot_index": -1, "file_path": "user://save_auto.json"},
	]

	for index in range(5):
		slot_descriptors.append({
			"is_auto": false,
			"slot_index": index,
			"file_path": "user://save_%02d.json" % (index + 1),
		})

	for descriptor in slot_descriptors:
		slots_container.add_child(_create_slot_button(descriptor))


func _create_slot_button(descriptor: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(420, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_theme(button)

	var is_auto: bool = bool(descriptor.get("is_auto", false))
	var slot_index: int = int(descriptor.get("slot_index", -1))
	var file_path: String = String(descriptor.get("file_path", ""))
	var info: Dictionary = {}
	if save_manager != null:
		info = save_manager.get_save_file_info(file_path)

	var prefix: String = "自动存档" if is_auto else "存档 %d" % (slot_index + 1)
	var display_label: String = String(info.get("label", "%s - 空" % prefix))
	if display_label == "空":
		display_label = "%s - 空" % prefix
	button.text = display_label

	if _mode == "save":
		button.disabled = is_auto
		if is_auto:
			button.text = "%s - 仅床互动触发" % prefix
	else:
		button.disabled = not bool(info.get("exists", false))

	button.pressed.connect(_on_slot_button_pressed.bind(is_auto, slot_index))
	return button


func _on_slot_button_pressed(is_auto: bool, slot_index: int) -> void:
	if save_manager == null:
		feedback_label.text = "SaveManager 未就绪"
		return

	if _mode == "save":
		if is_auto:
			return
		save_manager.save_game_manual(slot_index)
		return

	if is_auto:
		save_manager.load_game_auto()
	else:
		save_manager.load_game_manual(slot_index)


func _on_save_completed(success: bool, _file_path: String) -> void:
	feedback_label.text = "已存档" if success else "存档失败"
	_rebuild_slot_buttons()
	if success and _pause_menu != null:
		_pause_menu.request_close()


func _on_load_completed(success: bool, error_message: String) -> void:
	feedback_label.text = "读档完成" if success else error_message
	_rebuild_slot_buttons()
	if success and _pause_menu != null:
		_pause_menu.request_close()


func _on_back_button_pressed() -> void:
	emit_signal("back_requested")


func _apply_ui_theme() -> void:
	panel.add_theme_stylebox_override("panel", _build_textured_stylebox(_UI_PANEL_TEXTURE_PATH))
	_apply_button_theme(back_button)


func _apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _build_textured_stylebox(_UI_BUTTON_NORMAL_TEXTURE_PATH))
	button.add_theme_stylebox_override("hover", _build_textured_stylebox(_UI_BUTTON_HOVER_TEXTURE_PATH))
	button.add_theme_stylebox_override("pressed", _build_textured_stylebox(_UI_BUTTON_PRESSED_TEXTURE_PATH))


func _build_textured_stylebox(texture_path: String) -> StyleBoxTexture:
	var style_box := StyleBoxTexture.new()
	if ResourceLoader.exists(texture_path):
		var texture := load(texture_path)
		if texture is Texture2D:
			style_box.texture = texture
			style_box.texture_margin_left = 6
			style_box.texture_margin_top = 6
			style_box.texture_margin_right = 6
			style_box.texture_margin_bottom = 6
	style_box.content_margin_left = 8
	style_box.content_margin_top = 8
	style_box.content_margin_right = 8
	style_box.content_margin_bottom = 8
	return style_box
