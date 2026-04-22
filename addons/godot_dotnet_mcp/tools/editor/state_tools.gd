@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor state tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	if not ei:
		return _error("Editor interface not available")

	var tool_name = args.get("tool", "")
	var action = args.get("action", "")

	match tool_name:
		"status":
			return _execute_status(ei, action, args)
		"screenshot":
			return _execute_screenshot(ei, action, args)
		_:
			return _error("Unknown tool: %s" % tool_name)


func _execute_status(ei, action: String, args: Dictionary) -> Dictionary:
	match action:
		"get_info":
			return _get_editor_info(ei)
		"get_main_screen":
			return _get_main_screen(ei)
		"set_main_screen":
			return _set_main_screen(ei, args.get("screen", ""))
		"get_distraction_free":
			return _get_distraction_free(ei)
		"set_distraction_free":
			return _set_distraction_free(ei, args.get("enabled", false))
		"get_godot_path":
			return _get_godot_path()
		_:
			return _error("Unknown action: %s" % action)


func _execute_screenshot(ei, action: String, args: Dictionary) -> Dictionary:
	match action:
		"capture":
			return _capture_editor_screenshot(ei, str(args.get("path", "")))
		_:
			return _error("Unknown action: %s" % action)


func _get_editor_info(ei) -> Dictionary:
	var version_info = Engine.get_version_info()
	return _success({
		"godot_version": "%d.%d.%d" % [int(version_info.get("major", 0)), int(version_info.get("minor", 0)), int(version_info.get("patch", 0))],
		"version_string": str(version_info.get("string", "")),
		"is_debug": OS.is_debug_build(),
		"os": str(OS.get_name()),
		"editor_scale": float(ei.get_editor_scale())
	})


func _get_main_screen(ei) -> Dictionary:
	var current_screen = ei.get_editor_main_screen()
	var current_name = ""
	if current_screen != null:
		current_name = str(current_screen.name)
		if current_name.is_empty():
			current_name = str(current_screen.get_class())

	return _success({"current_screen": current_name, "available": ["2D", "3D", "Script", "AssetLib"]})


func _set_main_screen(ei, screen: String) -> Dictionary:
	if screen.is_empty():
		return _error("Screen is required")

	var valid_screens = ["2D", "3D", "Script", "AssetLib"]
	if not screen in valid_screens:
		return _error("Invalid screen: %s. Valid options: %s" % [screen, str(valid_screens)])

	ei.set_main_screen_editor(screen)
	return _success({"screen": screen}, "Switched to %s editor" % screen)


func _get_distraction_free(ei) -> Dictionary:
	return _success({"enabled": ei.is_distraction_free_mode_enabled()})


func _set_distraction_free(ei, enabled: bool) -> Dictionary:
	ei.set_distraction_free_mode(enabled)
	return _success({"enabled": enabled}, "Distraction-free mode %s" % ("enabled" if enabled else "disabled"))


func _get_godot_path() -> Dictionary:
	return _success({
		"godot_executable_path": OS.get_executable_path(),
		"project_root_path": ProjectSettings.globalize_path("res://")
	})


func _capture_editor_screenshot(ei, path: String) -> Dictionary:
	var base_control = ei.get_base_control()
	if base_control == null:
		return _error("Editor base control not available")

	var viewport = base_control.get_viewport()
	if viewport == null or not viewport.has_method("get_texture"):
		return _error("Editor viewport not available")

	var texture = viewport.get_texture()
	if texture == null or not texture.has_method("get_image"):
		return _error("Editor viewport texture not available")

	var image = texture.get_image()
	if image == null or image.is_empty():
		return _error("Editor screenshot image is empty")

	var target_path := path.strip_edges()
	if target_path.is_empty():
		target_path = "user://godot_mcp_editor_captures/editor_%s.png" % str(Time.get_unix_time_from_system())
	var absolute_path = ProjectSettings.globalize_path(target_path)
	var dir_error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if dir_error != OK:
		return _error("Failed to create screenshot directory: %s" % absolute_path.get_base_dir())

	var save_error = image.save_png(absolute_path)
	if save_error != OK:
		return _error("Failed to save editor screenshot: %s" % error_string(save_error))

	return _success({"path": target_path, "absolute_path": absolute_path, "width": image.get_width(), "height": image.get_height()}, "Editor screenshot captured")
