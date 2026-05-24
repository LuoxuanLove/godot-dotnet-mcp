@tool
extends VBoxContainer

const SERVER_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/server_panel.tscn"
const TOOLS_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/tools_tab.tscn"
const CONFIG_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/config_panel.tscn"
const SETTINGS_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/settings_panel.tscn"
const TAB_SCENE_SCRIPT_PATHS := {
	SERVER_TAB_SCENE_PATH: "res://addons/godot_dotnet_mcp/ui/server_tab.gd",
	TOOLS_TAB_SCENE_PATH: "res://addons/godot_dotnet_mcp/ui/tools_tab.gd",
	CONFIG_TAB_SCENE_PATH: "res://addons/godot_dotnet_mcp/ui/config_tab.gd",
	SETTINGS_TAB_SCENE_PATH: [
		"res://addons/godot_dotnet_mcp/ui/settings_tab_model_projection.gd",
		"res://addons/godot_dotnet_mcp/ui/settings_tab.gd"
	]
}
const DOCK_TAB_ACTIVATION_RETRY_COUNT := 6

signal current_tab_changed(index: int)
signal port_changed(value: int)
signal log_level_changed(level: String)
signal language_changed(language_code: String)
signal update_source_changed(source: String)
signal update_custom_branch_changed(branch: String)
signal update_check_requested
signal update_apply_requested
signal start_requested
signal restart_requested
signal stop_requested
signal full_reload_requested
signal clear_self_diagnostics_requested
signal tool_toggled(tool_name: String, enabled: bool)
signal delete_user_tool_requested(script_path: String)
signal category_toggled(category: String, enabled: bool)
signal domain_toggled(domain_key: String, enabled: bool)
signal tree_collapse_changed(kind: String, key: String, collapsed: bool)
signal cli_scope_changed(scope: String)
signal config_platform_changed(platform_id: String)
signal config_client_action_requested(client_id: String)
signal config_client_launch_requested(client_id: String)
signal config_client_path_pick_requested(client_id: String)
signal config_client_path_clear_requested(client_id: String)
signal config_client_open_config_dir_requested(client_id: String)
signal config_client_open_config_file_requested(client_id: String)
signal config_write_requested(config_type: String, filepath: String, config: String, client_name: String)
signal config_remove_requested(config_type: String, filepath: String, client_name: String)
signal copy_requested(text: String, source: String)

@onready var _status_indicator: ColorRect = %StatusIndicator
@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _tab_container: TabContainer = %TabContainer
var _current_scale := -1.0
var _server_tab: Control
var _tools_tab: Control
var _config_tab: Control
var _settings_tab: Control
var _is_running := false
var _last_model: Dictionary = {}


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ensure_tabs()
	_tab_container.tab_changed.connect(_on_tab_changed)

	if _server_tab:
		_server_tab.start_requested.connect(_on_server_tab_start_requested)
		_server_tab.restart_requested.connect(_on_server_tab_restart_requested)
		_server_tab.stop_requested.connect(_on_server_tab_stop_requested)
		_server_tab.full_reload_requested.connect(_on_server_tab_full_reload_requested)
		if _server_tab.has_signal("clear_self_diagnostics_requested"):
			_server_tab.clear_self_diagnostics_requested.connect(_on_server_tab_clear_self_diagnostics_requested)
		if _server_tab.has_signal("copy_requested"):
			_server_tab.copy_requested.connect(_on_server_tab_copy_requested)

	if _tools_tab:
		if _tools_tab.has_signal("delete_user_tool_requested"):
			_tools_tab.connect("delete_user_tool_requested", _on_tools_tab_delete_user_tool_requested)
		_tools_tab.tool_toggled.connect(_on_tools_tab_tool_toggled)
		_tools_tab.category_toggled.connect(_on_tools_tab_category_toggled)
		_tools_tab.domain_toggled.connect(_on_tools_tab_domain_toggled)
		_tools_tab.tree_collapse_changed.connect(_on_tools_tab_tree_collapse_changed)

	if _config_tab:
		_config_tab.cli_scope_changed.connect(_on_config_tab_cli_scope_changed)
		_config_tab.config_platform_changed.connect(_on_config_tab_platform_changed)
		_config_tab.config_client_action_requested.connect(_on_config_tab_client_action_requested)
		_config_tab.config_client_launch_requested.connect(_on_config_tab_client_launch_requested)
		_config_tab.config_client_path_pick_requested.connect(_on_config_tab_client_path_pick_requested)
		_config_tab.config_client_path_clear_requested.connect(_on_config_tab_client_path_clear_requested)
		_config_tab.config_client_open_config_dir_requested.connect(_on_config_tab_client_open_config_dir_requested)
		_config_tab.config_client_open_config_file_requested.connect(_on_config_tab_client_open_config_file_requested)
		_config_tab.config_write_requested.connect(_on_config_tab_config_write_requested)
		_config_tab.config_remove_requested.connect(_on_config_tab_config_remove_requested)
		_config_tab.copy_requested.connect(_on_config_tab_copy_requested)

	if _settings_tab:
		_settings_tab.port_changed.connect(_on_settings_tab_port_changed)
		_settings_tab.log_level_changed.connect(_on_settings_tab_log_level_changed)
		_settings_tab.language_changed.connect(_on_settings_tab_language_changed)
		_settings_tab.update_source_changed.connect(_on_settings_tab_update_source_changed)
		_settings_tab.update_custom_branch_changed.connect(_on_settings_tab_update_custom_branch_changed)
		_settings_tab.update_check_requested.connect(_on_settings_tab_update_check_requested)
		_settings_tab.update_apply_requested.connect(_on_settings_tab_update_apply_requested)

func apply_model(model: Dictionary) -> void:
	if _status_indicator == null or _tab_container == null:
		return
	var localization = model.get("localization")
	if localization == null:
		return
	var is_running = bool(model.get("is_running", false))
	var editor_scale = float(model.get("editor_scale", 1.0))
	_is_running = is_running
	_last_model = model

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)

	_title_label.text = localization.get_text("title")
	_status_label.text = localization.get_text("status_running") if is_running else localization.get_text("status_stopped")
	_refresh_theme_colors()

	if _tab_container.get_tab_count() >= 4:
		_tab_container.set_tab_title(0, localization.get_text("tab_server"))
		_tab_container.set_tab_title(1, localization.get_text("tab_tools"))
		_tab_container.set_tab_title(2, localization.get_text("tab_config"))
		_tab_container.set_tab_title(3, localization.get_text("tab_settings"))

	var current_tab = int(model.get("current_tab", 0))
	if current_tab >= 0 and current_tab < _tab_container.get_tab_count():
		_tab_container.current_tab = current_tab
	_apply_all_tab_models(model)


func _apply_all_tab_models(model: Dictionary) -> void:
	for tab in [_server_tab, _tools_tab, _config_tab, _settings_tab]:
		if tab and tab.has_method("apply_model"):
			tab.apply_model(model)
	_normalize_settings_update_buttons()


func _normalize_settings_update_buttons() -> void:
	if _settings_tab == null:
		return
	var check_button := _settings_tab.find_child("CheckButton", true, false) as Button
	if check_button != null:
		check_button.text = ""
		check_button.visible = false
		check_button.disabled = true
	var prepare_button := _settings_tab.find_child("PrepareButton", true, false) as Button
	if prepare_button != null:
		prepare_button.text = ""
		prepare_button.visible = false
		prepare_button.disabled = true


func show_message(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func show_confirmation(title: String, message: String, on_confirmed: Callable) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func() -> void:
		if on_confirmed.is_valid():
			on_confirmed.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)


func get_current_tab() -> int:
	return _tab_container.current_tab


func capture_focus_snapshot() -> Dictionary:
	var snapshot := {
		"tab_index": _tab_container.current_tab,
		"focus_path": NodePath("")
	}
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null or not (focused is Control):
		return snapshot

	var current_tab_control = _tab_container.get_current_tab_control()
	if current_tab_control == null or not current_tab_control.is_ancestor_of(focused):
		return snapshot

	snapshot["focus_path"] = current_tab_control.get_path_to(focused)
	return snapshot


func restore_focus_snapshot(snapshot: Dictionary) -> void:
	if _tab_container == null:
		return
	var tab_index = int(snapshot.get("tab_index", _tab_container.current_tab))
	if tab_index >= 0 and tab_index < _tab_container.get_tab_count():
		_tab_container.current_tab = tab_index

	var raw_focus_path = snapshot.get("focus_path", "")
	var focus_path := NodePath(str(raw_focus_path))
	if str(raw_focus_path).is_empty():
		return

	var current_tab_control = _tab_container.get_current_tab_control()
	if current_tab_control == null or not current_tab_control.has_node(focus_path):
		return

	var target = current_tab_control.get_node(focus_path)
	if target is Control and _can_grab_focus(target as Control):
		(target as Control).grab_focus()


func activate_editor_dock_tab() -> void:
	call_deferred("_activate_editor_dock_tab_retry", 0)


func _ensure_tabs() -> void:
	for child in _tab_container.get_children():
		child.queue_free()

	_server_tab = _instantiate_tab(_load_packed_scene(SERVER_TAB_SCENE_PATH), "ServerTab")
	_tools_tab = _instantiate_tab(_load_packed_scene(TOOLS_TAB_SCENE_PATH), "ToolsTab")
	_config_tab = _instantiate_tab(_load_packed_scene(CONFIG_TAB_SCENE_PATH), "ConfigTab")
	_settings_tab = _instantiate_tab(_load_packed_scene(SETTINGS_TAB_SCENE_PATH), "SettingsTab")


func _instantiate_tab(scene: PackedScene, fallback_name: String) -> Control:
	if scene == null:
		push_error("[Godot MCP] Failed to load tab scene: %s" % fallback_name)
		return null
	var control = scene.instantiate() as Control
	if control == null:
		push_error("[Godot MCP] Failed to instantiate tab scene: %s" % fallback_name)
		return null
	control.name = fallback_name
	_tab_container.add_child(control)
	if not control.has_method("apply_model"):
		push_error("[Godot MCP] Tab controller %s does not implement apply_model()" % fallback_name)
	return control


func focus_active_panel() -> void:
	if _tab_container:
		var current = _tab_container.get_current_tab_control()
		if current and current is Control:
			var target = _find_focusable_descendant(current as Control)
			if target != null:
				target.grab_focus()


func _on_tab_changed(index: int) -> void:
	current_tab_changed.emit(index)
	if not _last_model.is_empty():
		_apply_all_tab_models(_last_model)


func _on_server_tab_start_requested() -> void:
	start_requested.emit()


func _on_server_tab_restart_requested() -> void:
	restart_requested.emit()


func _on_server_tab_stop_requested() -> void:
	stop_requested.emit()


func _on_server_tab_full_reload_requested() -> void:
	full_reload_requested.emit()


func _on_server_tab_clear_self_diagnostics_requested() -> void:
	clear_self_diagnostics_requested.emit()


func _on_server_tab_copy_requested(text: String, source: String) -> void:
	copy_requested.emit(text, source)


func _on_tools_tab_delete_user_tool_requested(script_path: String) -> void:
	delete_user_tool_requested.emit(script_path)


func _on_tools_tab_tool_toggled(tool_name: String, enabled: bool) -> void:
	tool_toggled.emit(tool_name, enabled)


func _on_tools_tab_category_toggled(category: String, enabled: bool) -> void:
	category_toggled.emit(category, enabled)


func _on_tools_tab_domain_toggled(domain_key: String, enabled: bool) -> void:
	domain_toggled.emit(domain_key, enabled)


func _on_tools_tab_tree_collapse_changed(kind: String, key: String, collapsed: bool) -> void:
	tree_collapse_changed.emit(kind, key, collapsed)


func _on_config_tab_cli_scope_changed(scope: String) -> void:
	cli_scope_changed.emit(scope)


func _on_config_tab_platform_changed(platform_id: String) -> void:
	config_platform_changed.emit(platform_id)


func _on_config_tab_client_action_requested(client_id: String) -> void:
	config_client_action_requested.emit(client_id)


func _on_config_tab_client_launch_requested(client_id: String) -> void:
	config_client_launch_requested.emit(client_id)


func _on_config_tab_client_path_pick_requested(client_id: String) -> void:
	config_client_path_pick_requested.emit(client_id)


func _on_config_tab_client_path_clear_requested(client_id: String) -> void:
	config_client_path_clear_requested.emit(client_id)


func _on_config_tab_client_open_config_dir_requested(client_id: String) -> void:
	config_client_open_config_dir_requested.emit(client_id)


func _on_config_tab_client_open_config_file_requested(client_id: String) -> void:
	config_client_open_config_file_requested.emit(client_id)


func _on_config_tab_config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	config_write_requested.emit(config_type, filepath, config, client_name)


func _on_config_tab_config_remove_requested(config_type: String, filepath: String, client_name: String) -> void:
	config_remove_requested.emit(config_type, filepath, client_name)


func _on_config_tab_copy_requested(text: String, source: String) -> void:
	copy_requested.emit(text, source)


func _on_settings_tab_port_changed(value: int) -> void:
	port_changed.emit(value)


func _on_settings_tab_log_level_changed(level: String) -> void:
	log_level_changed.emit(level)


func _on_settings_tab_language_changed(language_code: String) -> void:
	language_changed.emit(language_code)


func _on_settings_tab_update_source_changed(source: String) -> void:
	update_source_changed.emit(source)


func _on_settings_tab_update_custom_branch_changed(branch: String) -> void:
	update_custom_branch_changed.emit(branch)


func _on_settings_tab_update_check_requested() -> void:
	update_check_requested.emit()


func _on_settings_tab_update_apply_requested() -> void:
	update_apply_requested.emit()


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale
	custom_minimum_size = Vector2(280, 400) * scale
	add_theme_constant_override("separation", int(round(6 * scale)))

	var header = get_node_or_null("Header") as PanelContainer
	if header == null or _status_indicator == null or _title_label == null or _status_label == null:
		return
	header.custom_minimum_size.y = 48.0 * scale
	header.remove_theme_stylebox_override("panel")

	var header_margin = get_node_or_null("Header/HeaderMargin") as MarginContainer
	if header_margin == null:
		return
	header_margin.add_theme_constant_override("margin_left", int(round(14 * scale)))
	header_margin.add_theme_constant_override("margin_right", int(round(14 * scale)))
	header_margin.add_theme_constant_override("margin_top", int(round(8 * scale)))
	header_margin.add_theme_constant_override("margin_bottom", int(round(8 * scale)))

	var header_content = get_node_or_null("Header/HeaderMargin/HeaderContent") as HBoxContainer
	if header_content == null:
		return
	header_content.add_theme_constant_override("separation", int(round(8 * scale)))

	_status_indicator.custom_minimum_size = Vector2(10, 10) * scale
	_title_label.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	_title_label.remove_theme_font_size_override("font_size")
	_status_label.remove_theme_font_size_override("font_size")
	_refresh_theme_colors()


func _refresh_theme_colors() -> void:
	if _title_label == null or _status_label == null:
		return
	var color := _get_status_color(_is_running)
	_title_label.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	_status_label.add_theme_color_override("font_color", color)
	if _status_indicator != null:
		_status_indicator.color = color


func _get_status_color(is_running: bool) -> Color:
	if is_running:
		return get_theme_color("accent_color", "Editor")
	return get_theme_color("error_color", "Editor")


func _load_packed_scene(path: String) -> PackedScene:
	_reload_scene_script(path)
	var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	return scene as PackedScene


func _reload_scene_script(scene_path: String) -> void:
	var raw_script_paths = TAB_SCENE_SCRIPT_PATHS.get(scene_path, "")
	var script_paths := _normalize_reload_script_paths(raw_script_paths)
	if script_paths.is_empty():
		return
	for script_path in script_paths:
		var script = ResourceLoader.load(script_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
		if script is Script:
			(script as Script).reload(false)


func _normalize_reload_script_paths(raw_script_paths) -> Array[String]:
	var script_paths: Array[String] = []
	if raw_script_paths is Array:
		for raw_script_path in raw_script_paths:
			var script_path := str(raw_script_path).strip_edges()
			if not script_path.is_empty():
				script_paths.append(script_path)
	else:
		var script_path := str(raw_script_paths).strip_edges()
		if not script_path.is_empty():
			script_paths.append(script_path)
	return script_paths


func _find_focusable_descendant(root: Control) -> Control:
	if _can_grab_focus(root):
		return root

	for child in root.get_children():
		if child is Control:
			var result = _find_focusable_descendant(child as Control)
			if result != null:
				return result

	return null


func _can_grab_focus(control: Control) -> bool:
	return control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree()


func _activate_editor_dock_tab_retry(attempt: int) -> void:
	_activate_editor_dock_tab_deferred()
	if attempt >= DOCK_TAB_ACTIVATION_RETRY_COUNT:
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.process_frame
	if not is_instance_valid(self):
		return
	_activate_editor_dock_tab_retry(attempt + 1)


func _activate_editor_dock_tab_deferred() -> void:
	var current: Node = self
	while current != null:
		if current.has_method("make_visible"):
			current.call("make_visible")
			return
		var parent = current.get_parent()
		if parent is TabContainer:
			var tab_container := parent as TabContainer
			for index in range(tab_container.get_tab_count()):
				if tab_container.get_tab_control(index) == current:
					tab_container.current_tab = index
					return
		current = parent
