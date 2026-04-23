@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor UI control tools for Godot MCP

const DEFAULT_LIST_LIMIT := 200
const DEFAULT_MAX_DEPTH := 6


func execute(ei, args: Dictionary) -> Dictionary:
	if not ei:
		return _error("Editor interface not available")

	var action := str(args.get("action", "")).strip_edges()
	match action:
		"list_visible":
			return _list_visible_controls(ei, args)
		"list_dock_tabs":
			return _list_dock_tabs(ei, bool(args.get("include_hidden", true)))
		"activate_dock_tab":
			return _activate_dock_tab(ei, str(args.get("title", "")).strip_edges())
		"get_control":
			return _get_control(ei, str(args.get("target_path", "")).strip_edges())
		"capture_control":
			return _capture_control(ei, args)
		"focus_control":
			return _focus_control(ei, str(args.get("target_path", "")).strip_edges())
		"activate_control":
			return _activate_control(ei, str(args.get("target_path", "")).strip_edges())
		"set_text":
			return _set_control_text(ei, str(args.get("target_path", "")).strip_edges(), str(args.get("text", "")))
		_:
			return _error("Unknown action: %s" % action)


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
	if not _select_owner_tab_for_control(dock, title):
		return _error("Failed to activate editor dock tab: %s" % title)
	return _success({
		"title": title,
		"target_path": _safe_control_path(dock)
	}, "Editor dock tab activated")


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
	if output_path.is_empty():
		output_path = "user://godot_mcp_editor_captures/control_%s_%s.png" % [
			_sanitize_file_label(str(control.name)),
			str(Time.get_unix_time_from_system())
		]
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


func _set_control_text(ei, target_path: String, text: String) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var control = _find_control(ei, target_path)
	if control == null:
		return _error("Editor control not found: %s" % target_path)
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
		}
	}
	if control != null and control.has_method("get_child_count"):
		summary["child_count"] = int(control.get_child_count())
	elif control != null and control.has_method("get_children"):
		summary["child_count"] = control.get_children().size()
	return summary


func _build_actionable_actions(control) -> Array[String]:
	var actions: Array[String] = []
	if _has_non_empty_rect(control):
		actions.append("capture_control")
	if _supports_focus(control):
		actions.append("focus_control")
	if _supports_activation(control):
		actions.append("activate_control")
	if _supports_text_input(control):
		actions.append("set_text")
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
	var control_class := _control_class_name(control)
	if control_class in ["Button", "CheckButton", "CheckBox", "OptionButton", "MenuButton", "LinkButton"]:
		return true
	return control.has_method("press")


func _supports_text_input(control) -> bool:
	if control == null:
		return false
	var control_class := _control_class_name(control)
	if control_class in ["LineEdit", "TextEdit", "CodeEdit"]:
		return true
	return control.has_method("set_text") or _has_property(control, "text")


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
