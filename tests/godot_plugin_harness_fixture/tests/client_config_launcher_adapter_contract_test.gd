extends RefCounted

const ClientConfigLauncherAdapterScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_launcher_adapter.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var adapter = ClientConfigLauncherAdapterScript.new()

	var cmd_invocation: Dictionary = adapter.build_cli_invocation("sample.cmd", PackedStringArray(["one", "two"]))
	if str(cmd_invocation.get("command", "")) != "cmd.exe":
		return _failure("CMD launchers should be wrapped with cmd.exe.")
	var cmd_args: PackedStringArray = cmd_invocation.get("arguments", PackedStringArray())
	if cmd_args.size() != 4 or cmd_args[0] != "/c" or cmd_args[1] != "sample.cmd":
		return _failure("CMD invocation should preserve /c and the original script path.")

	var exe_invocation: Dictionary = adapter.build_cli_invocation("sample.exe", PackedStringArray(["one"]))
	if str(exe_invocation.get("command", "")) != "sample.exe":
		return _failure("EXE launchers should not be wrapped with cmd.exe.")

	var windows_command_line := adapter.build_windows_cli_command_line("sample.bat", PackedStringArray(["arg one", "arg-two"]))
	if not windows_command_line.begins_with("call "):
		return _failure("BAT command lines should start with call.")
	if windows_command_line.find("\"arg one\"") == -1:
		return _failure("Windows CLI command lines should quote spaced arguments.")

	return {
		"name": "client_config_launcher_adapter_contracts",
		"success": true,
		"error": "",
		"details": {
			"cmd_argument_count": cmd_args.size(),
			"exe_command": str(exe_invocation.get("command", "")),
			"windows_command_line": windows_command_line
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_config_launcher_adapter_contracts",
		"success": false,
		"error": message
	}
