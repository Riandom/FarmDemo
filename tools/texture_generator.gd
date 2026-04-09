@tool
extends EditorScript

const TILE_SIZE: int = 32
const UI_BUTTON_SIZE: Vector2i = Vector2i(96, 32)
const UI_PANEL_SIZE: Vector2i = Vector2i(128, 96)
const PALETTE_PATH: String = "res://resources/data/placeholder_colors.tres"
const OUTPUT_ROOT: String = "res://assets/sprites/placeholder"

const PLAYER_OUTPUTS: PackedStringArray = [
	"player/idle_down.png",
	"player/idle_up.png",
	"player/idle_left.png",
	"player/idle_right.png",
	"player/walk_down.png",
	"player/walk_up.png",
	"player/walk_left.png",
	"player/walk_right.png",
]

const TILE_OUTPUTS: PackedStringArray = [
	"tiles/waste.png",
	"tiles/plowed.png",
	"tiles/seeded.png",
	"tiles/watered.png",
	"tiles/mature.png",
]

const CROP_OUTPUTS: PackedStringArray = [
	"crops/wheat_stage_0.png",
	"crops/wheat_stage_1.png",
	"crops/wheat_stage_2.png",
	"crops/wheat_stage_3.png",
]

const ITEM_OUTPUTS: PackedStringArray = [
	"items/seed_wheat.png",
	"items/crop_wheat.png",
	"items/hoe_wood.png",
	"items/watering_can_wood.png",
	"items/sickle_wood.png",
]

const UI_OUTPUTS: PackedStringArray = [
	"ui/button_normal.png",
	"ui/button_hover.png",
	"ui/button_pressed.png",
	"ui/panel_background.png",
]


func _run() -> void:
	var palette = _load_palette()
	if palette == null:
		push_error("[TextureGenerator] missing palette: %s" % PALETTE_PATH)
		return

	_ensure_output_directories()
	_generate_player_textures(palette)
	_generate_tile_textures(palette)
	_generate_crop_textures(palette)
	_generate_item_textures(palette)
	_generate_ui_textures(palette)
	_print_summary()


func _load_palette() -> Resource:
	if not ResourceLoader.exists(PALETTE_PATH):
		return null

	var resource: Resource = load(PALETTE_PATH)
	if resource != null:
		return resource

	return null


func _ensure_output_directories() -> void:
	var directories: PackedStringArray = [
		OUTPUT_ROOT,
		"%s/player" % OUTPUT_ROOT,
		"%s/tiles" % OUTPUT_ROOT,
		"%s/crops" % OUTPUT_ROOT,
		"%s/items" % OUTPUT_ROOT,
		"%s/ui" % OUTPUT_ROOT,
	]

	for res_dir in directories:
		var absolute_dir := ProjectSettings.globalize_path(res_dir)
		DirAccess.make_dir_recursive_absolute(absolute_dir)


func _generate_player_textures(palette) -> void:
	_generate_player_texture("idle_down", "down", false, palette)
	_generate_player_texture("idle_up", "up", false, palette)
	_generate_player_texture("idle_left", "left", false, palette)
	_generate_player_texture("idle_right", "right", false, palette)
	_generate_player_texture("walk_down", "down", true, palette)
	_generate_player_texture("walk_up", "up", true, palette)
	_generate_player_texture("walk_left", "left", true, palette)
	_generate_player_texture("walk_right", "right", true, palette)


func _generate_player_texture(file_name: String, direction: String, walking: bool, palette) -> void:
	var image: Image = _create_image(Vector2i(TILE_SIZE, TILE_SIZE), Color(0, 0, 0, 0))
	var outline = palette.player_outline
	var primary = palette.player_primary
	var accent = palette.player_accent

	_draw_rect_outline(image, Rect2i(8, 5, 16, 22), outline)
	_fill_rect(image, Rect2i(9, 6, 14, 6), accent)
	_fill_rect(image, Rect2i(9, 12, 14, 10), primary)

	if walking:
		match direction:
			"down":
				_fill_rect(image, Rect2i(10, 23, 4, 6), outline)
				_fill_rect(image, Rect2i(18, 21, 4, 8), outline)
			"up":
				_fill_rect(image, Rect2i(10, 21, 4, 8), outline)
				_fill_rect(image, Rect2i(18, 23, 4, 6), outline)
			"left":
				_fill_rect(image, Rect2i(9, 22, 4, 7), outline)
				_fill_rect(image, Rect2i(17, 22, 4, 5), outline)
			"right":
				_fill_rect(image, Rect2i(11, 22, 4, 5), outline)
				_fill_rect(image, Rect2i(19, 22, 4, 7), outline)
	_draw_player_facing_marker(image, direction, outline)
	_save_png(image, "%s/player/%s.png" % [OUTPUT_ROOT, file_name])


func _draw_player_facing_marker(image: Image, direction: String, color: Color) -> void:
	match direction:
		"down":
			_fill_rect(image, Rect2i(14, 10, 1, 2), color)
			_fill_rect(image, Rect2i(17, 10, 1, 2), color)
		"up":
			_fill_rect(image, Rect2i(14, 7, 1, 2), color)
			_fill_rect(image, Rect2i(17, 7, 1, 2), color)
		"left":
			_fill_rect(image, Rect2i(11, 10, 1, 2), color)
			_fill_rect(image, Rect2i(11, 14, 1, 2), color)
		"right":
			_fill_rect(image, Rect2i(20, 10, 1, 2), color)
			_fill_rect(image, Rect2i(20, 14, 1, 2), color)


func _generate_tile_textures(palette) -> void:
	for state in ["waste", "plowed", "seeded", "watered", "mature"]:
		var image := _create_image(Vector2i(TILE_SIZE, TILE_SIZE), palette.get_tile_color(state))
		_draw_tile_pattern(image, state, palette)
		_save_png(image, "%s/tiles/%s.png" % [OUTPUT_ROOT, state])


func _draw_tile_pattern(image: Image, state: String, palette) -> void:
	var border = palette.player_outline
	_draw_rect_outline(image, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), border)

	match state:
		"plowed", "seeded", "watered", "mature":
			for x in range(2, TILE_SIZE - 2, 6):
				_draw_line(image, Vector2i(x, 2), Vector2i(x + 4, TILE_SIZE - 3), border)

	if state == "seeded":
		for point in [Vector2i(9, 10), Vector2i(18, 8), Vector2i(22, 16), Vector2i(13, 21)]:
			_draw_circle(image, point, 1, Color("6FAF37"))

	if state == "watered":
		var water := Color(0.46, 0.72, 0.95, 0.70)
		for offset in range(4, TILE_SIZE - 4, 6):
			_draw_line(image, Vector2i(offset, 4), Vector2i(offset + 6, 16), water)
		for point in [Vector2i(10, 20), Vector2i(19, 23), Vector2i(24, 11)]:
			_draw_circle(image, point, 2, water)

	if state == "mature":
		var wheat = palette.crop_stage_3
		for stem_x in [9, 16, 23]:
			_draw_line(image, Vector2i(stem_x, 9), Vector2i(stem_x, 24), wheat)
			_draw_line(image, Vector2i(stem_x, 11), Vector2i(stem_x - 2, 14), wheat)
			_draw_line(image, Vector2i(stem_x, 14), Vector2i(stem_x + 2, 17), wheat)


func _generate_crop_textures(palette) -> void:
	for stage_index in range(4):
		var image := _create_image(Vector2i(TILE_SIZE, TILE_SIZE), Color(0, 0, 0, 0))
		_draw_crop_stage(image, stage_index, palette)
		_save_png(image, "%s/crops/wheat_stage_%d.png" % [OUTPUT_ROOT, stage_index])


func _draw_crop_stage(image: Image, stage_index: int, palette) -> void:
	var color = palette.get_crop_stage_color(stage_index)
	match stage_index:
		0:
			for point in [Vector2i(12, 22), Vector2i(16, 20), Vector2i(20, 22)]:
				_draw_circle(image, point, 2, color)
		1:
			for stem_x in [11, 16, 21]:
				_draw_line(image, Vector2i(stem_x, 26), Vector2i(stem_x, 18), color)
				_draw_line(image, Vector2i(stem_x, 22), Vector2i(stem_x - 2, 20), color)
		2:
			for stem_x in [10, 16, 22]:
				_draw_line(image, Vector2i(stem_x, 26), Vector2i(stem_x, 14), color)
				_draw_line(image, Vector2i(stem_x, 20), Vector2i(stem_x - 3, 17), color)
				_draw_line(image, Vector2i(stem_x, 18), Vector2i(stem_x + 3, 15), color)
		3:
			for stem_x in [10, 16, 22]:
				_draw_line(image, Vector2i(stem_x, 26), Vector2i(stem_x, 10), color)
				for i in range(4):
					image.set_pixel(stem_x - 1, 10 + i, color)
					image.set_pixel(stem_x + 1, 12 + i, color)


func _generate_item_textures(palette) -> void:
	_generate_seed_icon(palette)
	_generate_wheat_icon(palette)
	_generate_hoe_icon(palette)
	_generate_watering_can_icon(palette)
	_generate_sickle_icon(palette)


func _generate_seed_icon(palette) -> void:
	var image: Image = _create_image(Vector2i(TILE_SIZE, TILE_SIZE), Color(0, 0, 0, 0))
	var color = palette.get_item_color("seed_wheat")
	for point in [Vector2i(12, 12), Vector2i(18, 14), Vector2i(15, 19)]:
		_draw_circle(image, point, 3, color)
	_save_png(image, "%s/items/seed_wheat.png" % OUTPUT_ROOT)


func _generate_wheat_icon(palette) -> void:
	var image: Image = _create_image(Vector2i(TILE_SIZE, TILE_SIZE), Color(0, 0, 0, 0))
	var color = palette.get_item_color("crop_wheat")
	for stem_x in [12, 16, 20]:
		_draw_line(image, Vector2i(stem_x, 25), Vector2i(stem_x, 8), color)
		_draw_line(image, Vector2i(stem_x, 10), Vector2i(stem_x - 3, 13), color)
		_draw_line(image, Vector2i(stem_x, 12), Vector2i(stem_x + 3, 15), color)
	_save_png(image, "%s/items/crop_wheat.png" % OUTPUT_ROOT)


func _generate_hoe_icon(palette) -> void:
	var image: Image = _create_image(Vector2i(TILE_SIZE, TILE_SIZE), Color(0, 0, 0, 0))
	var wood = palette.get_item_color("hoe_wood")
	var metal: Color = Color("CED6DF")
	_draw_line(image, Vector2i(10, 24), Vector2i(20, 8), wood)
	_fill_rect(image, Rect2i(18, 6, 7, 4), metal)
	_save_png(image, "%s/items/hoe_wood.png" % OUTPUT_ROOT)


func _generate_watering_can_icon(palette) -> void:
	var image: Image = _create_image(Vector2i(TILE_SIZE, TILE_SIZE), Color(0, 0, 0, 0))
	var color = palette.get_item_color("watering_can_wood")
	_fill_rect(image, Rect2i(8, 12, 14, 10), color)
	_draw_rect_outline(image, Rect2i(8, 12, 14, 10), palette.player_outline)
	_draw_line(image, Vector2i(22, 15), Vector2i(27, 12), palette.player_outline)
	_draw_line(image, Vector2i(11, 12), Vector2i(11, 8), palette.player_outline)
	_draw_line(image, Vector2i(12, 8), Vector2i(17, 8), palette.player_outline)
	_save_png(image, "%s/items/watering_can_wood.png" % OUTPUT_ROOT)


func _generate_sickle_icon(palette) -> void:
	var image: Image = _create_image(Vector2i(TILE_SIZE, TILE_SIZE), Color(0, 0, 0, 0))
	var wood: Color = Color("8B5A2B")
	var metal = palette.get_item_color("sickle_wood")
	_draw_line(image, Vector2i(12, 25), Vector2i(18, 14), wood)
	for point in [Vector2i(19, 12), Vector2i(22, 11), Vector2i(24, 12), Vector2i(25, 14), Vector2i(24, 17), Vector2i(22, 19)]:
		_draw_circle(image, point, 2, metal)
	_save_png(image, "%s/items/sickle_wood.png" % OUTPUT_ROOT)


func _generate_ui_textures(palette) -> void:
	_save_png(_build_button_texture(UI_BUTTON_SIZE, palette.ui_button_normal, palette.ui_panel_border), "%s/ui/button_normal.png" % OUTPUT_ROOT)
	_save_png(_build_button_texture(UI_BUTTON_SIZE, palette.ui_button_hover, palette.ui_panel_border), "%s/ui/button_hover.png" % OUTPUT_ROOT)
	_save_png(_build_button_texture(UI_BUTTON_SIZE, palette.ui_button_pressed, palette.ui_panel_border), "%s/ui/button_pressed.png" % OUTPUT_ROOT)
	_save_png(_build_panel_texture(UI_PANEL_SIZE, palette.ui_panel_background, palette.ui_panel_border), "%s/ui/panel_background.png" % OUTPUT_ROOT)


func _build_button_texture(size: Vector2i, fill: Color, border: Color) -> Image:
	var image := _create_image(size, fill)
	_draw_rect_outline(image, Rect2i(0, 0, size.x, size.y), border)
	_draw_rect_outline(image, Rect2i(2, 2, size.x - 4, size.y - 4), border.darkened(0.2))
	return image


func _build_panel_texture(size: Vector2i, fill: Color, border: Color) -> Image:
	var image := _create_image(size, fill)
	_draw_rect_outline(image, Rect2i(0, 0, size.x, size.y), border)
	_draw_rect_outline(image, Rect2i(3, 3, size.x - 6, size.y - 6), border.darkened(0.25))
	return image


func _create_image(size: Vector2i, fill: Color) -> Image:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	return image


func _save_png(image: Image, res_path: String) -> void:
	var err := image.save_png(res_path)
	if err != OK:
		push_warning("[TextureGenerator] save failed: %s (err=%s)" % [res_path, err])


func _draw_rect_outline(image: Image, rect: Rect2i, color: Color) -> void:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		_set_if_valid(image, x, rect.position.y, color)
		_set_if_valid(image, x, rect.position.y + rect.size.y - 1, color)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		_set_if_valid(image, rect.position.x, y, color)
		_set_if_valid(image, rect.position.x + rect.size.x - 1, y, color)


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_set_if_valid(image, x, y, color)


func _draw_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= radius * radius:
				_set_if_valid(image, x, y, color)


func _draw_line(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var x0: int = from.x
	var y0: int = from.y
	var x1: int = to.x
	var y1: int = to.y
	var dx: int = abs(x1 - x0)
	var sx: int = 1 if x0 < x1 else -1
	var dy: int = -abs(y1 - y0)
	var sy: int = 1 if y0 < y1 else -1
	var err: int = dx + dy

	while true:
		_set_if_valid(image, x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _set_if_valid(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, color)


func _print_summary() -> void:
	var outputs: PackedStringArray = []
	outputs.append_array(PLAYER_OUTPUTS)
	outputs.append_array(TILE_OUTPUTS)
	outputs.append_array(CROP_OUTPUTS)
	outputs.append_array(ITEM_OUTPUTS)
	outputs.append_array(UI_OUTPUTS)
	print("[TextureGenerator] generated %d placeholder textures" % outputs.size())
	for output in outputs:
		print(" - %s/%s" % [OUTPUT_ROOT, output])
