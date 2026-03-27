@tool
extends "res://addons/godot_dotnet_mcp/tools/editor/service_base.gd"

var _current_action_name := ""


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"get_info":
			return _get_undo_info()
		"undo":
			return _perform_undo()
		"redo":
			return _perform_redo()
		"create_action":
			return _create_undo_action(args)
		"commit_action":
			return _commit_undo_action()
		"add_do_property":
			return _add_do_property(args)
		"add_undo_property":
			return _add_undo_property(args)
		"add_do_method":
			return _add_do_method(args)
		"add_undo_method":
			return _add_undo_method(args)
		"merge_mode":
			return _handle_merge_mode(args)
		_:
			return _error("Unknown action: %s" % action)


func _get_undo_info() -> Dictionary:
	var undo_redo = _get_active_undo_redo()
	if undo_redo == null:
		return _error("EditorUndoRedoManager not available")

	return _success({
		"has_undo": undo_redo.has_undo(),
		"has_redo": undo_redo.has_redo(),
		"current_action": _current_action_name if not _current_action_name.is_empty() else null,
		"is_committing": undo_redo.is_committing_action()
	})


func _perform_undo() -> Dictionary:
	var undo_redo = _get_active_undo_redo()
	if undo_redo == null:
		return _error("EditorUndoRedoManager not available")
	var before := _capture_undo_redo_state(undo_redo)
	if not bool(before.get("has_undo", false)):
		return _error("Nothing to undo")
	undo_redo.undo()
	return _success(_build_undo_redo_result("undo", before, _capture_undo_redo_state(undo_redo)), "Undo performed")


func _perform_redo() -> Dictionary:
	var undo_redo = _get_active_undo_redo()
	if undo_redo == null:
		return _error("EditorUndoRedoManager not available")
	var before := _capture_undo_redo_state(undo_redo)
	if not bool(before.get("has_redo", false)):
		return _error("Nothing to redo")
	undo_redo.redo()
	return _success(_build_undo_redo_result("redo", before, _capture_undo_redo_state(undo_redo)), "Redo performed")


func _create_undo_action(args: Dictionary) -> Dictionary:
	var action_name := str(args.get("name", "MCP Action"))
	var context := str(args.get("context", "local"))
	var undo_redo = _get_active_undo_redo()
	if undo_redo == null:
		return _error("EditorUndoRedoManager not available")

	var merge_mode = UndoRedo.MERGE_DISABLE
	match str(args.get("merge_mode", "disable")):
		"ends":
			merge_mode = UndoRedo.MERGE_ENDS
		"all":
			merge_mode = UndoRedo.MERGE_ALL

	var context_obj = null
	if context == "local":
		context_obj = _get_active_scene_root()

	if context_obj != null:
		undo_redo.create_action(action_name, merge_mode, context_obj)
	else:
		undo_redo.create_action(action_name, merge_mode)

	_current_action_name = action_name
	return _success({
		"name": action_name,
		"context": context
	}, "Undo action created")


func _commit_undo_action() -> Dictionary:
	var undo_redo = _get_active_undo_redo()
	if undo_redo == null:
		return _error("EditorUndoRedoManager not available")
	if _current_action_name.is_empty():
		return _error("No action to commit. Create an action first.")
	undo_redo.commit_action()
	var committed_name := _current_action_name
	_current_action_name = ""
	return _success({"name": committed_name}, "Undo action committed")


func _add_do_property(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var property_name := str(args.get("property", ""))
	if path.is_empty():
		return _error("Path is required")
	if property_name.is_empty():
		return _error("Property is required")
	var undo_redo = _get_active_undo_redo()
	if undo_redo == null:
		return _error("EditorUndoRedoManager not available")
	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var converted_value = _normalize_input_value(args.get("value"))
	undo_redo.add_do_property(node, property_name, converted_value)
	return _success({"path": path, "property": property_name}, "Do property added")


func _add_undo_property(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var property_name := str(args.get("property", ""))
	if path.is_empty():
		return _error("Path is required")
	if property_name.is_empty():
		return _error("Property is required")
	var undo_redo = _get_active_undo_redo()
	if undo_redo == null:
		return _error("EditorUndoRedoManager not available")
	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)
	var undo_value = args.get("value")
	if undo_value == null:
		undo_value = node.get(property_name)
	else:
		undo_value = _normalize_input_value(undo_value)
	undo_redo.add_undo_property(node, property_name, undo_value)
	return _success({"path": path, "property": property_name}, "Undo property added")


func _add_do_method(args: Dictionary) -> Dictionary:
	return _add_method(args, true)


func _add_undo_method(args: Dictionary) -> Dictionary:
	return _add_method(args, false)


func _add_method(args: Dictionary, is_do: bool) -> Dictionary:
	var path := str(args.get("path", ""))
	var method_name := str(args.get("method", ""))
	var method_args: Array = args.get("args", [])
	if path.is_empty():
		return _error("Path is required")
	if method_name.is_empty():
		return _error("Method is required")
	var undo_redo = _get_active_undo_redo()
	if undo_redo == null:
		return _error("EditorUndoRedoManager not available")
	var node = _find_active_node(path)
	if node == null:
		return _error("Node not found: %s" % path)

	if is_do:
		match method_args.size():
			0:
				undo_redo.add_do_method(node, method_name)
			1:
				undo_redo.add_do_method(node, method_name, method_args[0])
			2:
				undo_redo.add_do_method(node, method_name, method_args[0], method_args[1])
			3:
				undo_redo.add_do_method(node, method_name, method_args[0], method_args[1], method_args[2])
			_:
				undo_redo.add_do_method(node, method_name, method_args[0], method_args[1], method_args[2], method_args[3])
	else:
		match method_args.size():
			0:
				undo_redo.add_undo_method(node, method_name)
			1:
				undo_redo.add_undo_method(node, method_name, method_args[0])
			2:
				undo_redo.add_undo_method(node, method_name, method_args[0], method_args[1])
			3:
				undo_redo.add_undo_method(node, method_name, method_args[0], method_args[1], method_args[2])
			_:
				undo_redo.add_undo_method(node, method_name, method_args[0], method_args[1], method_args[2], method_args[3])

	return _success({"path": path, "method": method_name}, "%s method added" % ("Do" if is_do else "Undo"))


func _handle_merge_mode(args: Dictionary) -> Dictionary:
	var mode := str(args.get("merge_mode", ""))
	if mode.is_empty():
		return _success({
			"available_modes": ["disable", "ends", "all"]
		})
	return _success({
		"merge_mode": mode,
		"note": "Set merge_mode when calling create_action"
	})


func _capture_undo_redo_state(undo_redo) -> Dictionary:
	return {
		"has_undo": undo_redo.has_undo(),
		"has_redo": undo_redo.has_redo(),
		"current_action": _current_action_name if not _current_action_name.is_empty() else null,
		"is_committing": undo_redo.is_committing_action()
	}


func _build_undo_redo_result(direction: String, before: Dictionary, after: Dictionary) -> Dictionary:
	return {
		"action": direction,
		"direction": direction,
		"has_undo_before": before.get("has_undo", false),
		"has_undo_after": after.get("has_undo", false),
		"has_redo_before": before.get("has_redo", false),
		"has_redo_after": after.get("has_redo", false),
		"current_action": after.get("current_action"),
		"is_committing": after.get("is_committing", false)
	}
