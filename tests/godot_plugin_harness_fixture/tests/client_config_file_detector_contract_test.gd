extends RefCounted

const ClientConfigFileDetector = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_file_detector.gd")


class FakePathResolver extends RefCounted:
	var result := {
		"path": "C:/Programs/Cursor/Cursor.exe",
		"detected_via": "common_path",
		"using_manual_path": false,
		"has_manual_path": false,
		"manual_path_invalid": false,
		"manual_path": ""
	}

	func resolve_executable_path(_client_id: String, _candidates: Array[String], _where_aliases: Array[String], _extra_candidates: Array[String] = []) -> Dictionary:
		return result.duplicate(true)


class FakeRuntimeInspector extends RefCounted:
	func build_runtime_state(_executable_path: String, _image_names: Array[String], _running_processes: PackedStringArray) -> Dictionary:
		return {
			"status": "running",
			"is_running": true
		}


class FakeConfigEntryInspector extends RefCounted:
	func inspect_config_entry(_config_path: String, _config_type: String = "") -> Dictionary:
		return {
			"status": "present",
			"has_server_entry": true
		}

	func can_prepare_file_path(_file_path: String) -> bool:
		return true


func run_case(_tree: SceneTree) -> Dictionary:
	var detector = ClientConfigFileDetector.new()
	detector.configure_detector(
		"cursor",
		FakePathResolver.new(),
		FakeRuntimeInspector.new(),
		FakeConfigEntryInspector.new(),
		{
			"config_path": "C:/Users/Test/.cursor/mcp.json",
			"candidates": [],
			"where_aliases": ["cursor"],
			"image_names": ["cursor.exe"],
			"launch_supported": true
		}
	)

	var result = detector.detect(PackedStringArray())
	if str(result.get("status", "")) != "ready":
		return _failure("Client config file detector should report ready when executable and config path are both available.")
	if not bool(result.get("write_supported", false)):
		return _failure("Client config file detector should mark config-based clients as write_supported when config path is available.")
	if not bool(result.get("launch_supported", false)):
		return _failure("Client config file detector should preserve launch capability for launchable desktop clients.")
	if str(result.get("config_entry_status", {}).get("status", "")) != "present":
		return _failure("Client config file detector should propagate config entry inspection results.")

	return {
		"name": "client_config_file_detector_contracts",
		"success": true,
		"error": "",
		"details": {
			"status": str(result.get("status", "")),
			"config_path": str(result.get("config_path", "")),
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_config_file_detector_contracts",
		"success": false,
		"error": message,
	}
