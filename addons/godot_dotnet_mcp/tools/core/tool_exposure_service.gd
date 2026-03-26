@tool
extends RefCounted
class_name MCPToolExposureService

const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")

var _ensure_tool_definitions: Callable = Callable()
var _get_cached_tool_definitions: Callable = Callable()
var _get_entry: Callable = Callable()
var _get_runtime: Callable = Callable()
var _is_category_visible: Callable = Callable()
var _is_tool_enabled: Callable = Callable()
var _current_load_state: Callable = Callable()
var _exposed_categories := PackedStringArray(MCPToolManifest.EXPOSED_CATEGORIES)


func configure(options: Dictionary = {}) -> void:
	_ensure_tool_definitions = options.get("ensure_tool_definitions", Callable())
	_get_cached_tool_definitions = options.get("get_cached_tool_definitions", Callable())
	_get_entry = options.get("get_entry", Callable())
	_get_runtime = options.get("get_runtime", Callable())
	_is_category_visible = options.get("is_category_visible", Callable())
	_is_tool_enabled = options.get("is_tool_enabled", Callable())
	_current_load_state = options.get("current_load_state", Callable())
	var exposed_categories = options.get("exposed_categories", MCPToolManifest.get_exposed_categories())
	if exposed_categories is PackedStringArray:
		_exposed_categories = exposed_categories
	elif exposed_categories is Array:
		_exposed_categories = PackedStringArray(exposed_categories)


func dispose() -> void:
	_ensure_tool_definitions = Callable()
	_get_cached_tool_definitions = Callable()
	_get_entry = Callable()
	_get_runtime = Callable()
	_is_category_visible = Callable()
	_is_tool_enabled = Callable()
	_current_load_state = Callable()
	_exposed_categories = PackedStringArray()


func build_tools_by_category(ordered_categories: Array[String], visible_only: bool) -> Dictionary:
	var result: Dictionary = {}
	for category in ordered_categories:
		if visible_only and not _call_is_category_visible(category):
			continue
		var defs = _call_ensure_tool_definitions(category)
		if defs.is_empty():
			continue
		var decorated_defs: Array[Dictionary] = []
		for tool_def in defs:
			decorated_defs.append(_decorate_tool_definition(category, tool_def, false))
		result[category] = decorated_defs
	return result


func build_tool_definitions(ordered_categories: Array[String], visible_only: bool) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for category in ordered_categories:
		if visible_only and not _call_is_category_visible(category):
			continue
		for tool_def in _call_ensure_tool_definitions(category):
			definitions.append(_decorate_tool_definition(category, tool_def, true))
	return definitions


func build_exposed_tool_definitions(ordered_categories: Array[String], visible_only: bool) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for tool_def in build_tool_definitions(ordered_categories, visible_only):
		if not _is_exposed_tool_definition(tool_def):
			continue
		if not _as_bool(tool_def.get("enabled", true)):
			continue
		definitions.append((tool_def as Dictionary).duplicate(true))
	return definitions


func is_tool_exposed(tool_name: String, ordered_categories: Array[String], visible_only: bool) -> bool:
	for tool_def in build_exposed_tool_definitions(ordered_categories, visible_only):
		if str(tool_def.get("name", "")) == tool_name:
			return true
	return false


func build_domain_states(ordered_categories: Array[String], visible_only: bool) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for category in ordered_categories:
		if visible_only and not _call_is_category_visible(category):
			continue
		var entry = _call_get_entry(category)
		var runtime = _call_get_runtime(category)
		var defs = _call_get_cached_tool_definitions(category)
		states.append({
			"domain": category,
			"category": category,
			"domain_key": str(entry.get("domain_key", "other")),
			"source": str(entry.get("source", "builtin")),
			"script_path": str(entry.get("path", "")),
			"hot_reloadable": _as_bool(entry.get("hot_reloadable", true)),
			"loaded": runtime.get("instance", null) != null,
			"load_state": _call_current_load_state(category),
			"tool_count": defs.size(),
			"enabled_tool_count": _count_enabled_tools_in_category(category, defs),
			"version": int(runtime.get("version", 0)),
			"load_count": int(runtime.get("load_count", 0)),
			"last_loaded_at_unix": int(runtime.get("last_loaded_at_unix", 0)),
			"last_error": runtime.get("last_error", null)
		})
	return states


func build_tool_loader_status(ordered_categories: Array[String], tool_load_error_count: int) -> Dictionary:
	var tool_count := build_tool_definitions(ordered_categories, true).size()
	var exposed_tool_count := build_exposed_tool_definitions(ordered_categories, true).size()
	var category_count := ordered_categories.size()
	var status := "ready"
	var healthy := true
	if category_count <= 0 and tool_load_error_count <= 0:
		status = "empty_registry"
		healthy = false
	elif tool_count <= 0 or exposed_tool_count <= 0:
		status = "no_visible_tools"
		healthy = false
	elif tool_load_error_count > 0:
		status = "degraded"
	return {
		"initialized": category_count > 0 or tool_count > 0 or tool_load_error_count > 0,
		"healthy": healthy,
		"status": status,
		"tool_count": tool_count,
		"exposed_tool_count": exposed_tool_count,
		"category_count": category_count,
		"tool_load_error_count": tool_load_error_count
	}


func _decorate_tool_definition(category: String, tool_def: Dictionary, prefix_name: bool) -> Dictionary:
	var decorated = tool_def.duplicate(true)
	var entry = _call_get_entry(category)
	var full_name = "%s_%s" % [category, str(tool_def.get("name", ""))]
	decorated["category"] = category
	decorated["full_name"] = full_name
	decorated["enabled"] = _call_is_tool_enabled(full_name)
	decorated["load_state"] = _call_current_load_state(category)
	decorated["source"] = str(decorated.get("source", str(entry.get("source", "builtin"))))
	decorated["domain_script_path"] = str(entry.get("path", ""))
	decorated["script_path"] = str(decorated.get("script_path", str(entry.get("path", ""))))
	decorated["domain_key"] = str(entry.get("domain_key", "other"))
	if prefix_name:
		decorated["name"] = full_name
	return decorated


func _count_enabled_tools_in_category(category: String, defs: Array) -> int:
	var count = 0
	for tool_def in defs:
		if not (tool_def is Dictionary):
			continue
		var full_name = "%s_%s" % [category, str((tool_def as Dictionary).get("name", ""))]
		if _call_is_tool_enabled(full_name):
			count += 1
	return count


func _is_exposed_tool_definition(tool_def: Dictionary) -> bool:
	if _as_bool(tool_def.get("compatibility_alias", false)):
		return false
	return _exposed_categories.has(str(tool_def.get("category", "")))


func _call_ensure_tool_definitions(category: String) -> Array[Dictionary]:
	if not _ensure_tool_definitions.is_valid():
		return []
	var raw = _ensure_tool_definitions.call(category)
	var definitions: Array[Dictionary] = []
	if not (raw is Array):
		return definitions
	for tool_def in raw:
		if tool_def is Dictionary:
			definitions.append((tool_def as Dictionary).duplicate(true))
	return definitions


func _call_get_cached_tool_definitions(category: String) -> Array:
	if not _get_cached_tool_definitions.is_valid():
		return []
	var raw = _get_cached_tool_definitions.call(category)
	return raw if raw is Array else []


func _call_get_entry(category: String) -> Dictionary:
	if not _get_entry.is_valid():
		return {}
	var entry = _get_entry.call(category)
	return entry if entry is Dictionary else {}


func _call_get_runtime(category: String) -> Dictionary:
	if not _get_runtime.is_valid():
		return {}
	var runtime = _get_runtime.call(category)
	return runtime if runtime is Dictionary else {}


func _call_is_category_visible(category: String) -> bool:
	if not _is_category_visible.is_valid():
		return false
	return _as_bool(_is_category_visible.call(category))


func _call_is_tool_enabled(full_name: String) -> bool:
	if not _is_tool_enabled.is_valid():
		return true
	return _as_bool(_is_tool_enabled.call(full_name))


func _call_current_load_state(category: String) -> String:
	if not _current_load_state.is_valid():
		return "uninitialized"
	return str(_current_load_state.call(category))


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null
