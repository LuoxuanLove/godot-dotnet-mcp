@tool
extends RefCounted
class_name ToolLoaderTickService

var _last_user_definitions_revision := -1
var _last_user_executor = null
var _user_definitions_dirty := true


func invalidate_user_definitions() -> void:
	_user_definitions_dirty = true


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
		_last_user_definitions_revision = -1
		_last_user_executor = null
		_user_definitions_dirty = true
		return {
			"definitions_changed": false,
			"should_unload": previous_defs.is_empty(),
			"definitions": previous_defs.duplicate(true)
		}

	var current_revision := _get_user_definitions_revision(executor)
	var executor_changed: bool = executor != _last_user_executor
	var should_refresh_definitions: bool = _user_definitions_dirty or executor_changed or current_revision != _last_user_definitions_revision
	var next_defs: Array = previous_defs.duplicate(true)
	if should_refresh_definitions and executor.has_method("get_tools") and extract_tool_definitions.is_valid():
		var extracted = extract_tool_definitions.call("user", executor)
		if extracted is Array:
			next_defs = (extracted as Array).duplicate(true)
	var definitions_changed: bool = should_refresh_definitions and not _tool_definitions_match(previous_defs, next_defs)
	_last_user_executor = executor
	if current_revision >= 0:
		_last_user_definitions_revision = current_revision
	if should_refresh_definitions:
		_user_definitions_dirty = false
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
		if not _tool_definitions_equal(left[index], right[index]):
			return false
	return true


func _tool_definitions_equal(left, right) -> bool:
	if not (left is Dictionary) or not (right is Dictionary):
		return _variants_equal(left, right)
	var left_def := left as Dictionary
	var right_def := right as Dictionary
	for field in [
		"name",
		"description",
		"source"
	]:
		if str(left_def.get(field, "")) != str(right_def.get(field, "")):
			return false
	for field in [
		"enabled",
		"compatibility_alias"
	]:
		if bool(left_def.get(field, field == "enabled")) != bool(right_def.get(field, field == "enabled")):
			return false
	for field in [
		"outputSchema",
		"annotations",
		"presentation"
	]:
		if not _variants_equal(left_def.get(field, {}), right_def.get(field, {})):
			return false
	if not _variants_equal(left_def.get("icons", []), right_def.get("icons", [])):
		return false
	for field_pair in [
		["full_name", "fullName", ""],
		["load_state", "loadState", ""],
		["script_path", "scriptPath", ""]
	]:
		if str(_get_alias_field(left_def, str(field_pair[0]), str(field_pair[1]), field_pair[2])) != str(_get_alias_field(right_def, str(field_pair[0]), str(field_pair[1]), field_pair[2])):
			return false
	for field_pair in [
		["inputSchema", "parameters", {}]
	]:
		if not _variants_equal(
			_get_alias_field(left_def, str(field_pair[0]), str(field_pair[1]), field_pair[2]),
			_get_alias_field(right_def, str(field_pair[0]), str(field_pair[1]), field_pair[2])
		):
			return false
	return true


func _get_alias_field(tool_def: Dictionary, primary_key: String, fallback_key: String, default_value):
	if tool_def.has(primary_key):
		return tool_def.get(primary_key)
	return tool_def.get(fallback_key, default_value)


func _variants_equal(left, right) -> bool:
	if left is Dictionary and right is Dictionary:
		return _dictionaries_equal(left as Dictionary, right as Dictionary)
	if left is Array and right is Array:
		return _arrays_equal(left as Array, right as Array)
	return left == right


func _dictionaries_equal(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	var left_keys := left.keys()
	left_keys.sort()
	var right_keys := right.keys()
	right_keys.sort()
	for index in range(left_keys.size()):
		var left_key = left_keys[index]
		var right_key = right_keys[index]
		if left_key != right_key:
			return false
		if not _variants_equal(left.get(left_key), right.get(right_key)):
			return false
	return true


func _arrays_equal(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	for index in range(left.size()):
		if not _variants_equal(left[index], right[index]):
			return false
	return true


func _get_user_definitions_revision(executor) -> int:
	if executor != null and executor.has_method("get_definitions_revision"):
		var revision = executor.get_definitions_revision()
		if revision is int:
			return int(revision)
		if revision is float:
			return int(revision)
	return -1


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
