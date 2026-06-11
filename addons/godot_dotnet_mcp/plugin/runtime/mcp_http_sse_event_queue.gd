@tool
extends RefCounted
class_name MCPHttpSseEventQueue

const SSE_RETRY_MS := 1000
const MAX_EVENTS_PER_SESSION := 32
const MAX_SESSIONS := 64

var _event_logs: Dictionary = {}
var _event_counters: Dictionary = {}
var _event_base_indices: Dictionary = {}
var _session_access_order: Array[String] = []


func dispose() -> void:
	_event_logs.clear()
	_event_counters.clear()
	_event_base_indices.clear()
	_session_access_order.clear()


func append_event(session_id: String, event_name: String, payload: Dictionary, id_prefix: String = "streamable-http") -> Dictionary:
	var normalized_session := _normalize_session_id(session_id)
	_touch_session(normalized_session)
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
	var normalized_session := _normalize_session_id(session_id)
	var log := _log_for_session(normalized_session)
	var base_index := int(_event_base_indices.get(normalized_session, 0))
	var end_index := base_index + log.size()
	var bounded_start: int = clamp(start_index, base_index, end_index)
	return (log.slice(bounded_start - base_index) as Array).duplicate(true)


func event_count(session_id: String) -> int:
	var normalized_session := _normalize_session_id(session_id)
	return int(_event_base_indices.get(normalized_session, 0)) + _log_for_session(normalized_session).size()


func resume_status(session_id: String, last_event_id: String) -> Dictionary:
	var cursor := last_event_id.strip_edges()
	if cursor.is_empty():
		return {"found": false, "event_count_after_cursor": 0}
	var log := _log_for_session(_normalize_session_id(session_id))
	for index in range(log.size()):
		var event = log[index]
		if event is Dictionary and str((event as Dictionary).get("id", "")) == cursor:
			return {
				"found": true,
				"event_count_after_cursor": max(0, log.size() - index - 1)
			}
	return {"found": false, "event_count_after_cursor": 0}


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


func _build_event_id(session_id: String, id_prefix: String) -> String:
	var next_counter := int(_event_counters.get(session_id, 0)) + 1
	_event_counters[session_id] = next_counter
	return "%s-%s-%d" % [
		_sanitize_sse_token(id_prefix),
		_sanitize_sse_token(session_id),
		next_counter
	]


func _normalize_session_id(session_id: String) -> String:
	var normalized := session_id.strip_edges()
	return normalized if not normalized.is_empty() else "anonymous"


func _sanitize_sse_token(value: String) -> String:
	var sanitized := value.strip_edges()
	if sanitized.is_empty():
		return "anonymous"
	return sanitized.replace("\r", "_").replace("\n", "_").replace(" ", "_").replace(":", "-")
