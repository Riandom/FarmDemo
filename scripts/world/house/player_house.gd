extends Node2D
class_name PlayerHouse

@onready var bed_anchor: Marker2D = $BedAnchor
@onready var storage_anchor: Marker2D = $StorageAnchor
@onready var future_utility_anchor: Marker2D = $FutureUtilityAnchor


func get_anchor(anchor_name: String) -> Node2D:
	match anchor_name:
		"bed":
			return bed_anchor
		"storage":
			return storage_anchor
		"future_utility":
			return future_utility_anchor
		_:
			return null
