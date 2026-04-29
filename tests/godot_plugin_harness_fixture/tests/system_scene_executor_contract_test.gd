extends RefCounted

# {"name": "system_scene_executor_contracts"}

const SystemSceneExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_scene.gd")


class FakeBridge extends RefCounted:
	var calls: Array[Dictionary] = []

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		calls.append({"tool_name": tool_name, "args": args.duplicate(true)})
		match tool_name:
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

	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": message, "message": message, "data": data}


func run_case(_tree: SceneTree) -> Dictionary:
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

	return {
		"name": "system_scene_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"call_count": bridge.calls.size()
		}
	}


func _has_tool(tool_defs: Array[Dictionary], name: String) -> bool:
	for tool_def in tool_defs:
		if str(tool_def.get("name", "")) == name:
			return true
	return false


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_scene_executor_contracts",
		"success": false,
		"error": message
	}
