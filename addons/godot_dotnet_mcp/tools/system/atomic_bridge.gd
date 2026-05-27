@tool
extends RefCounted

## Shared atomic tool bridge for system implementations.
## call_atomic() is the single abstraction point for the v1 Backend Router.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

## Paths protected from write operations via system/user tools.
## Write ops targeting these paths require explicit allow_plugin_write=true in args.
const PLUGIN_PROTECTED_PATHS: Array = [
	"res://addons/godot_dotnet_mcp/",
]

## Custom tools directory is intentionally excluded from protection
## (managed via UserToolService, not direct atomic writes).
const PLUGIN_CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools/"

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
	"editor": ["res://addons/godot_dotnet_mcp/tools/editor_tools.gd"],
	"debug": ["res://addons/godot_dotnet_mcp/tools/debug_tools.gd"]
}
const GDScriptLspDiagnosticsService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")

const PROJECT_FILE_PATTERNS := {
	"gd_scripts": "*.gd",
	"cs_scripts": "*.cs",
	"scenes": "*.tscn",
	"resources_tres": "*.tres",
	"resources_res": "*.res"
}

var _atomic_executors := {}
var _runtime_context: Dictionary = {}


func success(data = null, message: String = "") -> Dictionary:
	return {"success": true, "data": data, "message": message}


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)
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
	if path.is_empty():
		return false
	# Custom tools dir is managed via UserToolService, not blocked here
	if path.begins_with(PLUGIN_CUSTOM_TOOLS_DIR):
		return false
	for protected in PLUGIN_PROTECTED_PATHS:
		if path.begins_with(str(protected)):
			return true
	return false


func _is_write_action(args: Dictionary) -> bool:
	var action := str(args.get("action", ""))
	for keyword in ["write", "create", "delete", "edit", "save", "patch", "set"]:
		if action.contains(keyword):
			return true
	return false


func _find_path_in_args(args: Dictionary) -> String:
	for key in ["path", "file_path", "scene_path", "script_path", "target"]:
		var val = args.get(key, "")
		if val is String and not str(val).is_empty():
			return str(val)
	return ""


func call_atomic(full_name: String, args: Dictionary = {}) -> Dictionary:
	MCPDebugBuffer.record("debug", "atomic",
		"%s action=%s" % [full_name, str(args.get("action", ""))])
	# Write protection: block writes to plugin directory unless explicitly authorized
	if _is_write_action(args):
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
	var path := str(EXECUTOR_SCRIPT_PATHS[category])
	for dependency_path in EXECUTOR_DEPENDENCY_PATHS.get(category, []):
		ResourceLoader.load(str(dependency_path), "", ResourceLoader.CACHE_MODE_REPLACE)
	var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if script == null:
		MCPDebugBuffer.record("error", "atomic",
			"Failed to load executor for: %s (path: %s)" % [category, path])
		return error("Failed to load atomic executor: %s" % path)
	if _atomic_executors.has(category):
		var old_executor = _atomic_executors[category]
		if old_executor != null:
			if old_executor.has_method("dispose"):
				old_executor.dispose()
			if old_executor.has_method("shutdown"):
				old_executor.shutdown()
	_atomic_executors[category] = script.new()
	var executor = _atomic_executors[category]
	if executor == null or not executor.has_method("execute"):
		MCPDebugBuffer.record("error", "atomic", "Executor not available: %s" % category)
		return error("Atomic executor not available: %s" % category)
	_configure_executor(executor, category)
	return executor.execute(tool_name, args)


func call_atomic_async(full_name: String, args: Dictionary = {}) -> Dictionary:
	MCPDebugBuffer.record("debug", "atomic",
		"%s action=%s" % [full_name, str(args.get("action", ""))])
	if _is_write_action(args):
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
	var path := str(EXECUTOR_SCRIPT_PATHS[category])
	for dependency_path in EXECUTOR_DEPENDENCY_PATHS.get(category, []):
		ResourceLoader.load(str(dependency_path), "", ResourceLoader.CACHE_MODE_REPLACE)
	var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if script == null:
		MCPDebugBuffer.record("error", "atomic",
			"Failed to load executor for: %s (path: %s)" % [category, path])
		return error("Failed to load atomic executor: %s" % path)
	if _atomic_executors.has(category):
		var old_executor = _atomic_executors[category]
		if old_executor != null:
			if old_executor.has_method("dispose"):
				old_executor.dispose()
			if old_executor.has_method("shutdown"):
				old_executor.shutdown()
	_atomic_executors[category] = script.new()
	var executor = _atomic_executors[category]
	if executor == null:
		MCPDebugBuffer.record("error", "atomic", "Executor not available: %s" % category)
		return error("Atomic executor not available: %s" % category)
	_configure_executor(executor, category)
	if executor.has_method("execute_async"):
		return await executor.execute_async(tool_name, args)
	if executor.has_method("execute"):
		return executor.execute(tool_name, args)
	return error("Atomic executor does not expose execute/execute_async: %s" % category)


func _configure_executor(executor, category: String) -> void:
	var context := _runtime_context.duplicate(true)
	context["category"] = category
	var plugin = _resolve_plugin_host(context)
	if plugin != null:
		context["plugin_host"] = plugin
		if not context.has("editor_interface") and plugin.has_method("get_editor_interface"):
			context["editor_interface"] = plugin.get_editor_interface()
	if executor.has_method("configure_runtime"):
		executor.configure_runtime(context.duplicate(true))
	if executor.has_method("configure_context"):
		executor.configure_context(context.duplicate(true))


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


func build_issue(severity: String, issue_type: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var issue := {
		"severity": severity,
		"type": issue_type,
		"message": message
	}
	for k in extra.keys():
		issue[k] = extra[k]
	return issue


func append_unique_issue(issues: Array, issue: Dictionary) -> void:
	if not (issue is Dictionary):
		return
	var msg := str(issue.get("message", ""))
	var tp := str(issue.get("type", ""))
	for existing in issues:
		if not (existing is Dictionary):
			continue
		if str(existing.get("message", "")) == msg and str(existing.get("type", "")) == tp:
			return
	issues.append(issue)


func has_severity(issues: Array, severity: String) -> bool:
	for issue in issues:
		if issue is Dictionary and str(issue.get("severity", "")) == severity:
			return true
	return false


func normalize_dependency_path(raw_path: String) -> String:
	var parsed := parse_dependency_reference(raw_path)
	return str(parsed.get("normalized_path", ""))


func parse_dependency_reference(raw_path: String, source_path: String = "") -> Dictionary:
	var raw := raw_path.strip_edges()
	var result := {
		"raw": raw,
		"uid": "",
		"type_hint": "",
		"declared_path": "",
		"normalized_path": "",
		"resolved_uid_path": "",
		"uid_exists": false,
		"path_exists": false,
		"has_uid_path_pair": false,
		"consistency": "unknown",
		"risk": "none",
		"hint": ""
	}
	if raw.is_empty():
		return result

	var primary := raw
	var declared := ""
	var type_hint := ""
	var parts := raw.split("::", true)
	if parts.size() >= 3:
		primary = str(parts[0]).strip_edges()
		type_hint = str(parts[1]).strip_edges()
		declared = str(parts[2]).strip_edges()
		result["has_uid_path_pair"] = primary.begins_with("uid://") and not declared.is_empty()
	elif raw.begins_with("uid://"):
		primary = raw
	else:
		declared = raw

	if primary.begins_with("uid://"):
		result["uid"] = primary
		var uid_id := ResourceUID.text_to_id(primary)
		if uid_id != ResourceUID.INVALID_ID and ResourceUID.has_id(uid_id):
			result["uid_exists"] = true
			result["resolved_uid_path"] = _normalize_resource_path(ResourceUID.get_id_path(uid_id), source_path)
	if declared.is_empty() and not primary.begins_with("uid://"):
		declared = primary

	var normalized_declared := _normalize_resource_path(declared, source_path)
	result["declared_path"] = normalized_declared
	result["type_hint"] = type_hint
	var resolved_uid := str(result.get("resolved_uid_path", ""))
	result["normalized_path"] = resolved_uid if not resolved_uid.is_empty() else normalized_declared
	result["path_exists"] = _resource_path_exists(normalized_declared)

	if not resolved_uid.is_empty() and not normalized_declared.is_empty():
		if resolved_uid == normalized_declared:
			result["consistency"] = "matched"
		elif _resource_path_exists(resolved_uid) and _resource_path_exists(normalized_declared):
			result["consistency"] = "uid_path_mismatch"
			result["risk"] = "warning"
			result["hint"] = "UID resolves to a different existing path than the fallback path; re-save or normalize the resource reference."
		elif _resource_path_exists(resolved_uid):
			result["consistency"] = "stale_fallback_path"
			result["risk"] = "warning"
			result["hint"] = "UID resolves successfully but the fallback path is stale; re-save the scene/resource to refresh the path."
		elif _resource_path_exists(normalized_declared):
			result["consistency"] = "stale_uid"
			result["risk"] = "warning"
			result["hint"] = "Fallback path exists but UID no longer resolves; reimport or re-save to refresh the UID cache."
		else:
			result["consistency"] = "missing_uid_and_path"
			result["risk"] = "error"
			result["hint"] = "Neither UID nor fallback path can be resolved; fix the reference path or regenerate the resource UID."
	elif primary.begins_with("uid://") and not bool(result.get("uid_exists", false)):
		if _resource_path_exists(normalized_declared):
			result["consistency"] = "stale_uid"
			result["risk"] = "warning"
			result["hint"] = "Fallback path exists but UID is unknown; reimport or re-save to refresh the UID cache."
		else:
			result["consistency"] = "missing_uid_and_path"
			result["risk"] = "error"
			result["hint"] = "Neither UID nor fallback path can be resolved; fix the reference path or regenerate the resource UID."
	elif not normalized_declared.is_empty():
		if _resource_path_exists(normalized_declared):
			result["consistency"] = "path_exists"
		else:
			result["consistency"] = "missing_path"
			result["risk"] = "error"
			result["hint"] = "Referenced path does not exist; fix the resource path or restore the file."
	return result


func _normalize_resource_path(path: String, source_path: String = "") -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return trimmed.simplify_path()
	if not source_path.is_empty() and not trimmed.contains("://") and trimmed.is_relative_path():
		return source_path.get_base_dir().path_join(trimmed).simplify_path()
	return trimmed


func _resource_path_exists(path: String) -> bool:
	if path.is_empty() or path.begins_with("uid://"):
		return false
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)
