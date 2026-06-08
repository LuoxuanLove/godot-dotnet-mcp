@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")

## Editor UI control tools for Godot MCP

const DEFAULT_LIST_LIMIT := 200
const DEFAULT_MAX_DEPTH := 6
const DEFAULT_WAIT_TIMEOUT_MS := 1000
const DEFAULT_WAIT_POLL_INTERVAL_MS := 50
const MAX_WAIT_TIMEOUT_MS := 5000
const MAX_WAIT_POLL_INTERVAL_MS := 500
const SEMANTIC_DOCK_ROOTS := ["mcpdock", "mcp"]
const DOCK_VISIBLE_NAME := "MCP"
const DOCK_LEGACY_NAME := "MCPDock"


class ClickSignalRecorder:
	extends RefCounted

	var counts := {}

	func record_pressed() -> void:
		_record("pressed")

	func record_button_down() -> void:
		_record("button_down")

	func record_button_up() -> void:
		_record("button_up")

	func record_toggled(_pressed: bool) -> void:
		_record("toggled")

	func record_gui_input(_event) -> void:
		_record("gui_input")

	func record_mouse_entered() -> void:
		_record("mouse_entered")

	func record_mouse_exited() -> void:
		_record("mouse_exited")

	func to_dictionary() -> Dictionary:
		return counts.duplicate(true)

	func _record(signal_name: String) -> void:
		counts[signal_name] = int(counts.get(signal_name, 0)) + 1


func execute(ei, args: Dictionary) -> Dictionary:
	if not ei:
		return _error("Editor interface not available")

	var action := str(args.get("action", "")).strip_edges()
	match action:
		"list_visible":
			return _list_visible_controls(ei, args)
		"wait_for_ui":
			if int(args.get("timeout_ms", DEFAULT_WAIT_TIMEOUT_MS)) > 0:
				return _error("wait_for_ui with timeout_ms > 0 requires async execution")
			return _wait_for_ui_once(ei, args)
		"list_dock_tabs":
			return _list_dock_tabs(ei, bool(args.get("include_hidden", true)))
		"activate_dock_tab":
			return _activate_dock_tab(ei, str(args.get("title", "")).strip_edges())
		"activate_ui":
			return _activate_ui(ei, args)
		"list_tree_items":
			return _list_tree_items(ei, args)
		"select_tree_item":
			return _select_tree_item(ei, args)
		"list_menus":
			return _list_menus(ei, args)
		"open_menu":
			return _open_menu(ei, args)
		"select_menu_item":
			return _select_menu_item(ei, args)
		"get_control":
			return _get_control(ei, str(args.get("target_path", "")).strip_edges())
		"capture_control":
			return _capture_control(ei, args)
		"focus_control":
			return _focus_control(ei, str(args.get("target_path", "")).strip_edges())
		"activate_control":
			return _activate_control(ei, str(args.get("target_path", "")).strip_edges())
		"click_control":
			return _click_control(ei, args, MOUSE_BUTTON_LEFT, "left")
		"right_click_control":
			return _click_control(ei, args, MOUSE_BUTTON_RIGHT, "right")
		"hover_control":
			return _hover_control(ei, args)
		"leave_control":
			return _leave_control(ei, args)
		"set_text":
			return _set_control_text(ei, str(args.get("target_path", "")).strip_edges(), str(args.get("text", "")))
		"set_value":
			return _set_control_value(ei, str(args.get("target_path", "")).strip_edges(), args.get("value"))
		_:
			return _error("Unknown action: %s" % action)


func execute_async(ei, args: Dictionary) -> Dictionary:
	if not ei:
		return _error("Editor interface not available")

	var action := str(args.get("action", "")).strip_edges()
	match action:
		"wait_for_ui":
			return await _wait_for_ui_async(ei, args)
		_:
			return execute(ei, args)


func _list_visible_controls(ei, args: Dictionary) -> Dictionary:
	var root = _get_editor_root(ei)
	if root == null:
		return _error("Editor base control not available")

	var include_hidden := bool(args.get("include_hidden", false))
	var class_filter := str(args.get("class_name", "")).strip_edges()
	var text_query := str(args.get("text_query", "")).strip_edges().to_lower()
	var limit := maxi(int(args.get("limit", DEFAULT_LIST_LIMIT)), 1)
	var max_depth := maxi(int(args.get("max_depth", DEFAULT_MAX_DEPTH)), 0)

	var matches: Array[Dictionary] = []
	_collect_controls_recursive(root, "", 0, max_depth, include_hidden, class_filter, text_query, limit, matches)
	return _success({
		"count": matches.size(),
		"controls": matches
	}, "Visible editor controls listed")


func _wait_for_ui_once(ei, args: Dictionary) -> Dictionary:
	var root = _get_editor_root(ei)
	if root == null:
		return _error("Editor base control not available")

	var validation := _validate_wait_args(args)
	if not bool(validation.get("success", false)):
		return validation
	var validation_data: Dictionary = validation.get("data", {})
	var condition := str(validation_data.get("condition", "exists"))
	var timeout_ms := 0
	var started_ms := Time.get_ticks_msec()
	var snapshot := _build_wait_snapshot(ei, args, condition)
	snapshot["elapsed_ms"] = Time.get_ticks_msec() - started_ms
	snapshot["poll_count"] = 1
	snapshot["timeout_ms"] = timeout_ms
	snapshot["poll_interval_ms"] = 0
	if bool(snapshot.get("condition_met", false)):
		return _success(snapshot, "Editor UI condition satisfied")
	return _error("Timed out waiting for editor UI condition: %s" % condition, snapshot)

func _wait_for_ui_async(ei, args: Dictionary) -> Dictionary:
	var root = _get_editor_root(ei)
	if root == null:
		return _error("Editor base control not available")

	var validation := _validate_wait_args(args)
	if not bool(validation.get("success", false)):
		return validation
	var validation_data: Dictionary = validation.get("data", {})
	var condition := str(validation_data.get("condition", "exists"))
	var timeout_ms := clampi(int(args.get("timeout_ms", DEFAULT_WAIT_TIMEOUT_MS)), 0, MAX_WAIT_TIMEOUT_MS)
	var poll_interval_ms := clampi(int(args.get("poll_interval_ms", DEFAULT_WAIT_POLL_INTERVAL_MS)), 10, MAX_WAIT_POLL_INTERVAL_MS)
	var started_ms := Time.get_ticks_msec()
	var deadline_ms := started_ms + timeout_ms
	var poll_count := 0
	var last_snapshot := {}

	while true:
		poll_count += 1
		var snapshot := _build_wait_snapshot(ei, args, condition)
		last_snapshot = snapshot
		if bool(snapshot.get("condition_met", false)):
			var elapsed_ms := Time.get_ticks_msec() - started_ms
			snapshot["elapsed_ms"] = elapsed_ms
			snapshot["poll_count"] = poll_count
			snapshot["timeout_ms"] = timeout_ms
			snapshot["poll_interval_ms"] = poll_interval_ms
			return _success(snapshot, "Editor UI condition satisfied")

		if Time.get_ticks_msec() >= deadline_ms:
			break
		var sleep_ms := mini(poll_interval_ms, maxi(deadline_ms - Time.get_ticks_msec(), 0))
		if not await _wait_poll_interval(sleep_ms):
			return _error("SceneTree is required for async wait_for_ui polling")

	var final_elapsed_ms := Time.get_ticks_msec() - started_ms
	last_snapshot["elapsed_ms"] = final_elapsed_ms
	last_snapshot["poll_count"] = poll_count
	last_snapshot["timeout_ms"] = timeout_ms
	last_snapshot["poll_interval_ms"] = poll_interval_ms
	return _error("Timed out waiting for editor UI condition: %s" % condition, last_snapshot)


func _validate_wait_args(args: Dictionary) -> Dictionary:
	var condition := str(args.get("condition", "exists")).strip_edges().to_lower()
	var supported_conditions := ["exists", "not_exists", "visible", "hidden", "text_contains", "text_equals", "enabled", "disabled"]
	if not supported_conditions.has(condition):
		return _error("Unsupported wait_for_ui condition: %s" % condition)
	if condition in ["text_contains", "text_equals"] and str(args.get("text", "")).is_empty():
		return _error("text is required for wait_for_ui condition: %s" % condition)
	return _success({"condition": condition})


func _wait_poll_interval(delay_ms: int) -> bool:
	var main_loop = Engine.get_main_loop()
	if main_loop == null or not main_loop.has_method("create_timer"):
		return false
	if delay_ms <= 0:
		await main_loop.process_frame
		return true
	var timer = main_loop.create_timer(float(delay_ms) / 1000.0)
	await timer.timeout
	return true


func _build_wait_snapshot(ei, args: Dictionary, condition: String) -> Dictionary:
	var root = _get_editor_root(ei)
	var target_path := str(args.get("target_path", "")).strip_edges()
	var class_filter := str(args.get("class_name", "")).strip_edges()
	var text_query := str(args.get("text_query", "")).strip_edges().to_lower()
	var expected_text := str(args.get("text", ""))
	var include_hidden := bool(args.get("include_hidden", false)) or condition in ["hidden", "disabled", "not_exists"]
	var limit := maxi(int(args.get("limit", DEFAULT_LIST_LIMIT)), 1)
	var max_depth := maxi(int(args.get("max_depth", DEFAULT_MAX_DEPTH)), 0)
	var controls: Array[Dictionary] = []
	var matched := {}

	if not target_path.is_empty():
		var target = _find_control(ei, target_path)
		if target != null:
			matched = _describe_control(target, _resolve_parent_path(target), 0)
			if _matches_filters(matched, class_filter, text_query):
				controls.append(matched)
			else:
				matched = {}
	else:
		_collect_controls_recursive(root, "", 0, max_depth, include_hidden, class_filter, text_query, limit, controls)
		if not controls.is_empty():
			matched = controls[0]

	var condition_met := _is_wait_condition_met(condition, matched, expected_text)
	return {
		"condition": condition,
		"condition_met": condition_met,
		"target_path": target_path,
		"class_name": class_filter,
		"text_query": text_query,
		"text": expected_text,
		"matched": matched,
		"observed": {
			"count": controls.size(),
			"controls": controls
		}
	}


func _is_wait_condition_met(condition: String, matched: Dictionary, expected_text: String) -> bool:
	var has_match := not matched.is_empty()
	match condition:
		"exists":
			return has_match
		"not_exists":
			return not has_match
		"visible":
			return has_match and bool(matched.get("visible", false))
		"hidden":
			return not has_match or not bool(matched.get("visible", false))
		"enabled":
			return has_match and not bool(matched.get("disabled", false))
		"disabled":
			return has_match and bool(matched.get("disabled", false))
		"text_contains":
			return has_match and _wait_text_haystack(matched).contains(expected_text.to_lower())
		"text_equals":
			return has_match and _wait_text_values(matched).has(expected_text)
		_:
			return false


func _wait_text_haystack(summary: Dictionary) -> String:
	return " ".join(_wait_text_values(summary)).to_lower()


func _wait_text_values(summary: Dictionary) -> Array[String]:
	return [
		str(summary.get("text", "")),
		str(summary.get("title", "")),
		str(summary.get("name", "")),
		str(summary.get("path", ""))
	]


func _list_dock_tabs(ei, include_hidden: bool) -> Dictionary:
	var root = _get_editor_root(ei)
	if root == null:
		return _error("Editor base control not available")
	var tabs: Array[Dictionary] = []
	_collect_dock_tabs_recursive(root, include_hidden, tabs)
	return _success({
		"count": tabs.size(),
		"tabs": tabs
	}, "Editor dock tabs listed")


func _activate_dock_tab(ei, title: String) -> Dictionary:
	if title.is_empty():
		return _error("title is required")
	var root = _get_editor_root(ei)
	if root == null:
		return _error("Editor base control not available")
	var dock = _find_dock_tab_by_title_recursive(root, title)
	if dock == null:
		return _error("Editor dock tab not found: %s" % title)
	if dock.has_method("make_visible"):
		dock.make_visible()
	elif not _select_owner_tab_for_control(dock, title):
		return _error("Failed to activate editor dock tab: %s" % title)
	return _success({
		"title": title,
		"target_path": _safe_control_path(dock),
		"visible": _is_control_visible(dock),
		"control": _describe_control(dock, _resolve_parent_path(dock), 0)
	}, "Editor dock tab activated")


func _activate_ui(ei, args: Dictionary) -> Dictionary:
	var semantic_path := str(args.get("semantic_path", "")).strip_edges()
	if not semantic_path.is_empty():
		return _activate_semantic_ui_path(ei, semantic_path, args)

	var target_path := str(args.get("target_path", "")).strip_edges()
	var tab_title := str(args.get("tab_title", "")).strip_edges()
	var tab_index := int(args.get("tab_index", -1))
	var title := str(args.get("title", "")).strip_edges()
	var bottom_panel_path := str(args.get("bottom_panel_path", "")).strip_edges()
	var bottom_panel_title := str(args.get("bottom_panel_title", "")).strip_edges()
	if not bottom_panel_path.is_empty() or not bottom_panel_title.is_empty():
		return _activate_bottom_panel(ei, bottom_panel_path, bottom_panel_title, args)
	if not target_path.is_empty() and (not tab_title.is_empty() or tab_index >= 0):
		return _activate_tab_container(ei, target_path, tab_title, tab_index, args)
	if not title.is_empty():
		var dock_result := _activate_dock_tab(ei, title)
		if not bool(dock_result.get("success", false)):
			return dock_result
		return _maybe_capture_activation_result(ei, dock_result, str(dock_result.get("data", {}).get("target_path", "")), args)
	return _error("semantic_path, title, or target_path with tab_title/tab_index is required")


func _list_tree_items(ei, args: Dictionary) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		return _error("target_path is required")
	var tree = _find_control(ei, target_path)
	if tree == null:
		return _error("Editor tree control not found: %s" % target_path)
	if _control_class_name(tree) != "Tree":
		return _error("Editor control is not a Tree: %s" % target_path)
	var text_query := str(args.get("text_query", "")).strip_edges().to_lower()
	var include_hidden := bool(args.get("include_hidden", false))
	var limit := maxi(int(args.get("limit", DEFAULT_LIST_LIMIT)), 1)
	var items: Array[Dictionary] = []
	_collect_tree_items(tree, text_query, include_hidden, limit, items)
	return _success({
		"target_path": target_path,
		"tree": _describe_control(tree, _resolve_parent_path(tree), 0),
		"count": items.size(),
		"items": items
	}, "Editor tree items listed")


func _select_tree_item(ei, args: Dictionary) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		return _error("target_path is required")
	var tree = _find_control(ei, target_path)
	if tree == null:
		return _error("Editor tree control not found: %s" % target_path)
	if _control_class_name(tree) != "Tree":
		return _error("Editor control is not a Tree: %s" % target_path)
	var resolution := _resolve_tree_item(tree, args)
	if not bool(resolution.get("success", false)):
		return resolution
	var resolution_data: Dictionary = resolution.get("data", {})
	var item = resolution_data.get("item")
	if item == null:
		return _error("Editor tree item not found")
	if tree.has_method("set_selected"):
		tree.call("set_selected", item, 0)
	elif item.has_method("select"):
		item.call("select", 0)
	else:
		return _error("Editor tree item cannot be selected")
	if tree.has_method("scroll_to_item"):
		tree.call("scroll_to_item", item, true)
	if tree.has_method("grab_focus"):
		tree.grab_focus()
	var selected_source = (resolution_data.get("resolution", {}) as Dictionary).get("matched", _describe_tree_item(tree, item, int(resolution_data.get("index", -1))))
	var selected := {}
	if selected_source is Dictionary:
		selected = (selected_source as Dictionary).duplicate(true)
	else:
		selected = _describe_tree_item(tree, item, int(resolution_data.get("index", -1)))
	selected["selected"] = true
	return _success({
		"target_path": target_path,
		"selected_item": selected,
		"resolution": resolution_data.get("resolution", {})
	}, "Editor tree item selected")


func _list_menus(ei, args: Dictionary) -> Dictionary:
	var root = _get_editor_root(ei)
	if root == null:
		return _error("Editor base control not available")
	var include_hidden := bool(args.get("include_hidden", false))
	var text_query := str(args.get("text_query", "")).strip_edges().to_lower()
	var limit := maxi(int(args.get("limit", DEFAULT_LIST_LIMIT)), 1)
	var max_depth := maxi(int(args.get("max_depth", DEFAULT_MAX_DEPTH)), 0)
	var menus: Array[Dictionary] = []
	_collect_menu_buttons_recursive(root, 0, max_depth, include_hidden, text_query, limit, menus)
	return _success({
		"count": menus.size(),
		"menus": menus
	}, "Editor menus listed")


func _open_menu(ei, args: Dictionary) -> Dictionary:
	var menu = _resolve_menu_button(ei, args)
	if menu == null:
		return _error("Editor menu not found")
	var open_result := _open_menu_button(menu)
	if not bool(open_result.get("success", false)):
		return open_result
	var popup = _get_menu_popup(menu)
	return _success({
		"target_path": _safe_control_path(menu),
		"menu": _describe_menu_button(menu),
		"popup": _describe_menu_popup(popup),
	}, "Editor menu opened")


func _select_menu_item(ei, args: Dictionary) -> Dictionary:
	var menu = _resolve_menu_button(ei, args)
	if menu == null:
		return _error("Editor menu not found")
	var popup = _get_menu_popup(menu)
	if popup == null:
		return _error("Editor menu does not expose a PopupMenu")
	var open_result := _open_menu_button(menu)
	if not bool(open_result.get("success", false)):
		return open_result
	var index := _resolve_menu_item_index(popup, args)
	if index < 0:
		return _error("Editor menu item not found")
	if _is_popup_menu_item_separator(popup, index):
		return _error("Editor menu item is a separator: %s" % _read_popup_menu_item_label(popup, index))
	if _is_popup_menu_item_disabled(popup, index):
		return _error("Editor menu item is disabled: %s" % _read_popup_menu_item_label(popup, index))
	if _is_popup_menu_item_submenu(popup, index):
		return _error("Editor menu item opens a submenu: %s" % _read_popup_menu_item_label(popup, index))
	_activate_popup_menu_item(popup, index)
	return _success({
		"target_path": _safe_control_path(menu),
		"item_index": index,
		"item_text": _read_popup_menu_item_label(popup, index),
		"item_id": _read_popup_menu_item_id(popup, index),
		"menu": _describe_menu_button(menu),
		"popup": _describe_menu_popup(popup),
	}, "Editor menu item selected")


func _get_control(ei, target_path: String) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	return _success({
		"control": _describe_control(control, _resolve_parent_path(control), 0)
	}, "Editor control fetched")


func _capture_control(ei, args: Dictionary) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	if not _is_control_visible(control):
		return _error("Editor control is not visible: %s" % target_path)
	if not _has_global_rect(control):
		return _error("Editor control does not expose a global rect: %s" % target_path)

	var image = _get_editor_viewport_image(ei)
	if image == null:
		return _error("Editor screenshot image is unavailable")

	var rect: Rect2i = _normalize_capture_rect(control.get_global_rect(), image)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return _error("Editor control rect is empty or outside the editor viewport: %s" % target_path)

	var cropped = image.get_region(rect)
	var output_path := str(args.get("path", "")).strip_edges()
	output_path = MCPUserDataPaths.normalize_editor_control_capture_output_path(output_path, "control_%s_%s.png" % [
		_sanitize_file_label(str(control.name)),
		str(Time.get_unix_time_from_system())
	])
	var save_result = _save_image_png(cropped, output_path)
	if not bool(save_result.get("success", false)):
		return save_result

	var payload: Dictionary = save_result.get("data", {})
	payload["target_path"] = target_path
	payload["capture_mode"] = "control"
	payload["control"] = _describe_control(control, _resolve_parent_path(control), 0)
	return _success(payload, "Editor control screenshot captured")


func _focus_control(ei, target_path: String) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	if not _supports_focus(control):
		return _error("Editor control does not support focus: %s" % target_path)
	control.grab_focus()
	return _success({
		"target_path": target_path,
		"class": _control_class_name(control)
	}, "Editor control focused")


func _activate_control(ei, target_path: String) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	if _is_control_disabled(control):
		return _error("Editor control is disabled: %s" % target_path)
	if not _supports_activation(control):
		return _error("Editor control does not support activation: %s" % target_path)

	if control.has_method("press"):
		control.press()
	elif control.has_method("emit_signal"):
		control.emit_signal("pressed")

	return _success({
		"target_path": target_path,
		"class": _control_class_name(control)
	}, "Editor control activated")


func _click_control(ei, args: Dictionary, button_index: int, button_name: String) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	if not _is_control_visible(control):
		return _error("Editor control is not visible: %s" % target_path)
	if _is_control_disabled(control):
		return _error("Editor control is disabled: %s" % target_path)
	if not _has_non_empty_rect(control):
		return _error("Editor control rect is empty: %s" % target_path)

	var local_position := _resolve_local_click_position(control, args)
	var local_rect := _read_control_local_rect(control)
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x >= local_rect.size.x or local_position.y >= local_rect.size.y:
		return _error("local_x/local_y is outside the control rect: %s" % target_path)

	var viewport_position := _control_local_to_viewport_position(control, local_position)
	var screen_position := _viewport_to_screen_position(control, viewport_position)
	var state_before := _read_click_observable_state(control)
	var signal_capture := _begin_click_signal_capture(control)
	var dispatch_result := _dispatch_control_mouse_click(control, button_index, viewport_position)
	var signal_observation := _end_click_signal_capture(control, signal_capture)
	if not bool(dispatch_result.get("success", false)):
		return dispatch_result
	var state_after := _read_click_observable_state(control)
	var dispatch_data: Dictionary = dispatch_result.get("data", {})

	return _success({
		"target_path": target_path,
		"class": _control_class_name(control),
		"button": button_name,
		"input_dispatch": dispatch_data,
		"target_observation": _build_click_target_observation(control, state_before, state_after, signal_observation),
		"local_position": _vector2_to_dict(local_position),
		"viewport_position": _vector2_to_dict(viewport_position),
		"screen_position": _vector2_to_dict(screen_position),
		"coordinate_mapping": _build_control_coordinate_mapping(control)
	}, "Editor control %s-click dispatched" % button_name)


func _hover_control(ei, args: Dictionary) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	if not _is_control_visible(control):
		return _error("Editor control is not visible: %s" % target_path)
	if not _has_non_empty_rect(control):
		return _error("Editor control rect is empty: %s" % target_path)

	var local_position := _resolve_local_click_position(control, args)
	var local_rect := _read_control_local_rect(control)
	if local_position.x < 0.0 or local_position.y < 0.0 or local_position.x >= local_rect.size.x or local_position.y >= local_rect.size.y:
		return _error("local_x/local_y is outside the control rect: %s" % target_path)

	var viewport_position := _control_local_to_viewport_position(control, local_position)
	var screen_position := _viewport_to_screen_position(control, viewport_position)
	var dispatch_result := _dispatch_control_mouse_motion(control, viewport_position)
	if not bool(dispatch_result.get("success", false)):
		return dispatch_result

	return _success({
		"target_path": target_path,
		"class": _control_class_name(control),
		"local_position": _vector2_to_dict(local_position),
		"viewport_position": _vector2_to_dict(viewport_position),
		"screen_position": _vector2_to_dict(screen_position),
		"coordinate_mapping": _build_control_coordinate_mapping(control)
	}, "Editor control hover dispatched")


func _leave_control(ei, args: Dictionary) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	if not _has_non_empty_rect(control):
		return _error("Editor control rect is empty: %s" % target_path)

	var viewport_position := _resolve_leave_viewport_position(control, args)
	if _read_control_rect(control).has_point(viewport_position):
		return _error("Failed to resolve leave position outside control rect: %s" % target_path)
	var screen_position := _viewport_to_screen_position(control, viewport_position)
	var dispatch_result := _dispatch_control_mouse_motion(control, viewport_position)
	if not bool(dispatch_result.get("success", false)):
		return dispatch_result

	return _success({
		"target_path": target_path,
		"class": _control_class_name(control),
		"viewport_position": _vector2_to_dict(viewport_position),
		"screen_position": _vector2_to_dict(screen_position),
		"coordinate_mapping": _build_control_coordinate_mapping(control)
	}, "Editor control leave dispatched")


func _set_control_text(ei, target_path: String, text: String) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	if not _is_control_visible(control):
		return _error("Editor control is not visible: %s" % target_path)
	if _is_control_disabled(control):
		return _error("Editor control is disabled: %s" % target_path)
	if not _supports_text_input(control):
		return _error("Editor control does not support text input: %s" % target_path)

	if control.has_method("set_text"):
		control.set_text(text)
	else:
		control.text = text

	return _success({
		"target_path": target_path,
		"class": _control_class_name(control),
		"text": text
	}, "Editor control text updated")


func _set_control_value(ei, target_path: String, value) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
	if not _is_control_visible(control):
		return _error("Editor control is not visible: %s" % target_path)
	if _is_control_disabled(control):
		return _error("Editor control is disabled: %s" % target_path)
	if not _supports_value_input(control):
		return _error("Editor control does not support mutable numeric value input: %s" % target_path)
	var numeric_value = value
	if not (numeric_value is int or numeric_value is float):
		var value_text := str(value).strip_edges()
		if not value_text.is_valid_float():
			return _error("value must be numeric for value controls: %s" % target_path)
		numeric_value = value_text.to_float()
	control.set("value", numeric_value)
	return _success({
		"target_path": target_path,
		"class": _control_class_name(control),
		"value": control.get("value")
	}, "Editor control value updated")


func _collect_controls_recursive(node, parent_path: String, depth: int, max_depth: int, include_hidden: bool, class_filter: String, text_query: String, limit: int, out: Array[Dictionary]) -> void:
	if node == null or out.size() >= limit:
		return

	var current_path := _safe_control_path(node)
	if _is_ui_control_node(node):
		var visible := _is_control_visible(node)
		if include_hidden or visible:
			var control_summary := _describe_control(node, parent_path, depth)
			if _matches_filters(control_summary, class_filter, text_query):
				out.append(control_summary)
				if out.size() >= limit:
					return

	if depth >= max_depth or not node.has_method("get_children"):
		return

	for child in node.get_children():
		if child == null:
			continue
		_collect_controls_recursive(child, current_path, depth + 1, max_depth, include_hidden, class_filter, text_query, limit, out)
		if out.size() >= limit:
			return


func _collect_dock_tabs_recursive(node, include_hidden: bool, out: Array[Dictionary]) -> void:
	if node == null:
		return
	if _is_ui_control_node(node) and _has_property(node, "title"):
		var title := _read_control_title(node)
		if not title.is_empty() and (include_hidden or _is_control_visible(node)):
			out.append({
				"title": title,
				"path": _safe_control_path(node),
				"class": _control_class_name(node),
				"visible": _is_control_visible(node)
			})
	if not node.has_method("get_children"):
		return
	for child in node.get_children():
		_collect_dock_tabs_recursive(child, include_hidden, out)


func _collect_menu_buttons_recursive(node, depth: int, max_depth: int, include_hidden: bool, text_query: String, limit: int, out: Array[Dictionary]) -> void:
	if node == null or out.size() >= limit:
		return
	if _is_menu_button(node) and (include_hidden or _is_control_visible(node)):
		var menu_summary := _describe_menu_button(node)
		if _menu_matches_query(menu_summary, text_query):
			out.append(menu_summary)
			if out.size() >= limit:
				return
	if depth >= max_depth or not node.has_method("get_children"):
		return
	for child in node.get_children():
		_collect_menu_buttons_recursive(child, depth + 1, max_depth, include_hidden, text_query, limit, out)
		if out.size() >= limit:
			return


func _collect_tree_items(tree, text_query: String, include_hidden: bool, limit: int, out: Array[Dictionary]) -> void:
	var root = _tree_root_item(tree)
	if root == null:
		return
	var start_items: Array = []
	if _tree_root_hidden(tree):
		var child = _tree_item_first_child(root)
		while child != null:
			start_items.append(child)
			child = _tree_item_next(child)
	else:
		start_items.append(root)
	var index := 0
	for item in start_items:
		index = _collect_tree_items_recursive(tree, item, [], 0, text_query, include_hidden, limit, out, index)
		if out.size() >= limit:
			return


func _collect_tree_items_recursive(tree, item, parent_labels: Array[String], depth: int, text_query: String, include_hidden: bool, limit: int, out: Array[Dictionary], start_index: int) -> int:
	if item == null or out.size() >= limit:
		return start_index
	var current_index := start_index
	var label := _tree_item_text(item)
	var labels := parent_labels.duplicate()
	if not label.is_empty():
		labels.append(label)
	var summary := _describe_tree_item(tree, item, current_index, labels, depth)
	if (include_hidden or bool(summary.get("visible", true))) and _tree_item_matches(summary, text_query):
		out.append(summary)
	current_index += 1
	var child = _tree_item_first_child(item)
	while child != null:
		current_index = _collect_tree_items_recursive(tree, child, labels, depth + 1, text_query, include_hidden, limit, out, current_index)
		if out.size() >= limit:
			return current_index
		child = _tree_item_next(child)
	return current_index


func _resolve_menu_button(ei, args: Dictionary):
	var target_path := str(args.get("target_path", "")).strip_edges()
	var menu_title := str(args.get("menu_title", "")).strip_edges()
	var root = _get_editor_root(ei)
	if root == null:
		return null
	if not target_path.is_empty():
		var target = _find_control(ei, target_path)
		return target if _is_menu_button(target) else null
	if not menu_title.is_empty():
		return _find_menu_button_by_title_recursive(root, menu_title)
	return null


func _find_menu_button_by_title_recursive(node, menu_title: String):
	var visible_match = _find_menu_button_by_title_recursive_internal(node, menu_title, true)
	if visible_match != null:
		return visible_match
	return _find_menu_button_by_title_recursive_internal(node, menu_title, false)


func _find_menu_button_by_title_recursive_internal(node, menu_title: String, require_visible: bool):
	if node == null:
		return null
	if _is_menu_button(node) and _menu_title_matches(node, menu_title) and (not require_visible or _is_control_visible(node)):
		return node
	if not node.has_method("get_children"):
		return null
	for child in node.get_children():
		var nested = _find_menu_button_by_title_recursive_internal(child, menu_title, require_visible)
		if nested != null:
			return nested
	return null


func _is_menu_button(control) -> bool:
	return control != null and _control_class_name(control) == "MenuButton"


func _menu_title_matches(control, menu_title: String) -> bool:
	var requested := menu_title.strip_edges().to_lower()
	if requested.is_empty():
		return false
	for value in [_read_node_name(control), _read_control_text(control), _read_control_title(control)]:
		if str(value).strip_edges().to_lower() == requested:
			return true
	return false


func _menu_matches_query(menu_summary: Dictionary, text_query: String) -> bool:
	if text_query.is_empty():
		return true
	var haystacks := [
		str(menu_summary.get("name", "")).to_lower(),
		str(menu_summary.get("title", "")).to_lower(),
		str(menu_summary.get("text", "")).to_lower(),
		str(menu_summary.get("path", "")).to_lower()
	]
	for item in menu_summary.get("items", []):
		if item is Dictionary:
			haystacks.append(str((item as Dictionary).get("text", "")).to_lower())
	for haystack in haystacks:
		if haystack.contains(text_query):
			return true
	return false


func _describe_menu_button(menu) -> Dictionary:
	var popup = _get_menu_popup(menu)
	var summary := _describe_control(menu, _resolve_parent_path(menu), 0)
	summary["items"] = _collect_menu_popup_items(popup)
	summary["item_count"] = summary["items"].size()
	summary["popup_path"] = _safe_control_path(popup)
	summary["popup_visible"] = _is_control_visible(popup) if popup != null else false
	return summary


func _describe_menu_popup(popup) -> Dictionary:
	if popup == null:
		return {}
	var rect := _read_control_rect(popup)
	return {
		"path": _safe_control_path(popup),
		"class": _control_class_name(popup),
		"name": _read_node_name(popup),
		"visible": _is_control_visible(popup),
		"rect": _rect2_to_dict(rect),
		"items": _collect_menu_popup_items(popup)
	}


func _describe_tree_item(tree, item, index: int, labels: Array[String] = [], depth: int = 0) -> Dictionary:
	var label := _tree_item_text(item)
	var item_labels := labels.duplicate()
	if item_labels.is_empty() and not label.is_empty():
		item_labels.append(label)
	return {
		"index": index,
		"text": label,
		"item_path": "/".join(item_labels),
		"depth": depth,
		"tree_control_path": _safe_control_path(tree),
		"visible": _tree_item_visible(item),
		"selected": _tree_item_selected(item),
		"collapsed": _tree_item_collapsed(item),
		"child_count": _tree_item_child_count(item)
	}


func _tree_item_matches(summary: Dictionary, text_query: String) -> bool:
	if text_query.is_empty():
		return true
	var query := text_query.to_lower()
	return str(summary.get("text", "")).to_lower().contains(query) or str(summary.get("item_path", "")).to_lower().contains(query)


func _tree_item_selector_summary(args: Dictionary) -> Dictionary:
	return {
		"item_path": str(args.get("item_path", "")),
		"item_text": str(args.get("item_text", "")),
		"item_index": int(args.get("item_index", -1))
	}


func _tree_root_item(tree):
	if tree != null and tree.has_method("get_root"):
		return tree.call("get_root")
	return null


func _tree_root_hidden(tree) -> bool:
	if tree != null and tree.has_method("is_root_hidden"):
		return bool(tree.call("is_root_hidden"))
	if _has_property(tree, "hide_root"):
		return bool(tree.get("hide_root"))
	return false


func _tree_item_first_child(item):
	if item != null and item.has_method("get_first_child"):
		return item.call("get_first_child")
	return null


func _tree_item_next(item):
	if item != null and item.has_method("get_next"):
		return item.call("get_next")
	return null


func _tree_item_text(item) -> String:
	if item != null and item.has_method("get_text"):
		return str(item.call("get_text", 0)).strip_edges()
	return ""


func _tree_item_visible(item) -> bool:
	if item != null and item.has_method("is_visible"):
		return bool(item.call("is_visible"))
	return true


func _tree_item_selected(item) -> bool:
	if item != null and item.has_method("is_selected"):
		return bool(item.call("is_selected", 0))
	return false


func _tree_item_collapsed(item) -> bool:
	if item != null and item.has_method("is_collapsed"):
		return bool(item.call("is_collapsed"))
	return false


func _tree_item_child_count(item) -> int:
	var count := 0
	var child = _tree_item_first_child(item)
	while child != null:
		count += 1
		child = _tree_item_next(child)
	return count


func _normalize_tree_item_path(value: String) -> String:
	return value.strip_edges().replace("\\", "/").to_lower()


func _get_menu_popup(menu):
	if menu != null and menu.has_method("get_popup"):
		return menu.get_popup()
	return null


func _open_menu_button(menu) -> Dictionary:
	if menu == null:
		return _error("Editor menu not found")
	if not _is_control_visible(menu):
		return _error("Editor menu is not visible: %s" % _safe_control_path(menu))
	if _is_control_disabled(menu):
		return _error("Editor menu is disabled: %s" % _safe_control_path(menu))
	if menu.has_method("show_popup"):
		menu.show_popup()
	elif menu.has_method("press"):
		menu.press()
	else:
		var popup = _get_menu_popup(menu)
		if popup != null and popup.has_method("popup"):
			popup.popup()
		else:
			return _error("Editor menu cannot be opened: %s" % _safe_control_path(menu))
	return _success({"target_path": _safe_control_path(menu)}, "Editor menu opened")


func _resolve_menu_item_index(popup, args: Dictionary) -> int:
	var item_index := int(args.get("item_index", -1))
	if item_index >= 0 and item_index < _get_popup_menu_item_count(popup):
		return item_index
	var item_text := str(args.get("item_text", "")).strip_edges()
	if item_text.is_empty():
		return -1
	var item_text_lower := item_text.to_lower()
	for index in range(_get_popup_menu_item_count(popup)):
		if _read_popup_menu_item_label(popup, index).strip_edges().to_lower() == item_text_lower:
			return index
	return -1


func _collect_menu_popup_items(popup) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for index in range(_get_popup_menu_item_count(popup)):
		items.append({
			"index": index,
			"id": _read_popup_menu_item_id(popup, index),
			"text": _read_popup_menu_item_label(popup, index),
			"disabled": _is_popup_menu_item_disabled(popup, index),
			"separator": _is_popup_menu_item_separator(popup, index),
			"has_submenu": _is_popup_menu_item_submenu(popup, index),
			"submenu": _read_popup_menu_item_submenu(popup, index)
		})
	return items


func _resolve_tree_item(tree, args: Dictionary) -> Dictionary:
	var item_path := _normalize_tree_item_path(str(args.get("item_path", "")))
	var item_text := str(args.get("item_text", "")).strip_edges().to_lower()
	var item_index := int(args.get("item_index", -1))
	if item_path.is_empty() and item_text.is_empty() and item_index < 0:
		return _error("item_path, item_text, or item_index is required")
	var items: Array[Dictionary] = []
	_collect_tree_items(tree, "", true, DEFAULT_LIST_LIMIT, items)
	var matches: Array[Dictionary] = []
	for summary in items:
		if not (summary is Dictionary):
			continue
		var dict := summary as Dictionary
		if item_index >= 0 and int(dict.get("index", -1)) == item_index:
			matches.append(dict)
			continue
		if not item_path.is_empty() and _normalize_tree_item_path(str(dict.get("item_path", ""))) == item_path:
			matches.append(dict)
			continue
		if not item_text.is_empty() and str(dict.get("text", "")).strip_edges().to_lower() == item_text:
			matches.append(dict)
	if matches.is_empty():
		return _error("Editor tree item not found", {"candidate_count": 0, "selector": _tree_item_selector_summary(args)})
	if matches.size() > 1:
		return _error("Multiple editor tree items matched", {"candidate_count": matches.size(), "candidates": matches, "selector": _tree_item_selector_summary(args)})
	var matched := matches[0]
	var item = _tree_item_by_index(tree, int(matched.get("index", -1)))
	if item == null:
		return _error("Editor tree item index could not be resolved", {"matched": matched})
	return _success({
		"item": item,
		"index": int(matched.get("index", -1)),
		"resolution": {
			"candidate_count": 1,
			"selector": _tree_item_selector_summary(args),
			"matched": matched
		}
	})


func _tree_item_by_index(tree, wanted_index: int):
	if wanted_index < 0:
		return null
	var root = _tree_root_item(tree)
	if root == null:
		return null
	var start_items: Array = []
	if _tree_root_hidden(tree):
		var child = _tree_item_first_child(root)
		while child != null:
			start_items.append(child)
			child = _tree_item_next(child)
	else:
		start_items.append(root)
	var index := 0
	for item in start_items:
		var result: Dictionary = _tree_item_by_index_recursive(item, wanted_index, index)
		index = int(result.get("next_index", index))
		if result.get("item") != null:
			return result.get("item")
	return null


func _tree_item_by_index_recursive(item, wanted_index: int, start_index: int) -> Dictionary:
	if item == null:
		return {"item": null, "next_index": start_index}
	if start_index == wanted_index:
		return {"item": item, "next_index": start_index + 1}
	var index := start_index + 1
	var child = _tree_item_first_child(item)
	while child != null:
		var result: Dictionary = _tree_item_by_index_recursive(child, wanted_index, index)
		index = int(result.get("next_index", index))
		if result.get("item") != null:
			return {"item": result.get("item"), "next_index": index}
		child = _tree_item_next(child)
	return {"item": null, "next_index": index}


func _get_popup_menu_item_count(popup) -> int:
	if popup == null or not popup.has_method("get_item_count"):
		return 0
	return int(popup.get_item_count())


func _read_popup_menu_item_label(popup, index: int) -> String:
	if popup != null and popup.has_method("get_item_text"):
		return str(popup.get_item_text(index))
	return ""


func _read_popup_menu_item_id(popup, index: int) -> int:
	if popup != null and popup.has_method("get_item_id"):
		return int(popup.get_item_id(index))
	return index


func _is_popup_menu_item_disabled(popup, index: int) -> bool:
	if popup != null and popup.has_method("is_item_disabled"):
		return bool(popup.is_item_disabled(index))
	return false


func _is_popup_menu_item_separator(popup, index: int) -> bool:
	if popup != null and popup.has_method("is_item_separator"):
		return bool(popup.is_item_separator(index))
	return false


func _is_popup_menu_item_submenu(popup, index: int) -> bool:
	return not _read_popup_menu_item_submenu(popup, index).is_empty()


func _read_popup_menu_item_submenu(popup, index: int) -> String:
	if popup != null and popup.has_method("get_item_submenu"):
		var submenu := str(popup.get_item_submenu(index))
		if not submenu.is_empty():
			return submenu
	var submenu_node = _read_popup_menu_item_submenu_node(popup, index)
	if submenu_node != null:
		if submenu_node.has_method("get_path"):
			return str(submenu_node.get_path())
		if _has_property(submenu_node, "name"):
			return str(submenu_node.name)
		return str(submenu_node)
	return ""


func _read_popup_menu_item_submenu_node(popup, index: int):
	if popup != null and popup.has_method("get_item_submenu_node"):
		return popup.get_item_submenu_node(index)
	return null


func _activate_popup_menu_item(popup, index: int) -> void:
	if popup == null:
		return
	if popup.has_method("activate_item"):
		popup.activate_item(index)
	elif popup.has_method("emit_signal"):
		popup.emit_signal("index_pressed", index)


func _find_dock_tab_by_title_recursive(node, title: String):
	if node == null:
		return null
	if _is_ui_control_node(node) and _has_property(node, "title") and _read_control_title(node) == title:
		return node
	if not node.has_method("get_children"):
		return null
	for child in node.get_children():
		var nested = _find_dock_tab_by_title_recursive(child, title)
		if nested != null:
			return nested
	return null


func _select_owner_tab_for_control(control, title: String) -> bool:
	var current = control
	while current != null and current.has_method("get_parent"):
		var parent = current.get_parent()
		if parent == null:
			break
		var tab_index := _resolve_tab_index(parent, current, control, title)
		if tab_index >= 0:
			if parent.has_method("set_current_tab"):
				parent.set_current_tab(tab_index)
				return true
			if _has_property(parent, "current_tab"):
				parent.set("current_tab", tab_index)
				return true
		current = parent
	return false


func _resolve_tab_index(parent, direct_child, target_control, title: String) -> int:
	if parent == null or not parent.has_method("get_tab_count"):
		return -1
	var count := int(parent.get_tab_count())
	for index in range(count):
		var tab_control = null
		if parent.has_method("get_tab_control"):
			tab_control = parent.get_tab_control(index)
		elif parent.has_method("get_current_tab_control"):
			var candidate = parent.get_child(index) if parent.has_method("get_child") and index < int(parent.get_child_count()) else null
			tab_control = candidate
		if tab_control != null:
			if tab_control == direct_child or tab_control == target_control:
				return index
			if tab_control is Node and tab_control.has_method("is_ancestor_of") and tab_control.is_ancestor_of(target_control):
				return index
		if parent.has_method("get_tab_title") and str(parent.get_tab_title(index)) == title:
			return index
	return -1


func _activate_semantic_ui_path(ei, semantic_path: String, args: Dictionary) -> Dictionary:
	var normalized := semantic_path.strip_edges().replace("\\", "/").trim_prefix("/").trim_suffix("/").to_lower()
	var parts := normalized.split("/", false)
	if parts.size() < 2 or not SEMANTIC_DOCK_ROOTS.has(str(parts[0])):
		return _error("Unsupported semantic_path: %s" % semantic_path)

	var root = _get_editor_root(ei)
	if root == null:
		return _error("Editor base control not available")
	var mcp_dock = _find_mcp_dock_control(root)
	if mcp_dock == null:
		return _error("Semantic UI root not found: MCPDock")
	var dock = _find_mcp_dock_tab(root)
	if dock != null:
		if dock.has_method("make_visible"):
			dock.make_visible()
		else:
			_select_owner_tab_for_control(dock, _get_dock_activation_title(dock))

	var tab_container = _find_named_control_recursive(mcp_dock, "TabContainer")
	if tab_container == null:
		return _error("Semantic UI tab container not found: MCPDock/TabContainer")

	var tab_key := str(parts[1])
	var tab_name := ""
	match tab_key:
		"home", "server", "main", "主页":
			tab_name = "ServerTab"
		"tools", "tool", "工具":
			tab_name = "ToolsTab"
		"config", "configuration", "配置":
			tab_name = "ConfigTab"
		_:
			return _error("Unsupported MCPDock semantic tab: %s" % tab_key)
	return _activate_tab_container_by_child(ei, tab_container, tab_name, args, semantic_path)


func _find_mcp_dock_control(root):
	var dock = _find_named_control_recursive(root, DOCK_VISIBLE_NAME)
	if dock != null:
		return dock
	return _find_named_control_recursive(root, DOCK_LEGACY_NAME)


func _find_mcp_dock_tab(root):
	var dock = _find_dock_tab_by_title_recursive(root, DOCK_VISIBLE_NAME)
	if dock != null:
		return dock
	return _find_dock_tab_by_title_recursive(root, DOCK_LEGACY_NAME)


func _get_dock_activation_title(dock) -> String:
	if dock != null and _has_property(dock, "title"):
		var title := _read_control_title(dock)
		if not title.is_empty():
			return title
	return DOCK_VISIBLE_NAME


func _activate_bottom_panel(ei, bottom_panel_path: String, bottom_panel_title: String, args: Dictionary) -> Dictionary:
	var editor_plugin = _get_editor_plugin()
	if editor_plugin == null or not editor_plugin.has_method("make_bottom_panel_item_visible"):
		return _error("Editor plugin does not support bottom panel activation")
	var control = null
	if not bottom_panel_path.is_empty():
		control = _find_control(ei, bottom_panel_path)
		if control == null:
			return _error("Bottom panel control not found: %s" % bottom_panel_path)
	else:
		var root = _get_editor_root(ei)
		if root == null:
			return _error("Editor base control not available")
		control = _find_control_by_label_recursive(root, bottom_panel_title)
		if control == null:
			return _error("Bottom panel control not found: %s" % bottom_panel_title)
	editor_plugin.make_bottom_panel_item_visible(control)
	_ensure_control_visible(control)
	var payload := {
		"bottom_panel_title": bottom_panel_title,
		"bottom_panel_path": bottom_panel_path,
		"target_path": _safe_control_path(control),
		"active_path": _safe_control_path(control),
		"visible": _is_control_visible(control),
		"control": _describe_control(control, _resolve_parent_path(control), 0)
	}
	return _maybe_capture_activation_payload(ei, payload, _safe_control_path(control), args)


func _ensure_control_visible(control) -> void:
	if control == null:
		return
	if control.has_method("show"):
		control.show()
	elif _has_property(control, "visible"):
		control.set("visible", true)


func _get_editor_plugin():
	var plugin = _context.get("plugin_host", null)
	if plugin != null and is_instance_valid(plugin):
		return plugin
	var getter = _context.get("get_plugin_host", Callable())
	if getter is Callable and getter.is_valid():
		plugin = getter.call()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	return null


func _activate_tab_container(ei, target_path: String, tab_title: String, tab_index: int, args: Dictionary) -> Dictionary:
	var tab_container = _find_control(ei, target_path)
	if tab_container == null:
		return _error("Editor control not found: %s" % target_path)
	if not tab_container.has_method("get_tab_count"):
		return _error("Editor control is not a TabContainer/TabBar-like control: %s" % target_path)
	var resolved_index := _resolve_requested_tab_index(tab_container, tab_title, tab_index)
	if resolved_index < 0:
		return _error("Editor tab not found: %s" % (tab_title if not tab_title.is_empty() else str(tab_index)))
	return _activate_tab_container_at_index(ei, tab_container, resolved_index, args, "")


func _activate_tab_container_by_child(ei, tab_container, child_name: String, args: Dictionary, semantic_path: String) -> Dictionary:
	if tab_container == null or not tab_container.has_method("get_tab_count"):
		return _error("Semantic UI tab container is not tab-like: %s" % semantic_path)
	var count := int(tab_container.get_tab_count())
	for index in range(count):
		var tab_control = _get_tab_control(tab_container, index)
		if tab_control != null and str(tab_control.name) == child_name:
			return _activate_tab_container_at_index(ei, tab_container, index, args, semantic_path)
	return _error("Semantic UI tab target not found: %s" % semantic_path)


func _activate_tab_container_at_index(ei, tab_container, tab_index: int, args: Dictionary, semantic_path: String) -> Dictionary:
	if tab_container.has_method("set_current_tab"):
		tab_container.set_current_tab(tab_index)
	elif _has_property(tab_container, "current_tab"):
		tab_container.set("current_tab", tab_index)
	else:
		return _error("Editor tab container does not expose current_tab")
	var active_control = _get_tab_control(tab_container, tab_index)
	var active_path := _safe_control_path(active_control) if active_control != null else _safe_control_path(tab_container)
	var payload := {
		"target_path": _safe_control_path(tab_container),
		"active_path": active_path,
		"tab_index": tab_index,
		"tab_title": _get_tab_title(tab_container, tab_index),
		"visible": _is_activation_target_visible(active_control, tab_container) if active_control != null else _is_control_visible(tab_container),
		"control": _describe_control(active_control if active_control != null else tab_container, _safe_control_path(tab_container), 0)
	}
	if not semantic_path.is_empty():
		payload["semantic_path"] = semantic_path
	return _maybe_capture_activation_payload(ei, payload, active_path, args)


func _resolve_requested_tab_index(tab_container, tab_title: String, tab_index: int) -> int:
	var count := int(tab_container.get_tab_count())
	if tab_index >= 0 and tab_index < count:
		return tab_index
	if tab_title.is_empty():
		return -1
	for index in range(count):
		if _get_tab_title(tab_container, index) == tab_title:
			return index
		var tab_control = _get_tab_control(tab_container, index)
		if tab_control != null and str(tab_control.name) == tab_title:
			return index
	return -1


func _get_tab_control(tab_container, index: int):
	if tab_container == null:
		return null
	if tab_container.has_method("get_tab_control"):
		return tab_container.get_tab_control(index)
	if tab_container.has_method("get_child") and index >= 0 and index < int(tab_container.get_child_count()):
		return tab_container.get_child(index)
	return null


func _get_tab_title(tab_container, index: int) -> String:
	if tab_container != null and tab_container.has_method("get_tab_title"):
		return str(tab_container.get_tab_title(index))
	var tab_control = _get_tab_control(tab_container, index)
	return str(tab_control.name) if tab_control != null else ""


func _maybe_capture_activation_result(ei, result: Dictionary, target_path: String, args: Dictionary) -> Dictionary:
	var payload: Dictionary = result.get("data", {})
	return _maybe_capture_activation_payload(ei, payload, target_path, args)


func _maybe_capture_activation_payload(ei, payload: Dictionary, target_path: String, args: Dictionary) -> Dictionary:
	var output_path := str(args.get("path", "")).strip_edges()
	if output_path.is_empty():
		return _success(payload, "Editor UI activated")
	var capture_args := args.duplicate(true)
	capture_args["target_path"] = target_path
	var capture_result := _capture_control(ei, capture_args)
	if not bool(capture_result.get("success", false)):
		var fallback_path := str(payload.get("target_path", "")).strip_edges()
		if not fallback_path.is_empty() and fallback_path != target_path:
			capture_args["target_path"] = fallback_path
			capture_result = _capture_control(ei, capture_args)
	if not bool(capture_result.get("success", false)):
		payload["capture_error"] = str(capture_result.get("message", capture_result.get("error", "")))
		return _success(payload, "Editor UI activated without capture")
	var capture_data: Dictionary = capture_result.get("data", {})
	payload["capture"] = capture_data
	if not bool(payload.get("visible", false)):
		payload["visible"] = bool(capture_data.get("control", {}).get("visible", false))
		payload["visible_path"] = str(capture_data.get("target_path", ""))
	return _success(payload, "Editor UI activated and captured")


func _is_activation_target_visible(active_control, fallback_control) -> bool:
	if _is_control_visible(active_control):
		return true
	if not _is_control_visible(fallback_control):
		return false
	return _is_control_self_visible(active_control)


func _is_control_self_visible(control) -> bool:
	if control == null:
		return false
	if _has_property(control, "visible"):
		return bool(control.get("visible"))
	return _is_control_visible(control)


func _find_named_control_recursive(node, control_name: String):
	if node == null:
		return null
	if _read_node_name(node) == control_name:
		return node
	if not node.has_method("get_children"):
		return null
	for child in node.get_children():
		var nested = _find_named_control_recursive(child, control_name)
		if nested != null:
			return nested
	return null


func _find_control_by_label_recursive(node, label: String):
	if node == null:
		return null
	if _is_ui_control_node(node):
		if _read_node_name(node) == label or _read_control_title(node) == label or _read_control_text(node) == label:
			return node
	if not node.has_method("get_children"):
		return null
	for child in node.get_children():
		var nested = _find_control_by_label_recursive(child, label)
		if nested != null:
			return nested
	return null


func _read_node_name(node) -> String:
	if node == null:
		return ""
	if _has_property(node, "name"):
		return str(node.get("name"))
	return ""


func _matches_filters(control_summary: Dictionary, class_filter: String, text_query: String) -> bool:
	if not class_filter.is_empty() and str(control_summary.get("class", "")) != class_filter:
		return false
	if text_query.is_empty():
		return true
	var haystacks := [
		str(control_summary.get("name", "")).to_lower(),
		str(control_summary.get("title", "")).to_lower(),
		str(control_summary.get("text", "")).to_lower(),
		str(control_summary.get("path", "")).to_lower()
	]
	for haystack in haystacks:
		if haystack.contains(text_query):
			return true
	return false


func _describe_control(control, parent_path: String, depth: int) -> Dictionary:
	var rect := _read_control_rect(control)
	var summary := {
		"path": _safe_control_path(control),
		"parent_path": parent_path,
		"depth": depth,
		"class": _control_class_name(control),
		"name": str(control.name) if control != null else "",
		"title": _read_control_title(control),
		"text": _read_control_text(control),
		"visible": _is_control_visible(control),
		"disabled": _is_control_disabled(control),
		"focusable": _supports_focus(control),
		"editable_text": _supports_text_input(control),
		"actionable": _build_actionable_actions(control),
		"rect": {
			"x": rect.position.x,
			"y": rect.position.y,
			"width": rect.size.x,
			"height": rect.size.y
		},
		"coordinate_mapping": _build_control_coordinate_mapping(control)
	}
	if control != null and control.has_method("get_child_count"):
		summary["child_count"] = int(control.get_child_count())
	elif control != null and control.has_method("get_children"):
		summary["child_count"] = control.get_children().size()
	_add_tab_summary(control, summary)
	return summary


func _add_tab_summary(control, summary: Dictionary) -> void:
	if control == null or not control.has_method("get_tab_count"):
		return
	var tab_count := int(control.get_tab_count())
	var current_tab := int(control.get("current_tab")) if _has_property(control, "current_tab") else -1
	var tabs: Array[Dictionary] = []
	for index in range(tab_count):
		var tab_control = _get_tab_control(control, index)
		tabs.append({
			"index": index,
			"title": _get_tab_title(control, index),
			"control_path": _safe_control_path(tab_control) if tab_control != null else "",
			"control_name": str(tab_control.name) if tab_control != null else "",
			"current": index == current_tab,
			"visible": _is_activation_target_visible(tab_control, control) if tab_control != null else _is_control_visible(control)
		})
	summary["tab_count"] = tab_count
	summary["current_tab_index"] = current_tab
	summary["tabs"] = tabs


func _build_actionable_actions(control) -> Array[String]:
	var actions: Array[String] = []
	if _has_non_empty_rect(control):
		actions.append("capture_control")
	if _supports_focus(control):
		actions.append("focus_control")
	if _supports_activation(control):
		actions.append("activate_control")
	if _has_non_empty_rect(control):
		actions.append("click_control")
		actions.append("right_click_control")
		actions.append("hover_control")
		actions.append("leave_control")
	if _supports_text_input(control):
		actions.append("set_text")
	if _supports_value_input(control):
		actions.append("set_value")
	return actions


func _get_editor_root(ei):
	if ei == null or not ei.has_method("get_base_control"):
		return null
	return ei.get_base_control()


func _find_control(ei, target_path: String):
	var root = _get_editor_root(ei)
	if root == null:
		return null
	return _find_control_recursive(root, target_path)


func _find_control_recursive(node, target_path: String):
	if node == null:
		return null
	if _safe_control_path(node) == target_path:
		return node
	if not node.has_method("get_children"):
		return null
	for child in node.get_children():
		if child == null:
			continue
		var nested = _find_control_recursive(child, target_path)
		if nested != null:
			return nested
	return null


func _get_editor_viewport_image(ei):
	var root = _get_editor_root(ei)
	if root == null or not root.has_method("get_viewport"):
		return null
	var viewport = root.get_viewport()
	if viewport == null or not viewport.has_method("get_texture"):
		return null
	var texture = viewport.get_texture()
	if texture == null or not texture.has_method("get_image"):
		return null
	var image = texture.get_image()
	if image == null or image.is_empty():
		return null
	return image


func _save_image_png(image, target_path: String) -> Dictionary:
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
		"height": image.get_height()
	})


func _normalize_capture_rect(rect_value, image) -> Rect2i:
	var rect := _read_rect2(rect_value)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2i()
	var x := maxi(int(floor(rect.position.x)), 0)
	var y := maxi(int(floor(rect.position.y)), 0)
	if x >= image.get_width() or y >= image.get_height():
		return Rect2i()
	var width := mini(int(ceil(rect.size.x)), image.get_width() - x)
	var height := mini(int(ceil(rect.size.y)), image.get_height() - y)
	return Rect2i(x, y, width, height)


func _resolve_local_click_position(control, args: Dictionary) -> Vector2:
	var local_rect := _read_control_local_rect(control)
	var x := local_rect.size.x * 0.5
	var y := local_rect.size.y * 0.5
	if args.has("local_x") and args.get("local_x") != null:
		x = float(args.get("local_x", x))
	if args.has("local_y") and args.get("local_y") != null:
		y = float(args.get("local_y", y))
	return Vector2(x, y)


func _dispatch_control_mouse_click(control, button_index: int, viewport_position: Vector2) -> Dictionary:
	var viewport = _resolve_viewport_for_control(control)
	if viewport == null or not viewport.has_method("push_input"):
		return _error("Editor viewport does not support GUI input dispatch")
	var button_mask := _mouse_button_mask(button_index)
	var press_event := InputEventMouseButton.new()
	press_event.button_index = button_index
	press_event.pressed = true
	press_event.position = viewport_position
	press_event.global_position = viewport_position
	press_event.button_mask = button_mask
	viewport.push_input(press_event, false)

	var release_event := InputEventMouseButton.new()
	release_event.button_index = button_index
	release_event.pressed = false
	release_event.position = viewport_position
	release_event.global_position = viewport_position
	release_event.button_mask = 0
	viewport.push_input(release_event, false)
	return _success({
		"event_count": 2,
		"button_index": button_index,
		"button_mask": button_mask
	})


func _begin_click_signal_capture(control) -> Dictionary:
	var recorder := ClickSignalRecorder.new()
	var connections: Array[Dictionary] = []
	var signal_specs := [
		{"signal": "pressed", "method": "record_pressed"},
		{"signal": "button_down", "method": "record_button_down"},
		{"signal": "button_up", "method": "record_button_up"},
		{"signal": "toggled", "method": "record_toggled"},
		{"signal": "gui_input", "method": "record_gui_input"},
		{"signal": "mouse_entered", "method": "record_mouse_entered"},
		{"signal": "mouse_exited", "method": "record_mouse_exited"}
	]
	for spec in signal_specs:
		var signal_name := str(spec.get("signal", ""))
		if not _has_signal(control, signal_name):
			continue
		var callable := Callable(recorder, str(spec.get("method", "")))
		var connect_error := int(control.connect(signal_name, callable))
		if connect_error == OK or connect_error == ERR_ALREADY_EXISTS:
			connections.append({
				"signal": signal_name,
				"callable": callable
			})
	return {
		"recorder": recorder,
		"connections": connections
	}


func _end_click_signal_capture(control, capture: Dictionary) -> Dictionary:
	var connections: Array = capture.get("connections", [])
	for connection in connections:
		if not (connection is Dictionary):
			continue
		var signal_name := str((connection as Dictionary).get("signal", ""))
		var callable = (connection as Dictionary).get("callable", Callable())
		if signal_name.is_empty() or not (callable is Callable):
			continue
		if _is_signal_connected(control, signal_name, callable):
			control.disconnect(signal_name, callable)
	var recorder = capture.get("recorder", null)
	var counts := {}
	if recorder != null and recorder.has_method("to_dictionary"):
		counts = recorder.to_dictionary()
	var any_signal_observed := false
	for signal_name in counts.keys():
		if int(counts.get(signal_name, 0)) > 0:
			any_signal_observed = true
			break
	var activation_observed := _click_activation_signal_observed(counts)
	var input_observed := _click_input_signal_observed(counts)
	return {
		"supported": connections.size() > 0,
		"observed": any_signal_observed,
		"activation_observed": activation_observed,
		"input_observed": input_observed,
		"signals": counts
	}


func _read_click_observable_state(control) -> Dictionary:
	return {
		"visible": _is_control_visible(control),
		"disabled": _is_control_disabled(control),
		"mouse_filter": _read_optional_property(control, "mouse_filter"),
		"focus_mode": _read_optional_property(control, "focus_mode"),
		"toggle_mode": _read_optional_property(control, "toggle_mode"),
		"button_pressed": _read_optional_property(control, "button_pressed"),
		"pressed": _read_optional_property(control, "pressed")
	}


func _build_click_target_observation(control, state_before: Dictionary, state_after: Dictionary, signal_observation: Dictionary) -> Dictionary:
	var state_changed := _observable_click_state_changed(state_before, state_after)
	var activation_state_changed := _observable_click_activation_state_changed(state_before, state_after)
	var button_like := _is_button_like_control(control)
	var activation_observed := bool(signal_observation.get("activation_observed", false))
	var hints: Array[String] = []
	if button_like and not activation_observed and not activation_state_changed:
		hints.append("Click input was dispatched, but no Button signal or pressed-state change was observed. If the control did not react, try activate_control or inspect overlays, mouse_filter, focus, and disabled state.")
	return {
		"button_like": button_like,
		"activation_supported": _supports_activation(control),
		"activation_observed": activation_observed or activation_state_changed,
		"state_before": state_before,
		"state_after": state_after,
		"state_changed": state_changed,
		"signal_observation": signal_observation,
		"hints": hints
	}


func _click_activation_signal_observed(signal_counts: Dictionary) -> bool:
	for signal_name in ["pressed", "toggled"]:
		if int(signal_counts.get(signal_name, 0)) > 0:
			return true
	return false


func _click_input_signal_observed(signal_counts: Dictionary) -> bool:
	for signal_name in ["gui_input", "button_down", "button_up", "mouse_entered", "mouse_exited"]:
		if int(signal_counts.get(signal_name, 0)) > 0:
			return true
	return false


func _observable_click_activation_state_changed(state_before: Dictionary, state_after: Dictionary) -> bool:
	for key in ["button_pressed", "pressed"]:
		if state_before.get(key, null) != state_after.get(key, null):
			return true
	return false


func _observable_click_state_changed(state_before: Dictionary, state_after: Dictionary) -> bool:
	for key in ["button_pressed", "pressed", "toggle_mode", "disabled", "visible"]:
		if state_before.get(key, null) != state_after.get(key, null):
			return true
	return false


func _dispatch_control_mouse_motion(control, viewport_position: Vector2) -> Dictionary:
	var viewport = _resolve_viewport_for_control(control)
	if viewport == null or not viewport.has_method("push_input"):
		return _error("Editor viewport does not support GUI input dispatch")
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = viewport_position
	motion_event.global_position = viewport_position
	viewport.push_input(motion_event, false)
	return _success({"event_count": 1})


func _resolve_leave_viewport_position(control, args: Dictionary) -> Vector2:
	if args.has("local_x") or args.has("local_y"):
		return _control_local_to_viewport_position(control, _resolve_local_click_position(control, args))
	var rect := _read_control_rect(control)
	var visible_rect := _read_viewport_visible_rect(control)
	var candidates: Array[Vector2] = [
		rect.position + Vector2(-8.0, -8.0),
		rect.position + rect.size + Vector2(8.0, 8.0),
		Vector2(rect.position.x - 8.0, rect.position.y + rect.size.y * 0.5),
		Vector2(rect.position.x + rect.size.x + 8.0, rect.position.y + rect.size.y * 0.5),
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y - 8.0),
		Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y + 8.0),
	]
	for candidate in candidates:
		if not rect.has_point(candidate) and visible_rect.has_point(candidate):
			return candidate
	for candidate in candidates:
		if not rect.has_point(candidate):
			return candidate
	return rect.position + Vector2(-8.0, -8.0)


func _mouse_button_mask(button_index: int) -> int:
	if button_index <= 0:
		return 0
	return 1 << (button_index - 1)


func _build_control_coordinate_mapping(control) -> Dictionary:
	var local_rect := _read_control_local_rect(control)
	var viewport_rect := _read_control_rect(control)
	var screen_rect := _control_viewport_rect_to_screen_rect(control, viewport_rect)
	var viewport_visible_rect := _read_viewport_visible_rect(control)
	var screenshot_size := _read_viewport_image_size(control)
	return {
		"control_local_rect": _rect2_to_dict(local_rect),
		"viewport_rect": _rect2_to_dict(viewport_rect),
		"screen_rect": _rect2_to_dict(screen_rect),
		"os_window_rect": _rect2i_to_dict(_read_os_window_rect()),
		"viewport_visible_rect": _rect2_to_dict(viewport_visible_rect),
		"screenshot_size": _vector2i_to_dict(screenshot_size),
		"viewport_to_screenshot_scale": _calculate_viewport_to_screenshot_scale(viewport_visible_rect, screenshot_size)
	}


func _read_control_local_rect(control) -> Rect2:
	var size := Vector2()
	if control != null and _has_property(control, "size"):
		var value = control.get("size")
		if value is Vector2:
			size = value
		elif value is Vector2i:
			size = Vector2(value)
	if size.x <= 0.0 or size.y <= 0.0:
		size = _read_control_rect(control).size
	return Rect2(Vector2.ZERO, size)


func _control_local_to_viewport_position(control, local_position: Vector2) -> Vector2:
	if control != null and control.has_method("get_global_transform_with_canvas"):
		return control.get_global_transform_with_canvas() * local_position
	return _read_control_rect(control).position + local_position


func _viewport_to_screen_position(control, viewport_position: Vector2) -> Vector2:
	var viewport = _resolve_viewport_for_control(control)
	if viewport != null and viewport.has_method("get_screen_transform"):
		return viewport.get_screen_transform() * viewport_position
	return viewport_position


func _control_viewport_rect_to_screen_rect(control, viewport_rect: Rect2) -> Rect2:
	var top_left := _viewport_to_screen_position(control, viewport_rect.position)
	var bottom_right := _viewport_to_screen_position(control, viewport_rect.position + viewport_rect.size)
	var min_x := minf(top_left.x, bottom_right.x)
	var min_y := minf(top_left.y, bottom_right.y)
	var max_x := maxf(top_left.x, bottom_right.x)
	var max_y := maxf(top_left.y, bottom_right.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _resolve_viewport_for_control(control):
	var current = control
	while current != null:
		if current.has_method("get_viewport"):
			var viewport = current.get_viewport()
			if viewport != null:
				return viewport
		if current.has_method("get_parent"):
			current = current.get_parent()
		else:
			current = null
	return null


func _read_viewport_visible_rect(control) -> Rect2:
	var viewport = _resolve_viewport_for_control(control)
	if viewport != null and viewport.has_method("get_visible_rect"):
		return _read_rect2(viewport.get_visible_rect())
	var image_size := _read_viewport_image_size(control)
	return Rect2(Vector2.ZERO, Vector2(image_size))


func _read_viewport_image_size(control) -> Vector2i:
	var viewport = _resolve_viewport_for_control(control)
	if viewport == null or not viewport.has_method("get_texture"):
		return Vector2i()
	var texture = viewport.get_texture()
	if texture == null or not texture.has_method("get_image"):
		return Vector2i()
	var image = texture.get_image()
	if image == null:
		return Vector2i()
	return Vector2i(int(image.get_width()), int(image.get_height()))


func _read_os_window_rect() -> Rect2i:
	return Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())


func _calculate_viewport_to_screenshot_scale(viewport_rect: Rect2, screenshot_size: Vector2i) -> Dictionary:
	var scale_x := 0.0
	var scale_y := 0.0
	if viewport_rect.size.x > 0.0:
		scale_x = float(screenshot_size.x) / viewport_rect.size.x
	if viewport_rect.size.y > 0.0:
		scale_y = float(screenshot_size.y) / viewport_rect.size.y
	return {"x": scale_x, "y": scale_y}


func _rect2_to_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _rect2i_to_dict(rect: Rect2i) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _vector2_to_dict(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _vector2i_to_dict(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}


func _read_control_rect(control) -> Rect2:
	if _has_global_rect(control):
		return _read_rect2(control.get_global_rect())
	return Rect2()


func _has_global_rect(control) -> bool:
	return control != null and control.has_method("get_global_rect")


func _has_non_empty_rect(control) -> bool:
	var rect := _read_control_rect(control)
	return rect.size.x > 0.0 and rect.size.y > 0.0


func _read_rect2(value) -> Rect2:
	if value is Rect2:
		return value
	if value is Rect2i:
		return Rect2((value as Rect2i).position, (value as Rect2i).size)
	return Rect2()


func _is_ui_control_node(node) -> bool:
	return node != null and (
		node is Control
		or node.has_method("get_global_rect")
		or node.has_method("get_ui_class")
	)


func _supports_focus(control) -> bool:
	return control != null and control.has_method("grab_focus")


func _supports_activation(control) -> bool:
	if control == null:
		return false
	if _is_button_like_control(control):
		return true
	return control.has_method("press")


func _is_button_like_control(control) -> bool:
	var control_class := _control_class_name(control)
	return control_class in ["Button", "CheckButton", "CheckBox", "OptionButton", "MenuButton", "LinkButton"]


func _supports_text_input(control) -> bool:
	if control == null:
		return false
	var control_class := _control_class_name(control)
	if control_class in ["Label", "RichTextLabel"] or _is_button_like_control(control):
		return false
	if control_class in ["LineEdit", "TextEdit", "CodeEdit"]:
		return _is_text_input_mutable(control)
	if _has_property(control, "editable"):
		return _is_text_input_mutable(control) and (control.has_method("set_text") or _has_property(control, "text"))
	if _has_property(control, "read_only"):
		return _is_text_input_mutable(control) and (control.has_method("set_text") or _has_property(control, "text"))
	return false


func _is_text_input_mutable(control) -> bool:
	if control == null:
		return false
	if _has_property(control, "editable") and not bool(control.get("editable")):
		return false
	if _has_property(control, "read_only") and bool(control.get("read_only")):
		return false
	return true


func _supports_value_input(control) -> bool:
	if control == null:
		return false
	if not _is_control_visible(control):
		return false
	if not _has_property(control, "value"):
		return false
	var control_class := _control_class_name(control)
	if not (control_class in ["SpinBox", "EditorSpinSlider", "HSlider", "VSlider", "Slider"]):
		return false
	return _is_value_input_mutable(control)


func _is_value_input_mutable(control) -> bool:
	if control == null:
		return false
	if _is_control_disabled(control):
		return false
	if _has_property(control, "editable") and not bool(control.get("editable")):
		return false
	if _has_property(control, "read_only") and bool(control.get("read_only")):
		return false
	return true


func _control_class_name(control) -> String:
	if control == null:
		return ""
	if control.has_method("get_ui_class"):
		return str(control.get_ui_class())
	if control.has_method("get_popup_class"):
		return str(control.get_popup_class())
	if control.has_method("get_class"):
		return str(control.get_class())
	return ""


func _read_control_text(control) -> String:
	if control == null:
		return ""
	if _has_property(control, "text"):
		return str(control.get("text"))
	return ""


func _read_control_title(control) -> String:
	if control == null:
		return ""
	if _has_property(control, "title"):
		return str(control.get("title"))
	if _has_property(control, "placeholder_text"):
		return str(control.get("placeholder_text"))
	return ""


func _has_property(control, property_name: String) -> bool:
	if control == null or not control.has_method("get_property_list"):
		return false
	for property_info in control.get_property_list():
		if not (property_info is Dictionary):
			continue
		if str((property_info as Dictionary).get("name", "")) == property_name:
			return true
	return false


func _has_signal(control, signal_name: String) -> bool:
	return control != null and control.has_method("has_signal") and bool(control.has_signal(signal_name))


func _is_signal_connected(control, signal_name: String, callable: Callable) -> bool:
	return control != null and control.has_method("is_connected") and bool(control.is_connected(signal_name, callable))


func _read_optional_property(control, property_name: String):
	if _has_property(control, property_name):
		return control.get(property_name)
	return null


func _safe_control_path(control) -> String:
	if control == null or not control.has_method("get_path"):
		return ""
	return str(control.get_path())


func _resolve_parent_path(control) -> String:
	if control == null or not control.has_method("get_parent"):
		return ""
	var parent = control.get_parent()
	if parent == null:
		return ""
	return _safe_control_path(parent)


func _is_control_visible(control) -> bool:
	if control == null:
		return false
	if control.has_method("is_visible_in_tree"):
		return bool(control.is_visible_in_tree())
	if _has_property(control, "visible"):
		return bool(control.get("visible"))
	return true


func _is_control_disabled(control) -> bool:
	if control == null:
		return true
	if _has_property(control, "disabled"):
		return bool(control.get("disabled"))
	return false


func _sanitize_file_label(value: String) -> String:
	var sanitized := value.strip_edges()
	if sanitized.is_empty():
		return "control"
	for ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		sanitized = sanitized.replace(ch, "_")
	return sanitized.to_lower()
