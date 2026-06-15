@tool
extends RefCounted
class_name ToolLoaderTickService


func tick_loaded_runtimes(runtime_by_category: Dictionary, tool_definitions_by_category: Dictionary, delta: float, extract_tool_definitions: Callable) -> Dictionary:
	var ticked_categories: Array[String] = []
	var user_definitions_changed := false
	var user_should_unload := false
	var next_user_definitions: Array = []

	for category_value in runtime_by_category.keys():
		var category := str(category_value)
		var runtime = runtime_by_category.get(category, {})
		if not (runtime is Dictionary):
			continue
		var executor = (runtime as Dictionary).get("instance", null)
		if executor != null and executor.has_method("tick"):
			executor.tick(delta)
			ticked_categories.append(category)
		if category != "user":
			continue

		var user_result := _evaluate_user_runtime(executor, tool_definitions_by_category, extract_tool_definitions)
		user_definitions_changed = bool(user_result.get("definitions_changed", false))
		user_should_unload = bool(user_result.get("should_unload", false))
		next_user_definitions = user_result.get("definitions", [])

	return {
		"ticked_categories": ticked_categories,
		"user_definitions_changed": user_definitions_changed,
		"user_should_unload": user_should_unload,
		"user_definitions": next_user_definitions
	}


func _evaluate_user_runtime(executor, tool_definitions_by_category: Dictionary, extract_tool_definitions: Callable) -> Dictionary:
	var previous_defs: Array = tool_definitions_by_category.get("user", [])
	if executor == null:
		return {
			"definitions_changed": false,
			"should_unload": previous_defs.is_empty(),
			"definitions": previous_defs.duplicate(true)
		}

	var next_defs: Array = previous_defs.duplicate(true)
	if executor.has_method("get_tools") and extract_tool_definitions.is_valid():
		var extracted = extract_tool_definitions.call("user", executor)
		if extracted is Array:
			next_defs = (extracted as Array).duplicate(true)
	var definitions_changed := not _tool_definitions_match(previous_defs, next_defs)
	var should_unload := false
	if executor.has_method("should_unload_runtime"):
		should_unload = _as_bool(executor.should_unload_runtime())

	return {
		"definitions_changed": definitions_changed,
		"should_unload": should_unload,
		"definitions": next_defs
	}


func _tool_definitions_match(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if _tool_definition_signature(left[index]) != _tool_definition_signature(right[index]):
			return false
	return true


func _tool_definition_signature(tool) -> String:
	if not (tool is Dictionary):
		return str(typeof(tool))
	var tool_def := tool as Dictionary
	return JSON.stringify([
		str(tool_def.get("name", "")),
		str(tool_def.get("full_name", tool_def.get("fullName", ""))),
		str(tool_def.get("description", "")),
		str(tool_def.get("source", "")),
		str(tool_def.get("load_state", tool_def.get("loadState", ""))),
		str(tool_def.get("script_path", tool_def.get("scriptPath", ""))),
		bool(tool_def.get("enabled", true)),
		bool(tool_def.get("compatibility_alias", false)),
		tool_def.get("inputSchema", tool_def.get("parameters", {})),
		tool_def.get("outputSchema", {}),
		tool_def.get("annotations", {}),
		tool_def.get("presentation", {}),
		tool_def.get("icons", [])
	])


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
