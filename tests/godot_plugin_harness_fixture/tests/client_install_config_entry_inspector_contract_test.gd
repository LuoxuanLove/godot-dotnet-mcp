extends RefCounted

const ClientInstallConfigEntryInspector = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_config_entry_inspector.gd")


class FakeInspector extends ClientInstallConfigEntryInspector:
	var files: Dictionary = {}
	var directories: Dictionary = {}

	func _file_exists(path: String) -> bool:
		return files.has(normalize_path(path))

	func _read_text_file(file_path: String):
		var normalized = normalize_path(file_path)
		if not files.has(normalized):
			return null
		return files[normalized]

	func _dir_exists(path: String) -> bool:
		return directories.has(normalize_path(path))


func run_case(_tree: SceneTree) -> Dictionary:
	var inspector = FakeInspector.new()
	inspector.files["C:/Users/Test/.cursor/mcp.json"] = "{\"mcpServers\":{\"godot-mcp\":{\"command\":\"godot\"}}}"
	inspector.directories["C:/Users/Test/.cursor"] = true
	inspector.directories["C:/Users/Test"] = true

	var present_result = inspector.inspect_config_entry("C:/Users/Test/.cursor/mcp.json")
	if str(present_result.get("status", "")) != ClientInstallConfigEntryInspector.ENTRY_PRESENT:
		return _failure("Client install config entry inspector should report present when the target server entry exists.")

	inspector.files["C:/Users/Test/.cursor/empty.json"] = "   "
	var empty_result = inspector.inspect_config_entry("C:/Users/Test/.cursor/empty.json")
	if str(empty_result.get("status", "")) != ClientInstallConfigEntryInspector.ENTRY_EMPTY:
		return _failure("Client install config entry inspector should report empty for blank config files.")

	inspector.files["C:/Users/Test/.cursor/invalid.json"] = "{"
	var invalid_result = inspector.inspect_config_entry("C:/Users/Test/.cursor/invalid.json")
	if str(invalid_result.get("status", "")) != ClientInstallConfigEntryInspector.ENTRY_INVALID_JSON:
		return _failure("Client install config entry inspector should report invalid_json for malformed content.")

	inspector.files["C:/Users/Test/.cursor/missing_server.json"] = "{\"mcpServers\":{}}"
	var missing_server_result = inspector.inspect_config_entry("C:/Users/Test/.cursor/missing_server.json")
	if str(missing_server_result.get("status", "")) != ClientInstallConfigEntryInspector.ENTRY_MISSING_SERVER:
		return _failure("Client install config entry inspector should report missing_server when the config file exists but the plugin entry is absent.")

	if not inspector.can_prepare_file_path("C:/Users/Test/.cursor/mcp.json"):
		return _failure("Client install config entry inspector should accept config paths whose ancestor directories already exist.")
	if inspector.can_prepare_file_path("Z:/Nope/StillMissing/config.json"):
		return _failure("Client install config entry inspector should reject config paths without an existing ancestor directory.")

	return {
		"name": "client_install_config_entry_inspector_contracts",
		"success": true,
		"error": "",
		"details": {
			"present_status": str(present_result.get("status", "")),
			"missing_server_status": str(missing_server_result.get("status", "")),
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_install_config_entry_inspector_contracts",
		"success": false,
		"error": message,
	}
