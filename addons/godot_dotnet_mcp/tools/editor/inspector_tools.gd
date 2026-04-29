@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor inspector tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	if not ei:
		return _error("Editor interface not available")

	var action = args.get("action", "")
	match action:
		"edit_object":
			return _edit_object(ei, args.get("path", ""))
		"get_edited":
			return _get_edited_object(ei)
		"refresh":
			return _refresh_inspector(ei)
		"get_selected_property":
			return _get_selected_property(ei)
		"inspect_resource":
			return _inspect_resource(ei, args.get("resource_path", ""))
		_:
			return _error("Unknown action: %s" % action)


func _edit_object(ei, path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var node = _find_node_by_path(path)
	if not node:
		return _error("Node not found: %s" % path)

	ei.edit_node(node)
	return _success({"path": path, "type": str(node.get_class())}, "Now editing: %s" % path)


func _get_edited_object(ei) -> Dictionary:
	var inspector = ei.get_inspector()
	if not inspector:
		return _error("Inspector not available")

	var edited = inspector.get_edited_object()
	if not edited:
		return _success({"editing": null}, "No object being edited")

	var info = {"editing": true, "class": str(edited.get_class())}
	if edited is Node:
		info["path"] = _get_scene_path(edited)
		info["name"] = str(edited.name)
	elif edited is Resource:
		info["resource_path"] = str(edited.resource_path)

	return _success(info)


func _refresh_inspector(ei) -> Dictionary:
	var inspector = ei.get_inspector()
	if not inspector:
		return _error("Inspector not available")

	var edited = inspector.get_edited_object()
	if edited:
		ei.inspect_object(edited)

	return _success(null, "Inspector refreshed")


func _get_selected_property(ei) -> Dictionary:
	var inspector = ei.get_inspector()
	if not inspector:
		return _error("Inspector not available")

	return _success({"selected_path": str(inspector.get_selected_path())})


func _inspect_resource(ei, resource_path: String) -> Dictionary:
	if resource_path.is_empty():
		return _error("Resource path is required")

	if not resource_path.begins_with("res://"):
		resource_path = "res://" + resource_path

	if not ResourceLoader.exists(resource_path):
		return _error("Resource not found: %s" % resource_path)

	var resource = load(resource_path)
	if not resource:
		return _error("Failed to load resource: %s" % resource_path)

	ei.edit_resource(resource)
	return _success({"resource_path": resource_path, "type": str(resource.get_class())}, "Now inspecting resource")
