extends RefCounted

const UIExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/ui/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_ui_contracts"
const THEME_PATH := "res://Tmp/godot_dotnet_mcp_ui_contracts/contract_theme.tres"

var _scene_root: Control = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = UIExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/ui_tools.gd"):
		return _failure("ui_tools.gd should be removed once the split executor becomes the only stable entry.")

	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 2:
		return _failure("UI executor should expose 2 tool definitions after the split.")

	var expected_names := ["theme", "control"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("UI executor is missing tool definition '%s'." % expected_name)

	var create_result: Dictionary = executor.execute("theme", {
		"action": "create",
		"save_path": THEME_PATH
	})
	if not bool(create_result.get("success", false)):
		return _failure("Theme create failed through the split theme service.")

	var set_color_result: Dictionary = executor.execute("theme", {
		"action": "set_color",
		"path": THEME_PATH,
		"name": "font_color",
		"type": "Button",
		"color": {"r": 0.25, "g": 0.5, "b": 0.75, "a": 1.0}
	})
	if not bool(set_color_result.get("success", false)):
		return _failure("Theme set_color failed through the split theme service.")

	var set_color_payload: Dictionary = set_color_result.get("data", {})
	if str(set_color_payload.get("name", "")) != "font_color":
		return _failure("Theme set_color returned an unexpected payload.")

	var set_constant_result: Dictionary = executor.execute("theme", {
		"action": "set_constant",
		"path": THEME_PATH,
		"name": "h_separation",
		"type": "BoxContainer",
		"value": 12
	})
	if not bool(set_constant_result.get("success", false)):
		return _failure("Theme set_constant failed through the split theme service.")
	if int(set_constant_result.get("data", {}).get("value", -1)) != 12:
		return _failure("Theme set_constant returned an unexpected payload.")

	var theme_info_result: Dictionary = executor.execute("theme", {
		"action": "get_info",
		"path": THEME_PATH
	})
	if not bool(theme_info_result.get("success", false)):
		return _failure("Theme get_info failed through the split theme service.")

	var assign_result: Dictionary = executor.execute("theme", {
		"action": "assign_to_node",
		"theme_path": THEME_PATH,
		"node_path": "ContainerNode/ButtonNode"
	})
	if not bool(assign_result.get("success", false)):
		return _failure("Theme assign_to_node failed through the split theme service.")

	var anchor_result: Dictionary = executor.execute("control", {
		"action": "set_anchor_preset",
		"path": "ContainerNode",
		"preset": "full_rect"
	})
	if not bool(anchor_result.get("success", false)):
		return _failure("Control set_anchor_preset failed through the split layout service.")

	var min_size_result: Dictionary = executor.execute("control", {
		"action": "set_min_size",
		"path": "ContainerNode/ButtonNode",
		"width": 160,
		"height": 48
	})
	if not bool(min_size_result.get("success", false)):
		return _failure("Control set_min_size failed through the split layout service.")

	var focus_result: Dictionary = executor.execute("control", {
		"action": "set_focus_mode",
		"path": "ContainerNode/ButtonNode",
		"mode": "all"
	})
	if not bool(focus_result.get("success", false)):
		return _failure("Control set_focus_mode failed through the split focus service.")

	var mouse_filter_result: Dictionary = executor.execute("control", {
		"action": "set_mouse_filter",
		"path": "ContainerNode/ButtonNode",
		"filter": "pass"
	})
	if not bool(mouse_filter_result.get("success", false)):
		return _failure("Control set_mouse_filter failed through the split focus service.")

	var arrange_result: Dictionary = executor.execute("control", {
		"action": "arrange",
		"path": "ContainerNode"
	})
	if not bool(arrange_result.get("success", false)):
		return _failure("Control arrange failed through the split control service.")

	var layout_result: Dictionary = executor.execute("control", {
		"action": "get_layout",
		"path": "ContainerNode/ButtonNode"
	})
	if not bool(layout_result.get("success", false)):
		return _failure("Control get_layout failed through the split control service.")

	return {
		"name": "ui_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"theme_path": THEME_PATH,
			"assigned_theme_node": str(assign_result.get("data", {}).get("node", "")),
			"focus_mode": str(focus_result.get("data", {}).get("focus_mode", "")),
			"min_width": float(layout_result.get("data", {}).get("custom_minimum_size", {}).get("x", 0.0))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Control:
	var root := Control.new()
	root.name = "UIToolExecutorContracts"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var container := VBoxContainer.new()
	container.name = "ContainerNode"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(container)

	var button := Button.new()
	button.name = "ButtonNode"
	button.text = "Contract Button"
	container.add_child(button)

	tree.root.add_child(root)
	return root


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_tree_absolute(absolute_path)


func _remove_tree_absolute(absolute_path: String) -> void:
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
				_remove_tree_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "ui_tool_executor_contracts",
		"success": false,
		"error": message
	}
