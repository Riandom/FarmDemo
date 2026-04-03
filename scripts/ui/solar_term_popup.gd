extends Control
class_name SolarTermPopup

const _PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"

@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Panel/VBoxContainer/SubtitleLabel
@onready var time_manager = get_node_or_null("/root/TimeManager")


func _ready() -> void:
	visible = false
	_apply_ui_theme()
	call_deferred("_connect_time_manager")


func _connect_time_manager() -> void:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return

	if not time_manager.solar_term_changed.is_connected(_on_solar_term_changed):
		time_manager.solar_term_changed.connect(_on_solar_term_changed)


func _on_solar_term_changed(_solar_term_index: int) -> void:
	if time_manager == null:
		return

	title_label.text = "今日%s" % time_manager.format_date_line().split("·")[1].split(" ")[0]
	subtitle_label.text = time_manager.format_date_line()
	_play_popup_animation()


func _play_popup_animation() -> void:
	visible = true
	modulate.a = 1.0
	var popup_width: float = max(panel.custom_minimum_size.x, 280.0)
	position = Vector2((get_viewport_rect().size.x - popup_width) * 0.5, -80.0)

	var tween = create_tween()
	tween.tween_property(self, "position:y", 18.0, 0.25)
	tween.tween_interval(3.0)
	tween.tween_property(self, "position:y", -80.0, 0.25)
	tween.finished.connect(func() -> void:
		visible = false
	)


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
	style_box.content_margin_left = 12
	style_box.content_margin_top = 10
	style_box.content_margin_right = 12
	style_box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style_box)
