@tool
extends RefCounted
class_name EditorDebuggerSessionRegistryService


func prune_stale_wired_sessions(wired_sessions: Dictionary, live_session_ids: Array[int], last_active_session_id: int) -> Dictionary:
	var next_wired_sessions: Dictionary = wired_sessions.duplicate(true)
	var live_lookup: Dictionary = {}
	for session_id in live_session_ids:
		live_lookup[int(session_id)] = true
	for raw_session_id in next_wired_sessions.keys().duplicate():
		var session_id := _normalize_session_id(raw_session_id)
		if session_id < 0:
			next_wired_sessions.erase(raw_session_id)
			continue
		if live_lookup.has(session_id):
			continue
		next_wired_sessions.erase(raw_session_id)
		if last_active_session_id == session_id:
			last_active_session_id = -1
	return {
		"wired_sessions": next_wired_sessions,
		"last_active_session_id": last_active_session_id
	}


func _normalize_session_id(raw_session_id) -> int:
	if raw_session_id is int:
		return int(raw_session_id)
	if raw_session_id is float:
		return int(raw_session_id)
	var text := str(raw_session_id).strip_edges()
	if text.is_valid_int():
		return int(text)
	return -1
