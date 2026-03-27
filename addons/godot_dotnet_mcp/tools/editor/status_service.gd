@tool
extends "res://addons/godot_dotnet_mcp/tools/editor/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	match action:
		"get_info":
			var version_info = Engine.get_version_info()
			return _success({
				"godot_version": "%d.%d.%d" % [int(version_info.get("major", 0)), int(version_info.get("minor", 0)), int(version_info.get("patch", 0))],
				"version_string": str(version_info.get("string", "")),
				"is_debug": OS.is_debug_build(),
				"os": str(OS.get_name()),
				"editor_scale": float(editor_interface.get_editor_scale())
			})
		"get_main_screen":
			var current_screen = editor_interface.get_editor_main_screen()
			var current_name := ""
			if current_screen != null:
				current_name = str(current_screen.name)
				if current_name.is_empty():
					current_name = str(current_screen.get_class())
			return _success({
				"current_screen": current_name,
				"available": ["2D", "3D", "Script", "AssetLib"]
			})
		"set_main_screen":
			var screen := str(args.get("screen", ""))
			if screen.is_empty():
				return _error("Screen is required")
			var valid_screens = ["2D", "3D", "Script", "AssetLib"]
			if not screen in valid_screens:
				return _error("Invalid screen: %s. Valid options: %s" % [screen, str(valid_screens)])
			editor_interface.set_main_screen_editor(screen)
			return _success({"screen": screen}, "Switched to %s editor" % screen)
		"get_distraction_free":
			return _success({"enabled": editor_interface.is_distraction_free_mode_enabled()})
		"set_distraction_free":
			var enabled := bool(args.get("enabled", false))
			editor_interface.set_distraction_free_mode(enabled)
			return _success({"enabled": enabled}, "Distraction-free mode %s" % ("enabled" if enabled else "disabled"))
		_:
			return _error("Unknown action: %s" % action)
