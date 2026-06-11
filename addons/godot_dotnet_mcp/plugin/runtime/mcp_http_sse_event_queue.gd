@tool
extends RefCounted
class_name MCPHttpSseEventQueue

const SSE_RETRY_MS := 1000
const MAX_EVENTS_PER_SESSION := 32
const MAX_SESSIONS := 64

var _event_logs: Dictionary = {}
var _event_counters: Dictionary = {}
var _event_base_indices: Dictionary = {}
var _session_id_prefixes: Dictionary = {}
var _terminated_sessions: Dictionary = {}
var _session_access_order: Array[String] = []


func dispose() -> void:
	_event_logs.clear()
	_event_counters.clear()
	_event_base_indices.clear()
	_session_id_prefixes.clear()
	_terminated_sessions.clear()
	_session_access_order.clear()


func append_event(session_id: String, event_name: String, payload: Dictionary, id_prefix: String = "streamable-http") -> Dictionary:
	var normalized_session := _normalize_session_id(session_id)
	_touch_session(normalized_session)
	_terminated_sessions.erase(normalized_session)
	_remember_session_id_prefix(normalized_session, id_prefix)
	var event_id := _build_event_id(normalized_session, id_prefix)
	var event := {
		"id": event_id,
		"event": event_name if not event_name.strip_edges().is_empty() else "message",
		"retry": SSE_RETRY_MS,
		"data": payload.duplicate(true)
	}
	var log := _log_for_session(normalized_session)
	log.append(event)
	var base_index := int(_event_base_indices.get(normalized_session, 0))
	while log.size() > MAX_EVENTS_PER_SESSION:
		log.pop_front()
		base_index += 1
	_event_logs[normalized_session] = log
	_event_base_indices[normalized_session] = base_index
	return event.duplicate(true)


func terminate_session(session_id: String) -> Dictionary:
	var normalized_session := _normalize_session_id(session_id)
	var had_history := _event_logs.has(normalized_session)
	var event_count_before := event_count(normalized_session)
	_event_logs.erase(normalized_session)
	_event_counters.erase(normalized_session)
	_event_base_indices.erase(normalized_session)
	_session_id_prefixes.erase(normalized_session)
	var existing_index := _session_access_order.find(normalized_session)
	if existing_index >= 0:
		_session_access_order.remove_at(existing_index)
	_terminated_sessions[normalized_session] = true
	_touch_session(normalized_session)
	return {
		"session_id": normalized_session,
		"had_history": had_history,
		"event_count_before": event_count_before,
		"terminated": true
	}


func is_session_terminated(session_id: String) -> bool:
	return bool(_terminated_sessions.get(_normalize_session_id(session_id), false))


func events_after_cursor(session_id: String, last_event_id: String) -> Array:
	var log := _log_for_session(_normalize_session_id(session_id))
	var cursor := last_event_id.strip_edges()
	if cursor.is_empty():
		return []
	for index in range(log.size()):
		var event = log[index]
		if event is Dictionary and str((event as Dictionary).get("id", "")) == cursor:
			return (log.slice(index + 1) as Array).duplicate(true)
	return []


func events_since_index(session_id: String, start_index: int) -> Array:
	return events_since_index_with_cursor(session_id, start_index).get("events", [])


func events_since_index_with_cursor(session_id: String, start_index: int) -> Dictionary:
	var normalized_session := _normalize_session_id(session_id)
	var log := _log_for_session(normalized_session)
	var base_index := int(_event_base_indices.get(normalized_session, 0))
	var end_index := base_index + log.size()
	var bounded_start: int = clamp(start_index, base_index, end_index)
	return {
		"events": (log.slice(bounded_start - base_index) as Array).duplicate(true),
		"next_index": end_index,
		"start_index": bounded_start,
		"base_index": base_index
	}


func event_count(session_id: String) -> int:
	var normalized_session := _normalize_session_id(session_id)
	return int(_event_base_indices.get(normalized_session, 0)) + _log_for_session(normalized_session).size()


func resume_status(session_id: String, last_event_id: String) -> Dictionary:
	var normalized_session := _normalize_session_id(session_id)
	var cursor := last_event_id.strip_edges()
	if cursor.is_empty():
		var current_base := int(_event_base_indices.get(normalized_session, 0))
		var current_end := current_base + _log_for_session(normalized_session).size()
		return {
			"found": false,
			"status": "no_cursor",
			"event_count_after_cursor": 0,
			"start_index": current_end,
			"base_index": current_base,
			"next_index": current_end
		}
	var has_session := _event_logs.has(normalized_session)
	var log := _log_for_session(normalized_session)
	var base_index := int(_event_base_indices.get(normalized_session, 0))
	var end_index := base_index + log.size()
	for index in range(log.size()):
		var event = log[index]
		if event is Dictionary and str((event as Dictionary).get("id", "")) == cursor:
			return {
				"found": true,
				"status": "matched",
				"event_count_after_cursor": max(0, log.size() - index - 1),
				"start_index": base_index + index + 1,
				"base_index": base_index,
				"next_index": end_index
			}
	var cursor_index := _event_index_from_cursor(normalized_session, cursor)
	if has_session and cursor_index > 0 and cursor_index <= base_index:
		return {
			"found": false,
			"status": "stale_cursor",
			"event_count_after_cursor": 0,
			"start_index": end_index,
			"base_index": base_index,
			"next_index": end_index
		}
	return {
		"found": false,
		"status": "unknown_cursor" if has_session else "unknown_session",
		"event_count_after_cursor": 0,
		"start_index": end_index,
		"base_index": base_index,
		"next_index": end_index
	}


func format_events(events: Array) -> String:
	var body := ""
	for event in events:
		if not (event is Dictionary):
			continue
		body += "id: %s\nretry: %d\nevent: %s\ndata: %s\n\n" % [
			str((event as Dictionary).get("id", "")),
			int((event as Dictionary).get("retry", SSE_RETRY_MS)),
			str((event as Dictionary).get("event", "message")),
			JSON.stringify((event as Dictionary).get("data", {}))
		]
	return body


func _log_for_session(session_id: String) -> Array:
	if _event_logs.get(session_id, []) is Array:
		return (_event_logs.get(session_id, []) as Array).duplicate(true)
	return []


func _touch_session(session_id: String) -> void:
	var existing_index := _session_access_order.find(session_id)
	if existing_index >= 0:
		_session_access_order.remove_at(existing_index)
	_session_access_order.append(session_id)
	while _session_access_order.size() > MAX_SESSIONS:
		var evicted_session := _session_access_order.pop_front()
		_event_logs.erase(evicted_session)
		_event_counters.erase(evicted_session)
		_event_base_indices.erase(evicted_session)
		_session_id_prefixes.erase(evicted_session)
		_terminated_sessions.erase(evicted_session)


func _build_event_id(session_id: String, id_prefix: String) -> String:
	var next_counter := int(_event_counters.get(session_id, 0)) + 1
	_event_counters[session_id] = next_counter
	return "%s-%s-%d" % [
		_sanitize_sse_token(id_prefix),
		_sanitize_sse_token(session_id),
		next_counter
	]


func _remember_session_id_prefix(session_id: String, id_prefix: String) -> void:
	var sanitized_prefix := _sanitize_sse_token(id_prefix)
	var prefixes = _session_id_prefixes.get(session_id, [])
	var known_prefixes: Array = prefixes if prefixes is Array else []
	if not known_prefixes.has(sanitized_prefix):
		known_prefixes.append(sanitized_prefix)
	_session_id_prefixes[session_id] = known_prefixes


func _event_index_from_cursor(session_id: String, cursor: String) -> int:
	var sanitized_session := _sanitize_sse_token(session_id)
	var prefixes = _session_id_prefixes.get(session_id, [])
	var known_prefixes: Array = prefixes if prefixes is Array else []
	for prefix in known_prefixes:
		var expected_prefix := "%s-%s-" % [str(prefix), sanitized_session]
		if not cursor.begins_with(expected_prefix):
			continue
		var counter_text := cursor.substr(expected_prefix.length())
		if counter_text.is_empty() or not counter_text.is_valid_int():
			return -1
		return int(counter_text)
	return -1




func _normalize_session_id(session_id: String) -> String:
	var normalized := session_id.strip_edges()
	return normalized if not normalized.is_empty() else "anonymous"


func _sanitize_sse_token(value: String) -> String:
	var sanitized := value.strip_edges()
	if sanitized.is_empty():
		return "anonymous"
	return sanitized.replace("\r", "_").replace("\n", "_").replace(" ", "_").replace(":", "-")
