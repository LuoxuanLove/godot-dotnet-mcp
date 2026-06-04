@tool
extends RefCounted
class_name MCPHttpConnectionState

var _clients: Array[StreamPeerTCP] = []
var _pending_data: Dictionary = {}
var _processing_clients: Dictionary = {}
var _client_states: Dictionary = {}
var _recent_client_sessions: Array[Dictionary] = []
var _total_connections: int = 0
var _total_requests: int = 0
var _rejected_requests: int = 0
var _last_request_method: String = ""
var _last_request_path: String = ""
var _last_request_id: String = ""
var _last_request_at_unix: int = 0

const MAX_RECENT_CLIENT_SESSIONS := 8
const MAX_RECENT_REQUESTS_PER_CLIENT := 5


func add_client(client: StreamPeerTCP) -> void:
	_clients.append(client)
	_pending_data[client] = ""
	_total_connections += 1
	var now := _now_unix()
	_client_states[client] = {
		"connection_id": "http-%d" % _total_connections,
		"active": true,
		"connected_at_unix": now,
		"last_seen_at_unix": now,
		"disconnected_at_unix": 0,
		"request_count": 0,
		"last_request_id": "",
		"last_request_method": "",
		"last_request_path": "",
		"last_request_at_unix": 0,
		"last_json_rpc_method": "",
		"client_summary": _build_initial_client_summary(client),
		"recent_requests": []
	}


func get_clients_snapshot() -> Array[StreamPeerTCP]:
	return _clients.duplicate()


func has_client(client: StreamPeerTCP) -> bool:
	return client in _clients


func is_processing(client: StreamPeerTCP) -> bool:
	return _processing_clients.has(client)


func mark_processing(client: StreamPeerTCP) -> void:
	_processing_clients[client] = true


func clear_processing(client: StreamPeerTCP) -> void:
	_processing_clients.erase(client)


func get_pending_data(client: StreamPeerTCP) -> String:
	return str(_pending_data.get(client, ""))


func set_pending_data(client: StreamPeerTCP, data: String) -> void:
	_pending_data[client] = data


func clear_pending_data(client: StreamPeerTCP) -> void:
	_pending_data.erase(client)


func remove_client(client: StreamPeerTCP) -> void:
	_archive_client_session(client)
	_clients.erase(client)
	_pending_data.erase(client)
	_processing_clients.erase(client)
	_client_states.erase(client)


func disconnect_all_clients() -> void:
	for client in _clients:
		if client != null:
			_archive_client_session(client)
			client.disconnect_from_host()
	_clients.clear()
	_pending_data.clear()
	_processing_clients.clear()
	_client_states.clear()


func get_connection_count() -> int:
	return _clients.size()


func record_request(method: String, client: StreamPeerTCP = null, path: String = "", headers: Dictionary = {}, request_body: String = "", body_byte_size: int = 0) -> String:
	_total_requests += 1
	_last_request_method = method
	_last_request_path = path
	_last_request_at_unix = _now_unix()
	if client == null or not _client_states.has(client):
		_last_request_id = "http-request-%d" % _total_requests
		return _last_request_id

	var state: Dictionary = _client_states.get(client, {})
	var request_count := int(state.get("request_count", 0)) + 1
	var connection_id := str(state.get("connection_id", "http-unknown"))
	var request_id := "%s-req-%d" % [connection_id, request_count]
	var json_rpc_summary := _extract_json_rpc_summary(request_body)
	var request_summary := {
		"request_id": request_id,
		"method": method,
		"path": path,
		"at_unix": _last_request_at_unix,
		"content_type": str(headers.get("content-type", "")),
		"body_byte_size": body_byte_size,
		"json_rpc_method": str(json_rpc_summary.get("method", "")),
		"json_rpc_id": json_rpc_summary.get("id", null)
	}
	var recent_requests: Array = []
	if state.get("recent_requests", []) is Array:
		recent_requests = (state.get("recent_requests", []) as Array).duplicate(true)
	recent_requests.append(request_summary)
	while recent_requests.size() > MAX_RECENT_REQUESTS_PER_CLIENT:
		recent_requests.pop_front()
	state["request_count"] = request_count
	state["last_seen_at_unix"] = _last_request_at_unix
	state["last_request_id"] = request_id
	state["last_request_method"] = method
	state["last_request_path"] = path
	state["last_request_at_unix"] = _last_request_at_unix
	state["last_json_rpc_method"] = str(json_rpc_summary.get("method", ""))
	state["client_summary"] = _build_client_summary(client, headers, state.get("client_summary", {}))
	state["recent_requests"] = recent_requests
	_client_states[client] = state
	_last_request_id = request_id
	return request_id


func record_rejected_request() -> void:
	_rejected_requests += 1


func get_connection_stats() -> Dictionary:
	return {
		"active_connections": _clients.size(),
		"connections": _clients.size(),
		"total_connections": _total_connections,
		"total_requests": _total_requests,
		"rejected_requests": _rejected_requests,
		"client_session_count": _clients.size(),
		"client_sessions": _build_active_client_sessions(),
		"recent_client_sessions": _recent_client_sessions.duplicate(true),
		"last_request_id": _last_request_id,
		"last_request_method": _last_request_method,
		"last_request_path": _last_request_path,
		"last_request_at_unix": _last_request_at_unix
	}


func _archive_client_session(client: StreamPeerTCP) -> void:
	if not _client_states.has(client):
		return
	var snapshot := _build_client_session_snapshot(_client_states.get(client, {}), false)
	snapshot["active"] = false
	snapshot["disconnected_at_unix"] = _now_unix()
	_recent_client_sessions.append(snapshot)
	while _recent_client_sessions.size() > MAX_RECENT_CLIENT_SESSIONS:
		_recent_client_sessions.pop_front()


func _build_active_client_sessions() -> Array[Dictionary]:
	var sessions: Array[Dictionary] = []
	for client in _clients:
		if _client_states.has(client):
			sessions.append(_build_client_session_snapshot(_client_states.get(client, {}), true))
	return sessions


func _build_client_session_snapshot(state: Dictionary, active: bool) -> Dictionary:
	var snapshot := {
		"connection_id": str(state.get("connection_id", "")),
		"active": active,
		"connected_at_unix": int(state.get("connected_at_unix", 0)),
		"last_seen_at_unix": int(state.get("last_seen_at_unix", 0)),
		"disconnected_at_unix": int(state.get("disconnected_at_unix", 0)),
		"request_count": int(state.get("request_count", 0)),
		"last_request_id": str(state.get("last_request_id", "")),
		"last_request_method": str(state.get("last_request_method", "")),
		"last_request_path": str(state.get("last_request_path", "")),
		"last_request_at_unix": int(state.get("last_request_at_unix", 0)),
		"last_json_rpc_method": str(state.get("last_json_rpc_method", "")),
		"client_summary": {},
		"recent_requests": []
	}
	if state.get("client_summary", {}) is Dictionary:
		snapshot["client_summary"] = (state.get("client_summary", {}) as Dictionary).duplicate(true)
	if state.get("recent_requests", []) is Array:
		snapshot["recent_requests"] = (state.get("recent_requests", []) as Array).duplicate(true)
	return snapshot


func _build_initial_client_summary(client: StreamPeerTCP) -> Dictionary:
	return _build_client_summary(client, {}, {})


func _build_client_summary(client: StreamPeerTCP, headers: Dictionary, previous_summary = {}) -> Dictionary:
	var summary := {}
	if previous_summary is Dictionary:
		summary = (previous_summary as Dictionary).duplicate(true)
	var remote_address := _get_client_string(client, "get_connected_host")
	var remote_port := _get_client_int(client, "get_connected_port")
	if not remote_address.is_empty():
		summary["remote_address"] = remote_address
	if remote_port > 0:
		summary["remote_port"] = remote_port
	for key in ["host", "origin", "user-agent", "accept", "content-type"]:
		var value := str(headers.get(key, "")).strip_edges()
		if not value.is_empty():
			summary[_summary_key_for_header(key)] = value
	if headers.has("authorization"):
		summary["authorization_present"] = true
	return summary


func _summary_key_for_header(header_name: String) -> String:
	match header_name:
		"user-agent":
			return "user_agent"
		"content-type":
			return "content_type"
		_:
			return header_name


func _extract_json_rpc_summary(request_body: String) -> Dictionary:
	if request_body.strip_edges().is_empty():
		return {}
	var parsed = JSON.parse_string(request_body)
	if parsed is Dictionary:
		return _extract_json_rpc_message_summary(parsed as Dictionary)
	if parsed is Array and not (parsed as Array).is_empty() and (parsed as Array)[0] is Dictionary:
		var first_message: Dictionary = (parsed as Array)[0]
		var summary := _extract_json_rpc_message_summary(first_message)
		summary["batch"] = true
		summary["batch_size"] = (parsed as Array).size()
		return summary
	return {}


func _extract_json_rpc_message_summary(message: Dictionary) -> Dictionary:
	return {
		"method": str(message.get("method", "")),
		"id": message.get("id", null)
	}


func _get_client_string(client: StreamPeerTCP, method_name: String) -> String:
	if client == null or not client.has_method(method_name):
		return ""
	var value = client.call(method_name)
	return str(value)


func _get_client_int(client: StreamPeerTCP, method_name: String) -> int:
	if client == null or not client.has_method(method_name):
		return 0
	var value = client.call(method_name)
	if typeof(value) == TYPE_INT:
		return int(value)
	return 0


func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())
