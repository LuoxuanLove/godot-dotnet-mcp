@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor undo/redo tools for Godot MCP

var _current_action_name: String = ""
var _undo_redo_manager = null


func execute(ei, args: Dictionary) -> Dictionary:
	_editor_interface_override = ei
	_scene_root_override = ei.get_edited_scene_root() if ei != null and ei.has_method("get_edited_scene_root") else null
	var action = args.get("action", "")

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


func _get_undo_redo():
	if _undo_redo_override != null:
		return _undo_redo_override
	if _undo_redo_manager:
		return _undo_redo_manager

	if _editor_interface_override:
		_undo_redo_manager = _editor_interface_override.get_editor_undo_redo()

	return _undo_redo_manager


func _get_undo_info() -> Dictionary:
	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	return _success({
		"has_undo": urm.has_undo(),
		"has_redo": urm.has_redo(),
		"current_action": _current_action_name if not _current_action_name.is_empty() else null,
		"is_committing": urm.is_committing_action()
	})


func _perform_undo() -> Dictionary:
	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	var before = _capture_undo_redo_state(urm)
	if not before["has_undo"]:
		return _error("Nothing to undo")

	var scene_root = _editor_interface_override.get_edited_scene_root() if _editor_interface_override else null
	if scene_root:
		var local_ur = urm.get_history_undo_redo(urm.get_object_history_id(scene_root))
		if local_ur and local_ur.has_undo():
			local_ur.undo()
			return _success(_build_undo_redo_result("undo", before, _capture_undo_redo_state(urm)), "Undo performed")

	return _success(_build_undo_redo_result("undo", before, _capture_undo_redo_state(urm)), "Undo available via editor")


func _perform_redo() -> Dictionary:
	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	var before = _capture_undo_redo_state(urm)
	if not before["has_redo"]:
		return _error("Nothing to redo")

	var scene_root = _editor_interface_override.get_edited_scene_root() if _editor_interface_override else null
	if scene_root:
		var local_ur = urm.get_history_undo_redo(urm.get_object_history_id(scene_root))
		if local_ur and local_ur.has_redo():
			local_ur.redo()
			return _success(_build_undo_redo_result("redo", before, _capture_undo_redo_state(urm)), "Redo performed")

	return _success(_build_undo_redo_result("redo", before, _capture_undo_redo_state(urm)), "Redo available via editor")


func _create_undo_action(args: Dictionary) -> Dictionary:
	var action_name = args.get("name", "MCP Action")
	var context = args.get("context", "local")

	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	var merge_mode = UndoRedo.MERGE_DISABLE
	var merge_str = args.get("merge_mode", "disable")
	match merge_str:
		"ends":
			merge_mode = UndoRedo.MERGE_ENDS
		"all":
			merge_mode = UndoRedo.MERGE_ALL

	var context_obj = null
	if context == "local" and _editor_interface_override:
		context_obj = _editor_interface_override.get_edited_scene_root()

	if context_obj:
		urm.create_action(action_name, merge_mode, context_obj)
	else:
		urm.create_action(action_name, merge_mode)

	_current_action_name = action_name

	return _success({
		"name": action_name,
		"context": context,
		"merge_mode": merge_str
	}, "Undo action created - add do/undo operations then commit")


func _commit_undo_action() -> Dictionary:
	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	if _current_action_name.is_empty():
		return _error("No action to commit. Create an action first.")

	urm.commit_action()
	var committed_name = _current_action_name
	_current_action_name = ""

	return _success({"name": committed_name}, "Undo action committed")


func _add_do_property(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var property = args.get("property", "")
	var value = args.get("value")

	if path.is_empty():
		return _error("Path is required")
	if property.is_empty():
		return _error("Property is required")

	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	var converted_value = _convert_value(value)
	urm.add_do_property(node, property, converted_value)

	return _success({"path": path, "property": property, "value": value}, "Do property added")


func _add_undo_property(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var property = args.get("property", "")
	var value = args.get("value")

	if path.is_empty():
		return _error("Path is required")
	if property.is_empty():
		return _error("Property is required")

	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	var undo_value = value
	if undo_value == null:
		undo_value = node.get(property)
	else:
		undo_value = _convert_value(undo_value)

	urm.add_undo_property(node, property, undo_value)

	return _success({"path": path, "property": property, "value": undo_value}, "Undo property added")


func _add_do_method(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var method = args.get("method", "")
	var method_args = args.get("args", [])

	if path.is_empty():
		return _error("Path is required")
	if method.is_empty():
		return _error("Method is required")

	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if method_args.size() == 0:
		urm.add_do_method(node, method)
	elif method_args.size() == 1:
		urm.add_do_method(node, method, method_args[0])
	elif method_args.size() == 2:
		urm.add_do_method(node, method, method_args[0], method_args[1])
	elif method_args.size() == 3:
		urm.add_do_method(node, method, method_args[0], method_args[1], method_args[2])
	else:
		urm.add_do_method(node, method, method_args[0], method_args[1], method_args[2], method_args[3])

	return _success({"path": path, "method": method, "args": method_args}, "Do method added")


func _add_undo_method(args: Dictionary) -> Dictionary:
	var path = args.get("path", "")
	var method = args.get("method", "")
	var method_args = args.get("args", [])

	if path.is_empty():
		return _error("Path is required")
	if method.is_empty():
		return _error("Method is required")

	var urm = _get_undo_redo()
	if not urm:
		return _error("EditorUndoRedoManager not available")

	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	if method_args.size() == 0:
		urm.add_undo_method(node, method)
	elif method_args.size() == 1:
		urm.add_undo_method(node, method, method_args[0])
	elif method_args.size() == 2:
		urm.add_undo_method(node, method, method_args[0], method_args[1])
	elif method_args.size() == 3:
		urm.add_undo_method(node, method, method_args[0], method_args[1], method_args[2])
	else:
		urm.add_undo_method(node, method, method_args[0], method_args[1], method_args[2], method_args[3])

	return _success({"path": path, "method": method, "args": method_args}, "Undo method added")


func _handle_merge_mode(args: Dictionary) -> Dictionary:
	var mode = args.get("merge_mode", "")

	if mode.is_empty():
		return _success({
			"available_modes": ["disable", "ends", "all"],
			"descriptions": {
				"disable": "No merging, each action is separate",
				"ends": "Merge with previous action if same name",
				"all": "Merge all actions with same name"
			}
		})

	return _success({"merge_mode": mode, "note": "Set merge_mode when calling create_action"})


func _convert_value(value):
	return _normalize_input_value(value)


func _capture_undo_redo_state(urm) -> Dictionary:
	return {
		"has_undo": urm.has_undo(),
		"has_redo": urm.has_redo(),
		"current_action": _current_action_name if not _current_action_name.is_empty() else null,
		"is_committing": urm.is_committing_action()
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
