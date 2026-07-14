@tool
extends RefCounted

## Runtime service for AtomicBridge executor lifecycle and dispatch.
## AtomicBridge remains the public facade; this service owns executor caching.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const AtomicBridgeExecutorManifest = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_executor_manifest.gd")

var _executor_script_paths: Dictionary = {}
var _executor_dependency_paths: Dictionary = {}
var _runtime_context: Dictionary = {}
var _executors: Dictionary = {}
var _runtime_context_provider := Callable()


func configure(executor_script_paths: Dictionary, executor_dependency_paths: Dictionary, runtime_context_provider: Callable = Callable()) -> void:
	_executor_script_paths = executor_script_paths.duplicate(true)
	_executor_dependency_paths = executor_dependency_paths.duplicate(true)
	_runtime_context_provider = runtime_context_provider
	invalidate()


func configure_default(runtime_context_provider: Callable = Callable()) -> void:
	configure(
		AtomicBridgeExecutorManifest.get_executor_script_paths(),
		AtomicBridgeExecutorManifest.get_executor_dependency_paths(),
		runtime_context_provider
	)


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)
	invalidate()


func invalidate() -> void:
	for executor in _executors.values():
		dispose_executor(executor)
	_executors.clear()


func has_category(category: String) -> bool:
	return _executor_script_paths.has(category)


func get_executor(category: String) -> Dictionary:
	if not has_category(category):
		MCPDebugBuffer.record("debug", "atomic", "Unknown category: %s" % category)
		return {"success": false, "error": "Unknown atomic category: %s" % category}

	var executor = _executors.get(category)
	if executor != null and is_instance_valid(executor):
		return {"success": true, "executor": executor}

	var path := str(_executor_script_paths[category])
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		MCPDebugBuffer.record("error", "atomic", "Failed to load executor for: %s (path: %s)" % [category, path])
		return {"success": false, "error": "Failed to load atomic executor: %s" % path}
	for dependency_path in _executor_dependency_paths.get(category, []):
		ResourceLoader.load(str(dependency_path), "", ResourceLoader.CACHE_MODE_REPLACE)
	var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if script == null:
		MCPDebugBuffer.record("error", "atomic", "Failed to load executor for: %s (path: %s)" % [category, path])
		return {"success": false, "error": "Failed to load atomic executor: %s" % path}

	if _executors.has(category):
		dispose_executor(_executors[category])
	_executors[category] = script.new()
	executor = _executors[category]
	if executor == null:
		MCPDebugBuffer.record("error", "atomic", "Executor not available: %s" % category)
		return {"success": false, "error": "Atomic executor not available: %s" % category}
	if not executor.has_method("execute") and not executor.has_method("execute_async"):
		MCPDebugBuffer.record("error", "atomic", "Executor not callable: %s" % category)
		return {"success": false, "error": "Atomic executor not available: %s" % category}

	_configure_executor(executor, category)
	return {"success": true, "executor": executor}


func dispatch(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	var executor_result := get_executor(category)
	if not bool(executor_result.get("success", false)):
		return {"success": false, "error": str(executor_result.get("error", "Atomic executor unavailable"))}
	var executor = executor_result.get("executor", null)
	if executor == null or not executor.has_method("execute"):
		return {"success": false, "error": "Atomic executor not available: %s" % category}
	return executor.execute(tool_name, args)


func dispatch_async(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	var executor_result := get_executor(category)
	if not bool(executor_result.get("success", false)):
		return {"success": false, "error": str(executor_result.get("error", "Atomic executor unavailable"))}
	var executor = executor_result.get("executor", null)
	if executor == null:
		return {"success": false, "error": "Atomic executor not available: %s" % category}
	if executor.has_method("execute_async"):
		return await executor.execute_async(tool_name, args)
	if executor.has_method("execute"):
		return executor.execute(tool_name, args)
	return {"success": false, "error": "Atomic executor does not expose execute/execute_async: %s" % category}


func dispose_executor(executor) -> void:
	if executor == null:
		return
	if executor.has_method("dispose"):
		executor.dispose()
	if executor.has_method("shutdown"):
		executor.shutdown()


func cache_executor_for_test(category: String, executor) -> void:
	if _executors.has(category):
		dispose_executor(_executors[category])
	_executors[category] = executor


func get_cached_executor_count_for_test() -> int:
	return _executors.size()


func _configure_executor(executor, category: String) -> void:
	var context := _build_runtime_context(category)
	if executor.has_method("configure_runtime"):
		executor.configure_runtime(context.duplicate(true))
	if executor.has_method("configure_context"):
		executor.configure_context(context.duplicate(true))


func _build_runtime_context(category: String) -> Dictionary:
	if _runtime_context_provider.is_valid():
		var provided = _runtime_context_provider.call(category, _runtime_context)
		if provided is Dictionary:
			return (provided as Dictionary).duplicate(true)
	var context := _runtime_context.duplicate(true)
	context["category"] = category
	return context
