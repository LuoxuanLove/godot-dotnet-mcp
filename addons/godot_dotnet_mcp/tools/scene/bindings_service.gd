@tool
extends "res://addons/godot_dotnet_mcp/tools/scene/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"current":
			return analyze_scene_bindings("")
		"from_path":
			return analyze_scene_bindings(str(args.get("path", "")))
		_:
			return _error("Unknown action: %s" % action)


func analyze_scene_bindings(path: String) -> Dictionary:
	var scene_result := _get_scene_root_for_analysis(path)
	if not bool(scene_result.get("success", false)):
		return scene_result

	var data: Dictionary = scene_result.get("data", {})
	var root = data.get("root")
	var issues: Array = []
	var bindings: Array = []

	_collect_bindings_recursive(root, bindings, issues)

	var result = {
		"scene_path": data.get("scene_path", ""),
		"root_name": str(root.name),
		"binding_count": bindings.size(),
		"bindings": bindings,
		"issues": issues
	}

	if bool(data.get("ephemeral", false)) and is_instance_valid(root):
		root.free()

	return _success(result)


func _get_scene_root_for_analysis(path: String) -> Dictionary:
	if path.is_empty():
		var root := _get_active_root()
		if root == null:
			return _error("No scene currently open")
		return _success({
			"root": root,
			"scene_path": _get_active_scene_path(),
			"ephemeral": false
		})

	var normalized := _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not ResourceLoader.exists(normalized):
		return _error("Scene file not found: %s" % normalized)

	var packed_scene = load(normalized)
	if packed_scene == null or not (packed_scene is PackedScene):
		return _error("Failed to load scene: %s" % normalized)

	var instance = packed_scene.instantiate()
	if instance == null:
		return _error("Failed to instantiate scene: %s" % normalized)

	return _success({
		"root": instance,
		"scene_path": normalized,
		"ephemeral": true
	})


func _collect_bindings_recursive(node: Node, bindings: Array, issues: Array) -> void:
	var script = node.get_script()
	if script != null:
		var script_path = str(script.resource_path)
		if script_path.is_empty():
			issues.append(_make_issue("warning", "script", _active_scene_path(node), "Attached script has no resource path"))
		elif not FileAccess.file_exists(script_path):
			issues.append(_make_issue("error", "script", _active_scene_path(node), "Script file not found: %s" % script_path))
		else:
			var parse_result = _parse_script_metadata(script_path)
			if not bool(parse_result.get("success", false)):
				issues.append(_make_issue("error", "script", _active_scene_path(node), str(parse_result.get("error", "Failed to parse script"))))
			else:
				for export_info in parse_result.get("data", {}).get("exports", []):
					var binding = _build_binding_info(node, parse_result.get("data", {}), export_info)
					bindings.append(binding)
					for issue in binding.get("issues", []):
						issues.append(issue)

	for child in node.get_children():
		_collect_bindings_recursive(child, bindings, issues)


func _build_binding_info(node: Node, script_meta: Dictionary, export_info: Dictionary) -> Dictionary:
	var property_name = str(export_info.get("name", ""))
	var property_info = _get_property_info(node, property_name)
	var binding = {
		"node_path": _active_scene_path(node),
		"node_name": str(node.name),
		"script_path": script_meta.get("path", ""),
		"language": script_meta.get("language", "unknown"),
		"class_name": script_meta.get("class_name", ""),
		"member_name": property_name,
		"member_type": export_info.get("type", ""),
		"member_kind": export_info.get("member_kind", ""),
		"group": export_info.get("group", ""),
		"property_exposed": not property_info.is_empty(),
		"assigned": false,
		"value": null,
		"issues": []
	}

	if property_info.is_empty():
		binding["issues"].append(_make_issue(
			"warning",
			"binding",
			_active_scene_path(node),
			"Exported member is not exposed on the node instance: %s" % property_name
		))
		return binding

	var value = node.get(property_name)
	binding["value"] = _summarize_binding_value(value)
	binding["assigned"] = _is_binding_assigned(node, property_info, value)

	if not binding["assigned"] and _binding_needs_assignment(property_info):
		binding["issues"].append(_make_issue(
			"warning",
			"binding",
			_active_scene_path(node),
			"Exported member is not assigned: %s" % property_name
		))

	return binding


func _binding_needs_assignment(property_info: Dictionary) -> bool:
	var type_name = str(property_info.get("type_name", ""))
	return type_name.contains("Object") or type_name.contains("NodePath") or type_name.contains("Array")


func _is_binding_assigned(node: Node, property_info: Dictionary, value) -> bool:
	match typeof(value):
		TYPE_NIL:
			return false
		TYPE_NODE_PATH, TYPE_STRING:
			var as_string := str(value)
			if as_string.is_empty():
				return false
			if typeof(value) == TYPE_NODE_PATH:
				return node.get_node_or_null(value) != null
			return true
		TYPE_ARRAY:
			return value.size() > 0
		TYPE_OBJECT:
			return value != null
		_:
			return true


func _summarize_binding_value(value):
	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Node:
				return {
					"type": value.get_class(),
					"path": _active_scene_path(value)
				}
			if value is Resource:
				return {
					"type": value.get_class(),
					"path": str(value.resource_path)
				}
			return str(value)
		TYPE_ARRAY:
			var items := []
			for item in value:
				items.append(_summarize_binding_value(item))
			return items
		_:
			return _serialize_value(value)


func _make_issue(severity: String, category: String, node_path: String, message: String) -> Dictionary:
	return {
		"severity": severity,
		"category": category,
		"node_path": node_path,
		"message": message
	}
