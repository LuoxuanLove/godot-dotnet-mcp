@tool
extends RefCounted

## Shared atomic tool bridge for intelligence implementations.
## call_atomic() is the single abstraction point for the v1 Backend Router.

## Paths protected from write operations via intelligence/user tools.
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
	"filesystem": "res://addons/godot_dotnet_mcp/tools/filesystem/executor.gd"
}

const PROJECT_FILE_PATTERNS := {
	"gd_scripts": "*.gd",
	"cs_scripts": "*.cs",
	"scenes": "*.tscn",
	"resources_tres": "*.tres",
	"resources_res": "*.res"
}

var _atomic_executors := {}


func success(data = null, message: String = "") -> Dictionary:
	return {"success": true, "data": data, "message": message}


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
	MCPDebugBuffer.record("trace", "atomic",
		"%s action=%s" % [full_name, str(args.get("action", ""))])
	# Write protection: block writes to plugin directory unless explicitly authorized
	if _is_write_action(args):
		var target_path := _find_path_in_args(args)
		if is_protected_path(target_path) and not bool(args.get("allow_plugin_write", false)):
			MCPDebugBuffer.record("warning", "atomic",
				"Write blocked on protected path: %s (tool: %s)" % [target_path, full_name])
			return error("Protected path: cannot write to MCP plugin directory via intelligence tools. Use plugin_developer tools with explicit authorization.")
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
	if not _atomic_executors.has(category):
		var path := str(EXECUTOR_SCRIPT_PATHS[category])
		var script = load(path)
		if script == null:
			MCPDebugBuffer.record("error", "atomic",
				"Failed to load executor for: %s (path: %s)" % [category, path])
			return error("Failed to load atomic executor: %s" % path)
		_atomic_executors[category] = script.new()
	var executor = _atomic_executors[category]
	if executor == null or not executor.has_method("execute"):
		MCPDebugBuffer.record("error", "atomic", "Executor not available: %s" % category)
		return error("Atomic executor not available: %s" % category)
	return executor.execute(tool_name, args)


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
	var result := call_atomic("filesystem_directory", {"action": "get_files", "filter": filter, "recursive": true})
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
	if raw_path.is_empty():
		return ""
	if raw_path.begins_with("res://") or raw_path.begins_with("user://"):
		return raw_path
	if raw_path.begins_with("uid://"):
		return raw_path
	return ""
