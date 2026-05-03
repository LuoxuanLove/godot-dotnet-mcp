@tool
extends RefCounted
class_name MCPEditorSessionIdentity

static var _session_id := ""
static var _started_at_unix := 0
static var _started_at_ticks_usec := 0


static func build_identity(listen_endpoint: Dictionary = {}) -> Dictionary:
	_ensure_session()
	var cmdline_args := _get_cmdline_args()
	var display_driver := str(DisplayServer.get_name())
	var identity: Dictionary = {
		"session_id": _session_id,
		"identity_scope": "current_editor_process",
		"process_owner": "godot_dotnet_mcp_editor",
		"external_validation_process": false,
		"safe_to_terminate": false,
		"pid": OS.get_process_id(),
		"started_at_unix": _started_at_unix,
		"started_at_ticks_usec": _started_at_ticks_usec,
		"godot_executable_path": OS.get_executable_path(),
		"project_root_path": ProjectSettings.globalize_path("res://"),
		"cmdline_args": cmdline_args,
		"headless": _is_headless(cmdline_args, display_driver),
		"editor_hint": Engine.is_editor_hint(),
		"display_driver": display_driver
	}
	var listen_snapshot := _normalize_listen_endpoint(listen_endpoint)
	if not listen_snapshot.is_empty():
		identity["listen"] = listen_snapshot
		identity["listen_host"] = str(listen_snapshot.get("host", ""))
		identity["listen_port"] = int(listen_snapshot.get("port", 0))
		identity["listen_url"] = str(listen_snapshot.get("url", ""))
	return identity


static func _ensure_session() -> void:
	if not _session_id.is_empty():
		return
	_started_at_unix = int(Time.get_unix_time_from_system())
	_started_at_ticks_usec = Time.get_ticks_usec()
	_session_id = "editor-%d-%d" % [OS.get_process_id(), _started_at_ticks_usec]


static func _get_cmdline_args() -> Array[String]:
	var result: Array[String] = []
	for arg in OS.get_cmdline_args():
		result.append(str(arg))
	return result


static func _is_headless(args: Array[String], display_driver: String) -> bool:
	if display_driver.to_lower() == "headless":
		return true
	for index in range(args.size()):
		var arg := str(args[index]).to_lower()
		if arg == "--headless":
			return true
		if arg == "--display-driver" and index + 1 < args.size() and str(args[index + 1]).to_lower() == "headless":
			return true
	return false


static func _normalize_listen_endpoint(listen_endpoint: Dictionary) -> Dictionary:
	if listen_endpoint.is_empty():
		return {}
	var host := str(listen_endpoint.get("host", listen_endpoint.get("listen_host", ""))).strip_edges()
	var port := int(listen_endpoint.get("port", listen_endpoint.get("listen_port", 0)))
	if host.is_empty() or port <= 0:
		return {}
	return {
		"host": host,
		"port": port,
		"url": str(listen_endpoint.get("url", "http://%s:%d/mcp" % [host, port])),
		"running": bool(listen_endpoint.get("running", false))
	}
