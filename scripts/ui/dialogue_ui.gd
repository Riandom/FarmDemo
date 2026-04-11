extends PanelContainer
class_name DialogueUI

signal ui_opened(ui_type: String)
signal ui_closed(ui_type: String)
signal service_requested(service_modal_type: String)
signal gift_requested(npc_id: String)

var _ui_root: UIRoot = null
var _dialogue_data: Dictionary = {}

@onready var name_label: Label = $MarginContainer/VBoxContainer/Header/NpcNameLabel
@onready var affinity_label: Label = $MarginContainer/VBoxContainer/Header/AffinityLabel
@onready var body_label: RichTextLabel = $MarginContainer/VBoxContainer/BodyLabel
@onready var feedback_label: Label = $MarginContainer/VBoxContainer/FeedbackLabel
@onready var gift_button: Button = $MarginContainer/VBoxContainer/Footer/GiftButton
@onready var service_button: Button = $MarginContainer/VBoxContainer/Footer/ServiceButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/Footer/CloseButton


func _ready() -> void:
	visible = false
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	if not service_button.pressed.is_connected(_on_service_button_pressed):
		service_button.pressed.connect(_on_service_button_pressed)
	if not gift_button.pressed.is_connected(_on_gift_button_pressed):
		gift_button.pressed.connect(_on_gift_button_pressed)


func set_ui_root(ui_root: UIRoot) -> void:
	_ui_root = ui_root


func set_dialogue_data(dialogue_data: Dictionary) -> void:
	_dialogue_data = dialogue_data.duplicate(true)
	_refresh_view()


func open_ui() -> void:
	visible = true
	_refresh_view()
	emit_signal("ui_opened", "dialogue")


func close_ui() -> void:
	visible = false
	emit_signal("ui_closed", "dialogue")


func _refresh_view() -> void:
	name_label.text = String(_dialogue_data.get("npc_name", "居民"))
	affinity_label.text = "好感：%d" % int(_dialogue_data.get("affinity", 0))
	body_label.text = String(_dialogue_data.get("text", "……"))
	feedback_label.text = String(_dialogue_data.get("affinity_feedback", ""))
	feedback_label.visible = feedback_label.text != ""

	var modal_type: String = String(_dialogue_data.get("service_modal_type", ""))
	var label: String = String(_dialogue_data.get("service_label", ""))
	service_button.visible = modal_type != "" and label != ""
	service_button.text = label
	gift_button.visible = bool(_dialogue_data.get("gift_enabled", false))


func _on_close_button_pressed() -> void:
	if _ui_root != null:
		_ui_root.close_modal("dialogue")
		return
	close_ui()


func _on_service_button_pressed() -> void:
	var modal_type: String = String(_dialogue_data.get("service_modal_type", ""))
	if modal_type == "":
		return
	emit_signal("service_requested", modal_type)


func _on_gift_button_pressed() -> void:
	var npc_id: String = String(_dialogue_data.get("npc_id", ""))
	if npc_id == "":
		return
	emit_signal("gift_requested", npc_id)
