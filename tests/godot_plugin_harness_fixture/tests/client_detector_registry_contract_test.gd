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
		if client_id == "codex" or client_id == "gemini" or client_id == "qwen":
			executable_path = "C:/Tools/codex.exe"
		elif client_id == "cursor":
			executable_path = "C:/Programs/Cursor/Cursor.exe"
		elif client_id == "antigravity":
			executable_path = "C:/Programs/Antigravity/Antigravity.exe"
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
	if supported_ids.size() != 15:
		return _failure("Client detector registry should register the full supported client set.")
	if not results.has("cursor") or not results.has("antigravity") or not results.has("codex") or not results.has("opencode") or not results.has("windsurf") or not results.has("qwen") or not results.has("cherry_studio"):
		return _failure("Client detector registry should expose all client ids through detect_all.")
	if str(results.get("cursor", {}).get("status", "")) != "ready":
		return _failure("Client detector registry should delegate config-file clients to the config detector path.")
	if not bool(results.get("codex", {}).get("auto_add_supported", false)):
		return _failure("Client detector registry should delegate CLI-managed clients to the executable detector path.")
	if not bool(results.get("opencode", {}).get("write_supported", false)):
		return _failure("Client detector registry should expose config-write support for OpenCode CLI.")
	if bool(results.get("antigravity", {}).get("write_supported", false)):
		return _failure("Antigravity registry detection should stay manual guidance until a documented config file contract exists.")
	if bool(results.get("antigravity", {}).get("auto_add_supported", false)):
		return _failure("Antigravity registry detection should not expose CLI-style auto add.")
	if str(results.get("antigravity", {}).get("config_entry_status", {}).get("status", "")) != "deferred":
		return _failure("Antigravity registry detection should mark config entry inspection as deferred.")
	var expected_support_levels := {
		"claude_desktop": "full_write",
		"claude_code": "auto_add",
		"cursor": "full_write",
		"trae": "full_write",
		"antigravity": "manual_guidance",
		"codex_desktop": "launch_path",
		"codex": "auto_add",
		"gemini": "auto_add",
		"opencode_desktop": "manual_guidance",
		"opencode": "full_write",
		"windsurf": "full_write",
		"cline": "full_write",
		"roo_code": "full_write",
		"qwen": "auto_add",
		"cherry_studio": "manual_guidance"
	}
	var expected_core_actions := {
		"full_write": ["write_config", "remove_config", "copy_config", "pick_path"],
		"auto_add": ["auto_add", "remove_config", "copy_config", "open_terminal", "pick_path"],
		"manual_guidance": ["open_config_dir", "copy_config", "pick_path"],
		"launch_path": ["copy_config", "pick_path"]
	}
	for client_id in supported_ids:
		var capability: Dictionary = results.get(client_id, {}).get("capability", {})
		if capability.is_empty():
			return _failure("Client detector registry should expose a capability matrix for %s." % client_id)
		var support_level := str(capability.get("support_level", ""))
		if support_level != str(expected_support_levels.get(client_id, "")):
			return _failure("Client detector registry should expose the expected support_level for %s." % client_id)
		if str(capability.get("kind", "")) != support_level:
			return _failure("Client detector registry should keep capability.kind compatible with support_level for %s." % client_id)
		var actions: Variant = capability.get("actions", [])
		if not (actions is Array) or actions.is_empty():
			return _failure("Client detector registry should expose supported actions for %s." % client_id)
		for expected_action in expected_core_actions.get(support_level, []):
			if not actions.has(expected_action):
				return _failure("Client detector registry should expose %s for %s." % [expected_action, client_id])
		if actions.has("clear_path"):
			return _failure("Client detector registry should not expose clear_path before runtime manual-path detection for %s." % client_id)
		var notes: Variant = capability.get("notes", [])
		if not (notes is Array) or notes.is_empty():
			return _failure("Client detector registry should expose capability notes for %s." % client_id)

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
