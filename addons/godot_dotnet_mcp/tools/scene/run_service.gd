@tool
extends "res://addons/godot_dotnet_mcp/tools/scene/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	match action:
		"play_main":
			editor_interface.play_main_scene()
			return _success(null, "Playing main scene")
		"play_current":
			editor_interface.play_current_scene()
			return _success(null, "Playing current scene")
		"play_custom":
			var path := _normalize_res_path(str(args.get("path", "")))
			if path.is_empty():
				return _error("Path required for play_custom")
			editor_interface.play_custom_scene(path)
			return _success({"path": path}, "Playing scene: %s" % path)
		"stop":
			editor_interface.stop_playing_scene()
			return _success(null, "Stopped playing scene")
		_:
			return _error("Unknown action: %s" % action)
