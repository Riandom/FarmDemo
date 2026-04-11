extends Node

signal orders_changed(orders: Array)
signal order_submitted(result: Dictionary)

const ORDER_STATUS_ACTIVE: String = "active"
const ORDER_STATUS_COMPLETED: String = "completed"

var daily_orders: Array[Dictionary] = []
var last_refresh_day_key: String = ""
var completed_order_ids: PackedStringArray = PackedStringArray()

@onready var event_manager = get_node_or_null("/root/EventManager")
@onready var time_manager = get_node_or_null("/root/TimeManager")
@onready var game_manager = get_node_or_null("/root/GameManager")
@onready var config_manager = get_node_or_null("/root/ConfigManager")


func _ready() -> void:
	call_deferred("_initialize_order_runtime")


func get_orders() -> Array[Dictionary]:
	ensure_orders_for_today()
	return _duplicate_orders(daily_orders)


func get_active_orders() -> Array[Dictionary]:
	ensure_orders_for_today()
	var active_orders: Array[Dictionary] = []
	for order in daily_orders:
		if not (order is Dictionary):
			continue
		if String(order.get("status", ORDER_STATUS_ACTIVE)) == ORDER_STATUS_ACTIVE:
			active_orders.append(order.duplicate(true))
	return active_orders


func ensure_orders_for_today() -> void:
	var current_day_key: String = _get_current_day_key()
	if daily_orders.is_empty():
		refresh_daily_orders(true)
		return

	if current_day_key == "":
		return

	if current_day_key != last_refresh_day_key:
		refresh_daily_orders(true)


func refresh_daily_orders(force: bool = false) -> void:
	var current_day_key: String = _get_current_day_key()
	if not force and current_day_key != "" and current_day_key == last_refresh_day_key and not daily_orders.is_empty():
		return

	var day_seed: int = _get_day_seed_value()
	var selected_crops: Array[CropConfig] = _get_selected_crops_for_today(day_seed)
	if selected_crops.size() < 3:
		push_warning("[OrderManager] Not enough crop configs to generate daily orders")
		return

	var low_crop: CropConfig = selected_crops[0]
	var mid_crop: CropConfig = selected_crops[1]
	var high_crop: CropConfig = selected_crops[2]
	var low_required_count: int = 2 + (day_seed % 3)
	var mid_required_count: int = 4 + (day_seed % 3)
	var high_required_count: int = 1 + int(floor(float(day_seed % 5) / 2.0))
	var low_reward_ratio: float = 0.30 + 0.03 * float(day_seed % 3)
	var mid_reward_ratio: float = 0.38 + 0.02 * float(day_seed % 4)
	var high_reward_ratio: float = 0.46 + 0.03 * float(day_seed % 3)

	daily_orders = [
		_build_order(low_crop, low_required_count, low_reward_ratio, "基础订单", day_seed),
		_build_order(mid_crop, mid_required_count, mid_reward_ratio, "常规订单", day_seed),
		_build_order(high_crop, high_required_count, high_reward_ratio, "收益订单", day_seed),
	]
	last_refresh_day_key = current_day_key
	completed_order_ids = PackedStringArray()
	emit_signal("orders_changed", get_orders())


func can_submit_order(order_id: String) -> bool:
	ensure_orders_for_today()
	var order: Dictionary = _find_order(order_id)
	if order.is_empty():
		return false
	if String(order.get("status", ORDER_STATUS_ACTIVE)) != ORDER_STATUS_ACTIVE:
		return false

	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null or not game_manager.has_method("has_item"):
		return false

	return bool(game_manager.call(
		"has_item",
		String(order.get("item_id", "")),
		int(order.get("required_count", 0))
	))


func submit_order(order_id: String) -> Dictionary:
	ensure_orders_for_today()
	var order_index: int = _find_order_index(order_id)
	if order_index == -1:
		return _build_submit_result(false, "订单不存在")

	var order: Dictionary = daily_orders[order_index]
	if String(order.get("status", ORDER_STATUS_ACTIVE)) != ORDER_STATUS_ACTIVE:
		return _build_submit_result(false, "订单已完成")

	if game_manager == null:
		game_manager = get_node_or_null("/root/GameManager")
	if game_manager == null:
		return _build_submit_result(false, "GameManager 未就绪")

	var item_id: String = String(order.get("item_id", ""))
	var required_count: int = int(order.get("required_count", 0))
	if not bool(game_manager.call("has_item", item_id, required_count)):
		return _build_submit_result(false, "物品数量不足")

	if not bool(game_manager.call("remove_item", item_id, required_count)):
		return _build_submit_result(false, "提交失败，无法扣除物品")

	var reward_gold: int = int(order.get("reward_gold", 0))
	if reward_gold > 0:
		game_manager.call("add_gold", reward_gold)

	var reward_items: Dictionary = order.get("reward_items", {})
	if reward_items is Dictionary:
		for reward_item_id in reward_items.keys():
			game_manager.call("add_item", String(reward_item_id), int(reward_items[reward_item_id]))

	var publisher_npc_id: String = String(order.get("publisher_npc_id", ""))
	var affinity_reward: int = int(order.get("affinity_reward", 0))
	if publisher_npc_id != "" and affinity_reward != 0 and game_manager.has_method("add_npc_affinity"):
		game_manager.call("add_npc_affinity", publisher_npc_id, affinity_reward)

	order["status"] = ORDER_STATUS_COMPLETED
	daily_orders[order_index] = order
	if not completed_order_ids.has(order_id):
		completed_order_ids.append(order_id)

	var result: Dictionary = _build_submit_result(
		true,
		_build_order_completion_message(publisher_npc_id, affinity_reward),
		reward_gold,
		reward_items if reward_items is Dictionary else {},
		publisher_npc_id,
		affinity_reward
	)
	emit_signal("orders_changed", get_orders())
	emit_signal("order_submitted", result)
	return result


func export_save_data() -> Dictionary:
	ensure_orders_for_today()
	return {
		"daily_orders": _duplicate_orders(daily_orders),
		"last_refresh_day_key": last_refresh_day_key,
		"completed_order_ids": Array(completed_order_ids),
	}


func apply_save_data(data: Dictionary) -> void:
	if not (data is Dictionary):
		daily_orders = []
		last_refresh_day_key = ""
		completed_order_ids = PackedStringArray()
		emit_signal("orders_changed", get_orders())
		return

	var saved_orders = data.get("daily_orders", [])
	if saved_orders is Array:
		daily_orders = _normalize_order_array(saved_orders)
	else:
		daily_orders = []

	last_refresh_day_key = String(data.get("last_refresh_day_key", ""))

	var saved_completed = data.get("completed_order_ids", [])
	if saved_completed is PackedStringArray:
		completed_order_ids = saved_completed.duplicate()
	elif saved_completed is Array:
		completed_order_ids = PackedStringArray(saved_completed)
	else:
		completed_order_ids = _extract_completed_order_ids(daily_orders)

	emit_signal("orders_changed", get_orders())


func _initialize_order_runtime() -> void:
	if event_manager == null:
		event_manager = get_node_or_null("/root/EventManager")
	if event_manager != null and event_manager.has_method("subscribe"):
		event_manager.call("subscribe", "day_started", Callable(self, "_on_day_started"))
		event_manager.call("subscribe", "save_loaded", Callable(self, "_on_save_loaded"))

	if daily_orders.is_empty():
		refresh_daily_orders(true)


func _on_day_started(_data: Dictionary) -> void:
	var current_day_key: String = _get_current_day_key()
	if current_day_key == "" or current_day_key != last_refresh_day_key:
		refresh_daily_orders(true)


func _on_save_loaded(_data: Dictionary) -> void:
	var current_day_key: String = _get_current_day_key()
	if daily_orders.is_empty():
		refresh_daily_orders(true)
		return

	if current_day_key != "" and last_refresh_day_key != "" and current_day_key != last_refresh_day_key:
		refresh_daily_orders(true)


func _get_selected_crops_for_today(day_seed: int) -> Array[CropConfig]:
	if config_manager == null:
		config_manager = get_node_or_null("/root/ConfigManager")
	if config_manager == null or not config_manager.has_method("get_all_crops"):
		return []

	var all_crops: Array[CropConfig] = config_manager.call("get_all_crops")
	var current_season: String = _get_current_season()
	var seasonal_crops: Array[CropConfig] = []
	for crop in all_crops:
		if crop == null:
			continue
		if crop.suitable_seasons.is_empty() or crop.suitable_seasons.has(current_season):
			seasonal_crops.append(crop)

	var candidates: Array[CropConfig] = seasonal_crops if seasonal_crops.size() >= 3 else all_crops
	candidates.sort_custom(Callable(self, "_sort_crop_by_sell_price"))
	if candidates.size() < 3:
		return candidates

	var tier_size: int = maxi(int(floor(float(candidates.size()) / 3.0)), 1)
	var low_pool: Array[CropConfig] = candidates.slice(0, tier_size)
	var mid_pool_start: int = clampi(tier_size, 0, candidates.size() - 1)
	var mid_pool_end: int = clampi(candidates.size() - tier_size, mid_pool_start + 1, candidates.size())
	var mid_pool: Array[CropConfig] = candidates.slice(mid_pool_start, mid_pool_end)
	var high_pool: Array[CropConfig] = candidates.slice(maxi(candidates.size() - tier_size, 0), candidates.size())

	return [
		_pick_crop_from_pool(low_pool, day_seed),
		_pick_crop_from_pool(mid_pool, day_seed + 1),
		_pick_crop_from_pool(high_pool, day_seed + 2),
	]


func _sort_crop_by_sell_price(a: CropConfig, b: CropConfig) -> bool:
	if a == null:
		return false
	if b == null:
		return true
	if a.sell_price != b.sell_price:
		return a.sell_price < b.sell_price
	return a.display_name < b.display_name


func _build_order(crop: CropConfig, required_count: int, reward_bonus_ratio: float, prefix: String, day_seed: int) -> Dictionary:
	var order_sale_total: int = crop.sell_price * required_count
	var reward_gold: int = order_sale_total + max(int(ceil(order_sale_total * reward_bonus_ratio)), 12)
	var current_day_key: String = _get_current_day_key()
	var publisher_npc_id: String = NPCOrderBridge.get_publisher_for_order(prefix, day_seed)
	var affinity_reward: int = 2 if publisher_npc_id != "" else 0
	return {
		"order_id": "%s_%s" % [current_day_key, crop.crop_id],
		"title": "%s：交付%s" % [prefix, crop.display_name],
		"item_id": crop.harvest_item_id,
		"required_count": required_count,
		"reward_gold": reward_gold,
		"reward_items": {},
		"publisher_npc_id": publisher_npc_id,
		"affinity_reward": affinity_reward,
		"status": ORDER_STATUS_ACTIVE,
	}


func _find_order(order_id: String) -> Dictionary:
	var order_index: int = _find_order_index(order_id)
	if order_index == -1:
		return {}
	return daily_orders[order_index].duplicate(true)


func _find_order_index(order_id: String) -> int:
	for index in range(daily_orders.size()):
		var order = daily_orders[index]
		if order is Dictionary and String(order.get("order_id", "")) == order_id:
			return index
	return -1


func _build_submit_result(success: bool, message: String, reward_gold: int = 0, reward_items: Dictionary = {}, publisher_npc_id: String = "", affinity_reward: int = 0) -> Dictionary:
	return {
		"success": success,
		"message": message,
		"reward_gold": reward_gold,
		"reward_items": reward_items.duplicate(true),
		"publisher_npc_id": publisher_npc_id,
		"affinity_reward": affinity_reward,
	}


func _build_order_completion_message(publisher_npc_id: String, affinity_reward: int) -> String:
	if publisher_npc_id == "" or affinity_reward <= 0:
		return "订单完成"
	return "%s 的委托已完成，好感提升 %d" % [_get_npc_display_name(publisher_npc_id), affinity_reward]


func _pick_crop_from_pool(pool: Array[CropConfig], day_seed: int) -> CropConfig:
	if pool.is_empty():
		return null
	var index: int = posmod(day_seed, pool.size())
	return pool[index]


func _get_day_seed_value() -> int:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return 0

	var snapshot: Dictionary = time_manager.export_save_data()
	var year_value: int = int(snapshot.get("year_count", 0))
	var solar_term_value: int = int(snapshot.get("solar_term", 0))
	var day_value: int = int(snapshot.get("day_in_term", 0))
	return year_value * 100 + solar_term_value * 10 + day_value


func _get_current_day_key() -> String:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return "day_unknown"

	var snapshot: Dictionary = time_manager.export_save_data()
	return "%s_%s_%s_%s" % [
		String(snapshot.get("season", "spring")),
		int(snapshot.get("year_count", 0)),
		int(snapshot.get("solar_term", 0)),
		int(snapshot.get("day_in_term", 0)),
	]


func _get_current_season() -> String:
	if time_manager == null:
		time_manager = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return "spring"
	return String(time_manager.get("season"))


func _duplicate_orders(source_orders: Array) -> Array[Dictionary]:
	var duplicated: Array[Dictionary] = []
	for order in source_orders:
		if order is Dictionary:
			duplicated.append(order.duplicate(true))
	return duplicated


func _normalize_order_array(source_orders: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for raw_order in source_orders:
		if not (raw_order is Dictionary):
			continue

		var order: Dictionary = {
			"order_id": String(raw_order.get("order_id", "")),
			"title": String(raw_order.get("title", "")),
			"item_id": String(raw_order.get("item_id", "")),
			"required_count": max(int(raw_order.get("required_count", 0)), 0),
			"reward_gold": max(int(raw_order.get("reward_gold", 0)), 0),
			"reward_items": raw_order.get("reward_items", {}) if raw_order.get("reward_items", {}) is Dictionary else {},
			"publisher_npc_id": String(raw_order.get("publisher_npc_id", "")),
			"affinity_reward": max(int(raw_order.get("affinity_reward", 0)), 0),
			"status": String(raw_order.get("status", ORDER_STATUS_ACTIVE)),
		}
		if String(order["order_id"]) == "" or String(order["item_id"]) == "":
			continue
		normalized.append(order)
	return normalized


func _extract_completed_order_ids(source_orders: Array[Dictionary]) -> PackedStringArray:
	var ids := PackedStringArray()
	for order in source_orders:
		if String(order.get("status", ORDER_STATUS_ACTIVE)) != ORDER_STATUS_COMPLETED:
			continue
		var order_id: String = String(order.get("order_id", ""))
		if order_id != "" and not ids.has(order_id):
			ids.append(order_id)
	return ids


func get_npc_display_name(npc_id: String) -> String:
	return _get_npc_display_name(npc_id)


func _get_npc_display_name(npc_id: String) -> String:
	match npc_id:
		"npc_general_store":
			return "沈老板"
		"npc_crafter":
			return "铁匠顾"
		"npc_resident":
			return "阿棠"
		_:
			return npc_id
