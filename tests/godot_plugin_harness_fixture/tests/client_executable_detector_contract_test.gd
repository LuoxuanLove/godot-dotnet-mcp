extends RefCounted

const ClientExecutableDetector = preload("res://addons/godot_dotnet_mcp/plugin/config/client_executable_detector.gd")


class FakePathResolver extends RefCounted:
	func resolve_executable_path(_client_id: String, _candidates: Array[String], _where_aliases: Array[String], _extra_candidates: Array[String] = []) -> Dictionary:
		return {
			"path": "C:/Tools/codex.exe",
			"detected_via": "where",
			"using_manual_path": false,
			"has_manual_path": true,
			"manual_path_invalid": true,
			"manual_path": "C:/Missing/codex.exe"
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
			"status": "missing_server",
			"has_server_entry": false
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var detector = ClientExecutableDetector.new()
	detector.configure_detector(
		"codex",
		FakePathResolver.new(),
		FakeRuntimeInspector.new(),
		FakeConfigEntryInspector.new(),
		{
			"config_path": "C:/Users/Test/.codex/config.toml",
			"where_aliases": ["codex"],
			"image_names": ["codex.exe"],
			"launch_supported": true,
			"auto_add_supported": true,
			"inspect_config_entry": true
		}
	)

	var result = detector.detect(PackedStringArray())
	if str(result.get("status", "")) != "ready":
		return _failure("Client executable detector should report ready when an executable path is available.")
	if not bool(result.get("auto_add_supported", false)):
		return _failure("Client executable detector should preserve auto_add capability for CLI-managed clients.")
	if not bool(result.get("launch_supported", false)):
		return _failure("Client executable detector should preserve launch capability for launchable CLI clients.")
	if not bool(result.get("path_clear_supported", false)):
		return _failure("Client executable detector should expose path_clear_supported when a manual path exists.")
	if str(result.get("config_entry_status", {}).get("status", "")) != "missing_server":
		return _failure("Client executable detector should optionally inspect config entry state when requested.")

	return {
		"name": "client_executable_detector_contracts",
		"success": true,
		"error": "",
		"details": {
			"status": str(result.get("status", "")),
			"detected_via": str(result.get("detected_via", "")),
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_executable_detector_contracts",
		"success": false,
		"error": message,
	}
