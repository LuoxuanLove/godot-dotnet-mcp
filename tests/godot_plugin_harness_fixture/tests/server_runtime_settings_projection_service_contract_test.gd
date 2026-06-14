extends RefCounted

const ServerRuntimeSettingsProjectionService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_settings_projection_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ServerRuntimeSettingsProjectionService.new()
	_clear_runtime_environment()

	var default_projection = service.project({
		"host": "   ",
		"port": "not-a-port",
		"debug_mode": "off",
		"transport_mode": "pipe",
		"stdio_framing_mode": "content-length",
		"disabled_tools": [" system_project_state ", "", 7]
	})
	if str(default_projection.get("host", "")) != ServerRuntimeSettingsProjectionService.DEFAULT_HOST:
		return _failure("Runtime settings projection should fall back to the default host when host is blank.")
	if int(default_projection.get("port", 0)) != ServerRuntimeSettingsProjectionService.DEFAULT_PORT:
		return _failure("Runtime settings projection should fall back to the default port when port is invalid.")
	if bool(default_projection.get("debug_mode", true)):
		return _failure("Runtime settings projection should normalize 'off' into false.")
	if str(default_projection.get("transport_mode", "")) != ServerRuntimeSettingsProjectionService.DEFAULT_TRANSPORT_MODE:
		return _failure("Runtime settings projection should fall back to the default transport mode for unsupported values.")
	if str(default_projection.get("stdio_framing_mode", "")) != ServerRuntimeSettingsProjectionService.DEFAULT_STDIO_FRAMING_MODE:
		return _failure("Runtime settings projection should default stdio framing to newline for unsupported values.")
	var default_disabled_tools: Array = default_projection.get("disabled_tools", [])
	if default_disabled_tools.size() != 2 or str(default_disabled_tools[0]) != "system_project_state" or str(default_disabled_tools[1]) != "7":
		return _failure("Runtime settings projection should trim and preserve non-empty disabled tool names.")

	OS.set_environment(ServerRuntimeSettingsProjectionService.ENV_RUNTIME_SERVER_HOST, "10.0.0.8")
	OS.set_environment(ServerRuntimeSettingsProjectionService.ENV_RUNTIME_SERVER_PORT, "4100")
	OS.set_environment(ServerRuntimeSettingsProjectionService.ENV_RUNTIME_STDIO_FRAMING, "legacy_content_length")
	var env_projection = service.project({
		"host": "127.0.0.1",
		"port": 3000,
		"debug_mode": "on",
		"transport_mode": "both",
		"stdio_framing_mode": "newline",
		"disabled_tools": ["project_state"]
	})
	if str(env_projection.get("host", "")) != "10.0.0.8":
		return _failure("Runtime settings projection should let environment host override the incoming host.")
	if int(env_projection.get("port", 0)) != 4100:
		return _failure("Runtime settings projection should let environment port override the default incoming port.")
	if not bool(env_projection.get("debug_mode", false)):
		return _failure("Runtime settings projection should normalize 'on' into true.")
	if str(env_projection.get("transport_mode", "")) != "both":
		return _failure("Runtime settings projection should preserve supported transport modes.")
	if str(env_projection.get("stdio_framing_mode", "")) != "legacy_content_length":
		return _failure("Runtime settings projection should let environment stdio framing override the default incoming mode.")

	var explicit_port_projection = service.project({
		"host": "127.0.0.1",
		"port": 3001,
		"debug_mode": true,
		"transport_mode": "http",
		"stdio_framing_mode": "legacy_content_length",
		"disabled_tools": []
	})
	if int(explicit_port_projection.get("port", 0)) != 3001:
		return _failure("Runtime settings projection should preserve an explicit non-default settings port over the environment port.")
	if str(explicit_port_projection.get("stdio_framing_mode", "")) != "legacy_content_length":
		return _failure("Runtime settings projection should preserve explicit legacy stdio framing over the environment/default projection.")

	var explicit_float_port_projection = service.project({
		"host": "127.0.0.1",
		"port": 3001.0,
		"debug_mode": true,
		"transport_mode": "http",
		"stdio_framing_mode": "legacy_content_length",
		"disabled_tools": []
	})
	if int(explicit_float_port_projection.get("port", 0)) != 3001:
		return _failure("Runtime settings projection should preserve JSON-loaded float ports over the environment port.")
	var controller_guard := _assert_stdio_transport_controller_guard()
	if not bool(controller_guard.get("success", false)):
		return controller_guard

	return {
		"name": "server_runtime_settings_projection_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"default_host": str(default_projection.get("host", "")),
			"default_port": int(default_projection.get("port", 0)),
			"env_host": str(env_projection.get("host", "")),
			"env_port": int(env_projection.get("port", 0)),
			"explicit_port": int(explicit_port_projection.get("port", 0)),
			"explicit_float_port": int(explicit_float_port_projection.get("port", 0)),
			"stdio_framing_mode": str(env_projection.get("stdio_framing_mode", "")),
			"disabled_tool_count": default_disabled_tools.size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_clear_runtime_environment()


func _clear_runtime_environment() -> void:
	OS.set_environment(ServerRuntimeSettingsProjectionService.ENV_RUNTIME_SERVER_HOST, "")
	OS.set_environment(ServerRuntimeSettingsProjectionService.ENV_RUNTIME_SERVER_PORT, "")
	OS.set_environment(ServerRuntimeSettingsProjectionService.ENV_RUNTIME_STDIO_FRAMING, "")


func _assert_stdio_transport_controller_guard() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_controller.gd")
	if source.find('if transport_mode == "stdio":') == -1:
		return _failure("ServerRuntimeController should special-case stdio transport before starting the HTTP listener.")
	var stdio_branch_pos := source.find('if transport_mode == "stdio":')
	var http_start_pos := source.find('var started = _server.start(operation_id)')
	if stdio_branch_pos == -1 or http_start_pos == -1 or stdio_branch_pos > http_start_pos:
		return _failure("ServerRuntimeController should ensure stdio mode before the HTTP server start call.")
	if source.find('if transport_mode in ["stdio", "both"]') != -1:
		return _failure("ServerRuntimeController should not tie stdio-only startup to the HTTP listener result.")
	if source.find('if _active_transport_mode == "stdio":') == -1 or source.find("return is_stdio_running()") == -1:
		return _failure("ServerRuntimeController.is_running should report stdio server state in stdio-only mode.")
	var attach_pos := source.find("func attach(")
	var reinitialize_pos := source.find("func reinitialize(")
	if attach_pos == -1 or reinitialize_pos == -1 or attach_pos > reinitialize_pos:
		return _failure("ServerRuntimeController source should expose attach before reinitialize for startup guard checks.")
	var attach_body := source.substr(attach_pos, reinitialize_pos - attach_pos)
	if attach_body.find("ensure_server_node(") != -1:
		return _failure("ServerRuntimeController.attach should stay lightweight and defer HTTP server node creation until start/reinitialize.")
	if attach_body.find("_pending_runtime_settings = runtime_settings.duplicate(true)") == -1:
		return _failure("ServerRuntimeController.attach should cache projected runtime settings for deferred startup.")
	if source.find("func set_disabled_tools(disabled_tools: Array) -> void:\n\t_pending_disabled_tools = disabled_tools.duplicate()") == -1:
		return _failure("ServerRuntimeController.set_disabled_tools should preserve pending settings before the server node exists.")
	return {"success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {
		"name": "server_runtime_settings_projection_service_contracts",
		"success": false,
		"error": message
	}
