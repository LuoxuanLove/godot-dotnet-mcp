extends RefCounted

const NodeExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/node/executor.gd")
const LegacyNodeToolsScript = preload("res://addons/godot_dotnet_mcp/tools/node_tools.gd")

var _scene_root: Node2D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = NodeExecutorScript.new()
	var legacy_wrapper = LegacyNodeToolsScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})
	legacy_wrapper.configure_context({"scene_root": _scene_root})

	var executor_tools: Array[Dictionary] = executor.get_tools()
	var wrapper_tools: Array[Dictionary] = legacy_wrapper.get_tools()
	if executor_tools.size() != 9:
		return _failure("Node executor should expose 9 tool definitions after the split.")
	if wrapper_tools.size() != executor_tools.size():
		return _failure("Legacy node_tools wrapper should mirror the new executor tool count.")

	var expected_names := ["query", "lifecycle", "transform", "property", "hierarchy", "process", "metadata", "call", "visibility"]
	var actual_names: Array[String] = []
	for tool_def in executor_tools:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Node executor is missing tool definition '%s'." % expected_name)

	var query_result: Dictionary = executor.execute("query", {"action": "get_info", "path": "Player"})
	if not bool(query_result.get("success", false)):
		return _failure("Node executor failed to query node info through the split query service.")
	if str(query_result.get("data", {}).get("class_name", "")) != "Node2D":
		return _failure("Node query should report the Player fixture as Node2D.")

	var create_result: Dictionary = executor.execute("lifecycle", {
		"action": "create",
		"type": "Node2D",
		"name": "Spawned",
		"parent_path": "."
	})
	if not bool(create_result.get("success", false)):
		return _failure("Node lifecycle create failed through the split lifecycle service.")

	var property_result: Dictionary = executor.execute("property", {
		"action": "set",
		"path": "Player",
		"property": "visible",
		"value": false
	})
	if not bool(property_result.get("success", false)):
		return _failure("Node property set failed through the split property service.")

	var metadata_result: Dictionary = executor.execute("metadata", {
		"action": "set",
		"path": "Player",
		"key": "spawn_id",
		"value": 7
	})
	if not bool(metadata_result.get("success", false)):
		return _failure("Node metadata set failed through the split metadata service.")

	var method_result: Dictionary = executor.execute("call", {
		"action": "has_method",
		"path": "Player",
		"method": "queue_free"
	})
	if not bool(method_result.get("success", false)) or not bool(method_result.get("data", {}).get("exists", false)):
		return _failure("Node call service should report queue_free as an available method.")

	var visibility_result: Dictionary = executor.execute("visibility", {
		"action": "hide",
		"path": "Player"
	})
	if not bool(visibility_result.get("success", false)):
		return _failure("Node visibility hide failed through the split visibility service.")

	var children_result: Dictionary = executor.execute("query", {
		"action": "get_children",
		"path": "."
	})
	if not bool(children_result.get("success", false)):
		return _failure("Node query children failed after lifecycle create.")

	return {
		"name": "node_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": executor_tools.size(),
			"root_child_count": int(children_result.get("data", {}).get("count", 0)),
			"created_path": str(create_result.get("data", {}).get("path", ""))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node2D:
	var root := Node2D.new()
	root.name = "NodeToolExecutorContracts"

	var player := Node2D.new()
	player.name = "Player"
	root.add_child(player)
	player.owner = root

	var enemy := Node2D.new()
	enemy.name = "Enemy"
	root.add_child(enemy)
	enemy.owner = root

	var child := Node.new()
	child.name = "Child"
	player.add_child(child)
	child.owner = root

	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "node_tool_executor_contracts",
		"success": false,
		"error": message
	}
