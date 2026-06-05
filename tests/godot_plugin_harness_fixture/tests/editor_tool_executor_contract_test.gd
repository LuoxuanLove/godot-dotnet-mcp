extends RefCounted

# {"name": "editor_tool_executor_contracts"}

const EditorExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/editor/executor.gd")


class FakeMainScreen:
	extends RefCounted

	var name := "MainScreenContainer"


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


class FakeScreenshotImage:
	extends RefCounted

	var width := 320
	var height := 180

	func is_empty() -> bool:
		return false

	func get_width() -> int:
		return width

	func get_height() -> int:
		return height

	func get_region(rect: Rect2i):
		var image := FakeScreenshotImage.new()
		image.width = rect.size.x
		image.height = rect.size.y
		return image

	func save_png(path: String) -> int:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return ERR_CANT_CREATE
		file.store_buffer(PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]))
		file.close()
		return OK


class FakeScreenshotTexture:
	extends RefCounted

	var _image := FakeScreenshotImage.new()

	func get_image():
		return _image


class FakeEditorViewport:
	extends RefCounted

	var _texture := FakeScreenshotTexture.new()
	var focus_owner = null
	var pushed_events: Array = []

	func get_texture():
		return _texture

	func gui_get_focus_owner():
		return focus_owner

	func get_visible_rect() -> Rect2:
		return Rect2(0, 0, 320, 180)

	func push_input(event, _in_local_coords: bool = false) -> void:
		pushed_events.append(event)


class FakeEditorBaseControl:
	extends RefCounted

	var _viewport := FakeEditorViewport.new()
	var _children: Array = []

	func get_viewport():
		return _viewport

	func add_popup_child(child) -> void:
		_children.append(child)
		if child != null and child.has_method("set_parent"):
			child.set_parent(self)

	func get_children() -> Array:
		return _children

	func get_parent():
		return null

	func get_path() -> NodePath:
		return NodePath("/root/Editor")


class FakePopupNode:
	extends RefCounted

	var name := ""
	var title := ""
	var text := ""
	var visible := true
	var disabled := false
	var _popup_class := "Control"
	var _parent_ref: WeakRef = null
	var _children: Array = []
	var pressed := false
	var _rect := Rect2(0, 0, 100, 24)
	var _items: Array[Dictionary] = []
	var selected_index := -1
	var selected_id := -1

	func _init(node_name: String = "", popup_class: String = "Control") -> void:
		name = node_name
		_popup_class = popup_class

	func set_parent(parent) -> void:
		_parent_ref = weakref(parent)

	func add_child(child) -> void:
		_children.append(child)
		if child != null and child.has_method("set_parent"):
			child.set_parent(self)

	func get_children() -> Array:
		return _children

	func get_parent():
		return _parent_ref.get_ref() if _parent_ref != null else null

	func get_popup_class() -> String:
		return _popup_class

	func get_path() -> NodePath:
		var parent = get_parent()
		if parent == null or not parent.has_method("get_path"):
			return NodePath("/" + name)
		return NodePath(str(parent.get_path()) + "/" + name)

	func is_visible_in_tree() -> bool:
		return visible

	func get_global_rect() -> Rect2:
		return _rect

	func hide() -> void:
		visible = false

	func press() -> void:
		pressed = true

	func add_menu_item(text_value: String, id_value: int, disabled_value: bool = false, separator_value: bool = false, submenu_value: String = "") -> void:
		_items.append({
			"text": text_value,
			"id": id_value,
			"disabled": disabled_value,
			"separator": separator_value,
			"submenu": submenu_value
		})

	func get_item_count() -> int:
		return _items.size()

	func get_item_id(index: int) -> int:
		return int(_items[index].get("id", index))

	func get_item_text(index: int) -> String:
		return str(_items[index].get("text", ""))

	func is_item_disabled(index: int) -> bool:
		return bool(_items[index].get("disabled", false))

	func is_item_separator(index: int) -> bool:
		return bool(_items[index].get("separator", false))

	func get_item_submenu(index: int) -> String:
		return str(_items[index].get("submenu", ""))

	func activate_item(index: int) -> void:
		selected_index = index
		selected_id = get_item_id(index)


class FakeLegacyPopupMenu:
	extends RefCounted

	signal index_pressed(index: int)
	signal id_pressed(id: int)

	var emitted_index := -1
	var emitted_id := -1

	func _init() -> void:
		index_pressed.connect(_record_index_pressed)
		id_pressed.connect(_record_id_pressed)

	func dispose() -> void:
		if index_pressed.is_connected(_record_index_pressed):
			index_pressed.disconnect(_record_index_pressed)
		if id_pressed.is_connected(_record_id_pressed):
			id_pressed.disconnect(_record_id_pressed)

	func _record_index_pressed(index: int) -> void:
		emitted_index = index

	func _record_id_pressed(id: int) -> void:
		emitted_id = id


class FakeUiControl:
	extends RefCounted

	var name := ""
	var text := ""
	var title := ""
	var visible := true
	var disabled := false
	var focused := false
	var pressed := false
	var _ui_class := "Control"
	var _parent_ref: WeakRef = null
	var _children: Array = []
	var _rect := Rect2(0, 0, 100, 24)
	var _button_group = null

	func _init(node_name: String = "", ui_class: String = "Control", rect: Rect2 = Rect2(0, 0, 100, 24)) -> void:
		name = node_name
		_ui_class = ui_class
		_rect = rect

	func set_parent(parent) -> void:
		_parent_ref = weakref(parent)

	func add_child(child) -> void:
		_children.append(child)
		if child != null and child.has_method("set_parent"):
			child.set_parent(self)

	func get_children() -> Array:
		return _children

	func get_child_count() -> int:
		return _children.size()

	func get_parent():
		return _parent_ref.get_ref() if _parent_ref != null else null

	func get_path() -> NodePath:
		var parent = get_parent()
		if parent == null or not parent.has_method("get_path"):
			return NodePath("/" + name)
		return NodePath(str(parent.get_path()) + "/" + name)

	func is_visible_in_tree() -> bool:
		return visible

	func get_global_rect() -> Rect2:
		return _rect

	func get_ui_class() -> String:
		return _ui_class

	func get_button_group():
		return _button_group

	func set_button_group(group) -> void:
		_button_group = group

	func grab_focus() -> void:
		focused = true

	func press() -> void:
		pressed = true

	func set_text(value: String) -> void:
		text = value


class FakePopupMenuControl:
	extends FakeUiControl

	var activated_index := -1
	var _items: Array[Dictionary] = []

	func _init(node_name: String = "", rect: Rect2 = Rect2(0, 0, 160, 120)) -> void:
		super(node_name, "PopupMenu", rect)
		visible = false

	func add_item(label: String, id: int = -1, disabled: bool = false, separator: bool = false, submenu: String = "") -> void:
		_items.append({
			"text": label,
			"id": id if id >= 0 else _items.size(),
			"disabled": disabled,
			"separator": separator,
			"submenu": submenu
		})

	func get_item_count() -> int:
		return _items.size()

	func get_item_text(index: int) -> String:
		return str(_items[index].get("text", ""))

	func get_item_id(index: int) -> int:
		return int(_items[index].get("id", index))

	func is_item_disabled(index: int) -> bool:
		return bool(_items[index].get("disabled", false))

	func is_item_separator(index: int) -> bool:
		return bool(_items[index].get("separator", false))

	func get_item_submenu(index: int) -> String:
		return str(_items[index].get("submenu", ""))

	func popup() -> void:
		visible = true

	func activate_item(index: int) -> void:
		activated_index = index


class FakeMenuButton:
	extends FakeUiControl

	var _popup := FakePopupMenuControl.new("ProjectPopup")

	func _init(node_name: String = "", label: String = "", rect: Rect2 = Rect2(0, 0, 80, 24)) -> void:
		super(node_name, "MenuButton", rect)
		text = label
		add_child(_popup)

	func get_popup():
		return _popup

	func show_popup() -> void:
		_popup.popup()


class FakeTabContainer:
	extends FakeUiControl

	var current_tab := 0
	var _tab_titles: Array[String] = []

	func _init(node_name: String = "", rect: Rect2 = Rect2(0, 0, 100, 24)) -> void:
		super(node_name, "TabContainer", rect)

	func add_tab(child, title: String) -> void:
		_tab_titles.append(title)
		add_child(child)
		_update_tab_visibility()

	func get_tab_count() -> int:
		return _children.size()

	func get_tab_control(index: int):
		if index < 0 or index >= _children.size():
			return null
		return _children[index]

	func get_tab_title(index: int) -> String:
		if index < 0 or index >= _tab_titles.size():
			return ""
		return _tab_titles[index]

	func set_current_tab(index: int) -> void:
		current_tab = index
		_update_tab_visibility()

	func _update_tab_visibility() -> void:
		for index in range(_children.size()):
			var child = _children[index]
			if child != null:
				child.visible = index == current_tab


class FakeFocusOwner:
	extends RefCounted

	var name := "InspectorSearch"

	func get_focus_class() -> String:
		return "LineEdit"

	func get_path() -> NodePath:
		return NodePath("/root/Editor/InspectorSearch")


class FakeSelection:
	extends RefCounted

	var _nodes: Array = []

	func get_selected_nodes() -> Array:
		return _nodes


class FakeEditorInterface:
	extends RefCounted

	var _main_screen := FakeMainScreen.new()
	var _distraction_free := false
	var _editor_settings := FakeEditorSettings.new()
	var _undo_redo := FakeUndoRedo.new()
	var _inspector := FakeInspector.new()
	var _filesystem := FakeFileSystem.new()
	var _base_control := FakeEditorBaseControl.new()
	var _selection := FakeSelection.new()
	var _edited_scene_root: Node = null
	var _selected_paths: PackedStringArray = PackedStringArray()
	var _plugin_states := {}
	var _main_screen_buttons := {}
	var last_edit_node = null
	var last_inspected_resource = null

	func get_editor_scale() -> float:
		return 1.5

	func get_editor_main_screen():
		return _main_screen

	func set_main_screen_editor(screen: String) -> void:
		for button_name in _main_screen_buttons.keys():
			var button = _main_screen_buttons.get(button_name, null)
			if button != null and button is Object:
				button.pressed = str(button_name).to_lower() == screen.to_lower()

	func register_main_screen_button(screen: String, button) -> void:
		_main_screen_buttons[screen] = button

	func is_distraction_free_mode_enabled() -> bool:
		return _distraction_free

	func set_distraction_free_mode(enabled: bool) -> void:
		_distraction_free = enabled

	func get_editor_settings():
		return _editor_settings

	func get_editor_undo_redo():
		return _undo_redo

	func get_base_control():
		return _base_control

	func get_selection():
		return _selection

	func get_edited_scene_root() -> Node:
		return _edited_scene_root

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
		var enabled_plugins = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
		var updated := PackedStringArray()
		if enabled_plugins is PackedStringArray:
			updated = enabled_plugins
		elif enabled_plugins is Array:
			for item in enabled_plugins:
				updated.append(str(item))
		var plugin_cfg := "res://addons/%s/plugin.cfg" % plugin_name
		if enabled:
			if not updated.has(plugin_cfg):
				updated.append(plugin_cfg)
		elif updated.has(plugin_cfg):
			updated.remove_at(updated.find(plugin_cfg))
		ProjectSettings.set_setting("editor_plugins/enabled", updated)


class FakeEditorPlugin:
	extends RefCounted

	var _editor_interface = null
	var visible_bottom_panel = null

	func _init(editor_interface = null) -> void:
		_editor_interface = editor_interface

	func get_editor_interface():
		return _editor_interface

	func make_bottom_panel_item_visible(control) -> void:
		visible_bottom_panel = control
		if control != null:
			control.visible = true


var _scene_root: Node = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = EditorExecutorScript.new()
	var editor_interface := FakeEditorInterface.new()
	var editor_plugin := FakeEditorPlugin.new(editor_interface)
	_ensure_editor_plugin_fixture()
	_scene_root = _build_scene_fixture(tree)
	var popup_root := FakePopupNode.new("SearchDialog", "PopupMenu")
	popup_root.title = "Search"
	popup_root.add_menu_item("Rename", 101)
	popup_root.add_menu_item("Disabled", 102, true)
	popup_root.add_menu_item("", 103, false, true)
	popup_root.add_menu_item("Delete", 104)
	popup_root.add_menu_item("More", 105, false, false, "MoreMenu")
	var popup_button := FakePopupNode.new("ConfirmButton", "Button")
	popup_button.text = "Confirm"
	var popup_input := FakePopupNode.new("SearchInput", "LineEdit")
	popup_input.text = "OldValue"
	var hidden_popup_root := FakePopupNode.new("HiddenDialog", "PopupMenu")
	hidden_popup_root.visible = false
	hidden_popup_root.add_menu_item("Hidden Rename", 201)
	var hidden_popup_button := FakePopupNode.new("HiddenButton", "Button")
	hidden_popup_root.add_child(hidden_popup_button)
	var non_popup_button := FakePopupNode.new("ToolbarButton", "Button")
	var non_popup_input := FakePopupNode.new("ToolbarInput", "LineEdit")
	non_popup_input.text = "ToolbarOld"
	var search_panel := FakeUiControl.new("SearchPanel", "PanelContainer", Rect2(16, 16, 200, 72))
	var search_field := FakeUiControl.new("SearchField", "LineEdit", Rect2(24, 24, 160, 24))
	search_field.text = "InitialQuery"
	var refresh_button := FakeUiControl.new("RefreshButton", "Button", Rect2(24, 56, 96, 24))
	refresh_button.text = "Refresh"
	var project_menu := FakeMenuButton.new("ProjectMenu", "Project", Rect2(0, 0, 96, 24))
	project_menu.get_popup().add_item("Project Settings...", 101)
	project_menu.get_popup().add_item("Export...", 102)
	project_menu.get_popup().add_item("Disabled Item", 103, true)
	project_menu.get_popup().add_item("---", 104, false, true)
	project_menu.get_popup().add_item("More Tools", 105, false, false, "MoreTools")
	var editor_top_bar := FakeUiControl.new("EditorTopBar", "HBoxContainer", Rect2(16, 88, 220, 28))
	var ordinary_top_bar_button := FakeUiControl.new("OrdinaryTopBarButton", "Button", Rect2(24, 92, 128, 24))
	ordinary_top_bar_button.text = "Ordinary Action"
	editor_top_bar.add_child(ordinary_top_bar_button)
	var ordinary_script_button := FakeUiControl.new("OrdinaryScriptButton", "Button", Rect2(24, 124, 128, 24))
	ordinary_script_button.text = "Script"
	ordinary_script_button.pressed = true
	editor_top_bar.add_child(ordinary_script_button)
	var main_screen_bar := FakeUiControl.new("MainScreenBar", "HBoxContainer", Rect2(360, 8, 320, 40))
	var main_screen_group := RefCounted.new()
	for builtin_screen in ["2D", "3D", "Script", "AssetLib"]:
		var builtin_button := FakeUiControl.new("%sButton" % builtin_screen, "Button", Rect2(360, 8, 56, 24))
		builtin_button.text = builtin_screen
		builtin_button.set_button_group(main_screen_group)
		builtin_button.pressed = builtin_screen == "2D"
		editor_interface.register_main_screen_button(builtin_screen, builtin_button)
		main_screen_bar.add_child(builtin_button)
	var stray_toolbar_button := FakeUiControl.new("RunProjectButton", "Button", Rect2(584, 8, 72, 24))
	stray_toolbar_button.text = "Run Project"
	main_screen_bar.add_child(stray_toolbar_button)
	var godex_button := FakeUiControl.new("GodexButton", "Button", Rect2(520, 96, 72, 24))
	godex_button.text = "Godex"
	godex_button.set_button_group(main_screen_group)
	editor_interface.register_main_screen_button("Godex", godex_button)
	main_screen_bar.add_child(godex_button)
	var mcp_dock := FakeUiControl.new("MCP", "VBoxContainer", Rect2(220, 16, 200, 160))
	var diagnostic_plugin_button := FakeUiControl.new("DiagnosticPluginButton", "Button", Rect2(460, 16, 160, 24))
	diagnostic_plugin_button.text = "Diagnostic Plugin"
	var mcp_tabs := FakeTabContainer.new("TabContainer", Rect2(220, 16, 200, 160))
	var server_tab := FakeUiControl.new("ServerTab", "VBoxContainer", Rect2(220, 48, 200, 128))
	var tools_tab := FakeUiControl.new("ToolsTab", "VBoxContainer", Rect2(220, 48, 200, 128))
	var config_tab := FakeUiControl.new("ConfigTab", "VBoxContainer", Rect2(220, 48, 200, 128))
	var output_panel := FakeUiControl.new("Output", "PanelContainer", Rect2(16, 120, 240, 80))
	output_panel.title = "Output"
	output_panel.visible = false
	mcp_tabs.add_tab(server_tab, "主页")
	mcp_tabs.add_tab(tools_tab, "工具")
	mcp_tabs.add_tab(config_tab, "配置")
	mcp_dock.add_child(mcp_tabs)
	search_panel.add_child(search_field)
	search_panel.add_child(refresh_button)
	popup_root.add_child(popup_button)
	popup_root.add_child(popup_input)
	editor_interface.get_base_control().add_popup_child(popup_root)
	editor_interface.get_base_control().add_popup_child(hidden_popup_root)
	editor_interface.get_base_control().add_popup_child(non_popup_button)
	editor_interface.get_base_control().add_popup_child(non_popup_input)
	editor_interface.get_base_control().add_popup_child(project_menu)
	editor_interface.get_base_control().add_popup_child(editor_top_bar)
	editor_interface.get_base_control().add_popup_child(main_screen_bar)
	editor_interface.get_base_control().add_popup_child(search_panel)
	editor_interface.get_base_control().add_popup_child(mcp_dock)
	editor_interface.get_base_control().add_popup_child(diagnostic_plugin_button)
	editor_interface.get_base_control().add_popup_child(output_panel)
	editor_interface._edited_scene_root = _scene_root
	editor_interface.get_base_control().get_viewport().focus_owner = FakeFocusOwner.new()
	editor_interface.get_selection()._nodes = [_scene_root.get_node("Target")]
	editor_interface.get_inspector().edited_object = _scene_root.get_node("Target")
	executor.configure_context({
		"editor_interface": editor_interface,
		"plugin_host": editor_plugin,
		"undo_redo": editor_interface.get_editor_undo_redo(),
		"scene_root": _scene_root,
	})

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 10:
		return _failure("Editor executor should expose 10 tool definitions after UI control is added.")

	var expected_names := ["status", "screenshot", "settings", "undo_redo", "notification", "ui_control", "popup", "inspector", "filesystem", "plugin"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Editor executor is missing tool definition '%s'." % expected_name)

	var set_screen_result: Dictionary = executor.execute("status", {"action": "set_main_screen", "screen": "Godex"})
	if not bool(set_screen_result.get("success", false)):
		return _failure("Editor status set_main_screen failed through the split service path.")
	if str(set_screen_result.get("data", {}).get("matched_main_screen", {}).get("name", "")) != "Godex":
		return _failure("Editor status set_main_screen should report the matched plugin main screen button.")
	if str(set_screen_result.get("data", {}).get("main_screen_container", "")) == "Godex":
		return _failure("Editor status set_main_screen should not depend on get_editor_main_screen() returning the selected screen name.")
	var get_screen_result: Dictionary = executor.execute("status", {"action": "get_main_screen"})
	if str(get_screen_result.get("data", {}).get("current_screen", "")) != "Godex":
		return _failure("Editor status get_main_screen did not reflect the updated screen.")
	if str(get_screen_result.get("data", {}).get("main_screen_container", "")) != "MainScreenContainer":
		return _failure("Editor status get_main_screen should report the stable editor main-screen container separately.")
	if not (get_screen_result.get("data", {}).get("available", []) as Array).has("Godex"):
		return _failure("Editor status get_main_screen should include discovered plugin main screens.")
	var lowercase_screen_result: Dictionary = executor.execute("status", {"action": "set_main_screen", "screen": "script"})
	if not bool(lowercase_screen_result.get("success", false)):
		return _failure("Editor status set_main_screen should match screen names case-insensitively.")
	if str(lowercase_screen_result.get("data", {}).get("after_screen", "")) != "Script":
		return _failure("Editor status set_main_screen should switch using the discovered screen label, not the raw input.")
	if str(lowercase_screen_result.get("data", {}).get("verification_source", "")) != "active_button_state":
		return _failure("Editor status set_main_screen should verify observable active button state when available.")
	var missing_screen_result: Dictionary = executor.execute("status", {"action": "set_main_screen", "screen": "NotARegisteredScreen"})
	if bool(missing_screen_result.get("success", false)):
		return _failure("Editor status set_main_screen should reject undiscovered screen names instead of using raw input.")
	var list_screens_result: Dictionary = executor.execute("status", {"action": "list_main_screens"})
	if not bool(list_screens_result.get("success", false)):
		return _failure("Editor status list_main_screens failed through the split service path.")
	if int(list_screens_result.get("data", {}).get("count", 0)) < 5:
		return _failure("Editor status list_main_screens should include builtin and plugin screens.")
	if (list_screens_result.get("data", {}).get("available", []) as Array).has("RunProjectButton"):
		return _failure("Editor status list_main_screens should not treat a toolbar control name as a main screen label.")
	if (list_screens_result.get("data", {}).get("available", []) as Array).has("Run Project"):
		return _failure("Editor status list_main_screens should not treat a toolbar control text as a main screen label.")
	if (list_screens_result.get("data", {}).get("available", []) as Array).has("Ordinary Action"):
		return _failure("Editor status list_main_screens should not treat ordinary top bar buttons as main screen labels.")
	var listed_main_screens: Array = list_screens_result.get("data", {}).get("main_screens", [])
	for listed_screen in listed_main_screens:
		if listed_screen is Dictionary and str((listed_screen as Dictionary).get("control_path", "")).find("OrdinaryScriptButton") != -1:
			return _failure("Editor status list_main_screens should ignore ordinary buttons whose text matches a built-in screen name.")

	var path_result: Dictionary = executor.execute("status", {"action": "get_godot_path"})
	if not bool(path_result.get("success", false)):
		return _failure("Editor status get_godot_path failed through the split service path.")
	var executable_path := str(path_result.get("data", {}).get("godot_executable_path", ""))
	var project_root := str(path_result.get("data", {}).get("project_root_path", ""))
	if executable_path.is_empty() or project_root.is_empty():
		return _failure("Editor status get_godot_path returned empty paths.")
	var executable_name := executable_path.get_file().to_lower()
	if executable_name.find("godot") == -1 or not executable_name.ends_with(".exe"):
		return _failure("Editor status get_godot_path returned an unexpected executable path.")
	var session_identity: Dictionary = path_result.get("data", {}).get("editor_session_identity", {})
	if str(session_identity.get("session_id", "")).is_empty():
		return _failure("Editor status get_godot_path should include a stable editor session id.")
	if int(session_identity.get("pid", 0)) <= 0:
		return _failure("Editor status get_godot_path should include the current editor process id.")
	if bool(session_identity.get("safe_to_terminate", true)) or bool(session_identity.get("external_validation_process", true)):
		return _failure("Editor session identity must mark the current MCP editor process as non-terminable and non-external.")

	var focus_context_result: Dictionary = executor.execute("status", {"action": "get_focus_context"})
	if not bool(focus_context_result.get("success", false)):
		return _failure("Editor status get_focus_context failed through the split service path.")
	if str(focus_context_result.get("data", {}).get("focus_owner_name", "")) != "InspectorSearch":
		return _failure("Editor status get_focus_context returned an unexpected focus owner.")
	if int(focus_context_result.get("data", {}).get("selected_node_count", 0)) != 1:
		return _failure("Editor status get_focus_context should report one selected scene node.")

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

	var search_field_path := str(search_field.get_path())
	var refresh_button_path := str(refresh_button.get_path())
	var list_controls_result: Dictionary = executor.execute("ui_control", {
		"action": "list_visible",
		"class_name": "LineEdit"
	})
	if not bool(list_controls_result.get("success", false)):
		return _failure("Editor ui_control list_visible failed through the split service path.")
	if int(list_controls_result.get("data", {}).get("count", 0)) < 1:
		return _failure("Editor ui_control list_visible should return at least one visible LineEdit.")

	var get_control_result: Dictionary = executor.execute("ui_control", {
		"action": "get_control",
		"target_path": search_field_path
	})
	if not bool(get_control_result.get("success", false)):
		return _failure("Editor ui_control get_control failed through the split service path.")
	if str(get_control_result.get("data", {}).get("control", {}).get("class", "")) != "LineEdit":
		return _failure("Editor ui_control get_control should preserve the control class.")

	var focus_control_result: Dictionary = executor.execute("ui_control", {
		"action": "focus_control",
		"target_path": search_field_path
	})
	if not bool(focus_control_result.get("success", false)):
		return _failure("Editor ui_control focus_control failed through the split service path.")
	if not bool(search_field.focused):
		return _failure("Editor ui_control focus_control should grab focus on the target control.")

	var set_text_result: Dictionary = executor.execute("ui_control", {
		"action": "set_text",
		"target_path": search_field_path,
		"text": "Player"
	})
	if not bool(set_text_result.get("success", false)):
		return _failure("Editor ui_control set_text failed through the split service path.")
	if search_field.text != "Player":
		return _failure("Editor ui_control set_text should update the target control text.")

	var activate_control_result: Dictionary = executor.execute("ui_control", {
		"action": "activate_control",
		"target_path": refresh_button_path
	})
	if not bool(activate_control_result.get("success", false)):
		return _failure("Editor ui_control activate_control failed through the split service path.")
	if not bool(refresh_button.pressed):
		return _failure("Editor ui_control activate_control should activate the target control.")

	var capture_control_result: Dictionary = executor.execute("ui_control", {
		"action": "capture_control",
		"target_path": search_field_path,
		"path": "user://editor_executor_control_capture.png"
	})
	if not bool(capture_control_result.get("success", false)):
		return _failure("Editor ui_control capture_control failed through the split service path.")
	var control_capture_path := ProjectSettings.globalize_path(str(capture_control_result.get("data", {}).get("path", "")))
	if not FileAccess.file_exists(control_capture_path):
		return _failure("Editor ui_control capture_control did not create the cropped PNG file.")
	if not str(capture_control_result.get("data", {}).get("path", "")).begins_with("user://godot_dotnet_mcp/captures/editor_controls/"):
		return _failure("Editor ui_control capture_control should normalize root-level user:// PNG paths into the managed control capture directory.")
	var coordinate_mapping: Dictionary = capture_control_result.get("data", {}).get("control", {}).get("coordinate_mapping", {})
	if coordinate_mapping.is_empty() or not coordinate_mapping.has("os_window_rect"):
		return _failure("Editor ui_control capture_control should expose coordinate mapping with OS window rect information.")

	var click_control_result: Dictionary = executor.execute("ui_control", {
		"action": "click_control",
		"target_path": search_field_path,
		"local_x": 8,
		"local_y": 6
	})
	if not bool(click_control_result.get("success", false)):
		return _failure("Editor ui_control click_control failed through the split service path.")
	var right_click_control_result: Dictionary = executor.execute("ui_control", {
		"action": "right_click_control",
		"target_path": search_field_path,
		"local_x": 9,
		"local_y": 7
	})
	if not bool(right_click_control_result.get("success", false)):
		return _failure("Editor ui_control right_click_control failed through the split service path.")
	var pushed_events: Array = editor_interface.get_base_control().get_viewport().pushed_events
	if pushed_events.size() != 4:
		return _failure("Editor ui_control click actions should dispatch press/release input events.")
	if int(pushed_events[0].button_index) != MOUSE_BUTTON_LEFT or not bool(pushed_events[0].pressed):
		return _failure("Editor ui_control click_control should dispatch a left-button press first.")
	if int(pushed_events[2].button_index) != MOUSE_BUTTON_RIGHT or not bool(pushed_events[2].pressed):
		return _failure("Editor ui_control right_click_control should dispatch a right-button press first.")
	if Vector2(pushed_events[0].position) != Vector2(32, 30):
		return _failure("Editor ui_control click_control should convert local coordinates to viewport coordinates.")

	var tab_container_path := str(mcp_tabs.get_path())
	var activate_tab_result: Dictionary = executor.execute("ui_control", {
		"action": "activate_ui",
		"target_path": tab_container_path,
		"tab_title": "ConfigTab",
		"path": "user://editor_executor_activate_tab.png"
	})
	if not bool(activate_tab_result.get("success", false)):
		return _failure("Editor ui_control activate_ui should switch a TabContainer by child tab title.")
	if mcp_tabs.current_tab != 2 or not config_tab.visible or server_tab.visible:
		return _failure("Editor ui_control activate_ui should set current_tab and update visible tab content.")
	if str(activate_tab_result.get("data", {}).get("active_path", "")) != str(config_tab.get_path()):
		return _failure("Editor ui_control activate_ui should return the active tab control path.")
	var activate_tab_capture_path := ProjectSettings.globalize_path(str(activate_tab_result.get("data", {}).get("capture", {}).get("path", "")))
	if not FileAccess.file_exists(activate_tab_capture_path):
		return _failure("Editor ui_control activate_ui should capture the activated tab when path is provided.")
	if not str(activate_tab_result.get("data", {}).get("capture", {}).get("path", "")).begins_with("user://godot_dotnet_mcp/captures/editor_controls/"):
		return _failure("Editor ui_control activate_ui should normalize root-level user:// PNG paths into the managed control capture directory.")

	var activate_semantic_result: Dictionary = executor.execute("ui_control", {
		"action": "activate_ui",
		"semantic_path": "MCPDock/tools"
	})
	if not bool(activate_semantic_result.get("success", false)):
		return _failure("Editor ui_control activate_ui should support MCPDock/tools semantic path.")
	if mcp_tabs.current_tab != 1 or not tools_tab.visible or config_tab.visible:
		return _failure("Editor ui_control activate_ui semantic path should switch to the requested MCPDock tab.")
	if str(activate_semantic_result.get("data", {}).get("semantic_path", "")) != "MCPDock/tools":
		return _failure("Editor ui_control activate_ui should return the semantic path it activated.")
	var activate_short_semantic_result: Dictionary = executor.execute("ui_control", {
		"action": "activate_ui",
		"semantic_path": "MCP/config"
	})
	if not bool(activate_short_semantic_result.get("success", false)):
		return _failure("Editor ui_control activate_ui should support MCP/config semantic path.")
	if mcp_tabs.current_tab != 2 or not config_tab.visible or tools_tab.visible:
		return _failure("Editor ui_control activate_ui MCP semantic path should switch to the requested tab.")

	var list_menus_result: Dictionary = executor.execute("ui_control", {
		"action": "list_menus",
		"text_query": "Project"
	})
	if not bool(list_menus_result.get("success", false)):
		return _failure("Editor ui_control list_menus failed through the split service path.")
	if int(list_menus_result.get("data", {}).get("count", 0)) != 1:
		return _failure("Editor ui_control list_menus should return the visible Project menu.")
	var listed_menu: Dictionary = list_menus_result.get("data", {}).get("menus", [{}])[0]
	if int(listed_menu.get("item_count", 0)) != 5:
		return _failure("Editor ui_control list_menus should expose PopupMenu item metadata.")
	var listed_menu_items: Array = listed_menu.get("items", [])
	if listed_menu_items.size() < 5 or not bool((listed_menu_items[4] as Dictionary).get("has_submenu", false)):
		return _failure("Editor ui_control list_menus should expose submenu item metadata.")

	var open_menu_result: Dictionary = executor.execute("ui_control", {
		"action": "open_menu",
		"menu_title": "Project"
	})
	if not bool(open_menu_result.get("success", false)):
		return _failure("Editor ui_control open_menu should open a MenuButton by title.")
	if not bool(project_menu.get_popup().visible):
		return _failure("Editor ui_control open_menu should make the MenuButton popup visible.")

	var select_menu_result: Dictionary = executor.execute("ui_control", {
		"action": "select_menu_item",
		"target_path": str(project_menu.get_path()),
		"item_text": "Project Settings..."
	})
	if not bool(select_menu_result.get("success", false)):
		return _failure("Editor ui_control select_menu_item should select a PopupMenu item by text.")
	if int(project_menu.get_popup().activated_index) != 0:
		return _failure("Editor ui_control select_menu_item should activate the matched PopupMenu item index.")
	var disabled_menu_result: Dictionary = executor.execute("ui_control", {
		"action": "select_menu_item",
		"menu_title": "Project",
		"item_text": "Disabled Item"
	})
	if bool(disabled_menu_result.get("success", false)):
		return _failure("Editor ui_control select_menu_item should reject disabled PopupMenu items.")
	var separator_menu_result: Dictionary = executor.execute("ui_control", {
		"action": "select_menu_item",
		"menu_title": "Project",
		"item_text": "---"
	})
	if bool(separator_menu_result.get("success", false)):
		return _failure("Editor ui_control select_menu_item should reject separator PopupMenu items.")
	var submenu_menu_result: Dictionary = executor.execute("ui_control", {
		"action": "select_menu_item",
		"menu_title": "Project",
		"item_text": "More Tools"
	})
	if bool(submenu_menu_result.get("success", false)) or int(project_menu.get_popup().activated_index) != 0:
		return _failure("Editor ui_control select_menu_item should reject submenu PopupMenu items without activating them.")

	var activate_bottom_result: Dictionary = executor.execute("ui_control", {
		"action": "activate_ui",
		"bottom_panel_title": "Output",
		"path": "user://editor_executor_bottom_panel.png"
	})
	if not bool(activate_bottom_result.get("success", false)):
		return _failure("Editor ui_control activate_ui should support bottom panel activation by title.")
	if editor_plugin.visible_bottom_panel != output_panel or not output_panel.visible:
		return _failure("Editor ui_control activate_ui should call make_bottom_panel_item_visible on the requested panel.")
	if str(activate_bottom_result.get("data", {}).get("active_path", "")) != str(output_panel.get_path()):
		return _failure("Editor ui_control activate_ui should return the active bottom panel path.")
	var bottom_capture_path := ProjectSettings.globalize_path(str(activate_bottom_result.get("data", {}).get("capture", {}).get("path", "")))
	if not FileAccess.file_exists(bottom_capture_path):
		return _failure("Editor ui_control activate_ui should capture the activated bottom panel when path is provided.")
	if not str(activate_bottom_result.get("data", {}).get("capture", {}).get("path", "")).begins_with("user://godot_dotnet_mcp/captures/editor_controls/"):
		return _failure("Editor ui_control activate_ui should normalize bottom panel captures into the managed control capture directory.")

	var popup_list_result: Dictionary = executor.execute("popup", {"action": "list_visible"})
	if not bool(popup_list_result.get("success", false)):
		return _failure("Editor popup list_visible failed through the split service path.")
	if int(popup_list_result.get("data", {}).get("count", 0)) != 1:
		return _failure("Editor popup list_visible should report one visible popup root.")
	var popup_summary: Dictionary = popup_list_result.get("data", {}).get("popups", [{}])[0]
	if str(popup_summary.get("parent_path", "")).is_empty() or not popup_summary.has("rect"):
		return _failure("Editor popup list_visible should expose popup parent_path and rect metadata.")
	if str(popup_summary.get("text", "")) != "":
		return _failure("Editor popup list_visible should expose popup text separately from title.")
	var popup_items: Array = popup_summary.get("items", [])
	if popup_items.size() != 5 or str(popup_items[0].get("text", "")) != "Rename":
		return _failure("Editor popup list_visible should expose PopupMenu item metadata.")
	if not bool((popup_items[4] as Dictionary).get("has_submenu", false)) or str((popup_items[4] as Dictionary).get("submenu", "")) != "MoreMenu":
		return _failure("Editor popup list_visible should mark PopupMenu submenu rows.")
	var popup_root_path := str(popup_list_result.get("data", {}).get("popups", [{}])[0].get("node_path", ""))
	var popup_button_path := "%s/ConfirmButton" % popup_root_path
	var popup_input_path := "%s/SearchInput" % popup_root_path

	var popup_select_by_text_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"text": "Rename"
	})
	if not bool(popup_select_by_text_result.get("success", false)):
		return _failure("Editor popup select_item should select a visible PopupMenu item by exact text.")
	if popup_root.selected_index != 0 or int(popup_select_by_text_result.get("data", {}).get("selected_item", {}).get("id", -1)) != 101:
		return _failure("Editor popup select_item should activate and return the selected item metadata.")

	var popup_select_by_id_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"id": 104
	})
	if not bool(popup_select_by_id_result.get("success", false)) or popup_root.selected_index != 3:
		return _failure("Editor popup select_item should select a visible PopupMenu item by id.")

	var popup_select_conflict_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"index": 0,
		"id": 104
	})
	if bool(popup_select_conflict_result.get("success", false)) or popup_root.selected_index != 3:
		return _failure("Editor popup select_item should reject conflicting item selectors without activating a new item.")
	var popup_select_empty_text_conflict_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"index": 0,
		"text": ""
	})
	if bool(popup_select_empty_text_conflict_result.get("success", false)) or popup_root.selected_index != 3:
		return _failure("Editor popup select_item should treat an empty text field as a conflicting selector when index is also provided.")
	var popup_select_id_text_conflict_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"id": 104,
		"text": "Rename"
	})
	if bool(popup_select_id_text_conflict_result.get("success", false)) or popup_root.selected_index != 3:
		return _failure("Editor popup select_item should reject id and text selectors when both are provided.")
	var popup_select_all_conflict_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"index": 0,
		"id": 104,
		"text": "Rename"
	})
	if bool(popup_select_all_conflict_result.get("success", false)) or popup_root.selected_index != 3:
		return _failure("Editor popup select_item should reject index, id, and text selectors when all are provided.")
	var popup_select_invalid_index_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"index": "0"
	})
	if bool(popup_select_invalid_index_result.get("success", false)) or popup_root.selected_index != 3:
		return _failure("Editor popup select_item should reject string index selectors instead of coercing them.")
	var popup_select_invalid_id_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"id": 104.5
	})
	if bool(popup_select_invalid_id_result.get("success", false)) or popup_root.selected_index != 3:
		return _failure("Editor popup select_item should reject fractional id selectors instead of coercing them.")

	var legacy_popup := FakeLegacyPopupMenu.new()
	executor._notification_tools._activate_popup_menu_item(legacy_popup, 2, {"id": -1})
	if legacy_popup.emitted_index != 2 or legacy_popup.emitted_id != 2:
		legacy_popup.dispose()
		return _failure("Editor popup select_item fallback should emit the item index for negative PopupMenu ids.")
	legacy_popup.dispose()

	var popup_select_disabled_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"index": 1
	})
	if bool(popup_select_disabled_result.get("success", false)):
		return _failure("Editor popup select_item should reject disabled PopupMenu items.")

	var popup_select_separator_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"index": 2
	})
	if bool(popup_select_separator_result.get("success", false)):
		return _failure("Editor popup select_item should reject PopupMenu separators.")

	var popup_select_submenu_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": popup_root_path,
		"index": 4
	})
	if bool(popup_select_submenu_result.get("success", false)) or popup_root.selected_index != 3 or not bool(popup_root.visible):
		return _failure("Editor popup select_item should reject submenu rows without activating or hiding the parent menu.")

	var hidden_popup_select_result: Dictionary = executor.execute("popup", {
		"action": "select_item",
		"target_path": str(hidden_popup_root.get_path()),
		"index": 0
	})
	if bool(hidden_popup_select_result.get("success", false)):
		return _failure("Editor popup select_item should reject hidden PopupMenu roots.")

	var popup_press_result: Dictionary = executor.execute("popup", {
		"action": "press_button",
		"target_path": popup_button_path
	})
	if not bool(popup_press_result.get("success", false)):
		return _failure("Editor popup press_button failed through the split service path.")
	if not bool(popup_button.pressed):
		return _failure("Editor popup press_button should activate the target button.")

	var popup_text_result: Dictionary = executor.execute("popup", {
		"action": "set_text",
		"target_path": popup_input_path,
		"text": "NewValue"
	})
	if not bool(popup_text_result.get("success", false)):
		return _failure("Editor popup set_text failed through the split service path.")
	if popup_input.text != "NewValue":
		return _failure("Editor popup set_text should update the popup input value.")

	var popup_close_result: Dictionary = executor.execute("popup", {
		"action": "close_popup",
		"target_path": popup_root_path
	})
	if not bool(popup_close_result.get("success", false)):
		return _failure("Editor popup close_popup failed through the split service path.")
	if popup_root.visible:
		return _failure("Editor popup close_popup should hide the popup root.")

	var hidden_popup_result: Dictionary = executor.execute("popup", {
		"action": "press_button",
		"target_path": str(hidden_popup_button.get_path())
	})
	if bool(hidden_popup_result.get("success", false)):
		return _failure("Editor popup press_button should reject targets inside hidden popup roots.")

	var non_popup_button_result: Dictionary = executor.execute("popup", {
		"action": "press_button",
		"target_path": str(non_popup_button.get_path())
	})
	if bool(non_popup_button_result.get("success", false)):
		return _failure("Editor popup press_button should reject targets outside popup roots.")

	var non_popup_input_result: Dictionary = executor.execute("popup", {
		"action": "set_text",
		"target_path": str(non_popup_input.get_path()),
		"text": "ToolbarNew"
	})
	if bool(non_popup_input_result.get("success", false)):
		return _failure("Editor popup set_text should reject targets outside popup roots.")

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

	var screenshot_result: Dictionary = executor.execute("screenshot", {
		"action": "capture",
		"path": "user://editor_executor_contract_screenshot.png"
	})
	if not bool(screenshot_result.get("success", false)):
		return _failure("Editor screenshot capture failed through the split service path.")
	var screenshot_data: Dictionary = screenshot_result.get("data", {})
	var screenshot_path := ProjectSettings.globalize_path(str(screenshot_data.get("path", "")))
	if not FileAccess.file_exists(screenshot_path):
		return _failure("Editor screenshot capture did not create the PNG file.")
	if not str(screenshot_data.get("path", "")).begins_with("user://godot_dotnet_mcp/captures/editor/"):
		return _failure("Editor screenshot capture should normalize root-level user:// PNG paths into the managed editor capture directory.")
	if int(screenshot_data.get("width", 0)) != 320 or int(screenshot_data.get("height", 0)) != 180:
		return _failure("Editor screenshot capture returned unexpected dimensions.")

	var region_screenshot_result: Dictionary = executor.execute("screenshot", {
		"action": "capture",
		"path": "user://editor_executor_contract_region.png",
		"x": 10,
		"y": 20,
		"width": 64,
		"height": 48
	})
	if not bool(region_screenshot_result.get("success", false)):
		return _failure("Editor screenshot region capture failed through the split service path.")
	var region_screenshot_data: Dictionary = region_screenshot_result.get("data", {})
	if str(region_screenshot_data.get("capture_mode", "")) != "region":
		return _failure("Editor screenshot region capture should report capture_mode=region.")
	if int(region_screenshot_data.get("width", 0)) != 64 or int(region_screenshot_data.get("height", 0)) != 48:
		return _failure("Editor screenshot region capture returned unexpected cropped dimensions.")

	var plugin_list_result: Dictionary = executor.execute("plugin", {"action": "list"})
	if not bool(plugin_list_result.get("success", false)):
		return _failure("Editor plugin list failed through the split service path.")
	var listed_plugins: Array = plugin_list_result.get("data", {}).get("plugins", [])
	if not _has_plugin_summary(listed_plugins, "diagnostic_plugin"):
		return _failure("Editor plugin list should include plugin.cfg metadata and diagnostics for fixture plugins.")

	var enable_plugin_result: Dictionary = executor.execute("plugin", {
		"action": "enable",
		"plugin": "diagnostic_plugin"
	})
	if not bool(enable_plugin_result.get("success", false)):
		return _failure("Editor plugin enable failed through the split service path.")
	var enable_plugin_data: Dictionary = enable_plugin_result.get("data", {})
	if not bool(enable_plugin_data.get("editor_enabled", false)) or not bool(enable_plugin_data.get("setting_enabled", false)):
		return _failure("Editor plugin enable should return editor-session and project-setting diagnostics.")
	if not bool(enable_plugin_data.get("main_screen_visible", false)):
		return _failure("Editor plugin diagnostics should detect visible plugin UI labels when present.")
	var plugin_state_result: Dictionary = executor.execute("plugin", {
		"action": "is_enabled",
		"plugin": "diagnostic_plugin"
	})
	if not bool(plugin_state_result.get("data", {}).get("enabled", false)):
		return _failure("Editor plugin is_enabled should report the enabled state after enable.")
	var missing_plugin_result: Dictionary = executor.execute("plugin", {
		"action": "inspect",
		"plugin": "missing_plugin"
	})
	if bool(missing_plugin_result.get("success", false)) or str(missing_plugin_result.get("data", {}).get("error_type", "")) != "plugin_not_found":
		return _failure("Editor plugin inspect should return a structured plugin_not_found error.")
	var self_disable_result: Dictionary = executor.execute("plugin", {
		"action": "disable",
		"plugin": "godot_dotnet_mcp"
	})
	if bool(self_disable_result.get("success", false)) or not bool(self_disable_result.get("data", {}).get("self_plugin", false)):
		return _failure("Editor plugin disable should refuse to toggle the active MCP plugin by default.")

	return {
		"name": "editor_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"godot_executable_path": executable_path,
			"project_root_path": project_root,
			"screenshot_path": screenshot_path,
			"control_capture_path": control_capture_path,
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


func _ensure_editor_plugin_fixture() -> void:
	var root_dir := DirAccess.open("res://")
	if root_dir != null:
		root_dir.make_dir_recursive("addons/diagnostic_plugin")
	var file := FileAccess.open("res://addons/diagnostic_plugin/plugin.cfg", FileAccess.WRITE)
	if file != null:
		file.store_string("[plugin]\nname=\"Diagnostic Plugin\"\ndescription=\"Fixture plugin for editor diagnostics.\"\nauthor=\"Harness\"\nversion=\"1.0.0\"\nscript=\"res://addons/diagnostic_plugin/plugin.gd\"\n")
		file.close()


func _has_plugin_summary(plugins: Array, plugin_name: String) -> bool:
	for plugin in plugins:
		if plugin is Dictionary and str((plugin as Dictionary).get("plugin", (plugin as Dictionary).get("name", ""))) == plugin_name:
			return (plugin as Dictionary).has("editor_enabled") and (plugin as Dictionary).has("setting_enabled")
	return false


func _failure(message: String) -> Dictionary:
	return {
		"name": "editor_tool_executor_contracts",
		"success": false,
		"error": message
	}
