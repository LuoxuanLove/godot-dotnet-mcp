@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

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
		"press_button":
			return _press_popup_button(ei, str(args.get("target_path", "")).strip_edges())
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
		var item := {"index": index}
		if node.has_method("get_item_id"):
			item["id"] = int(node.get_item_id(index))
		if node.has_method("get_item_text"):
			item["text"] = str(node.get_item_text(index))
		if node.has_method("is_item_disabled"):
			item["disabled"] = bool(node.is_item_disabled(index))
		if node.has_method("is_item_separator"):
			item["separator"] = bool(node.is_item_separator(index))
		if node.has_method("get_item_submenu"):
			item["submenu"] = str(node.get_item_submenu(index))
		items.append(item)
	return items


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
