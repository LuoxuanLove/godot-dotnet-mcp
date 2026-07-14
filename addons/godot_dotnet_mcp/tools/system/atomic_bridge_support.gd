@tool
extends RefCounted

## Stateless support helpers for AtomicBridge.
## Kept separate from executor loading so the bridge can shrink into a facade.

const PLUGIN_PROTECTED_PATHS: Array = [
	"res://addons/godot_dotnet_mcp/",
]
const MCPFileUtils = preload("res://addons/godot_dotnet_mcp/tools/mcp_file_utils.gd")

## Custom tools are managed via UserToolService, not blocked by atomic writes.
const PLUGIN_CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools/"
var _resource_path_utils = MCPFileUtils.new()

const WRITE_ACTIONS := {
	"add": true,
	"add_autoload": true,
	"add_export": true,
	"add_field": true,
	"add_function": true,
	"add_method": true,
	"add_node": true,
	"add_signal": true,
	"add_variable": true,
	"append": true,
	"attach_script": true,
	"capture": true,
	"clear": true,
	"cleanup_capture_cache": true,
	"cleanup_legacy_cache": true,
	"copy": true,
	"create": true,
	"delete": true,
	"delete_member": true,
	"disable": true,
	"edit": true,
	"enable": true,
	"ensure_layout": true,
	"find_and_replace": true,
	"full_reload_plugin": true,
	"move": true,
	"play_custom": true,
	"play_main": true,
	"reimport": true,
	"remove": true,
	"remove_autoload": true,
	"remove_member": true,
	"rename": true,
	"rename_member": true,
	"reorder": true,
	"reorder_node": true,
	"reparent": true,
	"reparent_node": true,
	"patch": true,
	"replace_function_body": true,
	"replace_method_body": true,
	"save": true,
	"save_as": true,
	"scan": true,
	"select_item": true,
	"select_popup_menu_item": true,
	"set": true,
	"set_control_text": true,
	"set_popup_text": true,
	"set_property": true,
	"set_setting": true,
	"set_source": true,
	"set_transform": true,
	"set_value": true,
	"start_sync": true,
	"stop": true,
	"update_property": true,
	"write": true
}


func is_protected_path(path: String) -> bool:
	if path.is_empty():
		return false
	var normalized := path.replace("\\", "/").simplify_path()
	var normalized_custom_tools := PLUGIN_CUSTOM_TOOLS_DIR.trim_suffix("/").simplify_path() + "/"
	if OS.get_name() == "Windows":
		normalized = normalized.to_lower()
		normalized_custom_tools = normalized_custom_tools.to_lower()
	if normalized.begins_with(normalized_custom_tools):
		return false
	for protected in PLUGIN_PROTECTED_PATHS:
		var normalized_protected := str(protected).trim_suffix("/").simplify_path()
		if OS.get_name() == "Windows":
			normalized_protected = normalized_protected.to_lower()
		if normalized == normalized_protected or normalized.begins_with(normalized_protected + "/"):
			return true
	return false


func is_write_action(args: Dictionary) -> bool:
	return is_write_action_name(str(args.get("action", "")).strip_edges())


func is_write_atomic_action(full_name: String, args: Dictionary) -> bool:
	var action := str(args.get("action", "")).strip_edges()
	if action.is_empty():
		action = infer_write_action_from_atomic_name(full_name)
	return is_write_action_name(action)


func is_write_action_name(action: String) -> bool:
	return WRITE_ACTIONS.has(action)


func infer_write_action_from_atomic_name(full_name: String) -> String:
	if full_name.begins_with("script_edit_"):
		return "write"
	return ""


func find_path_in_args(args: Dictionary) -> String:
	for key in ["path", "file_path", "scene_path", "script_path", "resource_path", "source", "dest", "target", "new_parent"]:
		var val = args.get(key, "")
		if val is String and not str(val).is_empty():
			return str(val)
	var paths = args.get("paths", [])
	if paths is Array:
		for val in paths:
			if val is String and not str(val).is_empty():
				return str(val)
	return ""


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
			result["resolved_uid_path"] = normalize_resource_path(ResourceUID.get_id_path(uid_id), source_path)
	if declared.is_empty() and not primary.begins_with("uid://"):
		declared = primary

	var normalized_declared := normalize_resource_path(declared, source_path)
	result["declared_path"] = normalized_declared
	result["type_hint"] = type_hint
	if not normalized_declared.is_empty() and not normalized_declared.begins_with("uid://"):
		var path_guard: Dictionary = _resource_path_utils.validate_project_path(normalized_declared, false)
		if not bool(path_guard.get("success", false)):
			result["normalized_path"] = normalized_declared
			result["path_exists"] = false
			result["consistency"] = "invalid_path"
			result["risk"] = "error"
			result["hint"] = "Referenced fallback path must stay inside res:// and must not traverse symlink, junction, or reparse-point segments."
			result["error_code"] = str(path_guard.get("error_code", path_guard.get("data", {}).get("code", "")))
			return result
		normalized_declared = str(path_guard.get("path", normalized_declared))
		result["declared_path"] = normalized_declared
	var resolved_uid := str(result.get("resolved_uid_path", ""))
	result["normalized_path"] = resolved_uid if not resolved_uid.is_empty() else normalized_declared
	result["path_exists"] = resource_path_exists(normalized_declared)

	if not resolved_uid.is_empty() and not normalized_declared.is_empty():
		if resolved_uid == normalized_declared:
			result["consistency"] = "matched"
		elif resource_path_exists(resolved_uid) and resource_path_exists(normalized_declared):
			result["consistency"] = "uid_path_mismatch"
			result["risk"] = "warning"
			result["hint"] = "UID resolves to a different existing path than the fallback path; re-save or normalize the resource reference."
		elif resource_path_exists(resolved_uid):
			result["consistency"] = "stale_fallback_path"
			result["risk"] = "warning"
			result["hint"] = "UID resolves successfully but the fallback path is stale; re-save the scene/resource to refresh the path."
		elif resource_path_exists(normalized_declared):
			result["consistency"] = "stale_uid"
			result["risk"] = "warning"
			result["hint"] = "Fallback path exists but UID no longer resolves; reimport or re-save to refresh the UID cache."
		else:
			result["consistency"] = "missing_uid_and_path"
			result["risk"] = "error"
			result["hint"] = "Neither UID nor fallback path can be resolved; fix the reference path or regenerate the resource UID."
	elif primary.begins_with("uid://") and not bool(result.get("uid_exists", false)):
		if resource_path_exists(normalized_declared):
			result["consistency"] = "stale_uid"
			result["risk"] = "warning"
			result["hint"] = "Fallback path exists but UID is unknown; reimport or re-save to refresh the UID cache."
		else:
			result["consistency"] = "missing_uid_and_path"
			result["risk"] = "error"
			result["hint"] = "Neither UID nor fallback path can be resolved; fix the reference path or regenerate the resource UID."
	elif not normalized_declared.is_empty():
		if resource_path_exists(normalized_declared):
			result["consistency"] = "path_exists"
		else:
			result["consistency"] = "missing_path"
			result["risk"] = "error"
			result["hint"] = "Referenced path does not exist; fix the resource path or restore the file."
	return result


func normalize_resource_path(path: String, source_path: String = "") -> String:
	var trimmed := path.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.begins_with("res://") or trimmed.begins_with("user://"):
		return trimmed.simplify_path()
	if not source_path.is_empty() and not trimmed.contains("://") and trimmed.is_relative_path():
		return source_path.get_base_dir().path_join(trimmed).simplify_path()
	return trimmed


func resource_path_exists(path: String) -> bool:
	if path.is_empty() or path.begins_with("uid://"):
		return false
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)
