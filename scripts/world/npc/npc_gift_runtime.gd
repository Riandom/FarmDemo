extends RefCounted
class_name NPCGiftRuntime

const REACTION_LIKE: String = "like"
const REACTION_NEUTRAL: String = "neutral"
const REACTION_DISLIKE: String = "dislike"


static func resolve_reaction(npc: Node, item_id: String) -> String:
	if item_id == "":
		return REACTION_NEUTRAL

	var liked_items: PackedStringArray = npc.get("liked_items")
	if liked_items.has(item_id):
		return REACTION_LIKE

	var disliked_items: PackedStringArray = npc.get("disliked_items")
	if disliked_items.has(item_id):
		return REACTION_DISLIKE

	return REACTION_NEUTRAL


static func get_affinity_delta(reaction: String) -> int:
	match reaction:
		REACTION_LIKE:
			return 8
		REACTION_DISLIKE:
			return -4
		_:
			return 3


static func build_feedback(display_name: String, item_name: String, reaction: String) -> String:
	match reaction:
		REACTION_LIKE:
			return "%s 很喜欢你送的%s。" % [display_name, item_name]
		REACTION_DISLIKE:
			return "%s 看起来不太喜欢这份%s。" % [display_name, item_name]
		_:
			return "%s 收下了你的%s。" % [display_name, item_name]
