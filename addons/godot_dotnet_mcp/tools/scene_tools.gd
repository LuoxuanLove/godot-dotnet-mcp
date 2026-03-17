@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Scene tools for Godot MCP
## Scene management, hierarchy inspection, runtime play controls, and exported binding analysis

const TEMP_SCENE_DIR := "res://Tmp/godot_dotnet_mcp_scene_temp"


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "management",
			"description": """SCENE MANAGEMENT: Control the currently edited scene in Godot Editor.

ACTIONS:
- get_current: Get the current scene info
- open: Open a scene by path
- save: Save the current scene
- save_as: Save the current scene to a new path
- create: Create and open a new scene
- close: Report close-scene limitations
- reload: Reload the current scene from disk""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_current", "open", "save", "save_as", "create", "close", "reload"]
					},
					"path": {"type": "string"},
					"root_type": {
						"type": "string",
						"enum": ["Node", "Node2D", "Node3D", "Control", "CanvasLayer"]
					},
					"name": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "hierarchy",
			"description": """SCENE HIERARCHY: Inspect and select nodes in the current scene.

ACTIONS:
- get_tree: Return the current scene tree
- get_selected: Return selected nodes
- select: Select nodes by path""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_tree", "get_selected", "select"]
					},
					"depth": {"type": "integer"},
					"include_internal": {"type": "boolean"},
					"paths": {"type": "array", "items": {"type": "string"}}
				},
				"required": ["action"]
			}
		},
		{
			"name": "run",
			"description": """SCENE RUN: Run or stop scenes for testing.

ACTIONS:
- play_main
- play_current
- play_custom
- stop""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["play_main", "play_current", "play_custom", "stop"]
					},
					"path": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "bindings",
			"description": """SCENE BINDINGS: Analyze exported script members used by a scene.

ACTIONS:
- current: Analyze the currently edited scene
- from_path: Load a scene by path and analyze its exported bindings""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["current", "from_path"]
					},
					"path": {"type": "string"}
				},
				"required": ["action"]
			}
		},
		{
			"name": "audit",
			"description": """SCENE AUDIT: Return structured scene issues derived from exported bindings.

ACTIONS:
- current: Audit the current edited scene
- from_path: Audit a scene loaded by path""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["current", "from_path"]
					},
					"path": {"type": "string"}
				},
				"required": ["action"]
			}
		}
	]


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"management":
			return _execute_management(args)
		"hierarchy":
			return _execute_hierarchy(args)
		"run":
			return _execute_run(args)
		"bindings":
			return _execute_bindings(args)
		"audit":
			return _execute_audit(args)
		_:
			return _error("Unknown tool: %s" % tool_name)


func _execute_management(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"get_current":
			return _get_current_scene()
		"open":
			return _open_scene(args.get("path", ""))
		"save":
			return _save_scene()
		"save_as":
			return _save_scene_as(args.get("path", ""))
		"create":
			return _create_scene(args.get("root_type", "Node"), args.get("name", "NewScene"))
		"close":
			return _close_scene()
		"reload":
			return _reload_scene()
		_:
			return _error("Unknown action: %s" % action)


func _execute_hierarchy(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")

	match action:
		"get_tree":
			return _get_scene_tree(args.get("depth", -1), args.get("include_internal", false))
		"get_selected":
			return _get_selected_nodes()
		"select":
			return _select_nodes(args.get("paths", []))
		_:
			return _error("Unknown action: %s" % action)


func _execute_run(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var ei = _get_editor_interface()
	if not ei:
		return _error("Editor interface not available")

	match action:
		"play_main":
			ei.play_main_scene()
			return _success(null, "Playing main scene")
		"play_current":
			ei.play_current_scene()
			return _success(null, "Playing current scene")
		"play_custom":
			var path = _normalize_res_path(args.get("path", ""))
			if path.is_empty():
				return _error("Path required for play_custom")
			ei.play_custom_scene(path)
			return _success({"path": path}, "Playing scene: %s" % path)
		"stop":
			ei.stop_playing_scene()
			return _success(null, "Stopped playing scene")
		_:
			return _error("Unknown action: %s" % action)


func _execute_bindings(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	if action == "current":
		return _analyze_scene_bindings("")
	if action == "from_path":
		return _analyze_scene_bindings(args.get("path", ""))
	return _error("Unknown action: %s" % action)


func _execute_audit(args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var analysis = {}

	if action == "current":
		analysis = _analyze_scene_bindings("")
	elif action == "from_path":
		analysis = _analyze_scene_bindings(args.get("path", ""))
	else:
		return _error("Unknown action: %s" % action)

	if not analysis.get("success", false):
		return analysis

	var data = analysis.get("data", {})
	return _success({
		"scene_path": data.get("scene_path", ""),
		"issue_count": data.get("issues", []).size(),
		"issues": data.get("issues", [])
	})


func _get_current_scene() -> Dictionary:
	var root = _get_edited_scene_root()
	if not root:
		return _success({
			"open": false,
			"message": "No scene currently open"
		})

	return _success({
		"open": true,
		"path": str(root.scene_file_path),
		"name": str(root.name),
		"root_type": str(root.get_class()),
		"node_count": _count_nodes(root)
	})


func _count_nodes(node: Node) -> int:
	var count = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count


func _open_scene(path: String) -> Dictionary:
	var normalized = _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not FileAccess.file_exists(normalized):
		return _error("Scene file not found: %s" % normalized)

	var ei = _get_editor_interface()
	if not ei:
		return _error("Editor interface not available")

	ei.open_scene_from_path(normalized)
	return _success({"path": normalized}, "Scene opened: %s" % normalized)


func _save_scene() -> Dictionary:
	var ei = _get_editor_interface()
	if not ei:
		return _error("Editor interface not available")

	var root = _get_edited_scene_root()
	if not root:
		return _error("No scene to save")

	var error = ei.save_scene()
	if error != OK:
		return _error("Failed to save scene: %s" % error_string(error))

	return _success({"path": str(root.scene_file_path)}, "Scene saved")


func _save_scene_as(path: String) -> Dictionary:
	var normalized = _normalize_res_path(path)
	if normalized.is_empty():
		return _error("Path is required")
	if not normalized.ends_with(".tscn"):
		normalized += ".tscn"

	var root = _get_edited_scene_root()
	if not root:
		return _error("No scene to save")

	var previous_path := str(root.scene_file_path)

	var packed_scene = PackedScene.new()
	packed_scene.pack(root)
	_ensure_res_directory(normalized.get_base_dir())
	var error = ResourceSaver.save(packed_scene, normalized)
	if error != OK:
		return _error("Failed to save scene: %s" % error_string(error))

	var ei = _get_editor_interface()
	if not ei:
		return _error("Editor interface not available")

	ei.open_scene_from_path(normalized)
	if _is_plugin_temp_scene_path(previous_path) and previous_path != normalized:
		_remove_resource_file(previous_path)

	return _success({"path": normalized}, "Scene saved as: %s" % normalized)


func _create_scene(root_type: String, scene_name: String) -> Dictionary:
	var ei = _get_editor_interface()
	if not ei:
		return _error("Editor interface not available")

	var root: Node
	match root_type:
		"Node":
			root = Node.new()
		"Node2D":
			root = Node2D.new()
		"Node3D":
			root = Node3D.new()
		"Control":
			root = Control.new()
		"CanvasLayer":
			root = CanvasLayer.new()
		_:
			return _error("Unknown root type: %s" % root_type)

	root.name = scene_name
	var packed_scene = PackedScene.new()
	packed_scene.pack(root)

	var temp_path = _build_temp_scene_path(scene_name)
	_ensure_res_directory(TEMP_SCENE_DIR)
	var error = ResourceSaver.save(packed_scene, temp_path)
	if error != OK:
		root.free()
		return _error("Failed to create scene: %s" % error_string(error))

	root.free()
	ei.open_scene_from_path(temp_path)

	return _success({
		"path": temp_path,
		"root_type": root_type,
		"name": scene_name
	}, "Scene created: %s" % temp_path)


func _build_temp_scene_path(scene_name: String) -> String:
	var slug := scene_name.to_lower().replace(" ", "_")
	if slug.is_empty():
		slug = "new_scene"
	return "%s/%s_%d.tscn" % [TEMP_SCENE_DIR, slug, Time.get_unix_time_from_system()]


func _ensure_res_directory(path: String) -> void:
	if path.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)


func _is_plugin_temp_scene_path(path: String) -> bool:
	return not path.is_empty() and path.begins_with(TEMP_SCENE_DIR + "/")


func _remove_resource_file(path: String) -> void:
	if path.is_empty():
		return
	var normalized := _normalize_res_path(path)
	if normalized.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(normalized)
	if FileAccess.file_exists(normalized):
		DirAccess.remove_absolute(absolute_path)


func _close_scene() -> Dictionary:
	return _error("Close scene is not exposed by the editor API. Use File > Close Scene in the editor.")


func _reload_scene() -> Dictionary:
	var root = _get_edited_scene_root()
	if not root:
		return _error("No scene to reload")

	var path = str(root.scene_file_path)
	if path.is_empty():
		return _error("Scene has not been saved yet")

	var ei = _get_editor_interface()
	if not ei:
		return _error("Editor interface not available")

	ei.reload_scene_from_path(path)
	return _success({"path": path}, "Scene reloaded: %s" % path)


func _get_scene_tree(max_depth: int, include_internal: bool) -> Dictionary:
	var root = _get_edited_scene_root()
	if not root:
		return _error("No scene open")

	return _success({
		"scene_path": str(root.scene_file_path),
		"root": _build_tree_recursive(root, 0, max_depth, include_internal)
	})


func _build_tree_recursive(node: Node, current_depth: int, max_depth: int, include_internal: bool) -> Dictionary:
	var result = _node_to_dict(node, false)
	if max_depth >= 0 and current_depth >= max_depth:
		result["children_truncated"] = node.get_child_count(include_internal) > 0
		return result

	var children: Array[Dictionary] = []
	for i in node.get_child_count(include_internal):
		children.append(_build_tree_recursive(node.get_child(i, include_internal), current_depth + 1, max_depth, include_internal))

	if not children.is_empty():
		result["children"] = children
	return result


func _get_selected_nodes() -> Dictionary:
	var selection = _get_selection()
	if not selection:
		return _error("Selection not available")

	var nodes: Array[Dictionary] = []
	for node in selection.get_selected_nodes():
		nodes.append(_node_to_dict(node, false))

	return _success({
		"count": nodes.size(),
		"nodes": nodes
	})


func _select_nodes(paths: Array) -> Dictionary:
	var selection = _get_selection()
	if not selection:
		return _error("Selection not available")

	selection.clear()

	var selected_count = 0
	var errors: Array[String] = []
	for path in paths:
		var node = _find_node_by_path(path)
		if node:
			selection.add_node(node)
			selected_count += 1
		else:
			errors.append("Node not found: %s" % path)

	return _success({
		"selected": selected_count,
		"requested": paths.size(),
		"errors": errors
	}, "Selected %d nodes" % selected_count)


func _analyze_scene_bindings(path: String) -> Dictionary:
	var scene_result = _get_scene_root_for_analysis(path)
	if not scene_result.get("success", false):
		return scene_result

	var data = scene_result.get("data", {})
	var root = data.get("root")
	var issues = []
	var bindings = []

	_collect_bindings_recursive(root, bindings, issues)

	var result = {
		"scene_path": data.get("scene_path", ""),
		"root_name": str(root.name),
		"binding_count": bindings.size(),
		"bindings": bindings,
		"issues": issues
	}

	if data.get("ephemeral", false) and is_instance_valid(root):
		root.free()

	return _success(result)


func _get_scene_root_for_analysis(path: String) -> Dictionary:
	if path.is_empty():
		var root = _get_edited_scene_root()
		if not root:
			return _error("No scene currently open")
		return _success({
			"root": root,
			"scene_path": str(root.scene_file_path),
			"ephemeral": false
		})

	var normalized = _normalize_res_path(path)
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
			issues.append(_make_issue("warning", "script", _get_scene_path(node), "Attached script has no resource path"))
		elif not FileAccess.file_exists(script_path):
			issues.append(_make_issue("error", "script", _get_scene_path(node), "Script file not found: %s" % script_path))
		else:
			var parse_result = _parse_script_metadata(script_path)
			if not parse_result.get("success", false):
				issues.append(_make_issue("error", "script", _get_scene_path(node), parse_result.get("error", "Failed to parse script")))
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
		"node_path": _get_scene_path(node),
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
			_get_scene_path(node),
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
			_get_scene_path(node),
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
			var as_string = str(value)
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
					"path": _get_scene_path(value)
				}
			if value is Resource:
				return {
					"type": value.get_class(),
					"path": str(value.resource_path)
				}
			return str(value)
		TYPE_ARRAY:
			var items = []
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
