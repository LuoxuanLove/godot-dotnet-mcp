extends RefCounted

const ClientDetectorRegistry = preload("res://addons/godot_dotnet_mcp/plugin/config/client_detector_registry.gd")
const TRAE_CN_FIXTURE := "user://client_detector_registry_appdata/Trae CN/User/mcp.json"


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


class PathResolverWithAppData extends FakePathResolver:
	var _app_data_root := ""

	func _init(app_data_root: String) -> void:
		_app_data_root = app_data_root.replace("\\", "/").strip_edges().trim_suffix("/")

	func get_app_data_root() -> String:
		return _app_data_root


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
	if not bool(results.get("antigravity", {}).get("write_supported", false)):
		return _failure("Antigravity registry detection should expose config write support once its MCP config file path is known.")
	if bool(results.get("antigravity", {}).get("auto_add_supported", false)):
		return _failure("Antigravity registry detection should not expose CLI-style auto add.")
	if str(results.get("antigravity", {}).get("config_path", "")) != "C:/Users/Test/.gemini/config/mcp_config.json":
		return _failure("Antigravity registry detection should expose its Gemini-backed MCP config file path.")
	if str(results.get("antigravity", {}).get("config_entry_status", {}).get("status", "")) != "missing_file":
		return _failure("Antigravity registry detection should inspect its config entry through the shared config-file path.")
	if str(results.get("cursor", {}).get("config_path", "")) != "C:/Users/Test/.cursor/mcp.json":
		return _failure("Client detector registry should resolve Cursor config paths through the configured path resolver.")
	if str(results.get("cline", {}).get("config_path", "")) != "C:/Users/Test/AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json":
		return _failure("Client detector registry should resolve VS Code extension config paths through APPDATA.")
	var trae_cn_absolute := ProjectSettings.globalize_path(TRAE_CN_FIXTURE).replace("\\", "/")
	_ensure_file(TRAE_CN_FIXTURE, "{}")
	var trae_registry = ClientDetectorRegistry.new()
	trae_registry.configure(PathResolverWithAppData.new(trae_cn_absolute.get_slice("/Trae CN/User/", 0)), FakeRuntimeInspector.new(), FakeConfigEntryInspector.new())
	var trae_results = trae_registry.detect_all(PackedStringArray())
	if str(trae_results.get("trae", {}).get("config_path", "")) != trae_cn_absolute:
		return _failure("Trae registry detection should preserve the existing Trae CN config path when resolver-based candidates are available.")
	if not str(results.get("codex_desktop", {}).get("config_path", "")).is_empty():
		return _failure("Client detector registry should not invent a Codex Desktop config path when no production config file is known.")
	if not str(results.get("opencode_desktop", {}).get("config_path", "")).is_empty():
		return _failure("Client detector registry should not invent an OpenCode Desktop config path when no production config file is known.")
	var source = FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/config/client_detector_registry.gd")
	if source.find("C:/Users/Test") != -1:
		return _failure("Client detector registry production source should not contain hard-coded test user paths.")
	var expected_support_levels := {
		"claude_desktop": "full_write",
		"claude_code": "auto_add",
		"cursor": "full_write",
		"trae": "full_write",
		"antigravity": "full_write",
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
		"manual_guidance": ["copy_config", "pick_path"],
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
		var expected_actions: Array = expected_core_actions.get(support_level, []).duplicate()
		if support_level == "manual_guidance":
			expected_actions.append("open_config_dir")
		for expected_action in expected_actions:
			if not actions.has(expected_action):
				return _failure("Client detector registry should expose %s for %s." % [expected_action, client_id])
		if client_id == "antigravity" and (not actions.has("write_config") or not actions.has("open_config_file")):
			return _failure("Antigravity registry capability should expose config-file write and open actions.")
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


func _ensure_file(path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()
