extends Resource
class_name ShopConfig

## 可购买商品字典
@export var buy_items: Dictionary = {}

## 可售卖商品字典
@export var sell_items: Dictionary = {}


## 检查单个商品条目是否合法
func is_valid_entry(entry: Dictionary) -> bool:
	if not entry.has("price"):
		return false

	if typeof(entry["price"]) != TYPE_INT:
		return false

	if int(entry["price"]) < 0:
		return false

	var display_name := String(entry.get("display_name", "")).strip_edges()
	if display_name == "":
		return false

	var icon_value = entry.get("icon", "")
	if typeof(icon_value) != TYPE_STRING:
		return false

	return true


## 验证整份配置并输出无效条目的警告
func validate_config() -> bool:
	var all_valid := true

	for item_id in buy_items.keys():
		var entry = buy_items[item_id]
		if not is_valid_entry(entry):
			push_warning("[ShopConfig] buy item invalid: %s" % String(item_id))
			all_valid = false

	for item_id in sell_items.keys():
		var entry = sell_items[item_id]
		if not is_valid_entry(entry):
			push_warning("[ShopConfig] sell item invalid: %s" % String(item_id))
			all_valid = false

	return all_valid


## 返回过滤后的合法商品字典
func get_valid_items(section: String) -> Dictionary:
	var source: Dictionary = buy_items if section == "buy" else sell_items
	var filtered: Dictionary = {}

	for item_id in source.keys():
		var entry: Dictionary = source[item_id]
		if is_valid_entry(entry):
			filtered[item_id] = entry

	return filtered
