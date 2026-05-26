extends RefCounted

# {"name": "system_editor_state_contracts"}

const SystemProjectImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd")


class FakeRuntimeControlService extends RefCounted:
	func get_status() -> Dictionary:
		return {
			"available": true,
			"armed": true,
			"session_snapshot": {
				"active_session_count": 1,
				"commandable_session_count": 1,
				"sessions": [{"id": 1, "commandable": true}]
			},
			"message": "Runtime control is armed."
		}


class FakeServer extends RefCounted:
	func get_runtime_control_service():
		return FakeRuntimeControlService.new()

	func get_listen_endpoint() -> Dictionary:
		return {
			"host": "127.0.0.1",
			"port": 3000,
			"url": "http://127.0.0.1:3000/mcp",
			"running": true
		}


class FakeBridge extends RefCounted:
	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
			"editor_status":
				match str(args.get("action", "")):
					"get_info":
						return success({
							"godot_version": "4.6.2",
							"version_string": "4.6.2.stable",
							"os": "Windows",
							"editor_scale": 1.25
						})
					"get_main_screen":
						return success({
							"current_screen": "Script",
							"available": ["2D", "3D", "Script", "AssetLib"]
						})
					"get_focus_context":
						return success({
							"has_focus_owner": true,
							"focus_owner_name": "InspectorSearch",
							"focus_owner_class": "LineEdit",
							"focus_owner_path": "/root/Editor/InspectorSearch",
							"selected_node_count": 1,
							"selected_node_paths": ["/root/Main/Player"]
						})
					"get_distraction_free":
						return success({"enabled": true})
					"get_godot_path":
						return success({
							"godot_executable_path": "C:/Godot/Godot.exe",
							"project_root_path": "C:/GodotProjects/ContractProject",
							"editor_session_identity": {
								"session_id": "editor-contract-session",
								"identity_scope": "current_editor_process",
								"process_owner": "godot_dotnet_mcp_editor",
								"external_validation_process": false,
								"safe_to_terminate": false,
								"pid": 4242,
								"cmdline_args": ["--path", "C:/GodotProjects/ContractProject"],
								"headless": false
							}
						})
					_:
						return error("Unsupported editor_status action")
			"editor_inspector":
				match str(args.get("action", "")):
					"get_edited":
						return success({
							"editing": true,
							"class": "Node3D",
							"path": "/root/Main/Player",
						})
					"get_selected_property":
						return success({"selected_path": "transform/origin"})
					_:
						return error("Unsupported editor_inspector action")
			"editor_filesystem":
				match str(args.get("action", "")):
					"get_selected":
						return success({
							"count": 1,
							"paths": ["res://Scenes/Main.tscn"]
						})
					"get_current_path":
						return success({
							"current_path": "res://Scenes/Main.tscn",
							"current_directory": "res://Scenes"
						})
					_:
						return error("Unsupported editor_filesystem action")
			"project_info":
				if str(args.get("action", "")) == "get_info":
					return success({
						"name": "ContractProject",
						"description": "Editor state contracts",
						"version": "1.0.1",
						"project_path": "res://",
						"godot_version": "4.6",
						"godot_version_string": "4.6.stable",
						"main_scene": "res://Scenes/Main.tscn"
					})
				return error("Unsupported project_info action")
			"project_dotnet":
				return success({"count": 1, "projects": [{"name": "ContractProject"}]})
			"debug_runtime_bridge":
				match str(args.get("action", "")):
					"get_summary":
						return success({
							"bridge_status": "ready",
							"session_count": 1,
							"sessions": {"editor": {"state": "running"}}
						})
					"get_errors_context":
						return success({"errors": []})
					"get_recent_filtered":
						return success({"events": []})
					"get_scene_snapshot":
						return success({"current_scene": "res://Scenes/Main.tscn"})
					_:
						return error("Unsupported debug_runtime_bridge action")
			"debug_dotnet":
				return success({"error_count": 2, "errors": []})
			_:
				return error("Unsupported fake bridge call: %s" % tool_name)

	func collect_files(pattern: String) -> Array:
		match pattern:
			"*.gd":
				return ["res://Player.gd"]
			"*.cs":
				return ["res://Player.cs"]
			"*.tscn":
				return ["res://Scenes/Main.tscn"]
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


class FakeFailingProjectBridge extends FakeBridge:
	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		if tool_name == "project_info" and str(args.get("action", "")) == "get_info":
			return error("project_info_unavailable")
		return super.call_atomic(tool_name, args)


func run_case(_tree: SceneTree) -> Dictionary:
	var executor = SystemProjectImplScript.new()
	executor.bridge = FakeBridge.new()
	executor.configure_runtime({"server": FakeServer.new()})

	var tool_defs: Array[Dictionary] = executor.get_tools()
	var tool_names: Array[String] = []
	for tool_def in tool_defs:
		tool_names.append(str(tool_def.get("name", "")))
	if not tool_names.has("editor_state"):
		return _failure("impl_project.gd should expose editor_state as a public system tool.")

	var result: Dictionary = executor.execute("editor_state", {})
	if not bool(result.get("success", false)):
		return _failure("editor_state should succeed through the system project implementation.")

	var data = result.get("data", {})
	if not (data is Dictionary):
		return _failure("editor_state should return a dictionary payload.")
	var payload: Dictionary = data
	for key in ["editor", "inspector", "filesystem", "project", "runtime_control"]:
		if not payload.has(key) or not (payload.get(key) is Dictionary):
			return _failure("editor_state is missing dictionary section '%s'." % key)

	var editor: Dictionary = payload.get("editor", {})
	if str(editor.get("main_screen", "")) != "Script":
		return _failure("editor_state.editor.main_screen should preserve the editor status snapshot.")
	if not bool(editor.get("distraction_free", false)):
		return _failure("editor_state.editor.distraction_free should preserve the editor status snapshot.")
	var focus_context: Dictionary = editor.get("focus_context", {})
	if str(focus_context.get("focus_owner_name", "")) != "InspectorSearch":
		return _failure("editor_state.editor.focus_context should preserve the focus owner snapshot.")
	if int(focus_context.get("selected_node_count", 0)) != 1:
		return _failure("editor_state.editor.focus_context should preserve selected scene nodes.")
	var editor_identity: Dictionary = editor.get("editor_session_identity", {})
	if str(editor_identity.get("session_id", "")) != "editor-contract-session":
		return _failure("editor_state.editor should expose the current editor session identity.")
	if int(editor_identity.get("listen_port", 0)) != 3000 or str(editor_identity.get("listen_host", "")) != "127.0.0.1":
		return _failure("editor_state.editor session identity should include the MCP listen endpoint when available.")
	if bool(editor_identity.get("safe_to_terminate", true)) or bool(editor_identity.get("external_validation_process", true)):
		return _failure("editor_state.editor session identity must distinguish the current MCP editor from external validation processes.")

	var inspector: Dictionary = payload.get("inspector", {})
	if str(inspector.get("selected_property", "")) != "transform/origin":
		return _failure("editor_state.inspector.selected_property should preserve the inspector selection.")

	var filesystem: Dictionary = payload.get("filesystem", {})
	if int(filesystem.get("selected_count", 0)) != 1:
		return _failure("editor_state.filesystem.selected_count should preserve filesystem selection.")

	var project: Dictionary = payload.get("project", {})
	if not bool(project.get("running", false)):
		return _failure("editor_state.project.running should preserve project running state.")
	if int(project.get("compile_error_count", 0)) != 2:
		return _failure("editor_state.project.compile_error_count should preserve project_state summary values.")

	var runtime_control: Dictionary = payload.get("runtime_control", {})
	if not bool(runtime_control.get("available", false)) or not bool(runtime_control.get("armed", false)):
		return _failure("editor_state.runtime_control should preserve runtime control status when the service is available.")
	if not bool(runtime_control.get("can_control_runtime", false)) or not bool(runtime_control.get("can_capture_runtime", false)):
		return _failure("editor_state.runtime_control should expose runtime control and capture capability bits.")
	var runtime_capabilities: Dictionary = payload.get("runtime_capabilities", {})
	if not bool(runtime_capabilities.get("can_control_runtime", false)) or not bool(runtime_capabilities.get("can_capture_runtime", false)):
		return _failure("editor_state should expose aggregate runtime capability bits.")
	if bool(runtime_capabilities.get("can_start_project", true)):
		return _failure("editor_state runtime capabilities should block project start when compile errors are present.")
	if bool(runtime_capabilities.get("can_run_without_focus", true)) or str(runtime_capabilities.get("foreground_window_policy", "")) != "requires_foreground_window":
		return _failure("editor_state runtime capabilities should expose the foreground-window launch policy.")
	var editor_context: Dictionary = runtime_capabilities.get("editor_context", {})
	var context_identity: Dictionary = editor_context.get("editor_session_identity", {})
	if str(context_identity.get("session_id", "")) != "editor-contract-session":
		return _failure("editor_state runtime capabilities should carry the editor session identity.")

	var failing_executor = SystemProjectImplScript.new()
	failing_executor.bridge = FakeFailingProjectBridge.new()
	failing_executor.configure_runtime({"server": FakeServer.new()})
	var failing_result: Dictionary = failing_executor.execute("editor_state", {})
	if not bool(failing_result.get("success", false)):
		return _failure("editor_state should keep the whole snapshot readable when the project section fails.")
	var failing_payload = failing_result.get("data", {})
	if not (failing_payload is Dictionary):
		return _failure("editor_state failure-path should still return a dictionary payload.")
	var failing_project: Dictionary = (failing_payload as Dictionary).get("project", {})
	if bool(failing_project.get("available", true)):
		return _failure("editor_state.project should report available=false when project_info fails.")
	if str(failing_project.get("error", "")).is_empty():
		return _failure("editor_state.project should surface an error message when the section fails.")

	return {
		"name": "system_editor_state_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"main_screen": str(editor.get("main_screen", "")),
			"selected_paths": filesystem.get("selected_paths", [])
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_editor_state_contracts",
		"success": false,
		"error": message
	}
