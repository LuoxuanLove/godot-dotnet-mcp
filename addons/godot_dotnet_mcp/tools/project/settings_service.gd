@tool
extends "res://addons/godot_dotnet_mcp/tools/project/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"set":
			return _set_setting(str(args.get("setting", "")), args.get("value"))
		"reset":
			return _reset_setting(str(args.get("setting", "")))
		"list_category":
			return _list_category(str(args.get("category", "")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _set_setting(setting: String, value) -> Dictionary:
	if setting.is_empty():
		return _error("Setting path is required")

	ProjectSettings.set_setting(setting, value)
	var error = ProjectSettings.save()
	if error != OK:
		return _error("Failed to save project settings")

	return _success({
		"setting": setting,
		"value": value
	}, "Setting updated")


func _reset_setting(setting: String) -> Dictionary:
	if setting.is_empty():
		return _error("Setting path is required")
	if not ProjectSettings.has_setting(setting):
		return _error("Setting not found: %s" % setting)

	ProjectSettings.set_setting(setting, null)
	var error = ProjectSettings.save()
	if error != OK:
		return _error("Failed to save project settings")

	return _success({"setting": setting}, "Setting reset to default")


func _list_category(category: String) -> Dictionary:
	if category.is_empty():
		return _error("Category is required")

	var settings := {}
	for prop in ProjectSettings.get_property_list():
		var prop_name := str(prop.name)
		if prop_name.begins_with(category + "/"):
			settings[prop_name] = ProjectSettings.get_setting(prop_name)

	return _success({
		"category": category,
		"count": settings.size(),
		"settings": settings
	})
