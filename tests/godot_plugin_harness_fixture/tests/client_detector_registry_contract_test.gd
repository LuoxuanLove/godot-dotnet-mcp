extends RefCounted

const ClientDetectorRegistry = preload("res://addons/godot_dotnet_mcp/plugin/config/client_detector_registry.gd")


class FakePathResolver extends RefCounted:
	func get_home_root() -> String:
		return "C:/Users/Test"

	func get_app_data_root() -> String:
		return "C:/Users/Test/AppData/Roaming"

	func get_local_app_data_root() -> String:
		return "C:/Users/Test/AppData/Local"

	func get_program_files_root() -> String:
		return "C:/Program Files"

	func get_secondary_program_files_root() -> String:
		return "E:/Program Files"

	func collect_appx_package_candidates(_package_name: String, _relative_paths: Array[String]) -> Array[String]:
		return []

	func resolve_executable_path(client_id: String, _candidates: Array[String], _where_aliases: Array[String], _extra_candidates: Array[String] = []) -> Dictionary:
		var executable_path = ""
		if client_id == "codex":
			executable_path = "C:/Tools/codex.exe"
		elif client_id == "cursor":
			executable_path = "C:/Programs/Cursor/Cursor.exe"
		return {
			"path": executable_path,
			"detected_via": "fake",
			"using_manual_path": false,
			"has_manual_path": false,
			"manual_path_invalid": false,
			"manual_path": ""
		}


class FakeRuntimeInspector extends RefCounted:
	func build_runtime_state(_executable_path: String, _image_names: Array[String], _running_processes: PackedStringArray) -> Dictionary:
		return {
			"status": "not_running",
			"is_running": false
		}


class FakeConfigEntryInspector extends RefCounted:
	func inspect_config_entry(_config_path: String, _config_type: String = "") -> Dictionary:
		return {
			"status": "missing_file",
			"has_server_entry": false
		}

	func can_prepare_file_path(_file_path: String) -> bool:
		return true


func run_case(_tree: SceneTree) -> Dictionary:
	var registry = ClientDetectorRegistry.new()
	registry.configure(FakePathResolver.new(), FakeRuntimeInspector.new(), FakeConfigEntryInspector.new())

	var results = registry.detect_all(PackedStringArray())
	var supported_ids = registry.get_supported_client_ids()
	if supported_ids.size() != 8:
		return _failure("Client detector registry should register the full supported client set.")
	if not results.has("cursor") or not results.has("codex") or not results.has("opencode"):
		return _failure("Client detector registry should expose all client ids through detect_all.")
	if str(results.get("cursor", {}).get("status", "")) != "ready":
		return _failure("Client detector registry should delegate config-file clients to the config detector path.")
	if not bool(results.get("codex", {}).get("auto_add_supported", false)):
		return _failure("Client detector registry should delegate CLI-managed clients to the executable detector path.")

	return {
		"name": "client_detector_registry_contracts",
		"success": true,
		"error": "",
		"details": {
			"supported_count": supported_ids.size(),
			"cursor_status": str(results.get("cursor", {}).get("status", "")),
			"codex_status": str(results.get("codex", {}).get("status", "")),
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_detector_registry_contracts",
		"success": false,
		"error": message,
	}
