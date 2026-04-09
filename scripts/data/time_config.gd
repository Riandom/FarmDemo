extends Resource
class_name TimeConfig

@export var ke_duration_seconds: float = 30.0
@export var days_per_solar_term: int = 7
@export var solar_terms_per_season: int = 6
@export var day_start_shi_chen: int = 3
@export var seasons: PackedStringArray = PackedStringArray(["spring", "summer", "autumn", "winter"])
