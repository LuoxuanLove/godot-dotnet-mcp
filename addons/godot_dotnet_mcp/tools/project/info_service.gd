@tool
extends "res://addons/godot_dotnet_mcp/tools/project/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	match str(args.get("action", "")):
		"get_info":
			return _get_project_info()
		"get_settings":
			return _get_project_settings(str(args.get("setting", "")))
		"get_features":
			return _get_features()
		"get_export_presets":
			return _get_export_presets()
		_:
			return _error("Unknown action: %s" % str(args.get("action", "")))


func _get_project_info() -> Dictionary:
	var version_info = Engine.get_version_info()
	return _success({
		"name": str(ProjectSettings.get_setting("application/config/name", "Untitled")),
		"description": str(ProjectSettings.get_setting("application/config/description", "")),
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"godot_version": "%d.%d.%d" % [version_info.get("major", 0), version_info.get("minor", 0), version_info.get("patch", 0)],
		"godot_version_string": str(version_info.get("string", "")),
		"project_path": ProjectSettings.globalize_path("res://"),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"window": {
			"width": int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152)),
			"height": int(ProjectSettings.get_setting("display/window/size/viewport_height", 648)),
			"mode": int(ProjectSettings.get_setting("display/window/size/mode", 0)),
			"resizable": bool(ProjectSettings.get_setting("display/window/size/resizable", true))
		}
	})


func _get_project_settings(setting: String) -> Dictionary:
	if not setting.is_empty():
		if not ProjectSettings.has_setting(setting):
			return _error("Setting not found: %s" % setting)

		var value = ProjectSettings.get_setting(setting)
		if typeof(value) == TYPE_OBJECT:
			value = str(value)

		return _success({
			"setting": setting,
			"value": value
		})

	var settings := {}
	var common_settings = [
		"application/config/name",
		"application/config/description",
		"application/run/main_scene",
		"display/window/size/viewport_width",
		"display/window/size/viewport_height",
		"rendering/renderer/rendering_method",
		"physics/2d/default_gravity",
		"physics/3d/default_gravity"
	]

	for setting_path in common_settings:
		if ProjectSettings.has_setting(setting_path):
			settings[setting_path] = ProjectSettings.get_setting(setting_path)

	return _success({"settings": settings})


func _get_features() -> Dictionary:
	var features: Array[String] = []
	if ProjectSettings.has_setting("application/config/features"):
		var feature_values = ProjectSettings.get_setting("application/config/features")
		if feature_values is PackedStringArray:
			for feature in feature_values:
				features.append(feature)

	return _success({
		"features": features,
		"os": OS.get_name(),
		"debug": OS.is_debug_build()
	})


func _get_export_presets() -> Dictionary:
	var presets: Array[Dictionary] = []
	var preset_path = "res://export_presets.cfg"
	if FileAccess.file_exists(preset_path):
		var config := ConfigFile.new()
		var error = config.load(preset_path)
		if error == OK:
			for section in config.get_sections():
				if section.begins_with("preset."):
					presets.append({
						"name": config.get_value(section, "name", ""),
						"platform": config.get_value(section, "platform", ""),
						"export_path": config.get_value(section, "export_path", "")
					})

	return _success({
		"count": presets.size(),
		"presets": presets
	})
