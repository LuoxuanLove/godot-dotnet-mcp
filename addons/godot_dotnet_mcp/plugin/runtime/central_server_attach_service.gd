@tool
extends RefCounted
class_name CentralServerAttachService

const ATTACH_PATH := "/api/editor/attach"
const HEARTBEAT_PATH := "/api/editor/heartbeat"
const DETACH_PATH := "/api/editor/detach"
const ATTACH_RETRY_INTERVAL_MS := 10000
const HEARTBEAT_INTERVAL_MS := 5000
const CAPABILITIES := ["editor_plugin", "editor_attach", "runtime_bridge"]
const ENV_CENTRAL_SERVER_HOST := "GODOT_DOTNET_MCP_CENTRAL_SERVER_HOST"
const ENV_CENTRAL_SERVER_PORT := "GODOT_DOTNET_MCP_CENTRAL_SERVER_PORT"
const ENV_RUNTIME_SERVER_HOST := "GODOT_DOTNET_MCP_SERVER_HOST"
const ENV_RUNTIME_SERVER_PORT := "GODOT_DOTNET_MCP_SERVER_PORT"

var _plugin: EditorPlugin
var _settings: Dictionary = {}
var _session_id := ""
var _project_id := ""
var _status := "idle"
var _last_error := ""
var _last_message := ""
var _last_attach_attempt_msec := 0
var _last_heartbeat_msec := 0
var _attach_in_flight := false
var _heartbeat_in_flight := false
var _detach_in_flight := false
var _attach_request: HTTPRequest
var _heartbeat_request: HTTPRequest
var _detach_request: HTTPRequest


func configure(plugin: EditorPlugin, settings: Dictionary) -> void:
	_plugin = plugin
	_settings = settings


func start() -> void:
	if not _can_host_request_nodes():
		return
	_ensure_request_nodes()
	if _session_id.is_empty():
		_session_id = _build_session_id()
	_status = "configured"
	_last_error = ""
	_last_message = "Central server attach is configured."
	_last_attach_attempt_msec = 0
	_last_heartbeat_msec = 0


func stop() -> void:
	if _project_id.is_empty():
		_cleanup_request_nodes()
		_reset_runtime_state("stopped")
		return
	if _can_issue_request(_detach_request):
		_send_detach()
	else:
		_cleanup_request_nodes()
	_reset_runtime_state("stopped")


func tick() -> void:
	if not _is_enabled():
		if _status != "disabled":
			_status = "disabled"
		return

	var now := Time.get_ticks_msec()
	if _project_id.is_empty():
		if _attach_in_flight:
			return
		if now - _last_attach_attempt_msec >= ATTACH_RETRY_INTERVAL_MS:
			_send_attach()
		return

	if _heartbeat_in_flight:
		return
	if now - _last_heartbeat_msec >= HEARTBEAT_INTERVAL_MS:
		_send_heartbeat()


func get_status() -> Dictionary:
	return {
		"enabled": _is_enabled(),
		"status": _status,
		"endpoint": _build_url(""),
		"project_root": _get_project_root(),
		"session_id": _session_id,
		"project_id": _project_id,
		"last_error": _last_error,
		"message": _last_message
	}


func request_attach_soon() -> void:
	if not _is_enabled():
		return
	_last_attach_attempt_msec = 0
	if _project_id.is_empty() and not _attach_in_flight and _can_host_request_nodes():
		_send_attach()


func _ensure_request_nodes() -> void:
	if not _can_host_request_nodes():
		return
	_attach_request = _ensure_request_node(_attach_request, "CentralServerAttachRequest", _on_attach_request_completed)
	_heartbeat_request = _ensure_request_node(_heartbeat_request, "CentralServerHeartbeatRequest", _on_heartbeat_request_completed)
	_detach_request = _ensure_request_node(_detach_request, "CentralServerDetachRequest", _on_detach_request_completed)


func _ensure_request_node(request: HTTPRequest, node_name: String, callback: Callable) -> HTTPRequest:
	if request != null and is_instance_valid(request):
		return request
	if not _can_host_request_nodes():
		return null
	var created := HTTPRequest.new()
	created.name = node_name
	created.timeout = 5.0
	created.request_completed.connect(callback)
	_plugin.add_child(created)
	return created


func _cleanup_request_nodes() -> void:
	_cleanup_request_node(_attach_request)
	_cleanup_request_node(_heartbeat_request)
	_cleanup_request_node(_detach_request)
	_attach_request = null
	_heartbeat_request = null
	_detach_request = null


func _cleanup_request_node(request: HTTPRequest) -> void:
	if request == null:
		return
	if is_instance_valid(request):
		request.queue_free()


func _send_attach() -> void:
	_ensure_request_nodes()
	if not _can_issue_request(_attach_request):
		_attach_in_flight = false
		_status = "attach_error"
		_last_error = "Attach request node is not ready."
		_last_message = _last_error
		return
	_attach_in_flight = true
	_last_attach_attempt_msec = Time.get_ticks_msec()
	_status = "attaching"
	_last_error = ""
	_last_message = "Attempting to attach to the central server."
	var payload := {
		"projectRoot": _get_project_root(),
		"sessionId": _session_id,
		"pluginVersion": _get_plugin_version(),
		"godotVersion": _get_godot_version(),
		"capabilities": CAPABILITIES,
		"transportMode": str(_settings.get("transport_mode", "http")),
		"serverHost": _resolve_runtime_server_host(),
		"serverPort": _resolve_runtime_server_port(),
		"serverRunning": _is_embedded_mcp_server_running()
	}
	var error := _attach_request.request(
		_build_url(ATTACH_PATH),
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_attach_in_flight = false
		_status = "attach_error"
		_last_error = "Attach request failed to start: %s" % error
		_last_message = _last_error


func _send_heartbeat() -> void:
	_ensure_request_nodes()
	if not _can_issue_request(_heartbeat_request):
		_heartbeat_in_flight = false
		_project_id = ""
		_status = "heartbeat_error"
		_last_error = "Heartbeat request node is not ready."
		_last_message = _last_error
		return
	_heartbeat_in_flight = true
	_last_heartbeat_msec = Time.get_ticks_msec()
	_status = "heartbeat_pending"
	_last_error = ""
	_last_message = "Heartbeat request is in flight."
	var payload := {
		"projectId": _project_id,
		"projectRoot": _get_project_root(),
		"sessionId": _session_id,
		"transportMode": str(_settings.get("transport_mode", "http")),
		"serverHost": _resolve_runtime_server_host(),
		"serverPort": _resolve_runtime_server_port(),
		"serverRunning": _is_embedded_mcp_server_running()
	}
	var error := _heartbeat_request.request(
		_build_url(HEARTBEAT_PATH),
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_heartbeat_in_flight = false
		_project_id = ""
		_status = "heartbeat_error"
		_last_error = "Heartbeat request failed to start: %s" % error
		_last_message = _last_error


func _send_detach() -> void:
	if _detach_in_flight:
		return
	_ensure_request_nodes()
	if not _can_issue_request(_detach_request):
		_detach_in_flight = false
		return
	_detach_in_flight = true
	var payload := {
		"projectId": _project_id,
		"projectRoot": _get_project_root(),
		"sessionId": _session_id
	}
	var error := _detach_request.request(
		_build_url(DETACH_PATH),
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_detach_in_flight = false


func _on_attach_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_attach_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_status = "attach_error"
		_last_error = _build_http_error_message("attach", result, response_code, body)
		_last_message = _last_error
		return

	var parsed = _parse_json_body(body)
	if not (parsed is Dictionary):
		_status = "attach_error"
		_last_error = "Attach response was not a JSON object."
		_last_message = _last_error
		return

	_project_id = str(parsed.get("projectId", "")).strip_edges()
	var returned_session_id = str(parsed.get("sessionId", "")).strip_edges()
	if not returned_session_id.is_empty():
		_session_id = returned_session_id
	_status = "attached"
	_last_error = ""
	_last_message = "Attached to central server."
	_last_heartbeat_msec = Time.get_ticks_msec()


func _on_heartbeat_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_heartbeat_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_project_id = ""
		_status = "heartbeat_error"
		_last_error = _build_http_error_message("heartbeat", result, response_code, body)
		_last_message = _last_error
		return

	_status = "attached"
	_last_error = ""
	_last_message = "Central server heartbeat succeeded."


func _on_detach_request_completed(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_detach_in_flight = false


func _build_url(path: String) -> String:
	var host := _resolve_central_server_host()
	var port := _resolve_central_server_port()
	return "http://%s:%d%s" % [host, port, path]


func _resolve_central_server_host() -> String:
	var env_host := OS.get_environment(ENV_CENTRAL_SERVER_HOST).strip_edges()
	if not env_host.is_empty():
		return env_host
	var configured_host := str(_settings.get("central_server_host", "127.0.0.1")).strip_edges()
	if configured_host.is_empty():
		return "127.0.0.1"
	return configured_host


func _resolve_central_server_port() -> int:
	var env_port_text := OS.get_environment(ENV_CENTRAL_SERVER_PORT).strip_edges()
	if not env_port_text.is_empty():
		var env_port := int(env_port_text)
		if env_port > 0:
			return env_port
	var configured_port := int(_settings.get("central_server_port", 3020))
	if configured_port <= 0:
		return 3020
	return configured_port


func _resolve_runtime_server_host() -> String:
	var env_host := OS.get_environment(ENV_RUNTIME_SERVER_HOST).strip_edges()
	if not env_host.is_empty():
		return env_host
	var configured_host := str(_settings.get("host", "127.0.0.1")).strip_edges()
	if configured_host.is_empty():
		return "127.0.0.1"
	return configured_host


func _resolve_runtime_server_port() -> int:
	var env_port_text := OS.get_environment(ENV_RUNTIME_SERVER_PORT).strip_edges()
	if env_port_text.is_valid_int():
		var env_port := int(env_port_text)
		if env_port > 0:
			return env_port
	var configured_port := int(_settings.get("port", 3000))
	if configured_port <= 0:
		return 3000
	return configured_port


func _parse_json_body(body: PackedByteArray):
	var text := body.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return null
	return JSON.parse_string(text)


func _build_http_error_message(action: String, result: int, response_code: int, body: PackedByteArray) -> String:
	var parsed = _parse_json_body(body)
	if parsed is Dictionary:
		var error_text = str(parsed.get("error", "")).strip_edges()
		if not error_text.is_empty():
			return "Central server %s failed: %s" % [action, error_text]
	return "Central server %s failed (result=%s, status=%s)." % [action, result, response_code]


func _is_embedded_mcp_server_running() -> bool:
	if _plugin == null or not is_instance_valid(_plugin):
		return false
	var server = _plugin.get_server()
	if server == null:
		return false
	if server.has_method("is_running"):
		return bool(server.is_running())
	return true


func _is_enabled() -> bool:
	return bool(_settings.get("central_server_attach_enabled", true))


func _get_project_root() -> String:
	return ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")


func _get_plugin_version() -> String:
	var config := ConfigFile.new()
	if config.load("res://addons/godot_dotnet_mcp/plugin.cfg") != OK:
		return ""
	return str(config.get_value("plugin", "version", ""))


func _get_godot_version() -> String:
	var info = Engine.get_version_info()
	return "%s.%s.%s" % [
		int(info.get("major", 0)),
		int(info.get("minor", 0)),
		int(info.get("patch", 0))
	]


func _build_session_id() -> String:
	return "%s-%s" % [Time.get_unix_time_from_system(), randi()]


func _can_host_request_nodes() -> bool:
	return _plugin != null and is_instance_valid(_plugin) and _plugin.is_inside_tree()


func _can_issue_request(request: HTTPRequest) -> bool:
	return _can_host_request_nodes() and request != null and is_instance_valid(request) and request.is_inside_tree()


func _reset_runtime_state(next_status: String) -> void:
	_project_id = ""
	_status = next_status
	_last_error = ""
	_last_message = ""
	_attach_in_flight = false
	_heartbeat_in_flight = false
	_detach_in_flight = false
