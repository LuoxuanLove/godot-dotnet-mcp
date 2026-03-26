@tool
extends RefCounted
class_name ClientConfigService

const ClientConfigSerializerScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_serializer.gd")
const ClientConfigFileTransactionScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_file_transaction.gd")
const ClientConfigLauncherAdapterScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_launcher_adapter.gd")
const MCP_SERVER_KEY := "godot-mcp"

var _serializer = ClientConfigSerializerScript.new()
var _file_transaction = ClientConfigFileTransactionScript.new()
var _launcher_adapter = ClientConfigLauncherAdapterScript.new()


func _init() -> void:
	_file_transaction.configure(_serializer)


func get_claude_config_path() -> String:
	return _serializer.get_claude_config_path()


func get_cursor_config_path() -> String:
	return _serializer.get_cursor_config_path()


func get_trae_config_path() -> String:
	return _serializer.get_trae_config_path()


func get_gemini_config_path() -> String:
	return _serializer.get_gemini_config_path()


func get_codex_config_path() -> String:
	return _serializer.get_codex_config_path()


func get_opencode_config_path() -> String:
	return _serializer.get_opencode_config_path()


func get_url_config(host: String, port: int) -> String:
	return _serializer.get_url_config(host, port)


func get_http_url_config(host: String, port: int) -> String:
	return _serializer.get_http_url_config(host, port)


func get_command_config(command: String, args: Array) -> String:
	return _serializer.get_command_config(command, args)


func get_opencode_local_config(command: String, args: Array) -> String:
	return _serializer.get_opencode_local_config(command, args)


func get_opencode_remote_config(host: String, port: int) -> String:
	return _serializer.get_opencode_remote_config(host, port)


func get_claude_code_command(scope: String, host: String, port: int) -> String:
	return _serializer.get_claude_code_command(scope, host, port)


func get_codex_command(host: String, port: int) -> String:
	return _serializer.get_codex_command(host, port)


func get_claude_code_stdio_command(scope: String, command: String, args: Array) -> String:
	return _serializer.get_claude_code_stdio_command(scope, command, args)


func get_codex_stdio_command(command: String, args: Array) -> String:
	return _serializer.get_codex_stdio_command(command, args)


func preflight_write_config(config_type: String, filepath: String, new_config: String) -> Dictionary:
	return _file_transaction.preflight_write_config(config_type, filepath, new_config)


func write_config_file(config_type: String, filepath: String, new_config: String, options: Dictionary = {}) -> Dictionary:
	return _file_transaction.write_config_file(config_type, filepath, new_config, options)


func inspect_config_entry(config_type: String, filepath: String, server_name: String = MCP_SERVER_KEY) -> Dictionary:
	return _file_transaction.inspect_config_entry(config_type, filepath, server_name)


func remove_config_entry(
	config_type: String,
	filepath: String,
	options: Dictionary = {},
	server_name: String = MCP_SERVER_KEY
) -> Dictionary:
	return _file_transaction.remove_config_entry(config_type, filepath, options, server_name)


func execute_cli_command(executable_path: String, arguments: PackedStringArray) -> Dictionary:
	return _launcher_adapter.execute_cli_command(executable_path, arguments)


func launch_desktop_client(executable_path: String, arguments: PackedStringArray, working_directory: String) -> Dictionary:
	return _launcher_adapter.launch_desktop_client(executable_path, arguments, working_directory)


func launch_cli_client_in_terminal(executable_path: String, arguments: PackedStringArray, working_directory: String) -> Dictionary:
	return _launcher_adapter.launch_cli_client_in_terminal(executable_path, arguments, working_directory)


func open_target_path(target_path: String) -> Dictionary:
	return _launcher_adapter.open_target_path(target_path)


func open_text_file(target_path: String) -> Dictionary:
	return _launcher_adapter.open_text_file(target_path)
