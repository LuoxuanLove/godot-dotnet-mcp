@tool
extends "res://addons/godot_dotnet_mcp/tools/project/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"list":
			return _list_autoloads()
		"add":
			return _add_autoload(str(args.get("name", "")), str(args.get("path", "")))
		"remove":
			return _remove_autoload(str(args.get("name", "")))
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _list_autoloads() -> Dictionary:
	var autoloads: Array[Dictionary] = []
	for prop in ProjectSettings.get_property_list():
		var prop_name := str(prop.name)
		if prop_name.begins_with("autoload/"):
			var autoload_name = prop_name.substr(9)
			var path_value = str(ProjectSettings.get_setting(prop_name))
			var is_singleton = path_value.begins_with("*")
			if is_singleton:
				path_value = path_value.substr(1)
			autoloads.append({
				"name": autoload_name,
				"path": path_value,
				"singleton": is_singleton
			})

	return _success({
		"count": autoloads.size(),
		"autoloads": autoloads
	})


func _add_autoload(_name: String, _path: String) -> Dictionary:
	return _error("Adding autoloads through MCP is disabled for safety")


func _remove_autoload(name: String) -> Dictionary:
	if name.is_empty():
		return _error("Autoload name is required")

	var setting_path = "autoload/" + name
	if not ProjectSettings.has_setting(setting_path):
		return _error("Autoload not found: %s" % name)

	ProjectSettings.set_setting(setting_path, null)
	var error = ProjectSettings.save()
	if error != OK:
		return _error("Failed to save project settings")

	return _success({"name": name}, "Autoload removed")
