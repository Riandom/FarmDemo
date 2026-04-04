extends PanelContainer
class_name TimeDisplay

const _PANEL_TEXTURE_PATH: String = "res://assets/sprites/placeholder/ui/panel_background.png"

@onready var date_label: Label = $VBoxContainer/DateLabel
@onready var clock_label: Label = $VBoxContainer/ClockLabel
@onready var year_label: Label = $VBoxContainer/YearLabel
@onready var time_manager = get_node_or_null("/root/TimeManager")


func _ready() -> void:
	_apply_ui_theme()
	call_deferred("_connect_time_manager")
	_refresh_display()


func _connect_time_manager() -> void:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return

	if not time_manager.time_changed.is_connected(_on_time_changed):
		time_manager.time_changed.connect(_on_time_changed)
	if not time_manager.day_changed.is_connected(_on_day_changed):
		time_manager.day_changed.connect(_on_day_changed)
	if not time_manager.solar_term_changed.is_connected(_on_solar_term_changed):
		time_manager.solar_term_changed.connect(_on_solar_term_changed)
	if not time_manager.season_changed.is_connected(_on_season_changed):
		time_manager.season_changed.connect(_on_season_changed)

	_refresh_display()


func _on_time_changed(_shi_chen: int, _ke: int) -> void:
	_refresh_display()


func _on_day_changed(_day_in_term: int) -> void:
	_refresh_display()


func _on_solar_term_changed(_solar_term_index: int) -> void:
	_refresh_display()


func _on_season_changed(_season_id: String, _year_count: int) -> void:
	_refresh_display()


func _refresh_display() -> void:
	if time_manager == null:
		year_label.text = "第 1 年"
		date_label.text = "春季·立春 第 1 天"
		clock_label.text = "卯时初刻"
		return

	year_label.text = time_manager.format_year_line()
	date_label.text = time_manager.format_season_day_line()
	clock_label.text = time_manager.format_clock_line()


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
	style_box.content_margin_left = 10
	style_box.content_margin_top = 8
	style_box.content_margin_right = 10
	style_box.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style_box)
