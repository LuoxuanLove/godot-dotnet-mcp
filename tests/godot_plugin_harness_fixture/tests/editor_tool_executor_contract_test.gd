extends RefCounted

const EditorExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/editor/executor.gd")


class FakeMainScreen:
	extends RefCounted

	var name := "2D"


class FakeEditorSettings:
	extends RefCounted

	var _settings := {
		"interface/editor/main_font_size": 14,
		"interface/editor/code_font_size": 16,
		"filesystem/file_dialog/show_hidden_files": false,
	}

	func has_setting(setting: String) -> bool:
		return _settings.has(setting)

	func get_setting(setting: String):
		return _settings.get(setting)

	func set_setting(setting: String, value) -> void:
		_settings[setting] = value


class FakeUndoRedo:
	extends RefCounted

	var _has_undo := false
	var _has_redo := false
	var _is_committing := false
	var _actions: Array[String] = []

	func has_undo() -> bool:
		return _has_undo

	func has_redo() -> bool:
		return _has_redo

	func is_committing_action() -> bool:
		return _is_committing

	func create_action(name: String, _merge_mode: int, _context_obj = null) -> void:
		_actions.append(name)
		_is_committing = false

	func commit_action() -> void:
		_has_undo = true
		_has_redo = false
		_is_committing = false

	func add_do_property(_node, _property, _value) -> void:
		pass

	func add_undo_property(_node, _property, _value) -> void:
		pass

	func add_do_method(_node, _method, _arg0 = null, _arg1 = null, _arg2 = null, _arg3 = null) -> void:
		pass

	func add_undo_method(_node, _method, _arg0 = null, _arg1 = null, _arg2 = null, _arg3 = null) -> void:
		pass

	func undo() -> void:
		_has_undo = false
		_has_redo = true

	func redo() -> void:
		_has_undo = true
		_has_redo = false


class FakeInspector:
	extends RefCounted

	var edited_object = null
	var selected_path := "speed"

	func get_edited_object():
		return edited_object

	func get_selected_path() -> String:
		return selected_path


class FakeFileSystem:
	extends RefCounted

	var scan_calls := 0
	var last_reimport_paths: PackedStringArray = PackedStringArray()

	func scan() -> void:
		scan_calls += 1

	func reimport_files(paths: PackedStringArray) -> void:
		last_reimport_paths = paths


class FakeEditorInterface:
	extends RefCounted

	var _main_screen := FakeMainScreen.new()
	var _distraction_free := false
	var _editor_settings := FakeEditorSettings.new()
	var _undo_redo := FakeUndoRedo.new()
	var _inspector := FakeInspector.new()
	var _filesystem := FakeFileSystem.new()
	var _selected_paths: PackedStringArray = PackedStringArray()
	var _plugin_states := {}
	var last_edit_node = null
	var last_inspected_resource = null

	func get_editor_scale() -> float:
		return 1.5

	func get_editor_main_screen():
		return _main_screen

	func set_main_screen_editor(screen: String) -> void:
		_main_screen.name = screen

	func is_distraction_free_mode_enabled() -> bool:
		return _distraction_free

	func set_distraction_free_mode(enabled: bool) -> void:
		_distraction_free = enabled

	func get_editor_settings():
		return _editor_settings

	func get_editor_undo_redo():
		return _undo_redo

	func get_inspector():
		return _inspector

	func edit_node(node: Node) -> void:
		last_edit_node = node

	func inspect_object(object) -> void:
		_inspector.edited_object = object

	func edit_resource(resource) -> void:
		last_inspected_resource = resource

	func select_file(path: String) -> void:
		_selected_paths = PackedStringArray([path])

	func get_selected_paths() -> PackedStringArray:
		return _selected_paths

	func get_current_path() -> String:
		return "res://scenes/main.tscn"

	func get_current_directory() -> String:
		return "res://scenes"

	func get_resource_filesystem():
		return _filesystem

	func is_plugin_enabled(plugin_name: String) -> bool:
		return bool(_plugin_states.get(plugin_name, false))

	func set_plugin_enabled(plugin_name: String, enabled: bool) -> void:
		_plugin_states[plugin_name] = enabled


var _scene_root: Node = null


func run_case(tree: SceneTree) -> Dictionary:
	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/editor_tools.gd"):
		return _failure("editor_tools.gd should be removed once the split executor becomes the only stable entry.")

	var executor = EditorExecutorScript.new()
	var editor_interface := FakeEditorInterface.new()
	_scene_root = _build_scene_fixture(tree)
	editor_interface.get_inspector().edited_object = _scene_root.get_node("Target")
	executor.configure_context({
		"editor_interface": editor_interface,
		"undo_redo": editor_interface.get_editor_undo_redo(),
		"scene_root": _scene_root,
	})

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 7:
		return _failure("Editor executor should expose 7 tool definitions after the split.")

	var expected_names := ["status", "settings", "undo_redo", "notification", "inspector", "filesystem", "plugin"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Editor executor is missing tool definition '%s'." % expected_name)

	var set_screen_result: Dictionary = executor.execute("status", {"action": "set_main_screen", "screen": "3D"})
	if not bool(set_screen_result.get("success", false)):
		return _failure("Editor status set_main_screen failed through the split service path.")
	var get_screen_result: Dictionary = executor.execute("status", {"action": "get_main_screen"})
	if str(get_screen_result.get("data", {}).get("current_screen", "")) != "3D":
		return _failure("Editor status get_main_screen did not reflect the updated screen.")

	var set_setting_result: Dictionary = executor.execute("settings", {
		"action": "set",
		"setting": "interface/editor/code_font_size",
		"value": 18
	})
	if not bool(set_setting_result.get("success", false)):
		return _failure("Editor settings set failed through the split service path.")
	var get_setting_result: Dictionary = executor.execute("settings", {
		"action": "get",
		"setting": "interface/editor/code_font_size"
	})
	if int(get_setting_result.get("data", {}).get("value", 0)) != 18:
		return _failure("Editor settings get did not return the updated value.")

	var create_action_result: Dictionary = executor.execute("undo_redo", {
		"action": "create_action",
		"name": "Rename Target",
		"context": "local"
	})
	if not bool(create_action_result.get("success", false)):
		return _failure("Editor undo_redo create_action failed through the split service path.")
	var add_do_property_result: Dictionary = executor.execute("undo_redo", {
		"action": "add_do_property",
		"path": "Target",
		"property": "process_priority",
		"value": 3
	})
	if not bool(add_do_property_result.get("success", false)):
		return _failure("Editor undo_redo add_do_property failed through the split service path.")
	var commit_action_result: Dictionary = executor.execute("undo_redo", {"action": "commit_action"})
	if not bool(commit_action_result.get("success", false)):
		return _failure("Editor undo_redo commit_action failed through the split service path.")

	var notification_result: Dictionary = executor.execute("notification", {
		"action": "toast",
		"message": "Editor executor contract",
		"severity": "info"
	})
	if not bool(notification_result.get("success", false)):
		return _failure("Editor notification toast failed through the split service path.")

	var edit_object_result: Dictionary = executor.execute("inspector", {
		"action": "edit_object",
		"path": "Target"
	})
	if not bool(edit_object_result.get("success", false)):
		return _failure("Editor inspector edit_object failed through the split service path.")
	var selected_property_result: Dictionary = executor.execute("inspector", {"action": "get_selected_property"})
	if str(selected_property_result.get("data", {}).get("selected_path", "")) != "speed":
		return _failure("Editor inspector get_selected_property returned an unexpected value.")

	var select_file_result: Dictionary = executor.execute("filesystem", {
		"action": "select_file",
		"path": "res://scenes/main.tscn"
	})
	if not bool(select_file_result.get("success", false)):
		return _failure("Editor filesystem select_file failed through the split service path.")
	var selected_files_result: Dictionary = executor.execute("filesystem", {"action": "get_selected"})
	if int(selected_files_result.get("data", {}).get("count", 0)) != 1:
		return _failure("Editor filesystem get_selected should report one selected file.")

	var enable_plugin_result: Dictionary = executor.execute("plugin", {
		"action": "enable",
		"plugin": "godot_dotnet_mcp"
	})
	if not bool(enable_plugin_result.get("success", false)):
		return _failure("Editor plugin enable failed through the split service path.")
	var plugin_state_result: Dictionary = executor.execute("plugin", {
		"action": "is_enabled",
		"plugin": "godot_dotnet_mcp"
	})
	if not bool(plugin_state_result.get("data", {}).get("enabled", false)):
		return _failure("Editor plugin is_enabled should report the enabled state after enable.")

	return {
		"name": "editor_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"current_screen": str(get_screen_result.get("data", {}).get("current_screen", "")),
			"selected_property": str(selected_property_result.get("data", {}).get("selected_path", "")),
			"selected_file_count": int(selected_files_result.get("data", {}).get("count", 0))
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
	root.name = "EditorExecutorContracts"
	tree.root.add_child(root)

	var target := Node.new()
	target.name = "Target"
	root.add_child(target)
	target.owner = root

	return root


func _failure(message: String) -> Dictionary:
	return {
		"name": "editor_tool_executor_contracts",
		"success": false,
		"error": message
	}
