@tool
extends "res://addons/godot_dotnet_mcp/tools/editor/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")
	var editor_settings = editor_interface.get_editor_settings()
	if editor_settings == null:
		return _error("Editor settings not available")

	match action:
		"get":
			var setting := str(args.get("setting", ""))
			if setting.is_empty():
				return _error("Setting path is required")
			if not editor_settings.has_setting(setting):
				return _error("Setting not found: %s" % setting)
			return _success({
				"setting": setting,
				"value": editor_settings.get_setting(setting)
			})
		"set":
			var setting := str(args.get("setting", ""))
			if setting.is_empty():
				return _error("Setting path is required")
			var value = args.get("value")
			editor_settings.set_setting(setting, value)
			return _success({
				"setting": setting,
				"value": value
			}, "Editor setting updated")
		"list_category":
			var category := str(args.get("category", ""))
			if category.is_empty():
				return _error("Category is required")
			var settings := {}
			for prop in editor_settings.get_property_list():
				var prop_name := str(prop.name)
				if prop_name.begins_with(category + "/"):
					settings[prop_name] = editor_settings.get_setting(prop_name)
			return _success({
				"category": category,
				"count": settings.size(),
				"settings": settings
			})
		"reset":
			var setting := str(args.get("setting", ""))
			if setting.is_empty():
				return _error("Setting path is required")
			if not editor_settings.has_setting(setting):
				return _error("Setting not found: %s" % setting)
			editor_settings.set_setting(setting, null)
			return _success({"setting": setting}, "Editor setting reset")
		_:
			return _error("Unknown action: %s" % action)
