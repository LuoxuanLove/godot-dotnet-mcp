@tool
extends RefCounted
class_name MCPToolRegistryStore

var _server_context: Object
var _entries_by_category: Dictionary = {}
var _ordered_categories: Array[String] = []
var _runtime_by_category: Dictionary = {}
var _tool_definitions_by_category: Dictionary = {}
var _disabled_tools: Dictionary = {}
var _reload_status: Dictionary = {}
var _force_reload_script_load := false


func configure(server_context: Object) -> void:
	_server_context = server_context


func clear_all() -> void:
	_server_context = null
	_entries_by_category.clear()
	_ordered_categories.clear()
	_runtime_by_category.clear()
	_tool_definitions_by_category.clear()
	_disabled_tools.clear()
	_reload_status.clear()
	_force_reload_script_load = false


func reset_registry_state() -> void:
	_entries_by_category.clear()
	_ordered_categories.clear()
	_runtime_by_category.clear()
	_tool_definitions_by_category.clear()


func set_entries(entries_by_category: Dictionary, ordered_categories: Array[String]) -> void:
	_entries_by_category = entries_by_category.duplicate(true)
	_ordered_categories = ordered_categories.duplicate()


func get_ordered_categories() -> Array[String]:
	return _ordered_categories.duplicate()


func get_entry(category: String) -> Dictionary:
	var entry = _entries_by_category.get(category, {})
	return entry.duplicate(true) if entry is Dictionary else {}


func get_entries_copy() -> Dictionary:
	return _entries_by_category.duplicate(true)


func has_entry(category: String) -> bool:
	return _entries_by_category.has(category)


func get_runtime(category: String) -> Dictionary:
	var runtime = _runtime_by_category.get(category, {})
	return runtime.duplicate(true) if runtime is Dictionary else {}


func set_runtime(category: String, runtime: Dictionary) -> void:
	_runtime_by_category[category] = runtime.duplicate(true)


func erase_runtime(category: String) -> void:
	_runtime_by_category.erase(category)


func runtime_categories() -> Array:
	return _runtime_by_category.keys()


func get_cached_tool_definitions(category: String) -> Array:
	var definitions = _tool_definitions_by_category.get(category, [])
	return definitions.duplicate(true) if definitions is Array else []


func set_tool_definitions(category: String, definitions: Array) -> void:
	_tool_definitions_by_category[category] = definitions.duplicate(true)


func erase_tool_definitions(category: String) -> void:
	_tool_definitions_by_category.erase(category)


func has_tool_definitions_cache(category: String) -> bool:
	return _tool_definitions_by_category.has(category)


func get_disabled_tools() -> Array:
	return _disabled_tools.keys()


func set_disabled_tools(disabled_tools: Array) -> void:
	_disabled_tools.clear()
	for tool_name in disabled_tools:
		_disabled_tools[str(tool_name)] = true


func is_tool_enabled(tool_name: String) -> bool:
	return not _disabled_tools.has(tool_name)


func count_enabled_tools_in_category(category: String) -> int:
	var count := 0
	for tool_def in _tool_definitions_by_category.get(category, []):
		if not (tool_def is Dictionary):
			continue
		var full_name := "%s_%s" % [category, str((tool_def as Dictionary).get("name", ""))]
		if is_tool_enabled(full_name):
			count += 1
	return count


func category_has_enabled_tools(category: String) -> bool:
	return count_enabled_tools_in_category(category) > 0


func set_reload_status(status: Dictionary) -> Dictionary:
	_reload_status = status.duplicate(true)
	return _reload_status.duplicate(true)


func get_reload_status() -> Dictionary:
	return _reload_status.duplicate(true)


func set_force_reload_script_load(force_reload_script_load: bool) -> void:
	_force_reload_script_load = force_reload_script_load


func get_force_reload_script_load() -> bool:
	return _force_reload_script_load


func get_server_context() -> Object:
	return _server_context


func get_permission_provider():
	if _server_context == null:
		return null
	if _server_context.has_method("get_plugin_permission_provider"):
		return _server_context.get_plugin_permission_provider()
	if _server_context.has_method("get_parent"):
		return _server_context.get_parent()
	return null


func is_category_visible(category: String) -> bool:
	var provider = get_permission_provider()
	if provider != null and provider.has_method("is_tool_category_visible_for_permission"):
		return _as_bool(provider.is_tool_category_visible_for_permission(category))
	return false


func is_category_executable(category: String) -> bool:
	var provider = get_permission_provider()
	if provider != null and provider.has_method("is_tool_category_executable_for_permission"):
		return _as_bool(provider.is_tool_category_executable_for_permission(category))
	return false


func get_permission_error(category: String) -> String:
	var provider = get_permission_provider()
	if provider != null and provider.has_method("get_permission_denied_message_for_category"):
		return str(provider.get_permission_denied_message_for_category(category))
	return "Current permission level does not allow this tool category"


func current_load_state(category: String) -> String:
	var runtime: Dictionary = _runtime_by_category.get(category, {})
	var defs = _tool_definitions_by_category.get(category, [])
	if runtime.has("state"):
		return str(runtime.get("state", "definitions_only"))
	if defs.is_empty():
		return "uninitialized"
	return "definitions_only"


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized: String = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null
