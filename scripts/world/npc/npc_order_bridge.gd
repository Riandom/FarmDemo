extends RefCounted
class_name NPCOrderBridge

const NPC_PUBLISHERS: PackedStringArray = [
	"npc_general_store",
	"npc_crafter",
	"npc_resident",
]


static func get_publisher_for_order(order_tier: String, day_seed: int) -> String:
	match order_tier:
		"基础订单":
			return "" if day_seed % 2 == 0 else "npc_general_store"
		"常规订单":
			return "npc_resident"
		"收益订单":
			return "npc_crafter" if day_seed % 2 == 0 else "npc_general_store"
		_:
			return ""
