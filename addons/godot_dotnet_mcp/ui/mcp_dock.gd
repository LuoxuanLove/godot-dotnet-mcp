@tool
extends VBoxContainer

const SERVER_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/server_panel.tscn"
const TOOLS_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/tools_tab.tscn"
const MCP_CATALOG_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/mcp_catalog_tab.tscn"
const CONFIG_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/config_panel.tscn"
const SETTINGS_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/settings_panel.tscn"
const DOCK_TAB_ACTIVATION_RETRY_COUNT := 6
const TAB_SERVER := 0
const TAB_TOOLS := 1
const TAB_RESOURCES := 2
const TAB_PROMPTS := 3
const TAB_CONFIG := 4
const TAB_SETTINGS := 5
const TAB_COUNT := 6

signal current_tab_changed(index: int)
signal port_changed(value: int)
signal log_level_changed(level: String)
signal language_changed(language_code: String)
signal update_source_changed(source: String)
signal update_custom_branch_changed(branch: String)
signal update_interaction_refresh_requested
signal update_check_requested
signal update_apply_requested
signal update_switch_requested(kind: String, target_ref: String, target_commit: String)
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
signal mcp_catalog_preview_requested(kind: String, id: String, arguments: Dictionary)
signal copy_requested(text: String, source: String)

@onready var _status_indicator: ColorRect = %StatusIndicator
@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _tab_container: TabContainer = %TabContainer
var _current_scale := -1.0
var _server_tab: Control
var _tools_tab: Control
var _resources_tab: Control
var _prompts_tab: Control
var _config_tab: Control
var _settings_tab: Control
var _is_running := false
var _last_model: Dictionary = {}
var _suppress_tab_changed := false


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ensure_tabs()
	_tab_container.tab_changed.connect(_on_tab_changed)
	_connect_server_tab()

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

	_apply_tab_titles(model)

	var current_tab = int(model.get("current_tab", 0))
	if current_tab >= 0 and current_tab < _tab_container.get_tab_count():
		_ensure_tab_instance(current_tab)
		_tab_container.current_tab = current_tab
	_apply_visible_tab_models(model)


func _apply_visible_tab_models(model: Dictionary) -> void:
	_apply_tab_model(_server_tab, model)
	var current_index := _tab_container.current_tab if _tab_container != null else int(model.get("current_tab", 0))
	var current_tab := _get_tab_for_index(current_index, true)
	if current_tab != _server_tab:
		_apply_tab_model(current_tab, model)
	if current_index == TAB_SETTINGS:
		_normalize_settings_update_buttons()


func _apply_tab_model(tab: Control, model: Dictionary) -> void:
	if tab != null and tab.has_method("apply_model"):
		tab.apply_model(model)


func _get_tab_for_index(index: int, instantiate: bool = false) -> Control:
	if instantiate:
		return _ensure_tab_instance(index)
	match index:
		TAB_SERVER:
			return _server_tab
		TAB_TOOLS:
			return _tools_tab
		TAB_RESOURCES:
			return _resources_tab
		TAB_PROMPTS:
			return _prompts_tab
		TAB_CONFIG:
			return _config_tab
		TAB_SETTINGS:
			return _settings_tab
		_:
			return null


func _normalize_settings_update_buttons() -> void:
	if _settings_tab == null:
		return
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

	_server_tab = null
	_tools_tab = null
	_resources_tab = null
	_prompts_tab = null
	_config_tab = null
	_settings_tab = null
	_server_tab = _instantiate_tab(_load_packed_scene(SERVER_TAB_SCENE_PATH), "ServerTab", TAB_SERVER)
	for index in range(TAB_TOOLS, TAB_COUNT):
		_create_tab_placeholder(index)


func _create_tab_placeholder(index: int) -> Control:
	var placeholder := Control.new()
	placeholder.name = _get_tab_name(index)
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(placeholder)
	_tab_container.move_child(placeholder, index)
	return placeholder


func _ensure_tab_instance(index: int) -> Control:
	var current := _get_tab_for_index(index)
	if current != null and is_instance_valid(current):
		return current
	var scene_path := _get_tab_scene_path(index)
	if scene_path.is_empty():
		return null
	var tab := _instantiate_tab(_load_packed_scene(scene_path), _get_tab_name(index), index)
	if tab == null:
		return null
	if index == TAB_RESOURCES and tab.has_method("set_catalog_mode"):
		tab.set_catalog_mode("resources")
	elif index == TAB_PROMPTS and tab.has_method("set_catalog_mode"):
		tab.set_catalog_mode("prompts")
	_connect_tab_signals(index)
	if not _last_model.is_empty():
		_apply_tab_titles(_last_model)
	return tab


func _instantiate_tab(scene: PackedScene, fallback_name: String, index: int) -> Control:
	if scene == null:
		push_error("[Godot MCP] Failed to load tab scene: %s" % fallback_name)
		return null
	var previous_suppress := _suppress_tab_changed
	_suppress_tab_changed = true
	var existing_title := ""
	var replacing_current := false
	if index >= 0 and index < _tab_container.get_tab_count():
		existing_title = _tab_container.get_tab_title(index)
		replacing_current = _tab_container.current_tab == index
		var existing := _tab_container.get_tab_control(index)
		if existing != null:
			_tab_container.remove_child(existing)
			existing.queue_free()
	var control = scene.instantiate() as Control
	if control == null:
		push_error("[Godot MCP] Failed to instantiate tab scene: %s" % fallback_name)
		_suppress_tab_changed = previous_suppress
		return null
	control.name = fallback_name
	_tab_container.add_child(control)
	_tab_container.move_child(control, index)
	if not existing_title.is_empty():
		_tab_container.set_tab_title(index, existing_title)
	if replacing_current:
		_tab_container.current_tab = index
	_suppress_tab_changed = previous_suppress
	_set_tab_reference(index, control)
	if not control.has_method("apply_model"):
		push_error("[Godot MCP] Tab controller %s does not implement apply_model()" % fallback_name)
	return control


func _set_tab_reference(index: int, control: Control) -> void:
	match index:
		TAB_SERVER:
			_server_tab = control
		TAB_TOOLS:
			_tools_tab = control
		TAB_RESOURCES:
			_resources_tab = control
		TAB_PROMPTS:
			_prompts_tab = control
		TAB_CONFIG:
			_config_tab = control
		TAB_SETTINGS:
			_settings_tab = control


func _connect_tab_signals(index: int) -> void:
	match index:
		TAB_SERVER:
			_connect_server_tab()
		TAB_TOOLS:
			_connect_tools_tab()
		TAB_RESOURCES:
			_connect_mcp_catalog_tab(_resources_tab)
		TAB_PROMPTS:
			_connect_mcp_catalog_tab(_prompts_tab)
		TAB_CONFIG:
			_connect_config_tab()
		TAB_SETTINGS:
			_connect_settings_tab()


func _connect_server_tab() -> void:
	if _server_tab == null:
		return
	if not _server_tab.start_requested.is_connected(_on_server_tab_start_requested):
		_server_tab.start_requested.connect(_on_server_tab_start_requested)
	if not _server_tab.restart_requested.is_connected(_on_server_tab_restart_requested):
		_server_tab.restart_requested.connect(_on_server_tab_restart_requested)
	if not _server_tab.stop_requested.is_connected(_on_server_tab_stop_requested):
		_server_tab.stop_requested.connect(_on_server_tab_stop_requested)
	if not _server_tab.full_reload_requested.is_connected(_on_server_tab_full_reload_requested):
		_server_tab.full_reload_requested.connect(_on_server_tab_full_reload_requested)
	if _server_tab.has_signal("clear_self_diagnostics_requested") and not _server_tab.clear_self_diagnostics_requested.is_connected(_on_server_tab_clear_self_diagnostics_requested):
		_server_tab.clear_self_diagnostics_requested.connect(_on_server_tab_clear_self_diagnostics_requested)
	if _server_tab.has_signal("copy_requested") and not _server_tab.copy_requested.is_connected(_on_server_tab_copy_requested):
		_server_tab.copy_requested.connect(_on_server_tab_copy_requested)


func _connect_tools_tab() -> void:
	if _tools_tab == null:
		return
	if _tools_tab.has_signal("delete_user_tool_requested"):
		_connect_signal_once(_tools_tab, "delete_user_tool_requested", _on_tools_tab_delete_user_tool_requested)
	_connect_signal_once(_tools_tab, "tool_toggled", _on_tools_tab_tool_toggled)
	_connect_signal_once(_tools_tab, "category_toggled", _on_tools_tab_category_toggled)
	_connect_signal_once(_tools_tab, "domain_toggled", _on_tools_tab_domain_toggled)
	_connect_signal_once(_tools_tab, "tree_collapse_changed", _on_tools_tab_tree_collapse_changed)


func _connect_mcp_catalog_tab(tab: Control) -> void:
	if tab == null:
		return
	if tab.has_signal("copy_requested") and not tab.copy_requested.is_connected(_on_mcp_catalog_tab_copy_requested):
		tab.copy_requested.connect(_on_mcp_catalog_tab_copy_requested)
	if tab.has_signal("preview_requested") and not tab.preview_requested.is_connected(_on_mcp_catalog_tab_preview_requested):
		tab.preview_requested.connect(_on_mcp_catalog_tab_preview_requested)


func _connect_config_tab() -> void:
	if _config_tab == null:
		return
	_connect_signal_once(_config_tab, "cli_scope_changed", _on_config_tab_cli_scope_changed)
	_connect_signal_once(_config_tab, "config_platform_changed", _on_config_tab_platform_changed)
	_connect_signal_once(_config_tab, "config_client_action_requested", _on_config_tab_client_action_requested)
	_connect_signal_once(_config_tab, "config_client_launch_requested", _on_config_tab_client_launch_requested)
	_connect_signal_once(_config_tab, "config_client_path_pick_requested", _on_config_tab_client_path_pick_requested)
	_connect_signal_once(_config_tab, "config_client_path_clear_requested", _on_config_tab_client_path_clear_requested)
	_connect_signal_once(_config_tab, "config_client_open_config_dir_requested", _on_config_tab_client_open_config_dir_requested)
	_connect_signal_once(_config_tab, "config_client_open_config_file_requested", _on_config_tab_client_open_config_file_requested)
	_connect_signal_once(_config_tab, "config_write_requested", _on_config_tab_config_write_requested)
	_connect_signal_once(_config_tab, "config_remove_requested", _on_config_tab_config_remove_requested)
	_connect_signal_once(_config_tab, "copy_requested", _on_config_tab_copy_requested)


func _connect_settings_tab() -> void:
	if _settings_tab == null:
		return
	_connect_signal_once(_settings_tab, "port_changed", _on_settings_tab_port_changed)
	_connect_signal_once(_settings_tab, "log_level_changed", _on_settings_tab_log_level_changed)
	_connect_signal_once(_settings_tab, "language_changed", _on_settings_tab_language_changed)
	_connect_signal_once(_settings_tab, "update_source_changed", _on_settings_tab_update_source_changed)
	_connect_signal_once(_settings_tab, "update_custom_branch_changed", _on_settings_tab_update_custom_branch_changed)
	_connect_signal_once(_settings_tab, "update_interaction_refresh_requested", _on_settings_tab_update_interaction_refresh_requested)
	_connect_signal_once(_settings_tab, "update_check_requested", _on_settings_tab_update_check_requested)
	_connect_signal_once(_settings_tab, "update_apply_requested", _on_settings_tab_update_apply_requested)
	_connect_signal_once(_settings_tab, "update_switch_requested", _on_settings_tab_update_switch_requested)


func _connect_signal_once(source: Object, signal_name: StringName, callback: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	var signal_ref := Signal(source, signal_name)
	if not signal_ref.is_connected(callback):
		signal_ref.connect(callback)


func _get_tab_scene_path(index: int) -> String:
	match index:
		TAB_SERVER:
			return SERVER_TAB_SCENE_PATH
		TAB_TOOLS:
			return TOOLS_TAB_SCENE_PATH
		TAB_RESOURCES, TAB_PROMPTS:
			return MCP_CATALOG_TAB_SCENE_PATH
		TAB_CONFIG:
			return CONFIG_TAB_SCENE_PATH
		TAB_SETTINGS:
			return SETTINGS_TAB_SCENE_PATH
		_:
			return ""


func _get_tab_name(index: int) -> String:
	match index:
		TAB_SERVER:
			return "ServerTab"
		TAB_TOOLS:
			return "ToolsTab"
		TAB_RESOURCES:
			return "ResourcesTab"
		TAB_PROMPTS:
			return "PromptsTab"
		TAB_CONFIG:
			return "ConfigTab"
		TAB_SETTINGS:
			return "SettingsTab"
		_:
			return "Tab"


func _apply_tab_titles(model: Dictionary) -> void:
	var localization = model.get("localization")
	if localization == null or _tab_container == null or _tab_container.get_tab_count() < TAB_COUNT:
		return
	_tab_container.set_tab_title(TAB_SERVER, localization.get_text("tab_server"))
	_tab_container.set_tab_title(TAB_TOOLS, localization.get_text("tab_tools"))
	_tab_container.set_tab_title(TAB_RESOURCES, localization.get_text("tab_resources"))
	_tab_container.set_tab_title(TAB_PROMPTS, localization.get_text("tab_prompts"))
	_tab_container.set_tab_title(TAB_CONFIG, localization.get_text("tab_config"))
	_tab_container.set_tab_title(TAB_SETTINGS, localization.get_text("tab_settings"))


func focus_active_panel() -> void:
	if _tab_container:
		_ensure_tab_instance(_tab_container.current_tab)
		var current = _tab_container.get_current_tab_control()
		if current and current is Control:
			var target = _find_focusable_descendant(current as Control)
			if target != null:
				target.grab_focus()


func _on_tab_changed(index: int) -> void:
	if _suppress_tab_changed:
		return
	_ensure_tab_instance(index)
	current_tab_changed.emit(index)
	if not _last_model.is_empty():
		_apply_tab_model(_get_tab_for_index(index), _last_model)
		if index == TAB_SETTINGS:
			_normalize_settings_update_buttons()


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


func _on_mcp_catalog_tab_copy_requested(text: String, source: String) -> void:
	copy_requested.emit(text, source)


func _on_mcp_catalog_tab_preview_requested(kind: String, id: String, arguments: Dictionary) -> void:
	mcp_catalog_preview_requested.emit(kind, id, arguments)


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


func _on_settings_tab_update_interaction_refresh_requested() -> void:
	update_interaction_refresh_requested.emit()


func _on_settings_tab_update_check_requested() -> void:
	update_check_requested.emit()


func _on_settings_tab_update_apply_requested() -> void:
	update_apply_requested.emit()


func _on_settings_tab_update_switch_requested(kind: String, target_ref: String, target_commit: String) -> void:
	update_switch_requested.emit(kind, target_ref, target_commit)


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
	var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	return scene as PackedScene


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
