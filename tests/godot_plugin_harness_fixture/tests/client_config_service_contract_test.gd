extends RefCounted

# {"name": "client_config_service_contracts"}

const ClientConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ClientConfigServiceScript.new()

	var truncated := str(service.call("_limit_cli_output", "A".repeat(70 * 1024)))
	if str(truncated).length() >= 70 * 1024:
		return _failure("Client config service should cap captured CLI output.")
	if not str(truncated).contains("output truncated after"):
		return _failure("Client config service should explain when CLI output is truncated.")

	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")
	for required in [
		"CLI_COMMAND_TIMEOUT_MSEC",
		"CLI_COMMAND_OUTPUT_LIMIT_BYTES",
		"OS.kill(pid)",
		"timed_out",
		"_limit_cli_output"
	]:
		if source.find(required) == -1:
			return _failure("Client config service process guard missing required marker: %s" % required)
	if source.find("while OS.is_process_running(pid):") == -1:
		return _failure("Client config service should keep polling spawned CLI processes explicitly.")
	if source.find("elapsed_msec >= max(timeout_msec, 1)") == -1:
		return _failure("Client config service should bound spawned CLI process waits with a timeout.")

	return {
		"name": "client_config_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"truncated_length": str(truncated).length()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_config_service_contracts",
		"success": false,
		"error": message
	}
