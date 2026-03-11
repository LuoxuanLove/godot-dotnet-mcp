@tool
extends RefCounted
class_name MCPDebugBuffer

const MAX_EVENTS := 200

static var _events: Array[Dictionary] = []


static func record(level: String, source: String, message: String, tool_name: String = "", metadata: Dictionary = {}) -> void:
	if message.is_empty():
		return

	var event := {
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"timestamp_text": Time.get_datetime_string_from_system(true, true),
		"level": level,
		"source": source,
		"message": message,
		"tool_name": tool_name
	}

	if not metadata.is_empty():
		event["metadata"] = metadata.duplicate(true)

	_events.append(event)
	if _events.size() > MAX_EVENTS:
		_events = _events.slice(_events.size() - MAX_EVENTS)


static func get_recent(limit: int = 50) -> Array[Dictionary]:
	var resolved_limit := maxi(limit, 0)
	if resolved_limit == 0:
		return []
	var start_index := maxi(_events.size() - resolved_limit, 0)
	return _events.slice(start_index).duplicate(true)


static func get_by_levels(levels: Array[String], limit: int = 50) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for event in _events:
		if levels.has(str(event.get("level", ""))):
			filtered.append(event.duplicate(true))

	var resolved_limit := maxi(limit, 0)
	if resolved_limit == 0 or filtered.size() <= resolved_limit:
		return filtered
	return filtered.slice(filtered.size() - resolved_limit)


static func clear() -> void:
	_events.clear()


static func size() -> int:
	return _events.size()
