@tool
extends RefCounted
class_name ToolLoaderEnablementService


var _disabled_tools: Dictionary = {}
var _disabled_tools_signature := ""


func configure_disabled_tools(disabled_tools: Array) -> bool:
	var next_disabled := {}
	var names := PackedStringArray()
	for tool_name in disabled_tools:
		var normalized := str(tool_name)
		next_disabled[normalized] = true
		names.append(normalized)
	names.sort()
	var next_signature := "\n".join(names)
	if next_signature == _disabled_tools_signature:
		return false
	_disabled_tools.clear()
	for tool_name in next_disabled.keys():
		_disabled_tools[str(tool_name)] = true
	_disabled_tools_signature = next_signature
	return true


func get_disabled_tools() -> Array:
	return _disabled_tools.keys()


func is_tool_enabled(tool_name: String) -> bool:
	return not _disabled_tools.has(tool_name)


func count_enabled_tools_in_category(category: String, tool_definitions_by_category: Dictionary) -> int:
	var count := 0
	for tool_def in _array(tool_definitions_by_category.get(category, [])):
		if not (tool_def is Dictionary):
			continue
		var full_name = "%s_%s" % [category, str((tool_def as Dictionary).get("name", ""))]
		if is_tool_enabled(full_name):
			count += 1
	return count


func category_has_enabled_tools(category: String, tool_definitions_by_category: Dictionary) -> bool:
	return count_enabled_tools_in_category(category, tool_definitions_by_category) > 0


func _array(value) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
