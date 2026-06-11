@tool
extends RefCounted

## Shared atomic tool bridge for system implementations.
## call_atomic() is the single abstraction point for the v1 Backend Router.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const AtomicBridgeSupportScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_support.gd")

const EXECUTOR_SCRIPT_PATHS := {
	"project": "res://addons/godot_dotnet_mcp/tools/project/executor.gd",
	"script": "res://addons/godot_dotnet_mcp/tools/script/executor.gd",
	"scene": "res://addons/godot_dotnet_mcp/tools/scene/executor.gd",
	"node": "res://addons/godot_dotnet_mcp/tools/node/executor.gd",
	"editor": "res://addons/godot_dotnet_mcp/tools/editor/executor.gd",
	"resource": "res://addons/godot_dotnet_mcp/tools/resource/executor.gd",
	"debug": "res://addons/godot_dotnet_mcp/tools/debug/executor.gd",
	"dap": "res://addons/godot_dotnet_mcp/tools/dap/executor.gd",
	"filesystem": "res://addons/godot_dotnet_mcp/tools/filesystem/executor.gd",
	"runtime": "res://addons/godot_dotnet_mcp/tools/runtime/executor.gd"
}
const EXECUTOR_DEPENDENCY_PATHS := {
	"editor": ["res://addons/godot_dotnet_mcp/tools/editor_tools.gd"]
}
const GDScriptLspDiagnosticsService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")

var _atomic_executors := {}
var _runtime_context: Dictionary = {}
var _support = AtomicBridgeSupportScript.new()


func success(data = null, message: String = "") -> Dictionary:
	return {"success": true, "data": data, "message": message}


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()
	_atomic_executors.clear()


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
	if executor == null:
		return
	if executor.has_method("dispose"):
		executor.dispose()
	if executor.has_method("shutdown"):
		executor.shutdown()


func _invalidate_atomic_executors() -> void:
	for executor in _atomic_executors.values():
		_dispose_executor(executor)
	_atomic_executors.clear()


func _find_path_in_args(args: Dictionary) -> String:
	return _support.find_path_in_args(args)


func call_atomic(full_name: String, args: Dictionary = {}) -> Dictionary:
	MCPDebugBuffer.record("debug", "atomic",
		"%s action=%s" % [full_name, str(args.get("action", ""))])
	# Write protection: block writes to plugin directory unless explicitly authorized
	var write_action := _is_write_atomic_action(full_name, args)
	if write_action:
		var target_path := _find_path_in_args(args)
		if is_protected_path(target_path) and not bool(args.get("allow_plugin_write", false)):
			MCPDebugBuffer.record("warning", "atomic",
				"Write blocked on protected path: %s (tool: %s)" % [target_path, full_name])
			return error("Protected path: cannot write to MCP plugin directory via system tools. Use plugin_developer tools with explicit authorization.")
	var parts := full_name.split("_", false, 1)
	if parts.size() < 2:
		MCPDebugBuffer.record("debug", "atomic", "Invalid atomic name: %s" % full_name)
		return error("Invalid atomic tool name: %s" % full_name)
	var category := parts[0]
	var tool_name := parts[1]
	if not EXECUTOR_SCRIPT_PATHS.has(category):
		MCPDebugBuffer.record("debug", "atomic",
			"Unknown category: %s (from %s)" % [category, full_name])
		return error("Unknown atomic category: %s (from %s)" % [category, full_name])

	var executor = _atomic_executors.get(category)
	if executor == null or not is_instance_valid(executor):
		var path := str(EXECUTOR_SCRIPT_PATHS[category])
		for dependency_path in EXECUTOR_DEPENDENCY_PATHS.get(category, []):
			ResourceLoader.load(str(dependency_path), "", ResourceLoader.CACHE_MODE_REPLACE)
		var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if script == null:
			MCPDebugBuffer.record("error", "atomic",
				"Failed to load executor for: %s (path: %s)" % [category, path])
			return error("Failed to load atomic executor: %s" % path)
		if _atomic_executors.has(category):
			_dispose_executor(_atomic_executors[category])
		_atomic_executors[category] = script.new()
		executor = _atomic_executors[category]
		if executor == null or not executor.has_method("execute"):
			MCPDebugBuffer.record("error", "atomic", "Executor not available: %s" % category)
			return error("Atomic executor not available: %s" % category)
		_configure_executor(executor, category)

	var result: Dictionary = executor.execute(tool_name, args)
	if write_action and bool(result.get("success", false)):
		_invalidate_atomic_executors()
	return result


func call_atomic_async(full_name: String, args: Dictionary = {}) -> Dictionary:
	MCPDebugBuffer.record("debug", "atomic",
		"%s action=%s" % [full_name, str(args.get("action", ""))])
	var write_action := _is_write_atomic_action(full_name, args)
	if write_action:
		var target_path := _find_path_in_args(args)
		if is_protected_path(target_path) and not bool(args.get("allow_plugin_write", false)):
			MCPDebugBuffer.record("warning", "atomic",
				"Write blocked on protected path: %s (tool: %s)" % [target_path, full_name])
			return error("Protected path: cannot write to MCP plugin directory via system tools. Use plugin_developer tools with explicit authorization.")
	var parts := full_name.split("_", false, 1)
	if parts.size() < 2:
		MCPDebugBuffer.record("debug", "atomic", "Invalid atomic name: %s" % full_name)
		return error("Invalid atomic tool name: %s" % full_name)
	var category := parts[0]
	var tool_name := parts[1]
	if not EXECUTOR_SCRIPT_PATHS.has(category):
		MCPDebugBuffer.record("debug", "atomic",
			"Unknown category: %s (from %s)" % [category, full_name])
		return error("Unknown atomic category: %s (from %s)" % category)

	var executor = _atomic_executors.get(category)
	if executor == null or not is_instance_valid(executor):
		var path := str(EXECUTOR_SCRIPT_PATHS[category])
		for dependency_path in EXECUTOR_DEPENDENCY_PATHS.get(category, []):
			ResourceLoader.load(str(dependency_path), "", ResourceLoader.CACHE_MODE_REPLACE)
		var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if script == null:
			MCPDebugBuffer.record("error", "atomic",
				"Failed to load executor for: %s (path: %s)" % [category, path])
			return error("Failed to load atomic executor: %s" % path)
		if _atomic_executors.has(category):
			_dispose_executor(_atomic_executors[category])
		_atomic_executors[category] = script.new()
		executor = _atomic_executors[category]
		if executor == null:
			MCPDebugBuffer.record("error", "atomic", "Executor not available: %s" % category)
			return error("Atomic executor not available: %s" % category)
		_configure_executor(executor, category)
	var result: Dictionary
	if executor.has_method("execute_async"):
		result = await executor.execute_async(tool_name, args)
		if write_action and bool(result.get("success", false)):
			_invalidate_atomic_executors()
		return result
	if executor.has_method("execute"):
		result = executor.execute(tool_name, args)
		if write_action and bool(result.get("success", false)):
			_invalidate_atomic_executors()
		return result
	return error("Atomic executor does not expose execute/execute_async: %s" % category)


func _configure_executor(executor, category: String) -> void:
	var context := _runtime_context.duplicate()
	context["category"] = category
	var plugin = _resolve_plugin_host(context)
	if plugin != null:
		context["plugin_host"] = plugin
		if not context.has("editor_interface") and plugin.has_method("get_editor_interface"):
			context["editor_interface"] = plugin.get_editor_interface()
	if executor.has_method("configure_runtime"):
		executor.configure_runtime(context.duplicate())
	if executor.has_method("configure_context"):
		executor.configure_context(context.duplicate())


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
