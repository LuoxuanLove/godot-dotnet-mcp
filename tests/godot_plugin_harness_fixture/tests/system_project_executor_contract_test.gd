extends RefCounted

const SystemProjectExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/system/project/executor.gd")


class FakeBridge extends RefCounted:
	var _tool_loader

	func _init(tool_loader = null) -> void:
		_tool_loader = tool_loader

	func get_tool_loader():
		return _tool_loader

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
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
				return success({"action": str(args.get("action", "")), "path": str(args.get("path", ""))}, "ok")
			"project_settings":
				return success({"applied": true})
			"project_autoload":
				return success({"count": 0, "entries": []})
			"project_input":
				return success({"count": 0, "actions": []})
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


class FakeToolLoader extends RefCounted:
	func get_gdscript_lsp_diagnostics_service():
		return null

	func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
		return {"service_available": false, "service": {"status": {"state": "idle"}}}

	func get_tool_loader_status() -> Dictionary:
		return {"status": "ready", "tool_count": 115, "exposed_tool_count": 18, "last_error": ""}


func run_case(_tree: SceneTree) -> Dictionary:
	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd"):
		return _failure("impl_project.gd should be removed once system/project/executor.gd becomes the only project entry.")

	var executor = SystemProjectExecutorScript.new()
	executor.bridge = FakeBridge.new(FakeToolLoader.new())
	executor.configure_runtime({})

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 6:
		return _failure("System project executor should expose 6 tool definitions after the split.")

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
	var tool_loader_health = runtime_health_dict.get("tool_loader", {})
	if not (tool_loader_health is Dictionary):
		return _failure("project_state runtime_health.tool_loader did not return a dictionary payload.")

	var project_advise: Dictionary = executor.execute("project_advise", {"goal": "fix errors"})
	if not bool(project_advise.get("success", false)):
		return _failure("project_advise did not succeed through the split system project executor.")

	var invalid_configure: Dictionary = executor.execute("project_configure", {"action": "bogus"})
	if bool(invalid_configure.get("success", false)):
		return _failure("project_configure bogus action should fail.")

	var project_run: Dictionary = executor.execute("project_run", {})
	if not bool(project_run.get("success", false)):
		return _failure("project_run did not succeed through the split runtime service.")

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


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_project_executor_contracts",
		"success": false,
		"error": message
	}
