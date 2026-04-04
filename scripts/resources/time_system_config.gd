extends Resource
class_name TimeSystemConfig

@export var ke_duration_seconds: float = 30.0
@export var days_per_solar_term: int = 7
@export var solar_terms_per_season: int = 6
@export var day_start_shi_chen: int = 3
@export var seasons_order: PackedStringArray = PackedStringArray(["spring", "summer", "autumn", "winter"])
@export var shi_chen_names: PackedStringArray = PackedStringArray([
	"子时", "丑时", "寅时", "卯时", "辰时", "巳时",
	"午时", "未时", "申时", "酉时", "戌时", "亥时",
])
@export var ke_names: PackedStringArray = PackedStringArray(["初刻", "二刻", "三刻", "四刻"])
