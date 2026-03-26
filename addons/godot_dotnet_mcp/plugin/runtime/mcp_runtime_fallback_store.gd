@tool
extends RefCounted
class_name MCPRuntimeFallbackStore

var _fallback_file_path := "user://godot_mcp_runtime_bridge_events.json"
var _max_stored_events := 300
var _pending_events: Array[Dictionary] = []
var _fallback_cache: Array[Dictionary] = []
var _fallback_cache_loaded := false


func configure(options: Dictionary = {}) -> void:
	_fallback_file_path = str(options.get("fallback_file_path", _fallback_file_path))
	_max_stored_events = maxi(int(options.get("max_stored_events", _max_stored_events)), 1)


func append_event(kind: String, payload: Dictionary, session_id: int = -1) -> void:
	var event := {
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"timestamp_text": Time.get_datetime_string_from_system(true, true),
		"kind": kind,
		"session_id": session_id,
		"payload": payload.duplicate(true)
	}
	_pending_events.append(event)
	_trim_cached_events()


func has_pending_events() -> bool:
	return not _pending_events.is_empty()


func flush() -> void:
	if _pending_events.is_empty():
		return
	if not _fallback_cache_loaded:
		_fallback_cache = _read_fallback_events()
		_fallback_cache_loaded = true
	_fallback_cache.append_array(_pending_events)
	if _fallback_cache.size() > _max_stored_events:
		_fallback_cache = _fallback_cache.slice(_fallback_cache.size() - _max_stored_events)
	_write_fallback_events(_fallback_cache)
	_pending_events.clear()


func read_events() -> Array[Dictionary]:
	if not _fallback_cache_loaded:
		_fallback_cache = _read_fallback_events()
		_fallback_cache_loaded = true
	var events: Array[Dictionary] = _fallback_cache.duplicate(true)
	for event in _pending_events:
		events.append(event.duplicate(true))
	return events


func clear_memory() -> void:
	_pending_events.clear()
	_fallback_cache.clear()
	_fallback_cache_loaded = false


func dispose() -> void:
	clear_memory()


func _read_fallback_events() -> Array[Dictionary]:
	if not FileAccess.file_exists(_fallback_file_path):
		return []
	var file := FileAccess.open(_fallback_file_path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		var events: Array[Dictionary] = []
		for item in parsed:
			if item is Dictionary:
				events.append((item as Dictionary).duplicate(true))
		return events
	if parsed is Dictionary:
		var data = parsed.get("events", [])
		if data is Array:
			var wrapped_events: Array[Dictionary] = []
			for item in data:
				if item is Dictionary:
					wrapped_events.append((item as Dictionary).duplicate(true))
			return wrapped_events
	return []


func _write_fallback_events(events: Array[Dictionary]) -> void:
	var file := FileAccess.open(_fallback_file_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(events))
	file.close()


func _trim_cached_events() -> void:
	var projected_size := _pending_events.size()
	if _fallback_cache_loaded:
		projected_size += _fallback_cache.size()
	if projected_size <= _max_stored_events:
		return
	var overflow := projected_size - _max_stored_events
	while overflow > 0 and not _pending_events.is_empty():
		_pending_events.remove_at(0)
		overflow -= 1
