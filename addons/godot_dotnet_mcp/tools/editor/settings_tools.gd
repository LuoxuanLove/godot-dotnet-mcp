@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor settings tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	if not ei:
		return _error("Editor interface not available")

	match action:
		"get":
			return _get_editor_setting(ei, args.get("setting", ""))
		"set":
			return _set_editor_setting(ei, args.get("setting", ""), args.get("value"))
		"list_category":
			return _list_editor_category(ei, args.get("category", ""))
		"reset":
			return _reset_editor_setting(ei, args.get("setting", ""))
		_:
			return _error("Unknown action: %s" % action)


func _get_editor_setting(ei, setting: String) -> Dictionary:
	if setting.is_empty():
		return _error("Setting path is required")

	var editor_settings = ei.get_editor_settings()
	if not editor_settings:
		return _error("Editor settings not available")

	if not editor_settings.has_setting(setting):
		return _error("Setting not found: %s" % setting)

	return _success({
		"setting": setting,
		"value": editor_settings.get_setting(setting)
	})


func _set_editor_setting(ei, setting: String, value) -> Dictionary:
	if setting.is_empty():
		return _error("Setting path is required")

	var editor_settings = ei.get_editor_settings()
	if not editor_settings:
		return _error("Editor settings not available")

	editor_settings.set_setting(setting, value)

	return _success({
		"setting": setting,
		"value": value
	}, "Editor setting updated")


func _list_editor_category(ei, category: String) -> Dictionary:
	if category.is_empty():
		return _error("Category is required")

	var editor_settings = ei.get_editor_settings()
	if not editor_settings:
		return _error("Editor settings not available")

	var settings: Dictionary = {}
	for prop in editor_settings.get_property_list():
		var prop_name = str(prop.name)
		if prop_name.begins_with(category + "/"):
			settings[prop_name] = editor_settings.get_setting(prop_name)

	return _success({
		"category": category,
		"count": settings.size(),
		"settings": settings
	})


func _reset_editor_setting(ei, setting: String) -> Dictionary:
	if setting.is_empty():
		return _error("Setting path is required")

	var editor_settings = ei.get_editor_settings()
	if not editor_settings:
		return _error("Editor settings not available")

	if not editor_settings.has_setting(setting):
		return _error("Setting not found: %s" % setting)

	editor_settings.set_setting(setting, null)

	return _success({"setting": setting}, "Editor setting reset")
