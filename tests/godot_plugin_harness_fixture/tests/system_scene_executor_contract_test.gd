extends RefCounted

# {"name": "system_scene_executor_contracts"}

const SystemSceneExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_scene.gd")
const AtomicBridgeScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge.gd")
const TEMP_ROOT := "res://tests_tmp/system_scene_executor_contracts"


class FakeBridge extends RefCounted:
	var calls: Array[Dictionary] = []
	var atomic_bridge = AtomicBridgeScript.new()

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		calls.append({"tool_name": tool_name, "args": args.duplicate(true)})
		match tool_name:
			"scene_audit":
				return success({"issues": []})
			"resource_query":
				return success({"dependencies": ["uid://missing_scene_contract::::res://tests_tmp/system_scene_executor_contracts/missing_dependency.cs"]})
			"scene_hierarchy":
				return success({"tool_name": tool_name, "action": str(args.get("action", ""))})
			"scene_management":
				return success({"tool_name": tool_name, "action": str(args.get("action", ""))})
			"node_lifecycle":
				return success({"tool_name": tool_name, "action": str(args.get("action", "")), "path": str(args.get("path", args.get("node_path", "")))})
			"node_property":
				return success({"tool_name": tool_name, "action": str(args.get("action", "")), "path": str(args.get("path", "")), "property": str(args.get("property", ""))})
			"node_hierarchy":
				return success({"tool_name": tool_name, "action": str(args.get("action", "")), "path": str(args.get("path", ""))})
			"node_transform":
				return success({"tool_name": tool_name, "action": str(args.get("action", "")), "path": str(args.get("path", ""))})
			_:
				return error("Unsupported fake bridge call: %s" % tool_name)

	func extract_data(result: Dictionary) -> Dictionary:
		var data = result.get("data", {})
		return (data as Dictionary).duplicate(true) if data is Dictionary else {}

	func parse_dependency_reference(raw_path: String, source_path: String = "") -> Dictionary:
		return atomic_bridge.parse_dependency_reference(raw_path, source_path)

	func normalize_dependency_path(raw_path: String) -> String:
		return atomic_bridge.normalize_dependency_path(raw_path)

	func build_issue(severity: String, issue_type: String, message: String, extra: Dictionary = {}) -> Dictionary:
		return atomic_bridge.build_issue(severity, issue_type, message, extra)

	func append_unique_issue(issues: Array, issue: Dictionary) -> void:
		atomic_bridge.append_unique_issue(issues, issue)

	func has_severity(issues: Array, severity: String) -> bool:
		return atomic_bridge.has_severity(issues, severity)

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": message, "message": message, "data": data}


func run_case(_tree: SceneTree) -> Dictionary:
	_prepare_temp_root()
	var scene_path := TEMP_ROOT.path_join("SceneWithMissingUidDependency.tscn")
	_write_text(scene_path, "[gd_scene format=3]\n[node name=\"Root\" type=\"Node\"]\n")

	var executor = SystemSceneExecutorScript.new()
	var bridge = FakeBridge.new()
	executor.bridge = bridge

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 4:
		return _failure("System scene implementation should expose scene_validate, scene_analyze, scene_tree and scene_patch.")
	if not _has_tool(tool_defs, "scene_tree"):
		return _failure("System scene implementation should expose scene_tree for high-level Scene dock changes.")

	var tree_result: Dictionary = executor.execute("scene_tree", {
		"action": "get_tree",
		"depth": 2,
		"include_internal": true
	})
	if not bool(tree_result.get("success", false)):
		return _failure("scene_tree get_tree should delegate to scene_hierarchy.")
	if str(bridge.calls[-1].get("tool_name", "")) != "scene_hierarchy":
		return _failure("scene_tree get_tree should use scene_hierarchy atomic tool.")

	var add_result: Dictionary = executor.execute("scene_tree", {
		"action": "add_node",
		"parent_path": "/root/Main",
		"type": "Node3D",
		"name": "Child"
	})
	if not bool(add_result.get("success", false)):
		return _failure("scene_tree add_node should delegate to node_lifecycle create.")
	if str(bridge.calls[-1].get("tool_name", "")) != "node_lifecycle" or str(bridge.calls[-1].get("args", {}).get("action", "")) != "create":
		return _failure("scene_tree add_node should call node_lifecycle create.")

	var reparent_result: Dictionary = executor.execute("scene_tree", {
		"action": "reparent_node",
		"node_path": "/root/Main/Child",
		"new_parent": "/root/Main/Other"
	})
	if not bool(reparent_result.get("success", false)):
		return _failure("scene_tree reparent_node should delegate to node_hierarchy reparent.")
	var reparent_args: Dictionary = bridge.calls[-1].get("args", {})
	if str(reparent_args.get("path", "")) != "/root/Main/Child":
		return _failure("scene_tree reparent_node should pass node_path as node_hierarchy.path.")

	var transform_result: Dictionary = executor.execute("scene_tree", {
		"action": "set_transform",
		"node_path": "/root/Main/Child",
		"x": 1,
		"y": 2,
		"z": 3
	})
	if not bool(transform_result.get("success", false)):
		return _failure("scene_tree set_transform should delegate to node_transform.")

	var validate_result: Dictionary = executor.execute("scene_validate", {"scene": scene_path})
	if not bool(validate_result.get("success", false)):
		return _failure("scene_validate should succeed and report dependency reference issues.")
	var validate_data: Dictionary = validate_result.get("data", {})
	if int(validate_data.get("dependency_reference_issue_count", 0)) < 1:
		return _failure("scene_validate should report UID/fallback dependency reference issues.")
	var validate_issues: Array = validate_data.get("issues", [])
	if not _has_issue_type(validate_issues, "missing_uid_and_path"):
		return _failure("scene_validate should classify missing UID plus fallback path references.")

	return {
		"name": "system_scene_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"call_count": bridge.calls.size()
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)


func _has_tool(tool_defs: Array[Dictionary], name: String) -> bool:
	for tool_def in tool_defs:
		if str(tool_def.get("name", "")) == name:
			return true
	return false


func _has_issue_type(issues: Array, issue_type: String) -> bool:
	for issue in issues:
		if issue is Dictionary and str((issue as Dictionary).get("type", "")) == issue_type:
			return true
	return false


func _prepare_temp_root() -> void:
	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create system scene contract fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree(ProjectSettings.localize_path(child_path))
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_scene_executor_contracts",
		"success": false,
		"error": message
	}
