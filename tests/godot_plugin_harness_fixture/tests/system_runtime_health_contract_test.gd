extends RefCounted

# {"name": "system_runtime_health_contracts"}

const ImplProjectScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd")
const PluginSelfDiagnosticStore = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")


class FakeBridge extends RefCounted:
	var _tool_loader

	func _init(tool_loader = null) -> void:
		_tool_loader = tool_loader

	func get_tool_loader():
		return _tool_loader

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		match tool_name:
			"editor_status":
				if str(args.get("action", "")) == "get_godot_path":
					return success({"godot_executable_path": "C:/Godot/Godot.exe", "project_root_path": "E:/Project/LuoxuanLove/Mechoes"})
				return error("Unsupported editor_status action")
			"project_info":
				if str(args.get("action", "")) == "get_info":
					return success({
						"name": "HealthContractProject",
						"description": "Runtime health contracts",
						"version": "1.0.0",
						"project_path": "res://",
						"godot_version": "4.6",
						"godot_version_string": "4.6.stable",
						"main_scene": "res://tests/project_contract_fixture/Main.tscn"
					})
				return error("Unsupported project_info action")
			"project_dotnet":
				return success({"count": 1, "projects": [{"name": "HealthContractProject"}]})
			"debug_runtime_bridge":
				match str(args.get("action", "")):
					"get_summary":
						return success({"bridge_status": "ready", "session_count": 1, "sessions": {"a": {"state": "running"}}})
					"get_errors_context":
						return success({"errors": []})
					"get_recent_filtered":
						return success({"events": []})
					"get_scene_snapshot":
						return success({"current_scene": "res://tests/project_contract_fixture/Main.tscn"})
					_:
						return error("Unsupported debug_runtime_bridge action")
			"debug_dotnet":
				return success({"error_count": 0, "errors": []})
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
		return {"service_available": true, "service": {"status": {"phase": "ready"}}}

	func get_tool_loader_status() -> Dictionary:
		return {"status": "ready", "tool_count": 118, "exposed_tool_count": 19, "last_error": ""}


func run_case(_tree: SceneTree) -> Dictionary:
	PluginSelfDiagnosticStore.clear()
	PluginSelfDiagnosticStore.record_incident(
		"warning",
		"contract_warning",
		"runtime_health_contract_incident",
		"Runtime health contract incident",
		"system_runtime_health_contract_test"
	)

	var executor = ImplProjectScript.new()
	executor.bridge = FakeBridge.new(FakeToolLoader.new())

	var result: Dictionary = executor.execute("project_state", {
		"error_limit": 5,
		"include_runtime_health": true
	})
	if not bool(result.get("success", false)):
		return _failure("project_state should succeed for runtime health aggregation.")

	var data = result.get("data", {})
	if not (data is Dictionary):
		return _failure("project_state should return a dictionary payload.")
	var runtime_health = (data as Dictionary).get("runtime_health", {})
	if not (runtime_health is Dictionary):
		return _failure("project_state should return runtime_health when include_runtime_health=true.")
	var runtime_health_dict: Dictionary = runtime_health
	for key in ["self_diagnostics", "lsp_diagnostics", "tool_loader"]:
		if not runtime_health_dict.has(key) or not (runtime_health_dict.get(key) is Dictionary):
			return _failure("runtime_health is missing dictionary section '%s'." % key)
	if not (runtime_health_dict.get("capabilities", {}) is Dictionary):
		return _failure("runtime_health should include runtime capability bits.")
	if not (runtime_health_dict.get("freshness", {}) is Dictionary):
		return _failure("runtime_health should include plugin instance freshness metadata.")
	var freshness: Dictionary = runtime_health_dict.get("freshness", {})
	if not freshness.has("running_instance") or not freshness.has("disk_source") or not freshness.has("comparison"):
		return _failure("runtime_health.freshness should expose running, disk and comparison sections.")
	var capabilities: Dictionary = runtime_health_dict.get("capabilities", {})
	if not capabilities.has("can_start_project") or not capabilities.has("can_control_runtime") or not capabilities.has("can_capture_runtime"):
		return _failure("runtime_health.capabilities should expose start/control/capture bits.")

	var self_diagnostics: Dictionary = runtime_health_dict.get("self_diagnostics", {})
	if not (self_diagnostics.get("freshness", {}) is Dictionary):
		return _failure("runtime_health.self_diagnostics should include freshness metadata.")
	if str(self_diagnostics.get("status", "")) != "warning":
		return _failure("runtime_health.self_diagnostics should surface the recorded warning status.")
	if int(self_diagnostics.get("active_incident_count", 0)) <= 0:
		return _failure("runtime_health.self_diagnostics should report active incidents.")

	return {
		"name": "system_runtime_health_contracts",
		"success": true,
		"error": "",
		"details": {
			"self_diagnostics_status": str(self_diagnostics.get("status", "")),
			"active_incident_count": int(self_diagnostics.get("active_incident_count", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_runtime_health_contracts",
		"success": false,
		"error": message
	}
