extends RefCounted

# {"name": "system_project_executor_contracts"}

const SystemProjectExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")


class FakeBridge extends RefCounted:
	var _tool_loader
	var scene_run_actions: Array[String] = []

	func _init(tool_loader = null) -> void:
		_tool_loader = tool_loader

	func get_tool_loader():
		return _tool_loader

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
			"editor_status":
				if str(args.get("action", "")) == "get_godot_path":
					return success({
						"godot_executable_path": "C:/Godot/Godot.exe",
						"project_root_path": "E:/Project/LuoxuanLove/Mechoes"
					})
				return error("Unsupported editor_status action")
			"project_info":
				if str(args.get("action", "")) == "get_info":
					return success({
						"name": "ContractProject",
						"description": "Future-only system project contracts",
						"version": "1.0.0",
						"project_path": "res://",
						"godot_version": "4.6",
						"godot_version_string": "4.6.stable",
						"main_scene": "res://tests/project_contract_fixture/Main.tscn"
					})
				if str(args.get("action", "")) == "get_settings":
					return success({"value": "contract-value"})
				return error("Unsupported project_info action")
			"project_dotnet":
				return success({"count": 1, "projects": [{"name": "ContractProject"}]})
			"debug_runtime_bridge":
				match str(args.get("action", "")):
					"get_summary":
						return success({"bridge_status": "ready", "session_count": 1, "sessions": {"a": {"state": "running"}}, "error_count": 1, "warning_count": 0})
					"get_errors_context":
						return success({"errors": [{"message": "Boom", "script": "res://Player.gd", "line": 5, "stacktrace": []}]})
					"get_recent_filtered":
						return success({"events": []})
					"get_scene_snapshot":
						return success({"current_scene": "res://tests/project_contract_fixture/Main.tscn"})
					_:
						return error("Unsupported debug_runtime_bridge action")
			"debug_dotnet":
				return success({"error_count": 1, "errors": [{"severity": "error", "message": "CS1001", "source_file": "Player.cs", "source_line": 3}]})
			"debug_performance":
				return success({"value": 60})
			"debug_editor_log":
				return success({"error_count": 0, "errors": []})
			"scene_run":
				scene_run_actions.append(str(args.get("action", "")))
				return success({"action": str(args.get("action", "")), "path": str(args.get("path", ""))}, "ok")
			"project_settings":
				return success({"applied": true})
			"project_autoload":
				return success({"count": 0, "entries": []})
			"project_input":
				return success({"count": 0, "actions": []})
			"filesystem_directory":
				match str(args.get("action", "")):
					"get_files":
						return success({"files": ["res://Player.gd"], "count": 1})
					"create", "delete":
						return success({"path": str(args.get("path", ""))})
					_:
						return error("Unsupported filesystem_directory action")
			"filesystem_file_read":
				return success({"path": str(args.get("path", "")), "content": "ok"})
			"filesystem_file_write":
				return success({"path": str(args.get("path", "")), "written": true})
			"filesystem_file_manage":
				return success({"action": str(args.get("action", "")), "path": str(args.get("path", ""))})
			"editor_filesystem":
				match str(args.get("action", "")):
					"select_file":
						return success({"path": str(args.get("path", ""))})
					"get_selected":
						return success({"paths": ["res://Player.gd"], "count": 1})
					"get_current_path":
						return success({"current_path": "res://Player.gd", "current_directory": "res://"})
					"scan", "reimport":
						return success({"ok": true})
					_:
						return error("Unsupported editor_filesystem action")
			_:
				return error("Unsupported fake bridge call: %s" % tool_name)

	func collect_files(pattern: String) -> Array:
		match pattern:
			"*.gd":
				return ["res://Player.gd"]
			"*.cs":
				return ["res://Player.cs"]
			"*.tscn":
				return ["res://tests/project_contract_fixture/Main.tscn"]
			"*.tres", "*.res":
				return ["res://mat/test.tres"]
			_:
				return []

	func extract_data(result: Dictionary) -> Dictionary:
		var data = result.get("data", {})
		return (data as Dictionary).duplicate(true) if data is Dictionary else {}

	func extract_array(result: Dictionary, key: String) -> Array:
		var data = result.get("data", {})
		if data is Dictionary:
			var value = (data as Dictionary).get(key, [])
			return (value as Array).duplicate(true) if value is Array else []
		return []

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message, "data": data}


class FakeFailingRunBridge extends FakeBridge:
	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		if tool_name == "scene_run":
			scene_run_actions.append(str(args.get("action", "")))
			return error("Editor interface not available")
		return super.call_atomic(tool_name, args)


class FakeToolLoader extends RefCounted:
	func get_gdscript_lsp_diagnostics_service():
		return null

	func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
		return {"service_available": false, "service": {"status": {"state": "idle"}}}

	func get_tool_loader_status() -> Dictionary:
		return {"status": "ready", "tool_count": 115, "exposed_tool_count": 18, "last_error": ""}


func run_case(_tree: SceneTree) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	PluginSelfDiagnosticStore.record_incident(
		"warning",
		"contract_warning",
		"project_state_contract_incident",
		"Contract incident",
		"system_project_executor_contract_test"
	)

	var executor = SystemProjectExecutorScript.new()
	executor.bridge = FakeBridge.new(FakeToolLoader.new())
	executor.configure_runtime({})

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 8:
		return _failure("System project implementation should expose 8 tool definitions including project_files and userdata_maintenance.")
	if not _has_tool(tool_defs, "userdata_maintenance"):
		return _failure("System project implementation should expose userdata_maintenance for manual cache cleanup.")
	if not _has_tool(tool_defs, "project_files"):
		return _failure("System project implementation should expose project_files for high-level FileSystem tree changes.")

	var project_state: Dictionary = executor.execute("project_state", {
		"error_limit": 5,
		"include_runtime_health": true
	})
	if not bool(project_state.get("success", false)):
		return _failure("project_state did not succeed through the split system project executor.")
	var project_state_data = project_state.get("data", {})
	if not (project_state_data is Dictionary):
		return _failure("project_state did not return a dictionary payload.")
	if int((project_state_data as Dictionary).get("compile_error_count", 0)) != 1:
		return _failure("project_state did not preserve compile_error_count through the split services.")
	var runtime_health = (project_state_data as Dictionary).get("runtime_health", {})
	if not (runtime_health is Dictionary):
		return _failure("project_state include_runtime_health did not return runtime_health.")
	var runtime_health_dict: Dictionary = runtime_health
	var self_diagnostics = runtime_health_dict.get("self_diagnostics", {})
	if not (self_diagnostics is Dictionary):
		return _failure("project_state runtime_health.self_diagnostics did not return a dictionary payload.")
	var tool_loader_health = runtime_health_dict.get("tool_loader", {})
	if not (tool_loader_health is Dictionary):
		return _failure("project_state runtime_health.tool_loader did not return a dictionary payload.")
	var runtime_capabilities = (project_state_data as Dictionary).get("runtime_capabilities", {})
	if not (runtime_capabilities is Dictionary):
		return _failure("project_state should return runtime_capabilities.")
	if not (runtime_health_dict.get("capabilities", {}) is Dictionary):
		return _failure("project_state runtime_health should include capability bits.")
	if not bool((runtime_capabilities as Dictionary).get("editor_interface_available", false)):
		return _failure("runtime_capabilities should report editor_interface_available when editor status is available.")
	if bool((runtime_capabilities as Dictionary).get("can_start_project", true)):
		return _failure("runtime_capabilities should block can_start_project when compile errors are present.")
	if not ((runtime_capabilities as Dictionary).get("blocking_reasons", []) as Array).has("compile_errors_present"):
		return _failure("runtime_capabilities should include compile_errors_present as a blocking reason.")

	var layout_result: Dictionary = executor.execute("userdata_maintenance", {"action": "ensure_layout"})
	if not bool(layout_result.get("success", false)):
		return _failure("userdata_maintenance ensure_layout should succeed.")
	var cleanup_preview: Dictionary = executor.execute("userdata_maintenance", {"action": "cleanup_legacy_cache"})
	if not bool(cleanup_preview.get("success", false)):
		return _failure("userdata_maintenance cleanup_legacy_cache dry-run should succeed.")
	if not bool(cleanup_preview.get("data", {}).get("dry_run", false)):
		return _failure("userdata_maintenance cleanup_legacy_cache should default to dry_run=true.")
	_create_user_file(MCPUserDataPaths.EDITOR_CAPTURE_DIR + "/contract_editor.png", "editor")
	_create_user_file(MCPUserDataPaths.EDITOR_CONTROL_CAPTURE_DIR + "/contract_control.png", "control")
	_create_user_file(MCPUserDataPaths.RUNTIME_CAPTURE_ROOT + "/contract_session/frame.png", "runtime")
	var capture_list: Dictionary = executor.execute("userdata_maintenance", {"action": "list_capture_cache"})
	if not bool(capture_list.get("success", false)):
		return _failure("userdata_maintenance list_capture_cache should succeed.")
	if int(capture_list.get("data", {}).get("file_count", 0)) < 3:
		return _failure("userdata_maintenance list_capture_cache should include managed editor/control/runtime captures.")
	var capture_cleanup_preview: Dictionary = executor.execute("userdata_maintenance", {"action": "cleanup_capture_cache"})
	if not bool(capture_cleanup_preview.get("success", false)) or not bool(capture_cleanup_preview.get("data", {}).get("dry_run", false)):
		return _failure("userdata_maintenance cleanup_capture_cache should default to dry_run=true.")
	if not FileAccess.file_exists(MCPUserDataPaths.EDITOR_CAPTURE_DIR + "/contract_editor.png"):
		return _failure("userdata_maintenance cleanup_capture_cache dry-run should not delete captures.")
	var capture_cleanup_apply: Dictionary = executor.execute("userdata_maintenance", {"action": "cleanup_capture_cache", "dry_run": false})
	if not bool(capture_cleanup_apply.get("success", false)):
		return _failure("userdata_maintenance cleanup_capture_cache should apply when dry_run=false.")
	if FileAccess.file_exists(MCPUserDataPaths.EDITOR_CAPTURE_DIR + "/contract_editor.png"):
		return _failure("userdata_maintenance cleanup_capture_cache should remove managed capture files when applied.")

	var invalid_configure: Dictionary = executor.execute("project_configure", {"action": "bogus"})
	if bool(invalid_configure.get("success", false)):
		return _failure("project_configure bogus action should fail.")

	var project_files_list: Dictionary = executor.execute("project_files", {"action": "list_dir", "path": "res://", "filter": "*.gd"})
	if not bool(project_files_list.get("success", false)):
		return _failure("project_files list_dir should delegate to the filesystem directory atomic tool.")
	var project_files_write: Dictionary = executor.execute("project_files", {"action": "write_file", "path": "res://notes.txt", "content": "ok"})
	if not bool(project_files_write.get("success", false)):
		return _failure("project_files write_file should delegate to the filesystem write atomic tool.")
	var project_files_select: Dictionary = executor.execute("project_files", {"action": "select_file", "path": "res://Player.gd"})
	if not bool(project_files_select.get("success", false)):
		return _failure("project_files select_file should delegate to the editor filesystem atomic tool.")

	var project_run: Dictionary = executor.execute("project_run", {})
	if not bool(project_run.get("success", false)):
		return _failure("project_run did not succeed through the split runtime service.")
	var timed_project_run: Dictionary = executor.execute("project_run", {"timeout_ms": 1})
	if not bool(timed_project_run.get("success", false)):
		return _failure("project_run with timeout_ms did not succeed.")
	await (Engine.get_main_loop() as SceneTree).create_timer(0.05).timeout
	if executor.bridge.scene_run_actions.size() < 3:
		return _failure("project_run timeout should trigger an automatic stop after the run starts.")
	if executor.bridge.scene_run_actions[1] != "play_main" or executor.bridge.scene_run_actions[2] != "stop":
		return _failure("project_run timeout should emit play_main followed by stop.")

	var failing_run_executor = SystemProjectExecutorScript.new()
	failing_run_executor.bridge = FakeFailingRunBridge.new(FakeToolLoader.new())
	failing_run_executor.configure_runtime({})
	var failing_run: Dictionary = failing_run_executor.execute("project_run", {"scene": "res://Missing.tscn"})
	if bool(failing_run.get("success", false)):
		return _failure("project_run should fail when the scene_run atomic tool fails.")
	var failing_run_data = failing_run.get("data", {})
	if not (failing_run_data is Dictionary):
		return _failure("project_run failure should return structured data.")
	if str((failing_run_data as Dictionary).get("error_code", "")) != "project_run_failed":
		return _failure("project_run failure should include project_run_failed error_code.")
	if not ((failing_run_data as Dictionary).get("runtime_capabilities", {}) is Dictionary):
		return _failure("project_run failure should include runtime capability context.")
	if not ((failing_run_data as Dictionary).get("runtime_control_status", {}) is Dictionary):
		return _failure("project_run failure should include runtime_control_status.")

	var runtime_diagnose: Dictionary = executor.execute("runtime_diagnose", {
		"include_compile_errors": true,
		"include_performance": true
	})
	if not bool(runtime_diagnose.get("success", false)):
		return _failure("runtime_diagnose did not succeed through the split runtime service.")
	var runtime_diagnose_data = runtime_diagnose.get("data", {})
	if not (runtime_diagnose_data is Dictionary) or int((runtime_diagnose_data as Dictionary).get("compile_error_count", 0)) != 1:
		return _failure("runtime_diagnose did not preserve compile_error_count through the split runtime service.")

	return {
		"name": "system_project_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"runtime_status": str((tool_loader_health as Dictionary).get("status", "")),
			"error_count": int((project_state_data as Dictionary).get("error_count", 0))
		}
	}


func _has_tool(tool_defs: Array[Dictionary], name: String) -> bool:
	for tool_def in tool_defs:
		if str(tool_def.get("name", "")) == name:
			return true
	return false


func cleanup_case(_tree: SceneTree) -> void:
	PluginSelfDiagnosticStore.clear()
	MCPUserDataPaths.cleanup_capture_cache(false)


func _create_user_file(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_project_executor_contracts",
		"success": false,
		"error": message
	}
