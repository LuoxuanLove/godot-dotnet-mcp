@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const MCPUserDataPaths = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_user_data_paths.gd")

## Editor notification tools for Godot MCP

const POPUP_ROOT_CLASSES := {
	"Window": true,
	"Popup": true,
	"PopupMenu": true,
	"PopupPanel": true,
	"AcceptDialog": true,
	"ConfirmationDialog": true,
	"FileDialog": true
}

const ACTIONABLE_CONTROL_CLASSES := {
	"Button": true,
	"CheckButton": true,
	"OptionButton": true,
	"LineEdit": true,
	"TextEdit": true,
	"CodeEdit": true
}


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var message = args.get("message", "")

	if message.is_empty():
		return _error("Message is required")

	match action:
		"toast":
			return _show_toast(ei, message, args.get("severity", "info"))
		"popup":
			return _show_popup(args.get("title", ""), message)
		"confirm":
			return _show_confirm(args.get("title", ""), message)
		_:
			return _error("Unknown action: %s" % action)


func execute_popup(ei, args: Dictionary) -> Dictionary:
	if not ei:
		return _error("Editor interface not available")
	var action := str(args.get("action", "")).strip_edges()
	match action:
		"list_visible":
			return _list_visible_popups(ei)
		"get_popup":
			return _get_popup(ei, str(args.get("target_path", "")).strip_edges())
		"capture_popup":
			return _capture_popup(ei, args)
		"press_button":
			return _press_popup_button(ei, str(args.get("target_path", "")).strip_edges())
		"select_item":
			return _select_popup_menu_item(ei, args)
		"set_text":
			return _set_popup_text(ei, str(args.get("target_path", "")).strip_edges(), str(args.get("text", "")))
		"close_popup":
			return _close_popup(ei, str(args.get("target_path", "")).strip_edges())
		_:
			return _error("Unknown action: %s" % action)


func _show_toast(ei, message: String, severity: String) -> Dictionary:
	if not ei:
		print("[Toast] %s: %s" % [severity, message])
		return _success({"method": "print"}, "Toast shown (via print)")

	match severity:
		"warning":
			push_warning(message)
		"error":
			push_error(message)
		_:
			print(message)

	return _success({
		"message": message,
		"severity": severity
	}, "Notification shown")


func _show_popup(title: String, message: String) -> Dictionary:
	print("[Popup] %s: %s" % [title, message])

	return _success({
		"title": title,
		"message": message
	}, "Popup shown (via console)")


func _show_confirm(title: String, message: String) -> Dictionary:
	print("[Confirm] %s: %s" % [title, message])

	return _success({
		"title": title,
		"message": message,
		"note": "Confirmation dialogs require user interaction"
	}, "Confirmation logged")


func _list_visible_popups(ei) -> Dictionary:
	var base_control = ei.get_base_control()
	if base_control == null:
		return _error("Editor base control not available")
	var popups: Array[Dictionary] = []
	_collect_visible_popups(base_control, popups)
	return _success({"count": popups.size(), "popups": popups})


func _get_popup(ei, target_path: String) -> Dictionary:
	var popup_root = _resolve_visible_popup_for_target(ei, target_path)
	if popup_root == null:
		return _error("Popup target not found or not inside a visible popup: %s" % target_path)
	return _success({
		"target_path": target_path,
		"popup_path": _safe_control_path(popup_root),
		"popup": _describe_popup_root(popup_root)
	}, "Popup fetched")


func _capture_popup(ei, args: Dictionary) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	var popup_root = _resolve_visible_popup_for_target(ei, target_path)
	if popup_root == null:
		return _error("Popup target not found or not inside a visible popup: %s" % target_path)

	var image = _get_editor_viewport_image(ei)
	if image == null:
		return _error("Editor screenshot image is unavailable")

	var rect: Rect2i = _normalize_capture_rect(_read_node_rect(popup_root), image)
	if rect.size.x <= 0 or rect.size.y <= 0:
		return _error("Popup rect is empty or outside the editor viewport: %s" % target_path)

	var cropped = image.get_region(rect)
	var output_path := str(args.get("path", "")).strip_edges()
	output_path = MCPUserDataPaths.normalize_editor_control_capture_output_path(output_path, "popup_%s_%s.png" % [
		MCPUserDataPaths.sanitize_filename(str(popup_root.name)),
		str(Time.get_unix_time_from_system())
	])
	var save_result := _save_image_png(cropped, output_path)
	if not bool(save_result.get("success", false)):
		return save_result

	var payload: Dictionary = save_result.get("data", {})
	payload["target_path"] = target_path
	payload["popup_path"] = _safe_control_path(popup_root)
	payload["capture_mode"] = "popup"
	payload["capture_rect"] = _rect2i_to_dict(rect)
	payload["popup"] = _describe_popup_root(popup_root)
	return _success(payload, "Popup screenshot captured")


func _press_popup_button(ei, target_path: String) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var target = _find_popup_target(ei, target_path)
	if target == null:
		return _error("Popup target not found: %s" % target_path)
	var popup_root = _resolve_popup_root(target)
	if popup_root == null:
		return _error("Target is not inside a visible popup: %s" % target_path)
	if not _is_visible_popup_root(popup_root):
		return _error("Target is not inside a visible popup: %s" % target_path)
	var control_class := _control_class_name(target)
	if not (control_class in ["Button", "CheckButton", "OptionButton"]):
		return _error("Target is not a popup button: %s" % target_path)
	if _is_control_disabled(target):
		return _error("Popup button is disabled: %s" % target_path)
	if target.has_method("press"):
		target.press()
	elif target.has_method("emit_signal"):
		target.emit_signal("pressed")
	return _success({"target_path": target_path, "class": control_class}, "Popup button pressed")


func _select_popup_menu_item(ei, args: Dictionary) -> Dictionary:
	var target_path := str(args.get("target_path", "")).strip_edges()
	if target_path.is_empty():
		return _error("target_path is required")
	var target = _find_popup_target(ei, target_path)
	if target == null:
		return _error("Popup target not found: %s" % target_path)
	var popup_root = _resolve_popup_root(target)
	if popup_root == null:
		return _error("Target is not inside a visible popup: %s" % target_path)
	if not _is_visible_popup_root(popup_root):
		return _error("Target is not inside a visible popup: %s" % target_path)
	if _control_class_name(popup_root) != "PopupMenu":
		return _error("Target is not inside a PopupMenu: %s" % target_path)
	var selector := _read_popup_item_selector(args)
	if selector.has("error"):
		return _error(str(selector.get("error", "")))
	if selector.is_empty():
		return _error("index, id, or text is required")
	var item_index := _find_popup_menu_item_index(popup_root, selector)
	if item_index < 0:
		return _error("PopupMenu item not found for selector: %s" % JSON.stringify(selector))
	var item := _describe_popup_menu_item(popup_root, item_index)
	if bool(item.get("separator", false)):
		return _error("PopupMenu item is a separator: %s" % JSON.stringify(item))
	if bool(item.get("disabled", false)):
		return _error("PopupMenu item is disabled: %s" % JSON.stringify(item))
	if bool(item.get("has_submenu", false)):
		return _error("PopupMenu item opens a submenu and cannot be selected as a leaf action: %s" % JSON.stringify(item))
	_activate_popup_menu_item(popup_root, item_index, item)
	return _success({
		"target_path": target_path,
		"popup_path": _safe_control_path(popup_root),
		"selector": selector,
		"selected_item": item
	}, "PopupMenu item selected")


func _set_popup_text(ei, target_path: String, text: String) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var target = _find_popup_target(ei, target_path)
	if target == null:
		return _error("Popup target not found: %s" % target_path)
	var popup_root = _resolve_popup_root(target)
	if popup_root == null:
		return _error("Target is not inside a visible popup: %s" % target_path)
	if not _is_visible_popup_root(popup_root):
		return _error("Target is not inside a visible popup: %s" % target_path)
	var control_class := _control_class_name(target)
	if not (control_class in ["LineEdit", "TextEdit", "CodeEdit"]):
		return _error("Target does not support text input: %s" % target_path)
	target.text = text
	return _success({"target_path": target_path, "class": control_class, "text": text}, "Popup text updated")


func _close_popup(ei, target_path: String) -> Dictionary:
	if target_path.is_empty():
		return _error("target_path is required")
	var target = _find_popup_target(ei, target_path)
	if target == null:
		return _error("Popup target not found: %s" % target_path)
	var popup_root = _resolve_popup_root(target)
	if popup_root == null:
		return _error("Popup root not found for target: %s" % target_path)
	if not _is_visible_popup_root(popup_root):
		return _error("Popup root is not visible: %s" % target_path)
	if popup_root.has_method("hide"):
		popup_root.hide()
	return _success({"target_path": target_path, "popup_path": _safe_control_path(popup_root)}, "Popup closed")


func _collect_visible_popups(node, out: Array[Dictionary]) -> void:
	if node == null or not node.has_method("get_children"):
		return
	for child in node.get_children():
		if child == null:
			continue
		if _is_visible_popup_root(child):
			out.append(_describe_popup_root(child))
		_collect_visible_popups(child, out)


func _describe_popup_root(popup_root) -> Dictionary:
	return {
		"node_path": _safe_control_path(popup_root),
		"parent_path": _resolve_parent_path(popup_root),
		"class": _control_class_name(popup_root),
		"name": str(popup_root.name),
		"title": _read_popup_title(popup_root),
		"text": _read_popup_text(popup_root),
		"visible": _is_control_visible(popup_root),
		"disabled": _is_control_disabled(popup_root),
		"rect": _rect2_to_dict(_read_node_rect(popup_root)),
		"items": _collect_popup_menu_items(popup_root),
		"actionable_children": _collect_actionable_children(popup_root)
	}


func _collect_actionable_children(root) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_collect_actionable_children_recursive(root, results)
	return results


func _collect_actionable_children_recursive(node, out: Array[Dictionary]) -> void:
	if node == null or not node.has_method("get_children"):
		return
	for child in node.get_children():
		if child == null:
			continue
		var control_class := _control_class_name(child)
		if ACTIONABLE_CONTROL_CLASSES.has(control_class) and _is_control_visible(child):
			out.append({
				"node_path": _safe_control_path(child),
				"parent_path": _resolve_parent_path(child),
				"class": control_class,
				"name": str(child.name),
				"title": _read_popup_title(child),
				"text": _read_popup_text(child),
				"visible": _is_control_visible(child),
				"disabled": _is_control_disabled(child),
				"rect": _rect2_to_dict(_read_node_rect(child))
			})
		_collect_actionable_children_recursive(child, out)


func _find_popup_target(ei, target_path: String):
	var base_control = ei.get_base_control()
	if base_control == null:
		return null
	return _find_popup_target_recursive(base_control, target_path)


func _resolve_visible_popup_for_target(ei, target_path: String):
	if target_path.is_empty():
		return null
	var target = _find_popup_target(ei, target_path)
	if target == null:
		return null
	var popup_root = _resolve_popup_root(target)
	if popup_root == null or not _is_visible_popup_root(popup_root):
		return null
	return popup_root


func _find_popup_target_recursive(node, target_path: String):
	if node == null or not node.has_method("get_children"):
		return null
	for child in node.get_children():
		if child == null:
			continue
		if _safe_control_path(child) == target_path:
			return child
		var nested = _find_popup_target_recursive(child, target_path)
		if nested != null:
			return nested
	return null


func _resolve_popup_root(node):
	var current = node
	while current != null:
		if _is_popup_root(current):
			return current
		if current.has_method("get_parent"):
			current = current.get_parent()
		else:
			current = null
	return null


func _is_visible_popup_root(node) -> bool:
	return _is_popup_root(node) and _is_control_visible(node)


func _is_popup_root(node) -> bool:
	return POPUP_ROOT_CLASSES.has(_control_class_name(node))


func _control_class_name(node) -> String:
	if node == null:
		return ""
	if node.has_method("get_popup_class"):
		return str(node.get_popup_class())
	if node.has_method("get_class"):
		return str(node.get_class())
	return ""


func _safe_control_path(node) -> String:
	if node == null:
		return ""
	if node.has_method("get_path"):
		return str(node.get_path())
	return ""


func _read_popup_title(node) -> String:
	if node == null:
		return ""
	if node.has_method("get"):
		var title = node.get("title")
		if title != null:
			return str(title)
		var text = node.get("text")
		if text != null:
			return str(text)
	return ""


func _read_popup_text(node) -> String:
	if node == null:
		return ""
	if node.has_method("get"):
		var text = node.get("text")
		if text != null:
			return str(text)
	return ""


func _collect_popup_menu_items(node) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if node == null or _control_class_name(node) != "PopupMenu" or not node.has_method("get_item_count"):
		return items
	var count := int(node.get_item_count())
	for index in range(count):
		items.append(_describe_popup_menu_item(node, index))
	return items


func _describe_popup_menu_item(node, index: int) -> Dictionary:
	var item := {"index": index}
	if node != null and node.has_method("get_item_id"):
		item["id"] = int(node.get_item_id(index))
	if node != null and node.has_method("get_item_text"):
		item["text"] = str(node.get_item_text(index))
	if node != null and node.has_method("is_item_disabled"):
		item["disabled"] = bool(node.is_item_disabled(index))
	else:
		item["disabled"] = false
	if node != null and node.has_method("is_item_separator"):
		item["separator"] = bool(node.is_item_separator(index))
	else:
		item["separator"] = false
	var submenu_node = null
	if node != null and node.has_method("get_item_submenu"):
		item["submenu"] = str(node.get_item_submenu(index))
	else:
		item["submenu"] = ""
	if node != null and node.has_method("get_item_submenu_node"):
		submenu_node = node.get_item_submenu_node(index)
	item["has_submenu"] = not str(item.get("submenu", "")).is_empty() or submenu_node != null
	if submenu_node != null:
		item["submenu_node_path"] = _safe_control_path(submenu_node)
	return item


func _read_popup_item_selector(args: Dictionary) -> Dictionary:
	var selector_keys: Array[String] = []
	if args.has("index") and args.get("index", null) != null:
		selector_keys.append("index")
	if args.has("id") and args.get("id", null) != null:
		selector_keys.append("id")
	if args.has("text") and args.get("text", null) != null:
		selector_keys.append("text")
	if selector_keys.size() > 1:
		return {"error": "Only one popup item selector is allowed: %s" % ", ".join(selector_keys)}
	if selector_keys.has("index"):
		var index_value := _read_popup_integer_selector_value(args, "index")
		if not bool(index_value.get("success", false)):
			return {"error": str(index_value.get("error", ""))}
		return {"type": "index", "value": int(index_value.get("value", -1))}
	if selector_keys.has("id"):
		var id_value := _read_popup_integer_selector_value(args, "id")
		if not bool(id_value.get("success", false)):
			return {"error": str(id_value.get("error", ""))}
		return {"type": "id", "value": int(id_value.get("value", -1))}
	if selector_keys.has("text"):
		return {"type": "text", "value": str(args.get("text", ""))}
	return {}


func _read_popup_integer_selector_value(args: Dictionary, key: String) -> Dictionary:
	var value = args.get(key, null)
	match typeof(value):
		TYPE_INT:
			return {"success": true, "value": int(value)}
		TYPE_FLOAT:
			var float_value := float(value)
			var rounded_value := round(float_value)
			if abs(float_value - rounded_value) < 0.000001:
				return {"success": true, "value": int(rounded_value)}
	return {"success": false, "error": "PopupMenu %s selector must be an integer" % key}


func _find_popup_menu_item_index(node, selector: Dictionary) -> int:
	if node == null or not node.has_method("get_item_count"):
		return -1
	var selector_type := str(selector.get("type", ""))
	var selector_value = selector.get("value", null)
	var count := int(node.get_item_count())
	match selector_type:
		"index":
			var index := int(selector_value)
			return index if index >= 0 and index < count else -1
		"id":
			if not node.has_method("get_item_id"):
				return -1
			for index in range(count):
				if int(node.get_item_id(index)) == int(selector_value):
					return index
		"text":
			if not node.has_method("get_item_text"):
				return -1
			var matches: Array[int] = []
			for index in range(count):
				if str(node.get_item_text(index)) == str(selector_value):
					matches.append(index)
			if matches.size() == 1:
				return int(matches[0])
			return -1
	return -1


func _activate_popup_menu_item(node, index: int, item: Dictionary) -> void:
	if node == null:
		return
	if node.has_method("activate_item"):
		node.activate_item(index)
		return
	if node.has_method("emit_signal"):
		node.emit_signal("index_pressed", index)
		if item.has("id"):
			var item_id := int(item.get("id", index))
			node.emit_signal("id_pressed", item_id if item_id >= 0 else index)
	if node.has_method("hide"):
		node.hide()


func _read_node_rect(node) -> Rect2:
	if node == null:
		return Rect2()
	if node.has_method("get_global_rect"):
		var rect_value = node.get_global_rect()
		if rect_value is Rect2:
			return rect_value
		if rect_value is Rect2i:
			return Rect2((rect_value as Rect2i).position, (rect_value as Rect2i).size)
	var position := Vector2()
	var size := Vector2()
	if node.has_method("get"):
		var position_value = node.get("position")
		if position_value is Vector2:
			position = position_value
		elif position_value is Vector2i:
			position = Vector2(position_value)
		var size_value = node.get("size")
		if size_value is Vector2:
			size = size_value
		elif size_value is Vector2i:
			size = Vector2(size_value)
	return Rect2(position, size)


func _resolve_parent_path(node) -> String:
	if node == null or not node.has_method("get_parent"):
		return ""
	var parent = node.get_parent()
	return _safe_control_path(parent) if parent != null else ""


func _rect2_to_dict(rect: Rect2) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _rect2i_to_dict(rect: Rect2i) -> Dictionary:
	return {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}


func _is_control_visible(node) -> bool:
	if node == null:
		return false
	if node.has_method("is_visible_in_tree"):
		return bool(node.is_visible_in_tree())
	if node.has_method("get"):
		var visible = node.get("visible")
		if visible != null:
			return bool(visible)
	return true


func _is_control_disabled(node) -> bool:
	if node == null:
		return true
	if node.has_method("get"):
		var disabled = node.get("disabled")
		if disabled != null:
			return bool(disabled)
	return false


func _get_editor_viewport_image(ei):
	var base_control = ei.get_base_control()
	if base_control == null or not base_control.has_method("get_viewport"):
		return null
	var viewport = base_control.get_viewport()
	if viewport == null or not viewport.has_method("get_texture"):
		return null
	var texture = viewport.get_texture()
	if texture == null or not texture.has_method("get_image"):
		return null
	var image = texture.get_image()
	if image == null or image.is_empty():
		return null
	return image


func _normalize_capture_rect(rect: Rect2, image) -> Rect2i:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2i()
	var x := maxi(int(floor(rect.position.x)), 0)
	var y := maxi(int(floor(rect.position.y)), 0)
	if x >= image.get_width() or y >= image.get_height():
		return Rect2i()
	var width := mini(int(ceil(rect.size.x)), image.get_width() - x)
	var height := mini(int(ceil(rect.size.y)), image.get_height() - y)
	return Rect2i(x, y, width, height)


func _save_image_png(image, target_path: String) -> Dictionary:
	var absolute_path = ProjectSettings.globalize_path(target_path)
	var dir_error = DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	if dir_error != OK:
		return _error("Failed to create screenshot directory: %s" % absolute_path.get_base_dir())
	var save_error = image.save_png(absolute_path)
	if save_error != OK:
		return _error("Failed to save popup screenshot: %s" % error_string(save_error))
	return _success({
		"path": target_path,
		"absolute_path": absolute_path,
		"width": image.get_width(),
		"height": image.get_height()
	})
