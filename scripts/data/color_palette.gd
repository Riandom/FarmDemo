extends Resource

## 玩家主体色
@export var player_primary: Color = Color("4C8CF5")

## 玩家强调色
@export var player_accent: Color = Color("F2D16B")

## 玩家描边色
@export var player_outline: Color = Color("1F2D3D")

## 5 种地块状态颜色
@export var tile_waste: Color = Color("5B5B5B")
@export var tile_plowed: Color = Color("8B5A2B")
@export var tile_seeded: Color = Color("A66C3D")
@export var tile_watered: Color = Color("6E4A2E")
@export var tile_mature: Color = Color("B28134")

## 小麦 4 个阶段颜色
@export var crop_stage_0: Color = Color("6C9E2A")
@export var crop_stage_1: Color = Color("7FB53D")
@export var crop_stage_2: Color = Color("B7C84A")
@export var crop_stage_3: Color = Color("E4C75A")

## 物品图标颜色
@export var item_seed_wheat: Color = Color("8DBE45")
@export var item_crop_wheat: Color = Color("E7C559")
@export var item_hoe_wood: Color = Color("8B5A2B")
@export var item_watering_can_wood: Color = Color("5899D6")
@export var item_sickle_wood: Color = Color("D5D8DC")

## UI 配色
@export var ui_panel_background: Color = Color(0.13, 0.11, 0.08, 0.94)
@export var ui_panel_border: Color = Color("D8C6A1")
@export var ui_button_normal: Color = Color("6B4F2A")
@export var ui_button_hover: Color = Color("8A6838")
@export var ui_button_pressed: Color = Color("4B351C")
@export var ui_text: Color = Color("FFF4DD")


func get_tile_color(state: String) -> Color:
	match state:
		"waste":
			return tile_waste
		"plowed":
			return tile_plowed
		"seeded":
			return tile_seeded
		"watered":
			return tile_watered
		"mature":
			return tile_mature
		_:
			return tile_waste


func get_crop_stage_color(stage_index: int) -> Color:
	match stage_index:
		0:
			return crop_stage_0
		1:
			return crop_stage_1
		2:
			return crop_stage_2
		3:
			return crop_stage_3
		_:
			return crop_stage_0


func get_item_color(item_id: String) -> Color:
	match item_id:
		"seed_wheat":
			return item_seed_wheat
		"crop_wheat":
			return item_crop_wheat
		"hoe_wood":
			return item_hoe_wood
		"watering_can_wood":
			return item_watering_can_wood
		"sickle_wood":
			return item_sickle_wood
		_:
			return ui_panel_border
