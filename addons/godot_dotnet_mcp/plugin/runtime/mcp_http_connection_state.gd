@tool
extends RefCounted
class_name MCPHttpConnectionState

var _clients: Array[StreamPeerTCP] = []
var _pending_data: Dictionary = {}
var _processing_clients: Dictionary = {}
var _total_connections: int = 0
var _total_requests: int = 0
var _last_request_method: String = ""
var _last_request_at_unix: int = 0


func add_client(client: StreamPeerTCP) -> void:
	_clients.append(client)
	_pending_data[client] = ""
	_total_connections += 1


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
	_clients.erase(client)
	_pending_data.erase(client)
	_processing_clients.erase(client)


func disconnect_all_clients() -> void:
	for client in _clients:
		if client != null:
			client.disconnect_from_host()
	_clients.clear()
	_pending_data.clear()
	_processing_clients.clear()


func get_connection_count() -> int:
	return _clients.size()


func record_request(method: String) -> void:
	_total_requests += 1
	_last_request_method = method
	_last_request_at_unix = int(Time.get_unix_time_from_system())


func get_connection_stats() -> Dictionary:
	return {
		"active_connections": _clients.size(),
		"connections": _clients.size(),
		"total_connections": _total_connections,
		"total_requests": _total_requests,
		"last_request_method": _last_request_method,
		"last_request_at_unix": _last_request_at_unix
	}
