@tool
extends RefCounted

const MCPBaseToolScript = preload("res://addons/godot_dotnet_mcp/tools/base_tools.gd")

var _custom_tools_dir := ""
var _user_category := ""
var _user_domain := ""
var _scaffold_version := ""


func configure(custom_tools_dir: String, user_category: String, user_domain: String, scaffold_version: String) -> void:
	_custom_tools_dir = custom_tools_dir
	_user_category = user_category
	_user_domain = user_domain
	_scaffold_version = scaffold_version


func list_user_tools() -> Array[Dictionary]:
	var tools: Array[Dictionary] = []
	var script_paths: Array[String] = []
	_collect_script_paths(_custom_tools_dir, script_paths)
	script_paths.sort()

	for script_path in script_paths:
		var inspected = _inspect_script(script_path)
		if not inspected.is_empty():
			tools.append(inspected)

	return tools


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
		"current_scaffold_version": _scaffold_version,
		"user_tool_count": user_tools.size(),
		"compatible_count": compatible.size(),
		"compatible": compatible,
		"needs_review_count": needs_review.size(),
		"needs_review": needs_review
	}


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
			var normalized_path = _normalize_script_path(child_path)
			if not normalized_path.is_empty():
				output.append(normalized_path)
	dir.list_dir_end()


func _inspect_script(script_path: String) -> Dictionary:
	var file_content = _read_script_content(script_path)
	var default_display_name = _humanize(script_path.get_file().get_basename())
	var inspected = {
		"script_path": script_path,
		"display_name": default_display_name,
		"category": _user_category,
		"domain_key": _user_domain,
		"tool_names": [],
		"scaffold_version": _extract_scaffold_version(file_content),
		"loadable": false
	}

	if not ClassDB.class_exists("MCPBaseTool"):
		inspected["load_error"] = "missing_mcp_base_tool"
		return inspected

	var script_resource = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (script_resource is Script):
		inspected["load_error"] = "script_load_failed"
		return inspected
	var executor = null
	if (script_resource as Script).can_instantiate():
		executor = script_resource.new()
		if executor == null or not executor.has_method("get_tools"):
			inspected["load_error"] = "missing_get_tools"
			return inspected
	else:
		inspected["load_error"] = "script_cannot_instantiate"
		if not script_resource.has_method("get_tools"):
			inspected["load_error"] = "missing_static_get_tools"
			return inspected
		executor = script_resource

	var registration: Dictionary = {}
	if executor.has_method("get_registration"):
		registration = executor.get_registration()

	var tool_names: Array[String] = []
	for tool_def in executor.get_tools():
		if tool_def is Dictionary:
			var logical_name = _normalize_runtime_tool_name(str(tool_def.get("name", "")))
			if not logical_name.is_empty():
				tool_names.append("%s_%s" % [_user_category, logical_name])

	inspected["display_name"] = str(registration.get("display_name", default_display_name))
	inspected["tool_names"] = tool_names
	inspected["loadable"] = true
	return inspected


func _read_script_content(script_path: String) -> String:
	if not FileAccess.file_exists(script_path):
		return ""

	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return ""

	var content = file.get_as_text()
	file.close()
	return content


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

	var comparison = _compare_versions(scaffold_version, _scaffold_version)
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


func _normalize_runtime_tool_name(tool_name: String) -> String:
	var normalized = tool_name.strip_edges()
	if normalized.begins_with("user_"):
		normalized = normalized.trim_prefix("user_")
	return normalized


func _normalize_script_path(script_path: String) -> String:
	var normalized = script_path.replace("\\", "/").strip_edges()
	if normalized.is_empty() or not normalized.ends_with(".gd"):
		return ""
	if not normalized.begins_with("res://") and not normalized.begins_with("user://"):
		normalized = "res://" + normalized.trim_prefix("/")

	var global_root = ProjectSettings.globalize_path(_custom_tools_dir).replace("\\", "/")
	var global_path = ProjectSettings.globalize_path(normalized).replace("\\", "/")
	if not global_path.begins_with(global_root + "/"):
		return ""

	var localized = ProjectSettings.localize_path(global_path).replace("\\", "/")
	if not localized.begins_with(_custom_tools_dir + "/"):
		return ""
	return localized


func _humanize(value: String) -> String:
	var words: Array[String] = []
	for word in value.split("_"):
		if word.is_empty():
			continue
		words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(words)
