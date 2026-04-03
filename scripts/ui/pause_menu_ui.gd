extends Control
class_name PauseMenuUI

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)

var _ui_root: UIRoot = null

@onready var panel: PanelContainer = $Panel
@onready var actions_container: VBoxContainer = $Panel/VBoxContainer/Actions
@onready var resume_button: Button = $Panel/VBoxContainer/Actions/ResumeButton
@onready var save_button: Button = $Panel/VBoxContainer/Actions/SaveButton
@onready var load_button: Button = $Panel/VBoxContainer/Actions/LoadButton
@onready var close_button: Button = $Panel/VBoxContainer/Header/CloseButton
@onready var save_load_ui: SaveLoadUI = $SaveLoadUI
@onready var time_manager = get_node_or_null("/root/TimeManager")


func _ready() -> void:
	visible = false
	save_load_ui.set_pause_menu(self)
	save_load_ui.back_requested.connect(_on_save_load_back_requested)

	resume_button.pressed.connect(_on_resume_button_pressed)
	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)


func set_ui_root(ui_root: UIRoot) -> void:
	_ui_root = ui_root


func open_ui() -> void:
	if visible:
		return

	visible = true
	_show_main_actions()
	_set_time_paused(true)
	emit_signal("ui_opened", "pause_menu")


func close_ui() -> void:
	if not visible:
		return

	save_load_ui.close_ui()
	visible = false
	_set_time_paused(false)
	emit_signal("ui_closed", "pause_menu")


func request_close() -> void:
	if _ui_root != null:
		_ui_root.close_modal("pause_menu")
		return

	close_ui()


func _show_main_actions() -> void:
	actions_container.visible = true
	save_load_ui.close_ui()


func _on_resume_button_pressed() -> void:
	request_close()


func _on_save_button_pressed() -> void:
	actions_container.visible = false
	save_load_ui.open_mode("save")


func _on_load_button_pressed() -> void:
	actions_container.visible = false
	save_load_ui.open_mode("load")


func _on_close_button_pressed() -> void:
	request_close()


func _on_save_load_back_requested() -> void:
	_show_main_actions()


func _set_time_paused(is_paused: bool) -> void:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager != null and time_manager.has_method("set_time_paused"):
		time_manager.set_time_paused(is_paused)
