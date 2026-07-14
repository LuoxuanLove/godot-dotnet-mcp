extends RefCounted

const RuntimeStateServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_runtime_state_service.gd")


class FakeExecutor:
	extends RefCounted

	var definitions: Array = []
	var disposed := false

	func _init(new_definitions: Array = []) -> void:
		definitions = new_definitions.duplicate(true)

	func dispose() -> void:
		disposed = true


class FakeRuntimeStateContext:
	extends RefCounted

	var entries_by_category: Dictionary = {}
	var runtime_by_category: Dictionary = {}
	var definitions_by_category: Dictionary = {}
	var force_reload_script_load := false
	var instantiate_failures: Dictionary = {}
	var instantiate_definitions: Dictionary = {}
	var instantiate_calls: Array = []
	var load_errors: Array = []
	var disposed_executors: Array = []

	func build() -> Dictionary:
		return {
			"entries_by_category": entries_by_category,
			"runtime_by_category": runtime_by_category,
			"tool_definitions_by_category": definitions_by_category,
			"force_reload_script_load": force_reload_script_load,
			"get_entries_by_category": Callable(self, "get_entries_by_category"),
			"get_runtime_by_category": Callable(self, "get_runtime_by_category"),
			"get_tool_definitions_by_category": Callable(self, "get_tool_definitions_by_category"),
			"get_force_reload_script_load": Callable(self, "get_force_reload_script_load"),
			"instantiate_executor": Callable(self, "instantiate_executor"),
			"extract_tool_definitions": Callable(self, "extract_tool_definitions"),
			"record_load_error": Callable(self, "record_load_error"),
			"dispose_executor": Callable(self, "dispose_executor"),
			"failure": Callable(self, "failure")
		}

	func get_entries_by_category() -> Dictionary:
		return entries_by_category

	func get_runtime_by_category() -> Dictionary:
		return runtime_by_category

	func get_tool_definitions_by_category() -> Dictionary:
		return definitions_by_category

	func get_force_reload_script_load() -> bool:
		return force_reload_script_load

	func instantiate_executor(category: String, force_reload: bool, reason: String) -> Dictionary:
		instantiate_calls.append({
			"category": category,
			"force_reload": force_reload,
			"reason": reason
		})
		if instantiate_failures.has(category):
			return {
				"success": false,
				"error": str(instantiate_failures.get(category, "failed"))
			}
		var definitions: Array = instantiate_definitions.get(category, [{"name": "%s_probe" % category}]).duplicate(true)
		return {
			"success": true,
			"executor": FakeExecutor.new(definitions)
		}

	func extract_tool_definitions(_category: String, executor) -> Array:
		if executor is FakeExecutor:
			return (executor as FakeExecutor).definitions.duplicate(true)
		return []

	func record_load_error(category: String, path: String, message: String) -> void:
		load_errors.append({
			"category": category,
			"path": path,
			"message": message
		})
		var runtime: Dictionary = runtime_by_category.get(category, {})
		runtime["last_error"] = {"message": message}
		runtime_by_category[category] = runtime

	func dispose_executor(executor) -> void:
		disposed_executors.append(executor)
		if executor != null and executor.has_method("dispose"):
			executor.dispose()

	func failure(error_type: String, category: String, tool_name: String, message: String) -> Dictionary:
		return {
			"success": false,
			"error": message,
			"data": {
				"error_type": error_type,
				"domain": category,
				"tool_name": category if tool_name.is_empty() else "%s_%s" % [category, tool_name]
			}
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var service = RuntimeStateServiceScript.new()

	var cached := FakeRuntimeStateContext.new()
	cached.definitions_by_category = {"system": [{"name": "cached_probe"}]}
	var cached_defs: Array = service.ensure_tool_definitions("system", cached.build())
	if cached_defs.size() != 1 or not cached.instantiate_calls.is_empty():
		return _failure("Runtime state service should return cached definitions without instantiating executors.")

	var definition_failure := FakeRuntimeStateContext.new()
	definition_failure.entries_by_category = {"broken": {"path": "res://addons/broken.gd"}}
	definition_failure.instantiate_failures = {"broken": "compile failed"}
	var failed_defs: Array = service.ensure_tool_definitions("broken", definition_failure.build())
	if not failed_defs.is_empty() or definition_failure.load_errors.is_empty():
		return _failure("Runtime state service should record load errors and cache empty definitions after definition instantiate failures.")
	if str((definition_failure.load_errors[0] as Dictionary).get("path", "")) != "res://addons/broken.gd":
		return _failure("Runtime state service should pass manifest paths to load-error diagnostics.")

	var definitions := FakeRuntimeStateContext.new()
	definitions.instantiate_definitions = {"system": [{"name": "system_probe"}]}
	var system_defs: Array = service.ensure_tool_definitions("system", definitions.build())
	if str((system_defs[0] as Dictionary).get("name", "")) != "system_probe":
		return _failure("Runtime state service should extract definitions from newly instantiated executors.")
	if not definitions.definitions_by_category.has("system"):
		return _failure("Runtime state service should write extracted definitions back to shared state.")

	var preload_context := FakeRuntimeStateContext.new()
	preload_context.runtime_by_category = {"system": {"version": 2, "load_count": 4}}
	preload_context.instantiate_definitions = {"system": [{"name": "loaded_probe"}]}
	var preload_result: Dictionary = service.ensure_runtime_loaded("system", "preload", preload_context.build())
	if not bool(preload_result.get("success", false)):
		return _failure("Runtime state service should load missing runtimes.")
	var preload_runtime: Dictionary = preload_context.runtime_by_category.get("system", {})
	if int(preload_runtime.get("version", 0)) != 3 or int(preload_runtime.get("load_count", 0)) != 5:
		return _failure("Runtime state service should increment runtime version and load_count.")
	if str(preload_runtime.get("state", "")) != "loaded":
		return _failure("Runtime state service should mark preload runtimes as loaded.")

	var on_demand := FakeRuntimeStateContext.new()
	var on_demand_result: Dictionary = service.ensure_runtime_loaded("project", "tool_call", on_demand.build())
	if not bool(on_demand_result.get("success", false)):
		return _failure("Runtime state service should load on-demand tool_call runtimes.")
	if str((on_demand.runtime_by_category.get("project", {}) as Dictionary).get("state", "")) != "loaded_on_demand":
		return _failure("Runtime state service should preserve loaded_on_demand state for tool calls.")

	var force_reload := FakeRuntimeStateContext.new()
	force_reload.force_reload_script_load = true
	var force_result: Dictionary = service.ensure_runtime_loaded("editor", "preload", force_reload.build())
	if not bool(force_result.get("success", false)) or force_reload.instantiate_calls.size() != 2:
		return _failure("Runtime state service should retry runtime instantiation with force_reload when requested.")
	if not bool((force_reload.instantiate_calls[1] as Dictionary).get("force_reload", false)):
		return _failure("Runtime state service should pass force_reload=true on the second instantiate attempt.")

	var runtime_failure := FakeRuntimeStateContext.new()
	runtime_failure.instantiate_failures = {"debug": "load failed"}
	var runtime_failure_result: Dictionary = service.ensure_runtime_loaded("debug", "tool_call", runtime_failure.build())
	if bool(runtime_failure_result.get("success", true)):
		return _failure("Runtime state service should return loader failure envelopes for runtime load failures.")
	if str(((runtime_failure_result.get("data", {}) as Dictionary).get("error_type", ""))) != "tool_load_failed":
		return _failure("Runtime state service should preserve runtime load failure error types.")

	var unload := FakeRuntimeStateContext.new()
	var executor := FakeExecutor.new([{"name": "debug_probe"}])
	unload.runtime_by_category = {"debug": {"instance": executor, "state": "loaded", "version": 1}}
	service.unload_runtime("debug", "disabled_tools_changed", unload.build())
	var unloaded_runtime: Dictionary = unload.runtime_by_category.get("debug", {})
	if unloaded_runtime.get("instance", "still-present") != null:
		return _failure("Runtime state service should clear executor instances on unload.")
	if str(unloaded_runtime.get("state", "")) != "definitions_only" or str(unloaded_runtime.get("last_unloaded_reason", "")) != "disabled_tools_changed":
		return _failure("Runtime state service should preserve definitions-only unload metadata.")
	if unload.disposed_executors.size() != 1 or not executor.disposed:
		return _failure("Runtime state service should dispose unloaded executor instances.")

	return {
		"name": "tool_loader_runtime_state_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"definition_failure_count": definition_failure.load_errors.size(),
			"force_reload_calls": force_reload.instantiate_calls.size(),
			"disposed_count": unload.disposed_executors.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_runtime_state_service_contracts",
		"success": false,
		"error": message
	}
