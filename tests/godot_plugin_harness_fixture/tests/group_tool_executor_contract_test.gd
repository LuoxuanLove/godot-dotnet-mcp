extends RefCounted

const GroupExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/group/executor.gd")


class GroupReceiver extends Node:
	var marks: Array = []

	func mark(value = null) -> void:
		marks.append(value)


var _scene_root: Node = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = GroupExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/group_tools.gd"):
		return _failure("group_tools.gd should be removed once the split executor becomes the only stable entry.")

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 1:
		return _failure("Group executor should expose exactly 1 tool definition after the split.")
	if str(tool_defs[0].get("name", "")) != "group":
		return _failure("Group executor should expose the canonical 'group' tool definition.")

	var add_a_result: Dictionary = executor.execute("group", {
		"action": "add",
		"path": "EnemyA",
		"group": "enemies"
	})
	if not bool(add_a_result.get("success", false)):
		return _failure("Group add failed through the split membership service.")

	var add_b_result: Dictionary = executor.execute("group", {
		"action": "add",
		"path": "EnemyB",
		"group": "enemies"
	})
	if not bool(add_b_result.get("success", false)):
		return _failure("Adding the second node to the group should succeed.")

	var list_result: Dictionary = executor.execute("group", {
		"action": "list",
		"path": "EnemyA"
	})
	if not bool(list_result.get("success", false)):
		return _failure("Group list failed through the split query service.")

	var is_in_result: Dictionary = executor.execute("group", {
		"action": "is_in",
		"path": "EnemyA",
		"group": "enemies"
	})
	if not bool(is_in_result.get("success", false)):
		return _failure("Group is_in failed through the split query service.")
	if not bool(is_in_result.get("data", {}).get("is_in_group", false)):
		return _failure("EnemyA should report that it belongs to the enemies group.")

	var get_nodes_result: Dictionary = executor.execute("group", {
		"action": "get_nodes",
		"group": "enemies"
	})
	if not bool(get_nodes_result.get("success", false)):
		return _failure("Group get_nodes failed through the split query service.")

	var call_result: Dictionary = executor.execute("group", {
		"action": "call_group",
		"group": "enemies",
		"method": "mark",
		"args": [42]
	})
	if not bool(call_result.get("success", false)):
		return _failure("Group call_group failed through the split operation service.")

	var set_result: Dictionary = executor.execute("group", {
		"action": "set_group",
		"group": "enemies",
		"property": "process_priority",
		"value": 9
	})
	if not bool(set_result.get("success", false)):
		return _failure("Group set_group failed through the split operation service.")

	var remove_result: Dictionary = executor.execute("group", {
		"action": "remove",
		"path": "EnemyB",
		"group": "enemies"
	})
	if not bool(remove_result.get("success", false)):
		return _failure("Group remove failed through the split membership service.")

	var enemy_a := _scene_root.get_node_or_null("EnemyA") as GroupReceiver
	var enemy_b := _scene_root.get_node_or_null("EnemyB") as GroupReceiver
	if enemy_a == null or enemy_b == null:
		return _failure("Group fixture nodes should exist in the test scene.")
	if enemy_a.marks.size() != 1 or int(enemy_a.marks[0]) != 42:
		return _failure("Group call_group should invoke the target method on EnemyA.")
	if enemy_b.marks.size() != 1 or int(enemy_b.marks[0]) != 42:
		return _failure("Group call_group should invoke the target method on EnemyB.")
	if enemy_a.process_priority != 9 or enemy_b.process_priority != 9:
		return _failure("Group set_group should update the target property on every node in the group.")

	var removed_is_in_result: Dictionary = executor.execute("group", {
		"action": "is_in",
		"path": "EnemyB",
		"group": "enemies"
	})
	if not bool(removed_is_in_result.get("success", false)):
		return _failure("Group is_in after remove should still succeed.")
	if bool(removed_is_in_result.get("data", {}).get("is_in_group", true)):
		return _failure("EnemyB should report not being in the enemies group after removal.")

	var invalid_call_result: Dictionary = executor.execute("group", {
		"action": "call_group",
		"group": "missing_group",
		"method": "mark"
	})
	if bool(invalid_call_result.get("success", false)):
		return _failure("Group call_group should fail when the group is missing.")

	return {
		"name": "group_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"group_count": int(list_result.get("data", {}).get("count", 0)),
			"node_count": int(get_nodes_result.get("data", {}).get("count", 0)),
			"called_count": int(call_result.get("data", {}).get("called_count", 0))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node:
	var root := Node.new()
	root.name = "GroupToolExecutorContracts"
	var enemy_a := GroupReceiver.new()
	enemy_a.name = "EnemyA"
	var enemy_b := GroupReceiver.new()
	enemy_b.name = "EnemyB"
	root.add_child(enemy_a)
	root.add_child(enemy_b)
	tree.root.add_child(root)
	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "group_tool_executor_contracts",
		"success": false,
		"error": message
	}
