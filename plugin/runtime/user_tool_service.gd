@tool
extends RefCounted
class_name UserToolService

const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"
const BACKUP_DIR := "res://addons/godot_dotnet_mcp/custom_tools/.backup"
const AUDIT_LOG_PATH := "user://godot_dotnet_mcp_user_tool_audit.log"
const LATEST_DELETED_META_PATH := "%s/latest_deleted.json" % BACKUP_DIR
const USER_CATEGORY := "user"
const USER_DOMAIN := "user"
const MAX_AUDIT_ENTRIES := 500
const SCAFFOLD_VERSION := "0.3.0"

var _session_id := ""


func _init() -> void:
	_session_id = _build_session_id()


func list_user_tools() -> Array[Dictionary]:
	var tools: Array[Dictionary] = []
	var script_paths: Array[String] = []
	_collect_script_paths(CUSTOM_TOOLS_DIR, script_paths)
	script_paths.sort()

	for script_path in script_paths:
		var inspected = _inspect_script(script_path)
		if not inspected.is_empty():
			tools.append(inspected)

	return tools


func create_tool_scaffold(tool_name: String, display_name: String, description: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	var slug = _slugify_tool_name(tool_name if not tool_name.is_empty() else display_name)
	if slug.is_empty():
		return _authorization_required("create_user_tool", {"reason": "empty_tool_name"})

	var preview = {
		"category": USER_CATEGORY,
		"domain_key": USER_DOMAIN,
		"tool_name": slug,
		"display_name": display_name if not display_name.is_empty() else _humanize(slug),
		"description": description if not description.is_empty() else "User-defined tool scaffold.",
		"script_path": "%s/%s.gd" % [CUSTOM_TOOLS_DIR, slug],
		"scaffold_version": SCAFFOLD_VERSION
	}

	if not authorized:
		_append_audit("create_user_tool", false, false, preview, "", agent_hint)
		return _authorization_required("create_user_tool", preview)

	if FileAccess.file_exists(str(preview["script_path"])):
		_append_audit("create_user_tool", true, false, preview, "script_exists", agent_hint)
		return {"success": false, "error": "User tool script already exists", "data": preview}

	var ensure_result = _ensure_custom_tools_dir()
	if not bool(ensure_result.get("success", false)):
		_append_audit("create_user_tool", true, false, preview, "mkdir_failed", agent_hint)
		return ensure_result

	var file = FileAccess.open(str(preview["script_path"]), FileAccess.WRITE)
	if file == null:
		_append_audit("create_user_tool", true, false, preview, "write_failed", agent_hint)
		return {"success": false, "error": "Failed to create user tool script", "data": preview}

	file.store_string(_build_scaffold(slug, preview))
	file.close()
	_append_audit("create_user_tool", true, true, preview, "", agent_hint)
	return {"success": true, "message": "User tool scaffold created", "data": preview}


func delete_tool(script_path: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	var normalized_path = _normalize_script_path(script_path)
	if normalized_path.is_empty():
		return {"success": false, "error": "Invalid user tool script path"}

	var preview = {
		"script_path": normalized_path,
		"uid_path": "%s.uid" % normalized_path
	}
	if not authorized:
		_append_audit("delete_user_tool", false, false, preview, "", agent_hint)
		return _authorization_required("delete_user_tool", preview)

	if not FileAccess.file_exists(normalized_path):
		_append_audit("delete_user_tool", true, false, preview, "missing_script", agent_hint)
		return {"success": false, "error": "User tool script does not exist", "data": preview}

	var backup_result = _backup_user_tool(normalized_path)
	if not bool(backup_result.get("success", false)):
		preview["backup_failed"] = true
		_append_audit("delete_user_tool", true, false, preview, "backup_failed", agent_hint)
		return backup_result
	preview.merge(backup_result.get("data", {}), true)

	var remove_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(normalized_path))
	if remove_error != OK:
		_append_audit("delete_user_tool", true, false, preview, "remove_failed", agent_hint)
		return {"success": false, "error": "Failed to delete user tool script", "data": preview}

	if FileAccess.file_exists(str(preview["uid_path"])):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(preview["uid_path"])))

	_append_audit("delete_user_tool", true, true, preview, "", agent_hint)
	return {"success": true, "message": "User tool deleted", "data": preview}


func restore_latest_backup(authorized: bool, agent_hint: String = "") -> Dictionary:
	var preview = _get_latest_deleted_backup()
	if preview.is_empty():
		return {"success": false, "error": "No deleted user tool backup is available"}

	if not authorized:
		_append_audit("restore_user_tool", false, false, preview, "", agent_hint)
		return _authorization_required("restore_user_tool", preview)

	var script_path = str(preview.get("script_path", ""))
	if script_path.is_empty():
		_append_audit("restore_user_tool", true, false, preview, "missing_script_path", agent_hint)
		return {"success": false, "error": "Backup metadata is missing the original script path", "data": preview}
	if FileAccess.file_exists(script_path):
		_append_audit("restore_user_tool", true, false, preview, "script_exists", agent_hint)
		return {"success": false, "error": "User tool script already exists", "data": preview}

	var ensure_result = _ensure_custom_tools_dir()
	if not bool(ensure_result.get("success", false)):
		_append_audit("restore_user_tool", true, false, preview, "mkdir_failed", agent_hint)
		return ensure_result

	var restore_result = _restore_backup_payload(preview)
	if not bool(restore_result.get("success", false)):
		_append_audit("restore_user_tool", true, false, preview, str(restore_result.get("data", {}).get("error_code", "restore_failed")), agent_hint)
		return restore_result

	_append_audit("restore_user_tool", true, true, preview, "", agent_hint)
	return {
		"success": true,
		"message": "User tool restored",
		"data": preview
	}


func get_audit_entries(limit: int = 20, filter_action: String = "", filter_session: String = "") -> Array[Dictionary]:
	if not FileAccess.file_exists(AUDIT_LOG_PATH):
		return []

	var file = FileAccess.open(AUDIT_LOG_PATH, FileAccess.READ)
	if file == null:
		return []

	var entries: Array[Dictionary] = []
	while not file.eof_reached():
		var line = file.get_line()
		if line.is_empty():
			continue
		var json = JSON.new()
		if json.parse(line) != OK:
			continue
		var data = json.get_data()
		if data is Dictionary:
			var entry := (data as Dictionary).duplicate(true)
			if not filter_action.is_empty() and str(entry.get("action", "")) != filter_action:
				continue
			if not filter_session.is_empty() and str(entry.get("session_id", "")) != filter_session:
				continue
			entries.append(entry)
	file.close()

	if limit <= 0 or entries.size() <= limit:
		return entries
	return entries.slice(entries.size() - limit)


func get_compatibility_report() -> Dictionary:
	var user_tools = list_user_tools()
	var compatible: Array[Dictionary] = []
	var needs_review: Array[Dictionary] = []

	for tool in user_tools:
		var item := tool.duplicate(true)
		var scaffold_version = str(item.get("scaffold_version", "unknown"))
		var status = _get_compatibility_status(scaffold_version)
		item["compatibility_status"] = status
		item["recommendation"] = _get_compatibility_recommendation(status)
		if status == "compatible":
			compatible.append(item)
		else:
			needs_review.append(item)

	return {
		"current_scaffold_version": SCAFFOLD_VERSION,
		"user_tool_count": user_tools.size(),
		"compatible_count": compatible.size(),
		"compatible": compatible,
		"needs_review_count": needs_review.size(),
		"needs_review": needs_review
	}


func _inspect_script(script_path: String) -> Dictionary:
	var file_content = _read_script_content(script_path)
	var default_display_name = _humanize(script_path.get_file().get_basename())
	var inspected = {
		"script_path": script_path,
		"display_name": default_display_name,
		"category": USER_CATEGORY,
		"domain_key": USER_DOMAIN,
		"tool_names": [],
		"scaffold_version": _extract_scaffold_version(file_content),
		"loadable": false
	}

	var script_resource = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (script_resource is Script):
		inspected["load_error"] = "script_load_failed"
		return inspected
	(script_resource as Script).reload()
	if not (script_resource as Script).can_instantiate():
		inspected["load_error"] = "script_cannot_instantiate"
		return inspected

	var executor = script_resource.new()
	if executor == null or not executor.has_method("get_tools"):
		inspected["load_error"] = "missing_get_tools"
		return inspected

	var registration: Dictionary = {}
	if executor.has_method("get_registration"):
		registration = executor.get_registration()

	var tool_names: Array[String] = []
	for tool_def in executor.get_tools():
		if tool_def is Dictionary:
			tool_names.append("%s_%s" % [USER_CATEGORY, str(tool_def.get("name", ""))])

	inspected["display_name"] = str(registration.get("display_name", default_display_name))
	inspected["tool_names"] = tool_names
	inspected["loadable"] = true
	return inspected


func _ensure_custom_tools_dir() -> Dictionary:
	var global_path = ProjectSettings.globalize_path(CUSTOM_TOOLS_DIR)
	if DirAccess.dir_exists_absolute(global_path):
		return {"success": true}

	var error = DirAccess.make_dir_recursive_absolute(global_path)
	if error != OK:
		return {
			"success": false,
			"error": "Failed to create custom tools directory",
			"data": {"path": CUSTOM_TOOLS_DIR, "error_code": error}
	}
	return {"success": true}


func _ensure_backup_dir() -> Dictionary:
	var global_path = ProjectSettings.globalize_path(BACKUP_DIR)
	if DirAccess.dir_exists_absolute(global_path):
		return {"success": true}

	var error = DirAccess.make_dir_recursive_absolute(global_path)
	if error != OK:
		return {
			"success": false,
			"error": "Failed to create backup directory",
			"data": {"path": BACKUP_DIR, "error_code": error}
		}
	return {"success": true}


func _collect_script_paths(dir_path: String, output: Array[String]) -> void:
	var global_path = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(global_path):
		return

	var dir = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path = "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_collect_script_paths(child_path, output)
		elif entry.ends_with(".gd"):
			output.append(child_path)
	dir.list_dir_end()


func _authorization_required(action: String, preview: Dictionary) -> Dictionary:
	return {
		"success": false,
		"error": "User authorization required",
		"data": {"action": action, "requires_authorization": true, "preview": preview}
	}


func _append_audit(action: String, authorized: bool, success: bool, payload: Dictionary, error_code: String = "", agent_hint: String = "") -> void:
	var file = FileAccess.open(AUDIT_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(AUDIT_LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[Godot MCP] audit log write failed: %s" % AUDIT_LOG_PATH)
		return

	file.seek_end()
	file.store_line(JSON.stringify({
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"session_id": _session_id,
		"agent_hint": agent_hint,
		"action": action,
		"authorized": authorized,
		"success": success,
		"error_code": error_code,
		"payload": payload
	}))
	file.close()
	_truncate_audit_log()


func _truncate_audit_log() -> void:
	var entries := get_audit_entries(0)
	if entries.size() <= MAX_AUDIT_ENTRIES:
		return
	var file = FileAccess.open(AUDIT_LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[Godot MCP] audit log truncate failed: %s" % AUDIT_LOG_PATH)
		return
	for entry in entries.slice(entries.size() - MAX_AUDIT_ENTRIES):
		file.store_line(JSON.stringify(entry))
	file.close()


func _build_scaffold(tool_name: String, preview: Dictionary) -> String:
	return """@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const _SCAFFOLD_VERSION := %s


func get_registration() -> Dictionary:
	return {
		"category": "user",
		"domain_key": "user",
		"hot_reloadable": true,
		"display_name": %s
	}


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": %s,
			"description": %s,
			"inputSchema": {
				"type": "object",
				"properties": {
					"message": {
						"type": "string",
						"description": "Optional test message"
					}
				}
			}
		}
	]


func execute(tool_name_value: String, args: Dictionary) -> Dictionary:
	match tool_name_value:
		%s:
			return _success({
				"echo": str(args.get("message", "")),
				"script_path": %s
			}, "User tool executed")
		_:
			return _error("Unknown user tool: %%s" %% tool_name_value)
""" % [
		JSON.stringify(SCAFFOLD_VERSION),
		JSON.stringify(str(preview.get("display_name", _humanize(tool_name)))),
		JSON.stringify(tool_name),
		JSON.stringify(str(preview.get("description", ""))),
		JSON.stringify(tool_name),
		JSON.stringify(str(preview.get("script_path", "")))
	]


func _read_script_content(script_path: String) -> String:
	if not FileAccess.file_exists(script_path):
		return ""

	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return ""

	var content = file.get_as_text()
	file.close()
	return content


func _backup_user_tool(script_path: String) -> Dictionary:
	var ensure_result = _ensure_backup_dir()
	if not bool(ensure_result.get("success", false)):
		return ensure_result

	var timestamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "_")
	var file_name = script_path.get_file()
	var backup_base = "%s/%s_%s" % [BACKUP_DIR, file_name.get_basename(), timestamp]
	var backup_path = "%s.gd.bak" % backup_base
	var uid_path = "%s.uid" % script_path
	var backup_uid_path = "%s.gd.uid.bak" % backup_base

	_clear_existing_backups(file_name.get_basename())

	var copy_result = _copy_file(script_path, backup_path)
	if not bool(copy_result.get("success", false)):
		return copy_result

	var backup_data = {
		"script_path": script_path,
		"backup_path": backup_path,
		"deleted_at_unix": int(Time.get_unix_time_from_system())
	}

	if FileAccess.file_exists(uid_path):
		var copy_uid_result = _copy_file(uid_path, backup_uid_path)
		if not bool(copy_uid_result.get("success", false)):
			return copy_uid_result
		backup_data["uid_path"] = uid_path
		backup_data["backup_uid_path"] = backup_uid_path

	var metadata_result = _write_json_file(LATEST_DELETED_META_PATH, backup_data)
	if not bool(metadata_result.get("success", false)):
		return metadata_result

	return {"success": true, "data": backup_data}


func _restore_backup_payload(backup_data: Dictionary) -> Dictionary:
	var backup_path = str(backup_data.get("backup_path", ""))
	var script_path = str(backup_data.get("script_path", ""))
	if backup_path.is_empty() or script_path.is_empty():
		return {
			"success": false,
			"error": "Backup metadata is incomplete",
			"data": {"error_code": "incomplete_backup_metadata"}
		}
	if not FileAccess.file_exists(backup_path):
		return {
			"success": false,
			"error": "Backup file does not exist",
			"data": {"error_code": "missing_backup_file", "backup_path": backup_path}
		}

	var copy_result = _copy_file(backup_path, script_path)
	if not bool(copy_result.get("success", false)):
		return copy_result

	var uid_path = str(backup_data.get("uid_path", ""))
	var backup_uid_path = str(backup_data.get("backup_uid_path", ""))
	if not uid_path.is_empty() and not backup_uid_path.is_empty() and FileAccess.file_exists(backup_uid_path):
		var copy_uid_result = _copy_file(backup_uid_path, uid_path)
		if not bool(copy_uid_result.get("success", false)):
			return copy_uid_result

	return {"success": true}


func _get_latest_deleted_backup() -> Dictionary:
	var read_result = _read_json_file(LATEST_DELETED_META_PATH)
	if not bool(read_result.get("success", false)):
		return {}
	var data = read_result.get("data", {})
	if not (data is Dictionary):
		return {}
	if not FileAccess.file_exists(str(data.get("backup_path", ""))):
		return {}
	return data.duplicate(true)


func _clear_existing_backups(tool_slug: String) -> void:
	var dir = DirAccess.open(BACKUP_DIR)
	if dir == null:
		return

	var prefix = "%s_" % tool_slug
	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		if entry == "latest_deleted.json":
			continue
		if not entry.begins_with(prefix):
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s" % [BACKUP_DIR, entry]))
	dir.list_dir_end()


func _copy_file(source_path: String, target_path: String) -> Dictionary:
	var content = _read_script_content(source_path)
	if content.is_empty() and not FileAccess.file_exists(source_path):
		return {
			"success": false,
			"error": "Source file does not exist",
			"data": {"error_code": "missing_source_file", "source_path": source_path}
		}

	var dir_path = target_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var file = FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		return {
			"success": false,
			"error": "Failed to write file",
			"data": {"error_code": "write_failed", "target_path": target_path}
		}
	file.store_string(content)
	file.close()
	return {"success": true}


func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false, "error": "File does not exist"}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Failed to open file"}

	var content = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(content) != OK:
		return {"success": false, "error": "Failed to parse JSON"}
	return {"success": true, "data": json.get_data()}


func _write_json_file(path: String, data: Dictionary) -> Dictionary:
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "error": "Failed to write JSON file"}
	file.store_string(JSON.stringify(data))
	file.close()
	return {"success": true}


func _extract_scaffold_version(content: String) -> String:
	if content.is_empty():
		return "unknown"

	var regex = RegEx.new()
	regex.compile("(?m)^const\\s+_SCAFFOLD_VERSION\\s*:=\\s*\"([^\"]+)\"")
	var match_result = regex.search(content)
	if match_result == null:
		return "unknown"
	return str(match_result.get_string(1)).strip_edges()


func _get_compatibility_status(scaffold_version: String) -> String:
	if scaffold_version.is_empty() or scaffold_version == "unknown":
		return "unknown"

	var comparison = _compare_versions(scaffold_version, SCAFFOLD_VERSION)
	if comparison == 0:
		return "compatible"
	if comparison < 0:
		return "outdated"
	return "newer"


func _get_compatibility_recommendation(status: String) -> String:
	match status:
		"compatible":
			return "No action required."
		"outdated":
			return "Rescaffold from the current template and migrate custom logic manually."
		"newer":
			return "Current plugin template is older than this user tool; verify plugin compatibility before editing."
		_:
			return "Add or verify the _SCAFFOLD_VERSION constant before relying on compatibility checks."


func _compare_versions(left: String, right: String) -> int:
	var left_parts = left.split(".")
	var right_parts = right.split(".")
	var max_parts = maxi(left_parts.size(), right_parts.size())

	for index in range(max_parts):
		var left_value = int(left_parts[index]) if index < left_parts.size() else 0
		var right_value = int(right_parts[index]) if index < right_parts.size() else 0
		if left_value < right_value:
			return -1
		if left_value > right_value:
			return 1

	return 0


func _normalize_script_path(script_path: String) -> String:
	var normalized = script_path.replace("\\", "/")
	if not normalized.begins_with(CUSTOM_TOOLS_DIR + "/"):
		return ""
	if not normalized.ends_with(".gd"):
		return ""
	return normalized


func _slugify_tool_name(value: String) -> String:
	var lowered = value.strip_edges().to_lower()
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]+")
	var sanitized = regex.sub(lowered, "_", true)
	while sanitized.contains("__"):
		sanitized = sanitized.replace("__", "_")
	return sanitized.trim_prefix("_").trim_suffix("_")


func _humanize(value: String) -> String:
	var words: Array[String] = []
	for word in value.split("_"):
		if word.is_empty():
			continue
		words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(words)


func _build_session_id() -> String:
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "_")
	return "%s_%010d" % [timestamp, randi()]
