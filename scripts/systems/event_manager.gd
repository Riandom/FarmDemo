extends Node

const MAX_HISTORY_SIZE: int = 100

var _subscriptions: Dictionary = {}
var _event_history: Array[Dictionary] = []


func subscribe(event_type: String, callback: Callable) -> void:
	if event_type == "" or callback.is_null():
		push_warning("[EventManager] Invalid subscribe request")
		return

	var subscribers: Array[Callable] = _get_subscribers(event_type)
	if callback in subscribers:
		push_warning("[EventManager] Callback already subscribed: %s" % event_type)
		return

	subscribers.append(callback)
	_subscriptions[event_type] = subscribers


func unsubscribe(event_type: String, callback: Callable) -> void:
	if not _subscriptions.has(event_type):
		return

	var subscribers: Array[Callable] = _get_subscribers(event_type)
	var index: int = subscribers.find(callback)
	if index == -1:
		return

	subscribers.remove_at(index)
	if subscribers.is_empty():
		_subscriptions.erase(event_type)
	else:
		_subscriptions[event_type] = subscribers


func unsubscribe_all(callback: Callable) -> void:
	var event_types: Array[String] = []
	for key: Variant in _subscriptions.keys():
		event_types.append(String(key))

	for event_type: String in event_types:
		unsubscribe(event_type, callback)


func publish(event_type: String, data: Dictionary = {}) -> void:
	_record_event(event_type, data)

	if not _subscriptions.has(event_type):
		return

	var subscribers: Array[Callable] = []
	for callback_ref: Callable in _get_subscribers(event_type):
		subscribers.append(callback_ref)

	for callback: Callable in subscribers:
		if callback.is_null():
			unsubscribe(event_type, callback)
			continue

		var target: Object = callback.get_object()
		if target != null and not is_instance_valid(target):
			unsubscribe(event_type, callback)
			continue

		callback.call(data)


func get_event_history(last_n: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count: int = clampi(last_n, 0, _event_history.size())
	var start_index: int = max(_event_history.size() - count, 0)

	for index: int in range(start_index, _event_history.size()):
		result.append(_event_history[index].duplicate(true))

	return result


func _get_subscribers(event_type: String) -> Array[Callable]:
	var raw_value: Variant = _subscriptions.get(event_type, [])
	var raw_array: Array = raw_value if raw_value is Array else []
	var subscribers: Array[Callable] = []
	for item: Variant in raw_array:
		if item is Callable:
			subscribers.append(item)
	return subscribers


func _record_event(event_type: String, data: Dictionary) -> void:
	_event_history.append({
		"timestamp": Time.get_ticks_msec(),
		"event_type": event_type,
		"data": data.duplicate(true),
	})

	if _event_history.size() > MAX_HISTORY_SIZE:
		_event_history.pop_front()
