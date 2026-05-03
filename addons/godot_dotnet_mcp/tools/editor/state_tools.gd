@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")
const MCPEditorSessionIdentity = preload("res://addons/godot_dotnet_mcp/plugin/runtime/editor_session_identity.gd")

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
		"get_focus_context":
			return _get_focus_context(ei)
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
			return _capture_editor_screenshot(ei, args)
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


func _get_focus_context(ei) -> Dictionary:
	var base_control = ei.get_base_control()
	if base_control == null:
		return _error("Editor base control not available")

	var viewport = base_control.get_viewport()
	var focus_owner = null
	if viewport != null and viewport.has_method("gui_get_focus_owner"):
		focus_owner = viewport.gui_get_focus_owner()

	var selected_paths: Array[String] = []
	var selection = null
	if ei.has_method("get_selection"):
		selection = ei.get_selection()
	if selection != null and selection.has_method("get_selected_nodes"):
		for node in selection.get_selected_nodes():
			if node != null and node.has_method("get_path"):
				selected_paths.append(str(node.get_path()))

	var focus_owner_name := ""
	var focus_owner_class := ""
	var focus_owner_path := ""
	if focus_owner != null:
		focus_owner_name = str(focus_owner.name)
		if focus_owner.has_method("get_focus_class"):
			focus_owner_class = str(focus_owner.get_focus_class())
		elif focus_owner.has_method("get_class"):
			focus_owner_class = str(focus_owner.get_class())
		if focus_owner.has_method("get_path"):
			focus_owner_path = str(focus_owner.get_path())

	return _success({
		"has_focus_owner": focus_owner != null,
		"focus_owner_name": focus_owner_name,
		"focus_owner_class": focus_owner_class,
		"focus_owner_path": focus_owner_path,
		"selected_node_count": selected_paths.size(),
		"selected_node_paths": selected_paths
	})


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
	var identity: Dictionary = MCPEditorSessionIdentity.build_identity()
	return _success({
		"godot_executable_path": str(identity.get("godot_executable_path", OS.get_executable_path())),
		"project_root_path": str(identity.get("project_root_path", ProjectSettings.globalize_path("res://"))),
		"editor_session_identity": identity
	})


func _capture_editor_screenshot(ei, args: Dictionary) -> Dictionary:
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

	var capture_mode := "full"
	var region_data := {}
	var region_x_value = args.get("x", null)
	var region_y_value = args.get("y", null)
	var region_width_value = args.get("width", null)
	var region_height_value = args.get("height", null)
	if region_x_value != null or region_y_value != null or region_width_value != null or region_height_value != null:
		var region_width := int(region_width_value) if region_width_value != null else 0
		var region_height := int(region_height_value) if region_height_value != null else 0
		if region_width <= 0 or region_height <= 0:
			return _error("Screenshot region width and height must be greater than 0")
		var region_x := maxi(int(region_x_value) if region_x_value != null else 0, 0)
		var region_y := maxi(int(region_y_value) if region_y_value != null else 0, 0)
		if region_x >= image.get_width() or region_y >= image.get_height():
			return _error("Screenshot region origin is outside the editor viewport")
		region_width = mini(region_width, image.get_width() - region_x)
		region_height = mini(region_height, image.get_height() - region_y)
		image = image.get_region(Rect2i(region_x, region_y, region_width, region_height))
		capture_mode = "region"
		region_data = {
			"x": region_x,
			"y": region_y,
			"width": region_width,
			"height": region_height
		}

	var path := str(args.get("path", ""))
	var target_path := MCPUserDataPaths.normalize_editor_capture_output_path(
		path,
		"editor_%s.png" % str(Time.get_unix_time_from_system())
	)
	var absolute_path = ProjectSettings.globalize_path(target_path)
	var dir_error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if dir_error != OK:
		return _error("Failed to create screenshot directory: %s" % absolute_path.get_base_dir())

	var save_error = image.save_png(absolute_path)
	if save_error != OK:
		return _error("Failed to save editor screenshot: %s" % error_string(save_error))

	return _success({
		"path": target_path,
		"absolute_path": absolute_path,
		"width": image.get_width(),
		"height": image.get_height(),
		"capture_mode": capture_mode,
		"region": region_data
	}, "Editor screenshot captured")
