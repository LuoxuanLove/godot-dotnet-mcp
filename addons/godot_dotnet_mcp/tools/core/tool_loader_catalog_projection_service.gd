@tool
extends RefCounted
class_name ToolLoaderCatalogProjectionService


func build_tools_by_category(context: Dictionary, visible_only: bool) -> Dictionary:
	var result: Dictionary = {}
	for category in _ordered_categories(context):
		if visible_only and not _call_bool(context.get("is_category_visible", Callable()), [category], true):
			continue
		var defs: Array = _call_array(context.get("ensure_tool_definitions", Callable()), [category])
		if defs.is_empty():
			continue
		var decorated_defs: Array[Dictionary] = []
		for tool_def in defs:
			if not (tool_def is Dictionary):
				continue
			var decorated_def := decorate_tool_definition(context, category, tool_def)
			if _call_bool(context.get("is_public_removed_tool_definition", Callable()), [decorated_def], false):
				continue
			decorated_defs.append(decorated_def)
		if decorated_defs.is_empty():
			continue
		result[category] = decorated_defs
	return result


func build_tool_definitions(context: Dictionary, visible_only: bool) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for category in _ordered_categories(context):
		if visible_only and not _call_bool(context.get("is_category_visible", Callable()), [category], true):
			continue
		for tool_def in _call_array(context.get("ensure_tool_definitions", Callable()), [category]):
			if not (tool_def is Dictionary):
				continue
			var full_def := decorate_tool_definition(context, category, tool_def)
			full_def["name"] = "%s_%s" % [category, str((tool_def as Dictionary).get("name", ""))]
			full_def["category"] = category
			definitions.append(full_def)
	return definitions


func build_exposed_tool_definitions(context: Dictionary, visible_tool_definitions: Array) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for tool_def in visible_tool_definitions:
		if not (tool_def is Dictionary):
			continue
		if not _call_bool(context.get("is_exposed_tool_definition", Callable()), [tool_def], false):
			continue
		if not _as_bool((tool_def as Dictionary).get("enabled", true)):
			continue
		definitions.append((tool_def as Dictionary).duplicate(true))
	return definitions


func build_domain_states(context: Dictionary, visible_only: bool) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var entries: Dictionary = _dictionary(context.get("entries_by_category", {}))
	var runtimes: Dictionary = _dictionary(context.get("runtime_by_category", {}))
	var definitions: Dictionary = _dictionary(context.get("tool_definitions_by_category", {}))
	for category in _ordered_categories(context):
		if visible_only and not _call_bool(context.get("is_category_visible", Callable()), [category], true):
			continue
		var entry: Dictionary = _dictionary(entries.get(category, {}))
		var runtime: Dictionary = _dictionary(runtimes.get(category, {}))
		var defs: Array = _array(definitions.get(category, []))
		states.append({
			"domain": category,
			"category": category,
			"domain_key": str(entry.get("domain_key", "other")),
			"source": str(entry.get("source", "builtin")),
			"script_path": str(entry.get("path", "")),
			"hot_reloadable": _as_bool(entry.get("hot_reloadable", true)),
			"loaded": runtime.get("instance", null) != null,
			"load_state": current_load_state(runtime, defs),
			"tool_count": defs.size(),
			"enabled_tool_count": _count_enabled_tools(category, defs, context.get("is_tool_enabled", Callable())),
			"version": int(runtime.get("version", 0)),
			"load_count": int(runtime.get("load_count", 0)),
			"last_loaded_at_unix": int(runtime.get("last_loaded_at_unix", 0)),
			"last_error": _duplicate_value(runtime.get("last_error", null))
		})
	return states


func decorate_tool_definition(context: Dictionary, category: String, tool_def: Dictionary) -> Dictionary:
	var decorated = tool_def.duplicate(true)
	var entries: Dictionary = _dictionary(context.get("entries_by_category", {}))
	var entry: Dictionary = _dictionary(entries.get(category, {}))
	var full_name = "%s_%s" % [category, str(tool_def.get("name", ""))]
	decorated["category"] = category
	decorated["full_name"] = full_name
	decorated["enabled"] = _call_bool(context.get("is_tool_enabled", Callable()), [full_name], true)
	decorated["load_state"] = current_load_state(
		_dictionary(_dictionary(context.get("runtime_by_category", {})).get(category, {})),
		_array(_dictionary(context.get("tool_definitions_by_category", {})).get(category, []))
	)
	decorated["source"] = str(decorated.get("source", str(entry.get("source", "builtin"))))
	decorated["domain_script_path"] = str(entry.get("path", ""))
	decorated["script_path"] = str(decorated.get("script_path", str(entry.get("path", ""))))
	decorated["domain_key"] = str(entry.get("domain_key", "other"))
	return decorated


func current_load_state(runtime: Dictionary, definitions: Array) -> String:
	if runtime.has("state"):
		return str(runtime.get("state", "definitions_only"))
	if definitions.is_empty():
		return "uninitialized"
	return "definitions_only"


func _count_enabled_tools(category: String, definitions: Array, is_tool_enabled: Callable) -> int:
	var count = 0
	for tool_def in definitions:
		if not (tool_def is Dictionary):
			continue
		var full_name = "%s_%s" % [category, str((tool_def as Dictionary).get("name", ""))]
		if _call_bool(is_tool_enabled, [full_name], true):
			count += 1
	return count


func _ordered_categories(context: Dictionary) -> Array[String]:
	var categories: Array[String] = []
	categories.assign(_array(context.get("ordered_categories", [])))
	return categories


func _call_array(callable: Callable, args: Array) -> Array:
	if not callable.is_valid():
		return []
	var result = callable.callv(args)
	if result is Array:
		return (result as Array).duplicate(true)
	return []


func _call_bool(callable: Callable, args: Array, default_value: bool) -> bool:
	if not callable.is_valid():
		return default_value
	return _as_bool(callable.callv(args))


func _dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _array(value) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _duplicate_value(value):
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value


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
