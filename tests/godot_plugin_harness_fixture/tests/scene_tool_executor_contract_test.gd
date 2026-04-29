extends RefCounted

const SceneExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/scene/executor.gd")


class FakeSelection:
	extends RefCounted

	var _selected_nodes: Array[Node] = []

	func clear() -> void:
		_selected_nodes.clear()

	func add_node(node: Node) -> void:
		if not _selected_nodes.has(node):
			_selected_nodes.append(node)

	func get_selected_nodes() -> Array[Node]:
		return _selected_nodes


class FakeEditorInterface:
	extends RefCounted

	var opened_scene_path := ""
	var reloaded_scene_path := ""
	var save_calls := 0
	var last_play_action := ""
	var last_custom_scene_path := ""

	func open_scene_from_path(path: String) -> void:
		opened_scene_path = path

	func save_scene() -> int:
		save_calls += 1
		return OK

	func reload_scene_from_path(path: String) -> void:
		reloaded_scene_path = path

	func play_main_scene() -> void:
		last_play_action = "play_main"

	func play_current_scene() -> void:
		last_play_action = "play_current"

	func play_custom_scene(path: String) -> void:
		last_play_action = "play_custom"
		last_custom_scene_path = path

	func stop_playing_scene() -> void:
		last_play_action = "stop"


var _scene_root: Node = null
var _temp_paths: Array[String] = []


func run_case(tree: SceneTree) -> Dictionary:
	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/scene_tools.gd"):
		return _failure("scene_tools.gd should be removed once the split executor becomes the only stable entry.")

	var executor = SceneExecutorScript.new()
	var selection := FakeSelection.new()
	var editor_interface := FakeEditorInterface.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({
		"scene_root": _scene_root,
		"scene_path": "res://tests_tmp/scene_executor_contracts/fixture_scene.tscn",
		"selection": selection,
		"editor_interface": editor_interface,
	})

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 5:
		return _failure("Scene executor should expose 5 tool definitions after the split.")

	var expected_names := ["management", "hierarchy", "run", "bindings", "audit"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Scene executor is missing tool definition '%s'." % expected_name)

	var get_current_result: Dictionary = executor.execute("management", {"action": "get_current"})
	if not bool(get_current_result.get("success", false)):
		return _failure("Scene management get_current failed through the split service path.")
	if int(get_current_result.get("data", {}).get("node_count", 0)) != 3:
		return _failure("Scene management get_current returned an unexpected node count.")

	var tree_result: Dictionary = executor.execute("hierarchy", {"action": "get_tree"})
	if not bool(tree_result.get("success", false)):
		return _failure("Scene hierarchy get_tree failed through the split service path.")

	var select_result: Dictionary = executor.execute("hierarchy", {"action": "select", "paths": ["BindingNode"]})
	if not bool(select_result.get("success", false)):
		return _failure("Scene hierarchy select failed through the split service path.")
	var selected_result: Dictionary = executor.execute("hierarchy", {"action": "get_selected"})
	if not bool(selected_result.get("success", false)):
		return _failure("Scene hierarchy get_selected failed through the split service path.")
	if int(selected_result.get("data", {}).get("count", 0)) != 1:
		return _failure("Scene hierarchy get_selected should report one selected node after select.")

	var run_result: Dictionary = executor.execute("run", {"action": "stop"})
	if not bool(run_result.get("success", false)):
		return _failure("Scene run stop failed through the split service path.")
	if editor_interface.last_play_action != "stop":
		return _failure("Scene run stop did not route to the fake editor interface.")

	var bindings_result: Dictionary = executor.execute("bindings", {"action": "current"})
	if not bool(bindings_result.get("success", false)):
		return _failure("Scene bindings current failed through the split service path.")
	if int(bindings_result.get("data", {}).get("binding_count", 0)) < 2:
		return _failure("Scene bindings current should report both exported members from the fixture script.")

	var audit_result: Dictionary = executor.execute("audit", {"action": "current"})
	if not bool(audit_result.get("success", false)):
		return _failure("Scene audit current failed through the split service path.")
	if int(audit_result.get("data", {}).get("issue_count", 0)) < 1:
		return _failure("Scene audit current should report at least one unassigned exported binding issue.")

	return {
		"name": "scene_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"binding_count": int(bindings_result.get("data", {}).get("binding_count", 0)),
			"issue_count": int(audit_result.get("data", {}).get("issue_count", 0)),
			"selected_count": int(selected_result.get("data", {}).get("count", 0))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame

	for i in range(_temp_paths.size() - 1, -1, -1):
		var path = _temp_paths[i]
		if path.ends_with(".gd"):
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_temp_paths.clear()


func _build_scene_fixture(tree: SceneTree) -> Node:
	var root := Node.new()
	root.name = "SceneExecutorContracts"
	tree.root.add_child(root)

	var target := Node.new()
	target.name = "TargetNode"
	root.add_child(target)
	target.owner = root

	var binding_node := Node.new()
	binding_node.name = "BindingNode"
	root.add_child(binding_node)
	binding_node.owner = root

	var temp_dir := "res://tests_tmp/scene_executor_contracts"
	_ensure_dir(temp_dir)
	_temp_paths.append(temp_dir)

	var script_path := "%s/fixture_binding_node.gd" % temp_dir
	_write_text(script_path, "extends Node\n\n@export var target: NodePath\n@export var speed: float = 1.0\n")
	_temp_paths.append(script_path)

	var fixture_script = load(script_path)
	binding_node.set_script(fixture_script)

	return root


func _ensure_dir(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)


func _write_text(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create scene contract fixture: %s" % path)
		return
	file.store_string(content)
	file.close()


func _failure(message: String) -> Dictionary:
	return {
		"name": "scene_tool_executor_contracts",
		"success": false,
		"error": message
	}
