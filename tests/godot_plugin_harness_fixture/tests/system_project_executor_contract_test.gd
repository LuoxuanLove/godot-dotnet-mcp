extends RefCounted

# {"name": "system_project_executor_contracts"}

const SystemProjectExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd")
const DebugToolsScript = preload("res://addons/godot_dotnet_mcp/tools/debug_tools.gd")
const AtomicBridgeScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const MCPRuntimeDebugStoreShared = preload("res://addons/godot_dotnet_mcp/tools/shared/mcp_runtime_debug_store.gd")
const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")
const TEMP_ROOT := "res://tests_tmp/system_project_executor_contracts"


class FakeBridge extends RefCounted:
	var _tool_loader
	var scene_run_actions: Array[String] = []
	var runtime_events: Array = []
	var runtime_events_after_start: Array = []
	var collect_files_calls := 0
	var collect_file_count_calls := 0
	var collect_file_counts_calls := 0
	var atomic_bridge = AtomicBridgeScript.new()

	func _init(tool_loader = null) -> void:
		_tool_loader = tool_loader

	func get_tool_loader():
		return _tool_loader

	func call_atomic(tool_name: String, args: Dictionary = {}) -> Dictionary:
		match tool_name:
			"editor_status":
				if str(args.get("action", "")) == "get_godot_path":
					return success({
						"godot_executable_path": "C:/Godot/Godot.exe",
						"project_root_path": "C:/GodotProjects/ContractProject",
						"editor_session_identity": {
							"session_id": "project-contract-session",
							"identity_scope": "current_editor_process",
							"process_owner": "godot_dotnet_mcp_editor",
							"external_validation_process": false,
							"safe_to_terminate": false,
							"pid": 5252,
							"cmdline_args": ["--path", "C:/GodotProjects/ContractProject"],
							"headless": false
						}
					})
				return error("Unsupported editor_status action")
			"project_info":
				if str(args.get("action", "")) == "get_info":
					return success({
						"name": "ContractProject",
						"description": "Future-only system project contracts",
						"version": "1.0.1",
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
					"get_recent":
						var recent_events := _tail_runtime_events(int(args.get("limit", 50)))
						return success({"bridge_status": "ready", "count": recent_events.size(), "events": recent_events})
					"get_since_event_id":
						var cursor_events := _runtime_events_after_event_id(int(args.get("after_event_id", -1)), int(args.get("limit", 50)))
						return success({"bridge_status": "ready", "count": cursor_events.size(), "events": cursor_events})
					"get_recent_filtered":
						var filtered_events := _tail_runtime_events(int(args.get("tail", args.get("limit", 50))))
						return success({"bridge_status": "ready", "count": filtered_events.size(), "events": filtered_events})
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
			"resource_query":
				if str(args.get("path", "")).ends_with(".tscn"):
					return success({"dependencies": []})
				return success({"dependencies": ["uid://missing_project_contract::::res://tests_tmp/system_project_executor_contracts/MissingResource.cs"]})
			"script_inspect":
				return success({"language": "csharp", "class_name": "WrongResourceName", "base_type": "Node"})
			"scene_run":
				var scene_action := str(args.get("action", ""))
				scene_run_actions.append(scene_action)
				if scene_action in ["play_main", "play_custom"] and not runtime_events_after_start.is_empty():
					runtime_events.append_array(runtime_events_after_start)
					runtime_events_after_start.clear()
				return success({"action": scene_action, "path": str(args.get("path", ""))}, "ok")
			"project_settings":
				return success({"applied": true})
			"project_autoload":
				return success({"count": 0, "entries": []})
			"project_input":
				if str(args.get("action", "")) == "get_action":
					return success({
						"name": str(args.get("name", "")),
						"deadzone": 0.5,
						"events": [
							{"type": "InputEventKey", "key_name": "Space"}
						]
					})
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
					"scan":
						return success({"ok": true})
					"reimport":
						for path in args.get("paths", []):
							if str(path) == "res://project.godot":
								return error("Path is not importable: res://project.godot", {
									"error_code": "not_importable_resource",
									"error_type": "not_importable_resource",
									"path": "res://project.godot",
									"reason": "project_settings_file"
								})
						return success({"ok": true})
					_:
						return error("Unsupported editor_filesystem action")
			_:
				return error("Unsupported fake bridge call: %s" % tool_name)

	func collect_files(pattern: String) -> Array:
		collect_files_calls += 1
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

	func collect_file_count(pattern: String) -> int:
		collect_file_count_calls += 1
		match pattern:
			"*.gd", "*.cs", "*.tscn", "*.tres", "*.res":
				return 1
			_:
				return 0

	func collect_file_counts(patterns: Array) -> Dictionary:
		collect_file_counts_calls += 1
		var counts := {}
		for pattern in patterns:
			var pattern_text := str(pattern)
			counts[pattern_text] = collect_file_count(pattern_text)
		return counts

	func reset_collection_counters() -> void:
		collect_files_calls = 0
		collect_file_count_calls = 0
		collect_file_counts_calls = 0

	func _tail_runtime_events(limit: int) -> Array:
		var resolved_limit: int = max(limit, 0)
		if resolved_limit == 0:
			return []
		if runtime_events.size() <= resolved_limit:
			return runtime_events.duplicate(true)
		return runtime_events.slice(runtime_events.size() - resolved_limit)

	func _runtime_events_after_event_id(after_event_id: int, limit: int) -> Array:
		var resolved_limit: int = max(limit, 0)
		var events: Array = []
		if resolved_limit == 0:
			return events
		for event in runtime_events:
			if not (event is Dictionary):
				continue
			if int((event as Dictionary).get("event_id", -1)) <= after_event_id:
				continue
			events.append((event as Dictionary).duplicate(true))
			if events.size() >= resolved_limit:
				break
		return events

	func extract_data(result: Dictionary) -> Dictionary:
		var data = result.get("data", {})
		return (data as Dictionary).duplicate(true) if data is Dictionary else {}

	func extract_array(result: Dictionary, key: String) -> Array:
		var data = result.get("data", {})
		if data is Dictionary:
			var value = (data as Dictionary).get(key, [])
			return (value as Array).duplicate(true) if value is Array else []
		return []

	func parse_dependency_reference(raw_path: String, source_path: String = "") -> Dictionary:
		return atomic_bridge.parse_dependency_reference(raw_path, source_path)

	func build_issue(severity: String, issue_type: String, message: String, extra: Dictionary = {}) -> Dictionary:
		return atomic_bridge.build_issue(severity, issue_type, message, extra)

	func append_unique_issue(issues: Array, issue: Dictionary) -> void:
		atomic_bridge.append_unique_issue(issues, issue)

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": "bridge_error", "message": message, "data": data}


class FakeFailingRunBridge extends FakeBridge:
	func call_atomic(tool_name: String, args: Dictionary = {}) -> Dictionary:
		if tool_name == "scene_run":
			scene_run_actions.append(str(args.get("action", "")))
			return error("Editor interface not available")
		return super.call_atomic(tool_name, args)


class FakeEmptyCollectBridge extends FakeBridge:
	func collect_files(_pattern: String) -> Array:
		return []


class FakeRoslynResourceBridge extends FakeBridge:
	func call_atomic(tool_name: String, args: Dictionary = {}) -> Dictionary:
		match tool_name:
			"resource_query":
				return success({"dependencies": []})
			"script_inspect":
				return success({
					"language": "csharp",
					"class_name": "WrongTopLevelResource",
					"base_type": "Node",
					"types": [{
						"name": "NoteData",
						"kind": "class",
						"namespace": "",
						"partial": true,
						"base_type": "Resource",
						"modifiers": ["public"],
						"line": 3,
						"column": 21
					}],
					"parse_errors": [],
					"degraded": false
				})
			_:
				return super.call_atomic(tool_name, args)


class FakeToolLoader extends RefCounted:
	func get_gdscript_lsp_diagnostics_service():
		return null

	func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
		return {"service_available": false, "service": {"status": {"state": "idle"}}}

	func get_tool_loader_status() -> Dictionary:
		return {"status": "ready", "tool_count": 115, "exposed_tool_count": 18, "last_error": ""}


class FakeDisposableExecutor extends RefCounted:
	var disposed := false
	var shutdown_called := false

	func dispose() -> void:
		disposed = true

	func shutdown() -> void:
		shutdown_called = true


class FakeFilesystemAtomicBridge extends AtomicBridgeScript:
	var last_args: Dictionary = {}

	func call_atomic(tool_name: String, args: Dictionary = {}) -> Dictionary:
		if tool_name != "filesystem_directory":
			return error("Unexpected atomic tool: %s" % tool_name)
		last_args = args.duplicate(true)
		if bool(args.get("count_only", false)):
			return success({"count": 1, "count_only": true})
		return success({"files": ["res://Player.gd"], "count": 1})


func run_case(_tree: SceneTree) -> Dictionary:
	_prepare_temp_root()
	var atomic_bridge = AtomicBridgeScript.new()
	var read_actions := [
		{"tool": "project_info", "args": {"action": "get_settings"}},
		{"tool": "scene_hierarchy", "args": {"action": "select"}},
		{"tool": "editor_filesystem", "args": {"action": "get_selected"}},
		{"tool": "editor_filesystem", "args": {"action": "select_file"}},
		{"tool": "filesystem_directory", "args": {"action": "get_files"}},
		{"tool": "script_references", "args": {"action": "get_scene_refs"}},
		{"tool": "debug_runtime_bridge", "args": {"action": "get_recent"}}
	]
	for item in read_actions:
		if atomic_bridge._is_write_action(item.get("args", {}) as Dictionary):
			return _failure("AtomicBridge should not classify read action as write: %s" % JSON.stringify(item))
	var write_actions := [
		{"tool": "project_settings", "args": {"action": "set_setting"}},
		{"tool": "filesystem_directory", "args": {"action": "create"}},
		{"tool": "filesystem_file_manage", "args": {"action": "move"}},
		{"tool": "filesystem_file_write", "args": {"action": "save"}},
		{"tool": "filesystem_file_write", "args": {"action": "save_as"}},
		{"tool": "scene_hierarchy", "args": {"action": "add_node"}},
		{"tool": "scene_hierarchy", "args": {"action": "reorder"}},
		{"tool": "scene_file", "args": {"action": "patch"}},
		{"tool": "script_edit_gd", "args": {"action": "add_function"}},
		{"tool": "script_edit_cs", "args": {"action": "replace_method_body"}}
	]
	for item in write_actions:
		if not atomic_bridge._is_write_action(item.get("args", {}) as Dictionary):
			return _failure("AtomicBridge should classify mutating action as write: %s" % JSON.stringify(item))
	if not atomic_bridge._is_write_atomic_action("script_edit_gd", {}):
		return _failure("AtomicBridge should infer script_edit_* atomic calls without an action as writes.")
	var disposable_executor := FakeDisposableExecutor.new()
	atomic_bridge._atomic_executors["script"] = disposable_executor
	atomic_bridge._invalidate_atomic_executors()
	if not disposable_executor.disposed or not disposable_executor.shutdown_called:
		return _failure("AtomicBridge write invalidation should dispose and shutdown cached executors.")
	if not atomic_bridge._atomic_executors.is_empty():
		return _failure("AtomicBridge write invalidation should clear all cached executors.")
	var atomic_collect_bridge = FakeFilesystemAtomicBridge.new()
	var atomic_files: Array = atomic_collect_bridge.collect_files("*.gd")
	if atomic_files.size() != 1:
		return _failure("AtomicBridge.collect_files should return files from filesystem_directory.")
	if str(atomic_collect_bridge.last_args.get("path", "")) != "res://":
		return _failure("AtomicBridge.collect_files should pass res:// as the filesystem_directory root path.")
	var atomic_file_count: int = atomic_collect_bridge.collect_file_count("*.gd")
	if atomic_file_count != 1:
		return _failure("AtomicBridge.collect_file_count should return count from filesystem_directory.")
	if not bool(atomic_collect_bridge.last_args.get("count_only", false)):
		return _failure("AtomicBridge.collect_file_count should request count_only filesystem enumeration.")
	var resource_path := TEMP_ROOT.path_join("GlobalGameConfig.tres")
	var valid_resource_path := TEMP_ROOT.path_join("ValidNoteData.tres")
	var quoted_id_path_resource_path := TEMP_ROOT.path_join("QuotedPathIdNoteData.tres")
	var missing_script_resource_path := TEMP_ROOT.path_join("MissingScriptId.tres")
	var non_script_resource_path := TEMP_ROOT.path_join("NonScriptId.tres")
	var script_path := TEMP_ROOT.path_join("ConfigResource.cs")
	var valid_script_path := TEMP_ROOT.path_join("NoteData.cs")
	var quoted_id_script_path := TEMP_ROOT.path_join("NoteData_id=inside.cs")
	var scene_path := TEMP_ROOT.path_join("NodeScriptScene.tscn")
	var node_script_path := TEMP_ROOT.path_join("NodeController.cs")
	_write_text(script_path, "using Godot;\n[GlobalClass]\npublic partial class ConfigResource : Resource {}\n")
	_write_text(valid_script_path, "using Godot;\n[GlobalClass]\npublic partial class NoteData : Resource {}\n")
	_write_text(quoted_id_script_path, "using Godot;\n[GlobalClass]\npublic partial class NoteData : Resource {}\n")
	_write_text(node_script_path, "using Godot;\npublic partial class NodeController : Node {}\n")
	_write_text(resource_path, "[gd_resource type=\"Resource\" script_class=\"ConfigResource\" format=3]\n[ext_resource type=\"Script\" path=\"%s\" id=\"1_script\"]\n[resource]\nscript = ExtResource(\"1_script\")\n" % script_path)
	_write_text(valid_resource_path, "[gd_resource type=\"Resource\" script_class=\"NoteData\" format=3]\n[ext_resource type=\"Script\" uid=\"uid://valid_note_data\" path=\"%s\" id=4_ssj7b]\n[resource]\nscript = ExtResource(\"4_ssj7b\")\n" % valid_script_path)
	_write_text(quoted_id_path_resource_path, "[gd_resource type=\"Resource\" script_class=\"NoteData\" format=3]\n[ext_resource type=\"Script\" path=\"%s\" id=\"5_quoted\"]\n[resource]\nscript = ExtResource(\"5_quoted\")\n" % quoted_id_script_path)
	_write_text(missing_script_resource_path, "[gd_resource type=\"Resource\" format=3]\n[resource]\nscript = ExtResource(\"missing_script\")\n")
	_write_text(non_script_resource_path, "[gd_resource type=\"Resource\" format=3]\n[ext_resource type=\"Resource\" path=\"%s\" id=4_not_script]\n[resource]\nscript = ExtResource(\"4_not_script\")\n" % valid_resource_path)
	_write_text(scene_path, "[gd_scene load_steps=2 format=3]\n[ext_resource type=\"Script\" path=\"%s\" id=\"1_script\"]\n[node name=\"Root\" type=\"Node\"]\nscript = ExtResource(\"1_script\")\n" % node_script_path)

	PluginSelfDiagnosticStore.clear()
	PluginSelfDiagnosticStore.record_incident(
		"warning",
		"contract_warning",
		"project_state_contract_incident",
		"Contract incident",
		"system_project_executor_contract_test"
	)

	var executor = SystemProjectExecutorScript.new()
	var bridge := FakeBridge.new(FakeToolLoader.new())
	executor.bridge = bridge
	executor.configure_runtime({})

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 11:
		return _failure("System project implementation should expose 11 tool definitions including plugin_reload, plugin_update, project_files, resource_reference_audit and userdata_maintenance.")
	if not _has_tool(tool_defs, "plugin_reload"):
		return _failure("System project implementation should expose plugin_reload for stable plugin lifecycle reloads.")
	if not _has_tool(tool_defs, "plugin_update"):
		return _failure("System project implementation should expose plugin_update for high-level plugin update flows.")
	if not _has_tool(tool_defs, "userdata_maintenance"):
		return _failure("System project implementation should expose userdata_maintenance for manual cache cleanup.")
	if not _has_tool(tool_defs, "project_files"):
		return _failure("System project implementation should expose project_files for high-level FileSystem tree changes.")
	if not _has_tool(tool_defs, "resource_reference_audit"):
		return _failure("System project implementation should expose resource_reference_audit for project-level resource consistency checks.")

	var reference_audit: Dictionary = executor.execute("resource_reference_audit", {"path": resource_path})
	if not bool(reference_audit.get("success", false)):
		return _failure("resource_reference_audit should run on a .tres fixture.")
	var reference_data: Dictionary = reference_audit.get("data", {})
	if int(reference_data.get("issue_count", 0)) < 1:
		return _failure("resource_reference_audit should report UID/path or C# Resource script issues.")
	if str(reference_data.get("build_status", "")) != "dotnet_build_may_pass":
		return _failure("resource_reference_audit should distinguish resource inconsistency from dotnet build status.")
	var valid_resource_executor = SystemProjectExecutorScript.new()
	valid_resource_executor.bridge = FakeRoslynResourceBridge.new(FakeToolLoader.new())
	valid_resource_executor.configure_runtime({})
	var valid_reference_audit: Dictionary = valid_resource_executor.execute("resource_reference_audit", {"path": valid_resource_path, "include_warnings": false})
	if not bool(valid_reference_audit.get("success", false)):
		return _failure("resource_reference_audit should run on a valid C# Resource .tres fixture.")
	var valid_reference_data: Dictionary = valid_reference_audit.get("data", {})
	var valid_reference_issues: Array = valid_reference_data.get("issues", [])
	if int(valid_reference_data.get("issue_count", -1)) != 0:
		return _failure("resource_reference_audit should not report false positives for declared C# [GlobalClass] Resource scripts: %s" % JSON.stringify(valid_reference_issues))
	var valid_file_results: Array = valid_reference_data.get("files", [])
	if valid_file_results.is_empty() or int((valid_file_results[0] as Dictionary).get("csharp_resource_script_count", 0)) != 1:
		return _failure("resource_reference_audit should count declared C# Resource script references after resolving Roslyn types metadata.")
	var quoted_path_audit: Dictionary = valid_resource_executor.execute("resource_reference_audit", {"path": quoted_id_path_resource_path, "include_warnings": false})
	if not bool(quoted_path_audit.get("success", false)):
		return _failure("resource_reference_audit should run on a .tres fixture whose path contains id= text.")
	var quoted_path_data: Dictionary = quoted_path_audit.get("data", {})
	var quoted_path_issues: Array = quoted_path_data.get("issues", [])
	if int(quoted_path_data.get("issue_count", -1)) != 0:
		return _failure("resource_reference_audit should ignore id= text inside quoted attribute values: %s" % JSON.stringify(quoted_path_issues))
	var missing_id_audit: Dictionary = valid_resource_executor.execute("resource_reference_audit", {"path": missing_script_resource_path, "include_warnings": false})
	if not _has_issue_type(missing_id_audit.get("data", {}).get("issues", []), "resource_script_ext_resource_missing"):
		return _failure("resource_reference_audit should report resource_script_ext_resource_missing when script ExtResource id is not declared.")
	var non_script_id_audit: Dictionary = valid_resource_executor.execute("resource_reference_audit", {"path": non_script_resource_path, "include_warnings": false})
	if not _has_issue_type(non_script_id_audit.get("data", {}).get("issues", []), "resource_script_ext_resource_not_script"):
		return _failure("resource_reference_audit should report resource_script_ext_resource_not_script when script ExtResource id declares a non-Script resource.")
	var scene_reference_audit: Dictionary = executor.execute("resource_reference_audit", {"path": scene_path})
	if not bool(scene_reference_audit.get("success", false)):
		return _failure("resource_reference_audit should run on a .tscn fixture.")
	var scene_reference_data: Dictionary = scene_reference_audit.get("data", {})
	var scene_issues: Array = scene_reference_data.get("issues", [])
	if _has_issue_type(scene_issues, "resource_script_base_type_unconfirmed") or _has_issue_type(scene_issues, "resource_script_missing_global_class_attribute"):
		return _failure("resource_reference_audit should not treat ordinary .tscn C# node scripts as custom Resource scripts.")

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
	var user_tools_health = runtime_health_dict.get("user_tools", {})
	if not (user_tools_health is Dictionary):
		return _failure("project_state runtime_health.user_tools did not return a dictionary payload.")
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
	var editor_context: Dictionary = (runtime_capabilities as Dictionary).get("editor_context", {})
	var context_identity: Dictionary = editor_context.get("editor_session_identity", {})
	if str(context_identity.get("session_id", "")) != "project-contract-session":
		return _failure("runtime_capabilities.editor_context should expose the current editor session identity.")
	if bool(context_identity.get("safe_to_terminate", true)) or bool(context_identity.get("external_validation_process", true)):
		return _failure("runtime_capabilities.editor_context should mark the current editor process as non-terminable and non-external.")
	if not bool((runtime_capabilities as Dictionary).get("headless_logic_ok", false)):
		return _failure("runtime_capabilities should declare that headless logic validation is a supported fallback.")
	if not bool((runtime_capabilities as Dictionary).get("visible_capture_required", false)):
		return _failure("runtime_capabilities should declare that visual QA requires visible capture.")
	if bool((runtime_capabilities as Dictionary).get("can_run_without_focus", true)) or bool((runtime_capabilities as Dictionary).get("no_focus_launch_supported", true)):
		return _failure("runtime_capabilities should explicitly report that no-focus runtime launch is unsupported.")
	if str((runtime_capabilities as Dictionary).get("foreground_window_policy", "")) != "requires_foreground_window":
		return _failure("runtime_capabilities should expose the foreground-window policy.")
	if not ((project_state_data as Dictionary).get("scene_paths", []) is Array):
		return _failure("project_state default payload should preserve scene_paths for backward compatibility.")

	bridge.reset_collection_counters()
	var project_state_summary: Dictionary = executor.execute("project_state", {"summary": true, "include_runtime_health": true})
	if not bool(project_state_summary.get("success", false)):
		return _failure("project_state summary mode should succeed.")
	if bridge.collect_files_calls != 0:
		return _failure("project_state summary mode should not collect full file path arrays.")
	if bridge.collect_file_counts_calls != 1:
		return _failure("project_state summary mode should use one bulk lightweight file count call for project file totals.")
	if bridge.collect_file_count_calls != 5:
		return _failure("project_state summary mode should resolve all project file glob totals through the bulk count helper.")
	var summary_data: Dictionary = project_state_summary.get("data", {})
	if not bool(summary_data.get("summary", false)):
		return _failure("project_state summary mode should mark the payload as a summary.")
	if summary_data.has("scene_paths") or summary_data.has("script_paths") or summary_data.has("resource_paths"):
		return _failure("project_state summary mode should omit large path arrays.")
	if not (summary_data.get("available_sections", []) is Array) or not (summary_data.get("available_sections", []) as Array).has("files"):
		return _failure("project_state summary mode should advertise available sections.")
	if int(summary_data.get("compile_error_count", -1)) != 1 or int(summary_data.get("scripts", 0)) < 2:
		return _failure("project_state summary mode should preserve key project counts.")

	bridge.reset_collection_counters()
	var project_state_sections: Dictionary = executor.execute("project_state", {"sections": ["summary", "files", "health"]})
	if not bool(project_state_sections.get("success", false)):
		return _failure("project_state sections mode should succeed.")
	if bridge.collect_files_calls < 5:
		return _failure("project_state sections mode should collect full file path arrays when the files section is requested.")
	var sections_data: Dictionary = project_state_sections.get("data", {})
	var sections = sections_data.get("sections", {})
	if not (sections is Dictionary):
		return _failure("project_state sections mode should return a sections dictionary.")
	var section_dict: Dictionary = sections
	if section_dict.keys().size() != 3 or not section_dict.has("summary") or not section_dict.has("files") or not section_dict.has("health"):
		return _failure("project_state sections mode should return only requested sections.")
	if not ((section_dict.get("files", {}) as Dictionary).get("scene_paths", []) is Array):
		return _failure("project_state files section should expose path arrays on demand.")
	if not ((section_dict.get("health", {}) as Dictionary).get("self_diagnostics", {}) is Dictionary):
		return _failure("project_state health section should include runtime health even without include_runtime_health.")
	if not ((section_dict.get("health", {}) as Dictionary).get("user_tools", {}) is Dictionary):
		return _failure("project_state health section should include User Tool runtime diagnostics.")
	bridge.reset_collection_counters()
	var project_state_summary_section: Dictionary = executor.execute("project_state", {"sections": ["summary"]})
	if not bool(project_state_summary_section.get("success", false)):
		return _failure("project_state summary-only section mode should succeed.")
	if bridge.collect_files_calls != 0:
		return _failure("project_state summary-only section mode should not collect full file path arrays.")
	if bridge.collect_file_counts_calls != 1:
		return _failure("project_state summary-only section mode should use one bulk lightweight file count call.")
	if bridge.collect_file_count_calls != 5:
		return _failure("project_state summary-only section mode should resolve all project file glob totals through the bulk count helper.")

	var invalid_project_state_section: Dictionary = executor.execute("project_state", {"sections": ["summary", "unknown"]})
	if bool(invalid_project_state_section.get("success", false)):
		return _failure("project_state sections mode should reject unknown sections.")
	if str(invalid_project_state_section.get("message", invalid_project_state_section.get("error", ""))).find("unknown") == -1:
		return _failure("project_state invalid section response should name the unknown section.")
	var invalid_project_state_sections_shape: Dictionary = executor.execute("project_state", {"sections": "summary"})
	if bool(invalid_project_state_sections_shape.get("success", false)):
		return _failure("project_state sections mode should reject non-array sections arguments.")
	var empty_project_state_sections: Dictionary = executor.execute("project_state", {"sections": []})
	if not bool(empty_project_state_sections.get("success", false)):
		return _failure("project_state empty sections should preserve default full payload behavior.")
	if not ((empty_project_state_sections.get("data", {}) as Dictionary).get("scene_paths", []) is Array):
		return _failure("project_state empty sections should return the default full payload.")
	var summary_with_sections: Dictionary = executor.execute("project_state", {"summary": true, "sections": ["files"]})
	if not bool(summary_with_sections.get("success", false)):
		return _failure("project_state summary plus sections should still return requested sections.")
	var summary_sections_data: Dictionary = summary_with_sections.get("data", {})
	if summary_sections_data.has("summary") or not ((summary_sections_data.get("sections", {}) as Dictionary).has("files")):
		return _failure("project_state sections should take precedence over summary=true when both are provided.")

	var empty_executor = SystemProjectExecutorScript.new()
	empty_executor.bridge = FakeEmptyCollectBridge.new(FakeToolLoader.new())
	empty_executor.configure_runtime({})
	var empty_reference_audit: Dictionary = empty_executor.execute("resource_reference_audit", {})
	if not bool(empty_reference_audit.get("success", false)):
		return _failure("resource_reference_audit should return structured diagnostics when project-level collection is empty.")
	var empty_audit_data: Dictionary = empty_reference_audit.get("data", {})
	if int(empty_audit_data.get("scanned_file_count", -1)) != 0:
		return _failure("resource_reference_audit empty-scope fixture should report scanned_file_count=0.")
	if bool(empty_audit_data.get("valid_scan_scope", true)):
		return _failure("resource_reference_audit should mark empty project-level scans as invalid scan scope.")
	if str(empty_audit_data.get("risk_level", "")) == "clean":
		return _failure("resource_reference_audit should not report clean when no files were scanned.")
	if str(empty_audit_data.get("scan_status", "")) != "invalid_scan_scope":
		return _failure("resource_reference_audit should expose invalid_scan_scope for empty project-level scans.")
	if int(empty_audit_data.get("issue_count", -1)) != 0:
		return _failure("resource_reference_audit should keep resource issue_count separate from scan diagnostics.")
	if not _has_diagnostic_code(empty_audit_data.get("enumeration_diagnostics", []), "resource_reference_scan_scope_empty"):
		return _failure("resource_reference_audit should include a stable empty scan diagnostic code.")
	var empty_project_state: Dictionary = empty_executor.execute("project_state", {})
	if not bool(empty_project_state.get("success", false)):
		return _failure("project_state should succeed while reporting suspect file enumeration.")
	var empty_project_data: Dictionary = empty_project_state.get("data", {})
	if bool(empty_project_data.get("valid_file_enumeration", true)):
		return _failure("project_state should mark empty script and scene enumeration as suspect.")
	if str(empty_project_data.get("file_enumeration_status", "")) != "suspect":
		return _failure("project_state should expose suspect file_enumeration_status for empty script and scene enumeration.")
	if not _has_diagnostic_code(empty_project_data.get("enumeration_diagnostics", []), "project_file_enumeration_empty"):
		return _failure("project_state should include a stable empty project enumeration diagnostic code.")

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
	var input_action_detail: Dictionary = executor.execute("project_configure", {"action": "get_input_action", "name": "jump"})
	if not bool(input_action_detail.get("success", false)):
		return _failure("project_configure get_input_action should delegate to project_input.get_action.")
	var input_action_data = input_action_detail.get("data", {})
	if not (input_action_data is Dictionary) or str((input_action_data as Dictionary).get("name", "")) != "jump":
		return _failure("project_configure get_input_action should preserve the action name.")
	if ((input_action_data as Dictionary).get("events", []) as Array).is_empty():
		return _failure("project_configure get_input_action should expose detailed input events.")
	var missing_input_action_name: Dictionary = executor.execute("project_configure", {"action": "get_input_action"})
	if bool(missing_input_action_name.get("success", false)):
		return _failure("project_configure get_input_action should reject an empty action name before delegation.")

	var project_files_list: Dictionary = executor.execute("project_files", {"action": "list_dir", "path": "res://", "filter": "*.gd"})
	if not bool(project_files_list.get("success", false)):
		return _failure("project_files list_dir should delegate to the filesystem directory atomic tool.")
	var project_files_write: Dictionary = executor.execute("project_files", {"action": "write_file", "path": "res://notes.txt", "content": "ok"})
	if not bool(project_files_write.get("success", false)):
		return _failure("project_files write_file should delegate to the filesystem write atomic tool.")
	var project_files_select: Dictionary = executor.execute("project_files", {"action": "select_file", "path": "res://Player.gd"})
	if not bool(project_files_select.get("success", false)):
		return _failure("project_files select_file should delegate to the editor filesystem atomic tool.")
	var project_settings_reimport: Dictionary = executor.execute("project_files", {"action": "reimport", "paths": ["res://project.godot"]})
	if bool(project_settings_reimport.get("success", false)):
		return _failure("project_files reimport should expose not_importable_resource errors from the editor filesystem tool.")
	if str(project_settings_reimport.get("data", {}).get("error_code", "")) != "not_importable_resource":
		return _failure("project_files reimport should preserve not_importable_resource error data.")

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
	var run_action_count_before_no_focus := int(executor.bridge.scene_run_actions.size())
	var no_focus_run: Dictionary = executor.execute("project_run", {"no_focus": true})
	if bool(no_focus_run.get("success", false)):
		return _failure("project_run should reject unsupported no_focus launches instead of starting the project.")
	if executor.bridge.scene_run_actions.size() != run_action_count_before_no_focus:
		return _failure("project_run should not call scene_run when no_focus launch is unsupported.")
	var no_focus_data = no_focus_run.get("data", {})
	if not (no_focus_data is Dictionary):
		return _failure("project_run no_focus rejection should include structured data.")
	if str((no_focus_data as Dictionary).get("error_code", "")) != "requires_foreground_window":
		return _failure("project_run no_focus rejection should expose requires_foreground_window.")
	if bool((no_focus_data as Dictionary).get("can_run_without_focus", true)):
		return _failure("project_run no_focus rejection should report can_run_without_focus=false.")

	var marker_success_executor = SystemProjectExecutorScript.new()
	var marker_success_bridge = FakeBridge.new(FakeToolLoader.new())
	marker_success_bridge.runtime_events_after_start = [{"event_id": 1, "kind": "runtime_log", "payload": {"message": "BOOT READY", "level": "info"}}]
	marker_success_executor.bridge = marker_success_bridge
	marker_success_executor.configure_runtime({})
	var marker_success: Dictionary = await marker_success_executor.execute_async("project_run", {
		"success_markers": ["BOOT READY"],
		"failure_markers": ["BOOT FAIL"],
		"timeout_ms": 50,
		"poll_interval_ms": 1,
		"log_tail": 10
	})
	if not bool(marker_success.get("success", false)):
		return _failure("project_run marker validation should pass when a success marker appears in runtime bridge events.")
	var marker_success_data: Dictionary = marker_success.get("data", {})
	var marker_success_validation: Dictionary = marker_success_data.get("validation", {})
	if str(marker_success_validation.get("status", "")) != "passed" or str(marker_success_validation.get("matched_marker", "")) != "BOOT READY":
		return _failure("project_run marker validation should report passed status and matched success marker details.")
	if marker_success_bridge.scene_run_actions != ["play_main", "stop"]:
		return _failure("project_run marker validation should auto-stop through scene_run stop by default.")

	var repeated_marker_executor = SystemProjectExecutorScript.new()
	var repeated_marker_bridge = FakeBridge.new(FakeToolLoader.new())
	repeated_marker_bridge.runtime_events = [{"event_id": 1, "kind": "runtime_log", "payload": {"message": "REPEAT READY", "level": "info"}}]
	repeated_marker_bridge.runtime_events_after_start = [{"event_id": 2, "kind": "runtime_log", "payload": {"message": "REPEAT READY", "level": "info"}}]
	repeated_marker_executor.bridge = repeated_marker_bridge
	repeated_marker_executor.configure_runtime({})
	var repeated_marker: Dictionary = await repeated_marker_executor.execute_async("project_run", {
		"success_markers": ["REPEAT READY"],
		"timeout_ms": 50,
		"poll_interval_ms": 1,
		"log_tail": 10
	})
	if not bool(repeated_marker.get("success", false)):
		return _failure("project_run marker validation should not filter out a new event that has the same text as a pre-run baseline event.")
	var repeated_marker_validation: Dictionary = repeated_marker.get("data", {}).get("validation", {})
	var repeated_matched_event: Dictionary = repeated_marker_validation.get("matched_event", {})
	if int(repeated_matched_event.get("event_id", 0)) != 2:
		return _failure("project_run marker validation should match the post-start event_id instead of the pre-run baseline event.")

	var high_volume_marker_executor = SystemProjectExecutorScript.new()
	var high_volume_marker_bridge = FakeBridge.new(FakeToolLoader.new())
	high_volume_marker_bridge.runtime_events_after_start = [{"event_id": 1, "kind": "runtime_log", "payload": {"message": "HIGH VOLUME READY", "level": "info"}}]
	for event_id in range(2, 40):
		high_volume_marker_bridge.runtime_events_after_start.append({"event_id": event_id, "kind": "runtime_log", "payload": {"message": "noise %d" % event_id, "level": "info"}})
	high_volume_marker_executor.bridge = high_volume_marker_bridge
	high_volume_marker_executor.configure_runtime({})
	var high_volume_marker: Dictionary = await high_volume_marker_executor.execute_async("project_run", {
		"success_markers": ["HIGH VOLUME READY"],
		"timeout_ms": 50,
		"poll_interval_ms": 1,
		"log_tail": 1
	})
	if not bool(high_volume_marker.get("success", false)):
		return _failure("project_run marker validation should not miss a marker that is followed by more events than log_tail.")

	MCPRuntimeDebugStoreShared.clear()
	_create_user_file(MCPUserDataPaths.RUNTIME_EVENTS_PATH, JSON.stringify([{
		"event_id": 100,
		"timestamp_unix": 25,
		"timestamp_text": "2026-01-01T00:00:25",
		"kind": "runtime_log",
		"session_id": 7,
		"payload": {"message": "OLD SHARED", "level": "info"}
	}]))
	var debug_tools = DebugToolsScript.new()
	var baseline_shared_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_recent", "limit": 5})
	if not bool(baseline_shared_result.get("success", false)):
		return _shared_store_failure("debug_runtime_bridge get_recent should read fallback runtime events before cursor checks.")
	var baseline_shared_events: Array = baseline_shared_result.get("data", {}).get("events", [])
	if baseline_shared_events.is_empty():
		return _shared_store_failure("debug_runtime_bridge get_recent should expose seeded fallback runtime events.")
	var baseline_shared_cursor := int((baseline_shared_events[baseline_shared_events.size() - 1] as Dictionary).get("event_id", -1))
	_create_user_file(MCPUserDataPaths.RUNTIME_EVENTS_PATH, JSON.stringify([{
		"event_id": 100,
		"timestamp_unix": 25,
		"timestamp_text": "2026-01-01T00:00:25",
		"kind": "runtime_log",
		"session_id": 7,
		"payload": {"message": "OLD SHARED", "level": "info"}
	}, {
		"event_id": 1,
		"timestamp_unix": 26,
		"timestamp_text": "2026-01-01T00:00:26",
		"kind": "runtime_log",
		"session_id": 7,
		"payload": {"message": "NEW FALLBACK", "level": "info"}
	}]))
	var fallback_cursor_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_since_event_id", "after_event_id": baseline_shared_cursor, "limit": 5})
	if not bool(fallback_cursor_result.get("success", false)):
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should read fallback events after a normalized cursor.")
	var fallback_cursor_events: Array = fallback_cursor_result.get("data", {}).get("events", [])
	if fallback_cursor_events.is_empty() or str((fallback_cursor_events[0] as Dictionary).get("payload", {}).get("message", "")) != "NEW FALLBACK":
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should handle newer fallback events with lower raw event_id values.")
	MCPRuntimeDebugStoreShared.clear()
	var ordered_event_a := _runtime_log_event(10, "ORDER A")
	var ordered_event_b := _runtime_log_event(20, "ORDER B")
	var ordered_event_c := _runtime_log_event(30, "ORDER C")
	_create_user_file(MCPUserDataPaths.RUNTIME_EVENTS_PATH, JSON.stringify([ordered_event_a, ordered_event_c]))
	var ordered_baseline_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_recent", "limit": 5})
	if not bool(ordered_baseline_result.get("success", false)):
		return _shared_store_failure("debug_runtime_bridge get_recent should seed ordered fallback cursor pagination.")
	var ordered_baseline_events: Array = ordered_baseline_result.get("data", {}).get("events", [])
	if ordered_baseline_events.size() != 2:
		return _shared_store_failure("debug_runtime_bridge get_recent should expose the seeded ordered fallback events.")
	var ordered_a_cursor := int((ordered_baseline_events[0] as Dictionary).get("event_id", -1))
	_create_user_file(MCPUserDataPaths.RUNTIME_EVENTS_PATH, JSON.stringify([ordered_event_a, ordered_event_b, ordered_event_c]))
	var ordered_first_page_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_since_event_id", "after_event_id": ordered_a_cursor, "limit": 1})
	if not bool(ordered_first_page_result.get("success", false)):
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should page ordered fallback events after insertion.")
	var ordered_first_page_events: Array = ordered_first_page_result.get("data", {}).get("events", [])
	if ordered_first_page_events.is_empty() or str((ordered_first_page_events[0] as Dictionary).get("payload", {}).get("message", "")) != "ORDER B":
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should return the inserted middle event on the first limited page.")
	var ordered_b_cursor := int((ordered_first_page_events[0] as Dictionary).get("event_id", -1))
	var ordered_second_page_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_since_event_id", "after_event_id": ordered_b_cursor, "limit": 1})
	if not bool(ordered_second_page_result.get("success", false)):
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should continue ordered fallback pagination.")
	var ordered_second_page_events: Array = ordered_second_page_result.get("data", {}).get("events", [])
	if ordered_second_page_events.is_empty() or str((ordered_second_page_events[0] as Dictionary).get("payload", {}).get("message", "")) != "ORDER C":
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should not skip an already-seen later event after an inserted middle event.")
	MCPRuntimeDebugStoreShared.clear()
	var full_fallback_events: Array = []
	for event_id in range(1, 302):
		full_fallback_events.append(_runtime_log_event(event_id, "BUFFER %d" % event_id))
	_create_user_file(MCPUserDataPaths.RUNTIME_EVENTS_PATH, JSON.stringify(full_fallback_events.slice(0, 300)))
	var full_buffer_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_recent", "limit": 300})
	if not bool(full_buffer_result.get("success", false)):
		return _shared_store_failure("debug_runtime_bridge get_recent should read a full runtime event buffer.")
	var full_buffer_events: Array = full_buffer_result.get("data", {}).get("events", [])
	if full_buffer_events.size() != 300:
		return _shared_store_failure("debug_runtime_bridge get_recent should expose the full seeded runtime event buffer.")
	var full_buffer_cursor := int((full_buffer_events[full_buffer_events.size() - 1] as Dictionary).get("event_id", -1))
	_create_user_file(MCPUserDataPaths.RUNTIME_EVENTS_PATH, JSON.stringify(full_fallback_events))
	var trimmed_buffer_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_since_event_id", "after_event_id": full_buffer_cursor, "limit": 5})
	if not bool(trimmed_buffer_result.get("success", false)):
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should read after a full buffer cursor.")
	var trimmed_buffer_events: Array = trimmed_buffer_result.get("data", {}).get("events", [])
	if trimmed_buffer_events.is_empty() or str((trimmed_buffer_events[0] as Dictionary).get("payload", {}).get("message", "")) != "BUFFER 301":
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should not skip a new event after the merged buffer reaches its max size.")
	MCPRuntimeDebugStoreShared.clear()
	_create_user_file(MCPUserDataPaths.RUNTIME_EVENTS_PATH, JSON.stringify([{
		"event_id": 25,
		"timestamp_unix": 25,
		"timestamp_text": "2026-01-01T00:00:25",
		"kind": "runtime_log",
		"session_id": 7,
		"payload": {"message": "OLD SHARED", "level": "info"}
	}]))
	var shared_recorded_event := MCPRuntimeDebugStoreShared.record_runtime_event("runtime_log", {"message": "LIVE SHARED READY", "level": "info"}, 7)
	if int(shared_recorded_event.get("event_id", 0)) <= 25:
		return _shared_store_failure("shared runtime debug store should assign live event_id values after persisted fallback events.")
	var shared_cursor_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_since_event_id", "after_event_id": 1, "limit": 5})
	if not bool(shared_cursor_result.get("success", false)):
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should read shared runtime events after a fallback cursor.")
	var shared_cursor_events: Array = shared_cursor_result.get("data", {}).get("events", [])
	if shared_cursor_events.is_empty() or str((shared_cursor_events[0] as Dictionary).get("payload", {}).get("message", "")) != "LIVE SHARED READY":
		return _shared_store_failure("debug_runtime_bridge get_since_event_id should not treat a live event as older than persisted fallback history.")
	MCPRuntimeDebugStoreShared.clear()
	MCPRuntimeDebugStoreShared.record_runtime_event("runtime_log", {"message": "LIVE SHARED READY", "level": "info"}, 7)
	var live_shared_result: Dictionary = debug_tools.execute("runtime_bridge", {"action": "get_recent", "limit": 5})
	var live_shared_events: Array = live_shared_result.get("data", {}).get("events", [])
	var live_shared_message := ""
	if not live_shared_events.is_empty() and live_shared_events[0] is Dictionary:
		live_shared_message = str((live_shared_events[0] as Dictionary).get("payload", {}).get("message", ""))
	MCPRuntimeDebugStoreShared.clear()
	if not bool(live_shared_result.get("success", false)):
		return _failure("debug_runtime_bridge get_recent should read the shared runtime debug store.")
	if live_shared_events.is_empty() or live_shared_message != "LIVE SHARED READY":
		return _failure("debug_runtime_bridge get_recent should expose live events recorded in the shared runtime debug store.")

	var marker_failure_executor = SystemProjectExecutorScript.new()
	var marker_failure_bridge = FakeBridge.new(FakeToolLoader.new())
	marker_failure_bridge.runtime_events_after_start = [{"event_id": 1, "kind": "runtime_log", "payload": {"message": "BOOT READY then BOOT FAIL", "level": "error"}}]
	marker_failure_executor.bridge = marker_failure_bridge
	marker_failure_executor.configure_runtime({})
	var marker_failure: Dictionary = await marker_failure_executor.execute_async("project_run", {
		"success_markers": ["BOOT READY"],
		"failure_markers": ["BOOT FAIL"],
		"timeout_ms": 50,
		"poll_interval_ms": 1,
		"log_tail": 10
	})
	if bool(marker_failure.get("success", false)):
		return _failure("project_run marker validation should fail when a failure marker appears, even if success text also appears.")
	var marker_failure_data: Dictionary = marker_failure.get("data", {})
	if str(marker_failure_data.get("error_code", "")) != "run_log_failure_marker_matched":
		return _failure("project_run marker validation failure should include run_log_failure_marker_matched error_code.")
	var marker_failure_validation: Dictionary = marker_failure_data.get("validation", {})
	if str(marker_failure_validation.get("status", "")) != "failed" or str(marker_failure_validation.get("matched_marker", "")) != "BOOT FAIL":
		return _failure("project_run marker validation should report failed status and matched failure marker details.")

	var marker_timeout_executor = SystemProjectExecutorScript.new()
	var marker_timeout_bridge = FakeBridge.new(FakeToolLoader.new())
	marker_timeout_executor.bridge = marker_timeout_bridge
	marker_timeout_executor.configure_runtime({})
	var marker_timeout: Dictionary = await marker_timeout_executor.execute_async("project_run", {
		"success_markers": ["NEVER READY"],
		"timeout_ms": 5,
		"poll_interval_ms": 1,
		"log_tail": 10,
		"auto_stop": false
	})
	if bool(marker_timeout.get("success", false)):
		return _failure("project_run marker validation should fail when no marker appears before timeout.")
	var marker_timeout_data: Dictionary = marker_timeout.get("data", {})
	if str(marker_timeout_data.get("error_code", "")) != "run_log_marker_timeout":
		return _failure("project_run marker validation timeout should include run_log_marker_timeout error_code.")
	if marker_timeout_bridge.scene_run_actions != ["play_main"]:
		return _failure("project_run marker validation should respect auto_stop=false and avoid scene_run stop.")

	var invalid_marker_executor = SystemProjectExecutorScript.new()
	var invalid_marker_bridge = FakeBridge.new(FakeToolLoader.new())
	invalid_marker_executor.bridge = invalid_marker_bridge
	invalid_marker_executor.configure_runtime({})
	var invalid_marker: Dictionary = await invalid_marker_executor.execute_async("project_run", {
		"success_markers": ["x".repeat(300)]
	})
	if bool(invalid_marker.get("success", false)):
		return _failure("project_run marker validation should reject oversized markers.")
	var invalid_marker_data: Dictionary = invalid_marker.get("data", {})
	if str(invalid_marker_data.get("error_code", "")) != "invalid_argument":
		return _failure("project_run marker validation should report invalid_argument for oversized markers.")
	if not invalid_marker_bridge.scene_run_actions.is_empty():
		return _failure("project_run marker validation should reject invalid marker arguments before starting the project.")

	var failing_run_executor = SystemProjectExecutorScript.new()
	failing_run_executor.bridge = FakeFailingRunBridge.new(FakeToolLoader.new())
	failing_run_executor.configure_runtime({})
	var failing_run: Dictionary = failing_run_executor.execute("project_run", {"scene": "res://Missing.tscn"})
	if bool(failing_run.get("success", false)):
		return _failure("project_run should fail when the scene_run atomic tool fails.")
	var failing_run_data = failing_run.get("data", {})
	if not (failing_run_data is Dictionary):
		return _failure("project_run failure should return structured data.")
	if str((failing_run_data as Dictionary).get("error_code", "")) != "editor_run_interface_unavailable_despite_state_available":
		return _failure("project_run failure should identify inconsistent EditorInterface availability.")
	if not ((failing_run_data as Dictionary).get("state_probe_vs_run_invoker", {}) is Dictionary):
		return _failure("project_run inconsistent EditorInterface failure should include state/run comparison.")
	if ((failing_run_data as Dictionary).get("recovery_suggestions", []) as Array).is_empty():
		return _failure("project_run inconsistent EditorInterface failure should include recovery suggestions.")
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


func _has_issue_type(issues: Array, issue_type: String) -> bool:
	for issue in issues:
		if issue is Dictionary and str((issue as Dictionary).get("type", "")) == issue_type:
			return true
	return false


func _has_diagnostic_code(diagnostics: Array, code: String) -> bool:
	for diagnostic in diagnostics:
		if diagnostic is Dictionary and str((diagnostic as Dictionary).get("code", "")) == code:
			return true
	return false


func cleanup_case(_tree: SceneTree) -> void:
	PluginSelfDiagnosticStore.clear()
	_remove_tree(TEMP_ROOT)
	MCPUserDataPaths.cleanup_capture_cache(false)


func _prepare_temp_root() -> void:
	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create system project contract fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree(ProjectSettings.localize_path(child_path))
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _create_user_file(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


func _runtime_log_event(event_id: int, message: String) -> Dictionary:
	return {
		"event_id": event_id,
		"timestamp_unix": event_id,
		"timestamp_text": "2026-01-01T00:%02d:%02d" % [int(event_id / 60), event_id % 60],
		"kind": "runtime_log",
		"session_id": 7,
		"payload": {"message": message, "level": "info"}
	}


func _shared_store_failure(message: String) -> Dictionary:
	MCPRuntimeDebugStoreShared.clear()
	return _failure(message)


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_project_executor_contracts",
		"success": false,
		"error": message
	}
