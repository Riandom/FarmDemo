extends "res://scripts/world/farm/plot.gd"
class_name CropPlot

const PLACEHOLDER_TEXTURES: Dictionary = {
	STATE_WASTE: "res://assets/sprites/placeholder/tiles/waste.png",
	STATE_PLOWED: "res://assets/sprites/placeholder/tiles/plowed.png",
	STATE_SEEDED: "res://assets/sprites/placeholder/tiles/seeded.png",
	STATE_WATERED: "res://assets/sprites/placeholder/tiles/watered.png",
	STATE_MATURE: "res://assets/sprites/placeholder/tiles/mature.png",
}

@onready var crop_sprite: Sprite2D = $CropSprite2D


func _ready() -> void:
	"""先执行基类初始化，再应用地块贴图。"""
	super._ready()
	_apply_visual_state()


func _apply_visual_state() -> void:
	"""根据地块状态刷新地面层和作物层贴图。"""
	var texture_path: String = PLACEHOLDER_TEXTURES.get(base_state, "")
	if texture_path != "" and ResourceLoader.exists(texture_path):
		sprite.texture = load(texture_path)

	var crop_texture_path := _get_crop_texture_path()
	if crop_texture_path != "" and ResourceLoader.exists(crop_texture_path):
		crop_sprite.texture = load(crop_texture_path)
		crop_sprite.visible = true
	else:
		crop_sprite.texture = null
		crop_sprite.visible = false


func request_visual_refresh() -> void:
	"""地块请求刷新时先更新本地贴图，再通知外部系统。"""
	_apply_visual_state()
	super.request_visual_refresh()


func _get_crop_texture_path() -> String:
	"""将简化状态机映射到 4 阶段小麦占位图。"""
	var crop_config: CropConfig = _load_crop_config()
	if crop_config == null or crop_config.sprites_per_stage.is_empty():
		return ""

	match base_state:
		STATE_SEEDED:
			return crop_config.sprites_per_stage[0]
		STATE_WATERED:
			var intermediate_max_index: int = max(crop_config.sprites_per_stage.size() - 2, 1)
			var normalized_growth: float = clampf((float(growth_stage) + growth_progress) / float(max(crop_config.growth_stages, 1)), 0.0, 0.999)
			var stage_index: int = clampi(1 + int(floor(normalized_growth * float(intermediate_max_index))), 1, intermediate_max_index)
			return crop_config.sprites_per_stage[stage_index]
		STATE_MATURE:
			return crop_config.sprites_per_stage[crop_config.sprites_per_stage.size() - 1]
		_:
			return ""
