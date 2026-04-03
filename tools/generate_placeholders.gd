@tool
extends EditorScript

const TILE_SIZE: int = 32

func _run() -> void:
	_generate_player_texture()
	_generate_tile_textures()
	print("占位贴图生成完成!")

func _generate_player_texture() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(_rgb8(65, 105, 225)) # #4169e1
	_save_png(image, "res://assets/sprites/placeholder/player.png")

func _generate_tile_textures() -> void:
	_generate_tile_waste()
	_generate_tile_plowed()
	_generate_tile_seeded()
	_generate_tile_watered()
	_generate_tile_mature()

func _generate_tile_waste() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(_rgb8(58, 58, 58)) # #3a3a3a
	_save_png(image, "res://assets/sprites/placeholder/tile_waste.png")

func _generate_tile_plowed() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(_rgb8(139, 69, 19)) # #8b4513
	# 简单添加耕作纹理，让贴图更像“翻土”。
	var dark := _rgb8(110, 52, 16)
	for i in range(0, TILE_SIZE, 4):
		_draw_line(image, Vector2i(i, 0), Vector2i(i + 4, TILE_SIZE - 1), dark)
	_save_png(image, "res://assets/sprites/placeholder/tile_plowed.png")

func _generate_tile_seeded() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(_rgb8(205, 133, 63)) # #cd853f
	var seed := _rgb8(34, 139, 34) # #228b22
	# 撒下若干绿色小点。
	var dots: Array[Vector2i] = [
		Vector2i(10, 11),
		Vector2i(16, 8),
		Vector2i(22, 14),
		Vector2i(9, 19),
		Vector2i(18, 20),
		Vector2i(24, 22),
	]
	for p in dots:
		_draw_circle(image, p, 1, seed)
	# 适当增加一两点稍大种子点。
	_draw_circle(image, Vector2i(14, 14), 2, seed)
	_save_png(image, "res://assets/sprites/placeholder/tile_seeded.png")

func _generate_tile_watered() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(_rgb8(101, 67, 32)) # #654320
	# 水光效果：蓝色半透明“高光”和几滴水。
	var water := _rgb8(70, 130, 180, 0.75) # #4682b4
	# 左上到右下的高光带。
	for i in range(0, TILE_SIZE):
		var x: int = i
		var y: int = int(i / 2)
		if x >= 0 and x < TILE_SIZE and y >= 0 and y < TILE_SIZE:
			image.set_pixel(x, y, water)
			if x + 1 < TILE_SIZE and y + 1 < TILE_SIZE:
				image.set_pixel(x + 1, y + 1, water)
	# 几滴水（小圆点叠加）。
	var droplets: Array[Vector2i] = [
		Vector2i(12, 10),
		Vector2i(20, 12),
		Vector2i(15, 20),
		Vector2i(23, 22),
	]
	for d in droplets:
		_draw_circle(image, d, 2, water)
	# 轻微“反光”点。
	image.set_pixel(6, 6, _rgb8(180, 220, 255, 0.45))
	image.set_pixel(8, 8, _rgb8(180, 220, 255, 0.35))
	_save_png(image, "res://assets/sprites/placeholder/tile_watered.png")

func _generate_tile_mature() -> void:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(_rgb8(218, 165, 32)) # #daa520
	# 用更深/更浅的金色绘制“麦穗”风格图案。
	var dark := _rgb8(184, 138, 11)
	var light := _rgb8(240, 205, 100)
	# 三根“麦穗”竖条。
	for base_x in [9, 16, 23]:
		var top: int = 6
		# 竖条
		for y in range(top, 24):
			image.set_pixel(base_x, y, dark)
			if base_x + 1 < TILE_SIZE:
				image.set_pixel(base_x + 1, y, light)
		# 穗尖
		for i in range(0, 4):
			var yy: int = top + i
			var xx1: int = base_x - i
			var xx2: int = base_x + i
			if xx1 >= 0:
				image.set_pixel(xx1, yy, light)
			if xx2 < TILE_SIZE:
				image.set_pixel(xx2, yy, light)
	_save_png(image, "res://assets/sprites/placeholder/tile_mature.png")

func _save_png(image: Image, res_path: String) -> void:
	# 在 EditorScript 中直接输出到 res:// 路径即可。
	var err := image.save_png(res_path)

	if err != OK:
		push_warning("保存 PNG 失败: %s (err=%s)" % [res_path, err])

func _rgb8(r: int, g: int, b: int, a: float = 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)

func _draw_circle(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= radius * radius:
				if x >= 0 and x < TILE_SIZE and y >= 0 and y < TILE_SIZE:
					image.set_pixel(x, y, color)

func _draw_line(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	# 简单线段绘制（Bresenham 简化版）。
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
		if x0 >= 0 and x0 < TILE_SIZE and y0 >= 0 and y0 < TILE_SIZE:
			image.set_pixel(x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
