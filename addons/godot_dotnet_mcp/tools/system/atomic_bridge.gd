@tool
extends RefCounted

## Shared atomic tool bridge for system implementations.
## call_atomic() is the single abstraction point for the v1 Backend Router.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const AtomicBridgeSupportScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_support.gd")
const AtomicBridgeRuntimeScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_runtime.gd")
const AtomicBridgeDispatchServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_dispatch_service.gd")

const GDScriptLspDiagnosticsService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")

var _runtime_context: Dictionary = {}
var _support = AtomicBridgeSupportScript.new()
var _runtime = AtomicBridgeRuntimeScript.new()
var _dispatch_service = AtomicBridgeDispatchServiceScript.new()


func _init() -> void:
	_runtime.configure_default(Callable(self, "_build_atomic_runtime_context"))


func success(data = null, message: String = "") -> Dictionary:
	return {"success": true, "data": data, "message": message}


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()
	_runtime.configure_runtime(_runtime_context)


func get_tool_loader():
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("get_tool_loader"):
			var loader = runtime_bridge.get_tool_loader()
			if loader != null:
				return loader
	return _runtime_context.get("tool_loader", null)


func get_gdscript_lsp_diagnostics_service():
	var loader = get_tool_loader()
	if loader != null and loader.has_method("get_gdscript_lsp_diagnostics_service"):
		var loader_service = loader.get_gdscript_lsp_diagnostics_service()
		if loader_service != null:
			return loader_service
	if Engine.has_singleton("MCPRuntimeBridge"):
		var runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
		if runtime_bridge != null and runtime_bridge.has_method("get_gdscript_lsp_diagnostics_service"):
			var service = runtime_bridge.get_gdscript_lsp_diagnostics_service()
			if service != null:
				return service
	return GDScriptLspDiagnosticsService.get_singleton()


func error(message: String, data = null, hints: Array = []) -> Dictionary:
	var result := {"success": false, "error": message}
	if data != null:
		result["data"] = data
	if not hints.is_empty():
		result["hints"] = hints
	return result


func is_protected_path(path: String) -> bool:
	return _support.is_protected_path(path)


func _is_write_action(args: Dictionary) -> bool:
	return _support.is_write_action(args)


func _is_write_atomic_action(full_name: String, args: Dictionary) -> bool:
	return _support.is_write_atomic_action(full_name, args)


func _is_write_action_name(action: String) -> bool:
	return _support.is_write_action_name(action)


func _infer_write_action_from_atomic_name(full_name: String) -> String:
	return _support.infer_write_action_from_atomic_name(full_name)


func _dispose_executor(executor) -> void:
	_runtime.dispose_executor(executor)


func _invalidate_atomic_executors() -> void:
	_runtime.invalidate()


func _cache_atomic_executor_for_test(category: String, executor) -> void:
	_runtime.cache_executor_for_test(category, executor)


func _get_cached_atomic_executor_count_for_test() -> int:
	return _runtime.get_cached_executor_count_for_test()


func _find_path_in_args(args: Dictionary) -> String:
	return _support.find_path_in_args(args)


func call_atomic(full_name: String, args: Dictionary = {}) -> Dictionary:
	return _dispatch_service.call_atomic(full_name, args, _support, _runtime)


func call_atomic_async(full_name: String, args: Dictionary = {}) -> Dictionary:
	return await _dispatch_service.call_atomic_async(full_name, args, _support, _runtime)


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
	var d = result.get("data", {})
	if d is Dictionary:
		return d
	return {}


func extract_array(result: Dictionary, key: String) -> Array:
	var d := extract_data(result)
	var v = d.get(key, [])
	if v is Array:
		return v
	return []


func collect_files(filter: String) -> Array:
	var result := call_atomic("filesystem_directory", {"action": "get_files", "path": "res://", "filter": filter, "recursive": true})
	var files = extract_array(result, "files")
	return files


func collect_file_count(filter: String) -> int:
	var result := call_atomic("filesystem_directory", {"action": "get_files", "path": "res://", "filter": filter, "recursive": true, "count_only": true})
	var data := extract_data(result)
	return int(data.get("count", 0))


func collect_file_counts(filters: Array) -> Dictionary:
	var result := call_atomic("filesystem_directory", {"action": "get_files", "path": "res://", "filters": filters, "recursive": true, "count_only": true})
	var data := extract_data(result)
	var counts_raw = data.get("counts_by_filter", {})
	if counts_raw is Dictionary:
		return (counts_raw as Dictionary).duplicate(true)
	return {}


func build_issue(severity: String, issue_type: String, message: String, extra: Dictionary = {}) -> Dictionary:
	return _support.build_issue(severity, issue_type, message, extra)


func append_unique_issue(issues: Array, issue: Dictionary) -> void:
	_support.append_unique_issue(issues, issue)


func has_severity(issues: Array, severity: String) -> bool:
	return _support.has_severity(issues, severity)


func normalize_dependency_path(raw_path: String) -> String:
	return _support.normalize_dependency_path(raw_path)


func parse_dependency_reference(raw_path: String, source_path: String = "") -> Dictionary:
	return _support.parse_dependency_reference(raw_path, source_path)


func _normalize_resource_path(path: String, source_path: String = "") -> String:
	return _support.normalize_resource_path(path, source_path)


func _resource_path_exists(path: String) -> bool:
	return _support.resource_path_exists(path)
