@tool
extends RefCounted

## Shared atomic tool bridge for system implementations.
## call_atomic() is the single abstraction point for the v1 Backend Router.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const AtomicBridgeContextResolverScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_context_resolver.gd")
const AtomicBridgeExecutionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_execution_service.gd")

var _runtime_context: Dictionary = {}
var _context_resolver = AtomicBridgeContextResolverScript.new()
var _execution_service = AtomicBridgeExecutionServiceScript.new()


func _init() -> void:
	_execution_service.configure_default(Callable(self, "_build_atomic_runtime_context"))


func success(data = null, message: String = "") -> Dictionary:
	return {"success": true, "data": data, "message": message}


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()
	_execution_service.configure_runtime(_runtime_context)


func get_tool_loader():
	return _context_resolver.get_tool_loader(_runtime_context)


func get_gdscript_lsp_diagnostics_service():
	return _context_resolver.get_gdscript_lsp_diagnostics_service(_runtime_context)


func error(message: String, data = null, hints: Array = []) -> Dictionary:
	var result := {"success": false, "error": message}
	if data != null:
		result["data"] = data
	if not hints.is_empty():
		result["hints"] = hints
	return result


func is_protected_path(path: String) -> bool:
	return _execution_service.is_protected_path(path)


func _is_write_action(args: Dictionary) -> bool:
	return _execution_service.is_write_action(args)


func _is_write_atomic_action(full_name: String, args: Dictionary) -> bool:
	return _execution_service.is_write_atomic_action(full_name, args)


func _is_write_action_name(action: String) -> bool:
	return _execution_service.is_write_action_name(action)


func _infer_write_action_from_atomic_name(full_name: String) -> String:
	return _execution_service.infer_write_action_from_atomic_name(full_name)


func _dispose_executor(executor) -> void:
	_execution_service.dispose_executor(executor)


func _invalidate_atomic_executors() -> void:
	_execution_service.invalidate()


func _cache_atomic_executor_for_test(category: String, executor) -> void:
	_execution_service.cache_executor_for_test(category, executor)


func _get_cached_atomic_executor_count_for_test() -> int:
	return _execution_service.get_cached_executor_count_for_test()


func _find_path_in_args(args: Dictionary) -> String:
	return _execution_service.find_path_in_args(args)


func call_atomic(full_name: String, args: Dictionary = {}) -> Dictionary:
	return _execution_service.call_atomic(full_name, args)


func call_atomic_async(full_name: String, args: Dictionary = {}) -> Dictionary:
	return await _execution_service.call_atomic_async(full_name, args)


func _build_atomic_runtime_context(category: String, _runtime_context_source: Dictionary) -> Dictionary:
	var context := _runtime_context.duplicate()
	context["category"] = category
	var plugin = _resolve_plugin_host(context)
	if plugin != null:
		context["plugin_host"] = plugin
		if not context.has("editor_interface") and plugin.has_method("get_editor_interface"):
			context["editor_interface"] = plugin.get_editor_interface()
	return context


func _resolve_plugin_host(context: Dictionary):
	var plugin = context.get("plugin_host", null)
	if plugin != null and is_instance_valid(plugin):
		return plugin
	var getter = context.get("get_plugin_host", Callable())
	if getter is Callable and getter.is_valid():
		plugin = getter.call()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	var server = context.get("server", null)
	if server != null and is_instance_valid(server) and server.has_method("get_parent"):
		plugin = server.get_parent()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	return null


func extract_data(result: Dictionary) -> Dictionary:
	return _execution_service.extract_data(result)


func extract_array(result: Dictionary, key: String) -> Array:
	return _execution_service.extract_array(result, key)


func collect_files(filter: String) -> Array:
	return _execution_service.collect_files(filter, Callable(self, "call_atomic"))


func collect_file_count(filter: String) -> int:
	return _execution_service.collect_file_count(filter, Callable(self, "call_atomic"))


func collect_file_counts(filters: Array) -> Dictionary:
	return _execution_service.collect_file_counts(filters, Callable(self, "call_atomic"))


func build_issue(severity: String, issue_type: String, message: String, extra: Dictionary = {}) -> Dictionary:
	return _execution_service.build_issue(severity, issue_type, message, extra)


func append_unique_issue(issues: Array, issue: Dictionary) -> void:
	_execution_service.append_unique_issue(issues, issue)


func has_severity(issues: Array, severity: String) -> bool:
	return _execution_service.has_severity(issues, severity)


func normalize_dependency_path(raw_path: String) -> String:
	return _execution_service.normalize_dependency_path(raw_path)


func parse_dependency_reference(raw_path: String, source_path: String = "") -> Dictionary:
	return _execution_service.parse_dependency_reference(raw_path, source_path)


func _normalize_resource_path(path: String, source_path: String = "") -> String:
	return _execution_service.normalize_resource_path(path, source_path)


func _resource_path_exists(path: String) -> bool:
	return _execution_service.resource_path_exists(path)
