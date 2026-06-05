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
		"list_main_screens":
			return _list_main_screens(ei)
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
	var main_screen_container := _editor_main_screen_container_name(ei)
	var main_screens := _collect_main_screens(ei, main_screen_container)
	var current_name := _infer_current_main_screen_name(main_screens, main_screen_container)

	return _success({
		"current_screen": current_name,
		"current_screen_source": _current_screen_source(main_screens, current_name),
		"main_screen_container": main_screen_container,
		"available": _extract_main_screen_names(main_screens),
		"main_screens": main_screens
	})


func _list_main_screens(ei) -> Dictionary:
	var main_screen_container := _editor_main_screen_container_name(ei)
	var main_screens := _collect_main_screens(ei, main_screen_container)
	var current_name := _infer_current_main_screen_name(main_screens, main_screen_container)
	return _success({
		"current_screen": current_name,
		"current_screen_source": _current_screen_source(main_screens, current_name),
		"main_screen_container": main_screen_container,
		"count": main_screens.size(),
		"main_screens": main_screens,
		"available": _extract_main_screen_names(main_screens)
	})


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
	screen = screen.strip_edges()
	if screen.is_empty():
		return _error("Screen is required")

	var before_data: Dictionary = _get_main_screen(ei).get("data", {})
	var before_screen := str(before_data.get("current_screen", ""))
	var before_screens: Array = before_data.get("main_screens", [])
	var matched_screen := _find_main_screen_summary(before_screens, screen)
	if matched_screen.is_empty():
		return _error("Screen not found: %s" % screen, {
			"screen": screen,
			"before_screen": before_screen,
			"available": _extract_main_screen_names(before_screens),
			"main_screens": before_screens
		})
	var resolved_screen := _main_screen_summary_label(matched_screen)
	ei.set_main_screen_editor(resolved_screen)
	var after_data: Dictionary = _get_main_screen(ei).get("data", {})
	var after_screen := str(after_data.get("current_screen", ""))
	var after_screens: Array = after_data.get("main_screens", [])
	var after_matched_screen := _find_main_screen_summary(after_screens, resolved_screen)
	if after_matched_screen.is_empty():
		return _error("Screen switch did not take effect: %s" % resolved_screen, {
			"screen": resolved_screen,
			"requested_screen": screen,
			"before_screen": before_screen,
			"after_screen": after_screen,
			"current_screen": after_screen,
			"current_screen_source": str(after_data.get("current_screen_source", "")),
			"main_screen_container": str(after_data.get("main_screen_container", "")),
			"matched_main_screen": matched_screen,
			"main_screens": after_screens,
			"available": _extract_main_screen_names(after_screens),
			"visible_button_found": false,
			"switch_requested": true,
			"switch_verified": false,
			"verification_source": "visible_target"
		})
	var active_state_observable := bool(after_matched_screen.get("active_state_observable", false))
	if active_state_observable and not bool(after_matched_screen.get("active", false)):
		return _error("Screen switch did not take effect: %s" % resolved_screen, {
			"screen": resolved_screen,
			"requested_screen": screen,
			"before_screen": before_screen,
			"after_screen": after_screen,
			"current_screen": after_screen,
			"current_screen_source": str(after_data.get("current_screen_source", "")),
			"main_screen_container": str(after_data.get("main_screen_container", "")),
			"matched_main_screen": after_matched_screen,
			"main_screens": after_screens,
			"available": _extract_main_screen_names(after_screens),
			"visible_button_found": true,
			"switch_requested": true,
			"switch_verified": false,
			"verification_source": "active_button_state"
		})
	return _success({
		"screen": resolved_screen,
		"requested_screen": screen,
		"before_screen": before_screen,
		"after_screen": after_screen,
		"current_screen": after_screen,
		"current_screen_source": str(after_data.get("current_screen_source", "")),
		"main_screen_container": str(after_data.get("main_screen_container", "")),
		"matched_main_screen": after_matched_screen,
		"main_screens": after_screens,
		"available": _extract_main_screen_names(after_screens),
		"visible_button_found": true,
		"switch_requested": true,
		"switch_verified": active_state_observable and bool(after_matched_screen.get("active", false)),
		"verification_source": "active_button_state" if active_state_observable else "visible_target"
	}, "Switched to %s editor" % resolved_screen)


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


func _editor_main_screen_container_name(ei) -> String:
	var current_screen = ei.get_editor_main_screen() if ei != null and ei.has_method("get_editor_main_screen") else null
	if current_screen == null:
		return ""
	var container_name := str(current_screen.name)
	if container_name.is_empty() and current_screen.has_method("get_class"):
		container_name = str(current_screen.get_class())
	return container_name


func _collect_main_screens(ei, current_name: String) -> Array[Dictionary]:
	var builtin_names := ["2D", "3D", "Script", "AssetLib"]
	var collected: Array[Dictionary] = []
	var base_control = ei.get_base_control() if ei != null and ei.has_method("get_base_control") else null
	if base_control != null:
		_collect_main_screen_buttons(base_control, collected, current_name, 0)
	for builtin_name in builtin_names:
		if _main_screen_summary_name_exists(collected, builtin_name):
			continue
		collected.append({
			"name": builtin_name,
			"title": builtin_name,
			"text": builtin_name,
			"control_path": "",
			"visible": true,
			"disabled": false,
			"active": builtin_name == current_name,
			"inferred_active": builtin_name == current_name,
			"active_state_observable": false,
			"rect": {},
			"source": "builtin"
		})
	return collected


func _collect_main_screen_buttons(node, collected: Array[Dictionary], current_name: String, depth: int) -> void:
	if node == null or depth > 8 or not node.has_method("get_children"):
		return
	for child in node.get_children():
		if child == null:
			continue
		var summary := _build_main_screen_button_summary(child, current_name)
		if not summary.is_empty() and not _main_screen_summary_exists(collected, str(summary.get("name", "")), str(summary.get("control_path", ""))):
			collected.append(summary)
		_collect_main_screen_buttons(child, collected, current_name, depth + 1)


func _build_main_screen_button_summary(control, current_name: String) -> Dictionary:
	var control_class := _control_class_name(control)
	if control_class.find("Button") == -1:
		return {}
	var label := _control_label(control)
	if label.is_empty():
		return {}
	var rect := _control_rect(control)
	var builtin_names := ["2D", "3D", "Script", "AssetLib"]
	if label in builtin_names:
		if not _is_builtin_main_screen_button(control, builtin_names):
			return {}
	elif not _is_plugin_main_screen_button(control, builtin_names):
		return {}
	var source := "builtin" if label in builtin_names else "plugin"
	var active_state_observable := _control_active_state_observable(control)
	var active := _control_active(control) if active_state_observable else label == current_name
	return {
		"name": label,
		"title": label,
		"text": label,
		"control_path": _control_path(control),
		"visible": _control_visible(control),
		"disabled": _control_disabled(control),
		"active": active,
		"inferred_active": active,
		"active_state_observable": active_state_observable,
		"rect": rect,
		"source": source
	}


func _find_main_screen_summary(screens: Array, screen: String) -> Dictionary:
	for item in screens:
		if item is Dictionary:
			var data: Dictionary = item
			if str(data.get("name", "")).to_lower() == screen.to_lower() or str(data.get("title", "")).to_lower() == screen.to_lower() or str(data.get("text", "")).to_lower() == screen.to_lower():
				return data.duplicate(true)
	return {}


func _main_screen_summary_label(screen: Dictionary) -> String:
	for property_name in ["name", "title", "text"]:
		var value := str(screen.get(property_name, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _screen_names_equal(left: String, right: String) -> bool:
	return left.strip_edges().to_lower() == right.strip_edges().to_lower()


func _infer_current_main_screen_name(screens: Array, fallback_name: String) -> String:
	for item in screens:
		if item is Dictionary:
			var data: Dictionary = item
			if bool(data.get("active", false)):
				return _main_screen_summary_label(data)
	for item in screens:
		if item is Dictionary:
			var label := _main_screen_summary_label(item as Dictionary)
			if _screen_names_equal(label, fallback_name):
				return label
	return ""


func _current_screen_source(screens: Array, current_name: String) -> String:
	if current_name.is_empty():
		return "unavailable"
	for item in screens:
		if item is Dictionary:
			var data: Dictionary = item
			if _screen_names_equal(_main_screen_summary_label(data), current_name) and bool(data.get("active", false)) and bool(data.get("active_state_observable", false)):
				return "active_button_state"
	return "fallback"


func _extract_main_screen_names(screens: Array) -> Array[String]:
	var names: Array[String] = []
	for item in screens:
		if item is Dictionary:
			var name := str((item as Dictionary).get("name", "")).strip_edges()
			if not name.is_empty() and not names.has(name):
				names.append(name)
	return names


func _main_screen_summary_name_exists(screens: Array, name: String) -> bool:
	for item in screens:
		if item is Dictionary:
			var label := _main_screen_summary_label(item as Dictionary)
			if _screen_names_equal(label, name):
				return true
	return false


func _main_screen_summary_exists(screens: Array, name: String, control_path: String) -> bool:
	for item in screens:
		if item is Dictionary:
			var data: Dictionary = item
			if not control_path.is_empty() and str(data.get("control_path", "")) == control_path:
				return true
			if str(data.get("name", "")).to_lower() == name.to_lower() and str(data.get("control_path", "")).is_empty():
				return true
	return false


func _is_plugin_main_screen_button(control, builtin_names: Array) -> bool:
	if not _control_visible(control) or _control_disabled(control):
		return false
	if not _has_named_main_screen_ancestor(control):
		return false
	return _has_builtin_main_screen_group_sibling(control, builtin_names)


func _is_builtin_main_screen_button(control, builtin_names: Array) -> bool:
	if not _control_visible(control) or _control_disabled(control):
		return false
	if not _has_named_main_screen_ancestor(control):
		return false
	return _has_builtin_main_screen_group_sibling(control, builtin_names)


func _has_builtin_main_screen_group_sibling(control, builtin_names: Array) -> bool:
	if control == null or not control.has_method("get_parent"):
		return false
	var button_group = _control_button_group(control)
	if button_group == null:
		return false
	var parent = control.get_parent()
	if parent == null or not parent.has_method("get_children"):
		return false
	for sibling in parent.get_children():
		if sibling == null or sibling == control:
			continue
		var sibling_class := _control_class_name(sibling)
		if sibling_class.find("Button") == -1:
			continue
		if _control_button_group(sibling) == button_group and builtin_names.has(_control_label(sibling)):
			return true
	return false


func _has_named_main_screen_ancestor(control) -> bool:
	var current = control
	var depth := 0
	while current != null and depth < 6:
		var path_label := ""
		if current.has_method("get_path"):
			path_label = str(current.get_path()).to_lower()
		var node_name := ""
		if current is Object:
			node_name = str(current.get("name")).to_lower()
		var combined := "%s %s" % [node_name, path_label]
		if combined.find("main_screen") != -1 or combined.find("mainscreen") != -1 or combined.find("main screen") != -1:
			return true
		if not current.has_method("get_parent"):
			return false
		current = current.get_parent()
		depth += 1
	return false


func _control_class_name(control) -> String:
	if control.has_method("get_ui_class"):
		return str(control.get_ui_class())
	if control.has_method("get_popup_class"):
		return str(control.get_popup_class())
	if control.has_method("get_class"):
		return str(control.get_class())
	return ""


func _control_label(control) -> String:
	for property_name in ["text", "title"]:
		var value = control.get(property_name) if control is Object else null
		var label := str(value).strip_edges()
		if not label.is_empty():
			return label
	return ""


func _control_button_group(control):
	if control != null and control.has_method("get_button_group"):
		return control.get_button_group()
	return null


func _control_active_state_observable(control) -> bool:
	if control == null:
		return false
	if control.has_method("is_pressed"):
		return true
	if control is Object:
		for property_name in ["button_pressed", "pressed", "selected"]:
			if control.get(property_name) != null:
				return true
	return false


func _control_active(control) -> bool:
	if control != null and control.has_method("is_pressed"):
		return bool(control.is_pressed())
	if control is Object:
		for property_name in ["button_pressed", "pressed", "selected"]:
			var value = control.get(property_name)
			if value != null:
				return bool(value)
	return false


func _control_path(control) -> String:
	if control.has_method("get_path"):
		return str(control.get_path())
	return ""


func _control_visible(control) -> bool:
	if control.has_method("is_visible_in_tree"):
		return bool(control.is_visible_in_tree())
	if control is Object:
		return bool(control.get("visible"))
	return true


func _control_disabled(control) -> bool:
	if control is Object:
		return bool(control.get("disabled"))
	return false


func _control_rect(control) -> Dictionary:
	if not control.has_method("get_global_rect"):
		return {}
	var rect: Rect2 = control.get_global_rect()
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y
	}


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
