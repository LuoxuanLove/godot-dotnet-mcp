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


func _failure(message: String) -> Dictionary:
	return {
		"name": "server_runtime_settings_projection_service_contracts",
		"success": false,
		"error": message
	}
