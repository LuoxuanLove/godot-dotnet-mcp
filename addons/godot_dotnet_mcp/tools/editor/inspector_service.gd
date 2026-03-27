@tool
extends "res://addons/godot_dotnet_mcp/tools/editor/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var editor_interface = _get_active_editor_interface()
	if editor_interface == null:
		return _error("Editor interface not available")

	match action:
		"edit_object":
			var path := str(args.get("path", ""))
			if path.is_empty():
				return _error("Path is required")
			var node = _find_active_node(path)
			if node == null:
				return _error("Node not found: %s" % path)
			editor_interface.edit_node(node)
			return _success({"path": path, "type": str(node.get_class())}, "Now editing: %s" % path)
		"get_edited":
			var inspector = editor_interface.get_inspector()
			if inspector == null:
				return _error("Inspector not available")
			var edited = inspector.get_edited_object()
			if edited == null:
				return _success({"editing": null}, "No object being edited")
			var info = {"editing": true, "class": str(edited.get_class())}
			if edited is Node:
				info["path"] = _get_scene_path(edited)
				info["name"] = str(edited.name)
			elif edited is Resource:
				info["resource_path"] = str(edited.resource_path)
			return _success(info)
		"refresh":
			var inspector = editor_interface.get_inspector()
			if inspector == null:
				return _error("Inspector not available")
			var edited = inspector.get_edited_object()
			if edited != null:
				editor_interface.inspect_object(edited)
			return _success(null, "Inspector refreshed")
		"get_selected_property":
			var inspector = editor_interface.get_inspector()
			if inspector == null:
				return _error("Inspector not available")
			return _success({"selected_path": str(inspector.get_selected_path())})
		"inspect_resource":
			var resource_path := str(args.get("resource_path", ""))
			if resource_path.is_empty():
				return _error("Resource path is required")
			resource_path = _normalize_res_path(resource_path)
			if not ResourceLoader.exists(resource_path):
				return _error("Resource not found: %s" % resource_path)
			var resource = load(resource_path)
			if resource == null:
				return _error("Failed to load resource: %s" % resource_path)
			editor_interface.edit_resource(resource)
			return _success({"resource_path": resource_path, "type": str(resource.get_class())}, "Now inspecting resource")
		_:
			return _error("Unknown action: %s" % action)
