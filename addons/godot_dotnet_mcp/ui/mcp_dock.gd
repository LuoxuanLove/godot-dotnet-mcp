@tool
extends VBoxContainer

const SERVER_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/server_panel.tscn"
const TOOLS_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/tools_tab.tscn"
const CONFIG_TAB_SCENE_PATH := "res://addons/godot_dotnet_mcp/ui/config_panel.tscn"

signal current_tab_changed(index: int)
signal port_changed(value: int)
signal auto_start_toggled(enabled: bool)
signal log_level_changed(level: String)
signal permission_level_changed(level: String)
signal language_changed(language_code: String)
signal start_requested
signal restart_requested
signal stop_requested
signal full_reload_requested
signal tool_toggled(tool_name: String, enabled: bool)
signal delete_user_tool_requested(script_path: String)
signal category_toggled(category: String, enabled: bool)
signal domain_toggled(domain_key: String, enabled: bool)
signal tree_collapse_changed(kind: String, key: String, collapsed: bool)
signal cli_scope_changed(scope: String)
signal config_platform_changed(platform_id: String)
signal config_write_requested(config_type: String, filepath: String, config: String, client_name: String)
signal copy_requested(text: String, source: String)

@onready var _status_indicator: ColorRect = %StatusIndicator
@onready var _title_label: Label = %TitleLabel
@onready var _status_label: Label = %StatusLabel
@onready var _self_diag_panel: PanelContainer = %SelfDiagnosticsPanel
@onready var _self_diag_title: Label = %SelfDiagnosticsTitle
@onready var _self_diag_badge: Label = %SelfDiagnosticsBadge
@onready var _self_diag_copy_button: Button = %SelfDiagnosticsCopyButton
@onready var _self_diag_summary: Label = %SelfDiagnosticsSummary
@onready var _self_diag_details: Label = %SelfDiagnosticsDetails
@onready var _tab_container: TabContainer = %TabContainer
var _current_scale := -1.0
var _server_tab: Control
var _tools_tab: Control
var _config_tab: Control
var _self_diag_copy_text := ""


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ensure_tabs()
	_tab_container.tab_changed.connect(_on_tab_changed)
	_self_diag_copy_button.pressed.connect(_on_self_diag_copy_pressed)

	if _server_tab:
		_server_tab.port_changed.connect(_on_server_tab_port_changed)
		_server_tab.auto_start_toggled.connect(_on_server_tab_auto_start_toggled)
		_server_tab.log_level_changed.connect(_on_server_tab_log_level_changed)
		_server_tab.permission_level_changed.connect(_on_server_tab_permission_level_changed)
		_server_tab.language_changed.connect(_on_server_tab_language_changed)
		_server_tab.start_requested.connect(_on_server_tab_start_requested)
		_server_tab.restart_requested.connect(_on_server_tab_restart_requested)
		_server_tab.stop_requested.connect(_on_server_tab_stop_requested)
		_server_tab.full_reload_requested.connect(_on_server_tab_full_reload_requested)
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
		_config_tab.config_write_requested.connect(_on_config_tab_config_write_requested)
		_config_tab.copy_requested.connect(_on_config_tab_copy_requested)


func apply_model(model: Dictionary) -> void:
	if _status_indicator == null or _tab_container == null:
		return
	var localization = model.get("localization")
	if localization == null:
		return
	var is_running = bool(model.get("is_running", false))
	var editor_scale = float(model.get("editor_scale", 1.0))
	var color = Color(0.2, 0.8, 0.2) if is_running else Color(0.9, 0.3, 0.3)

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)

	_status_indicator.color = color
	_title_label.text = localization.get_text("title")
	_status_label.text = localization.get_text("status_running") if is_running else localization.get_text("status_stopped")
	_status_label.add_theme_color_override("font_color", color)
	_self_diag_panel.visible = false

	if _tab_container.get_tab_count() >= 3:
		_tab_container.set_tab_title(0, localization.get_text("tab_server"))
		_tab_container.set_tab_title(1, localization.get_text("tab_tools"))
		_tab_container.set_tab_title(2, localization.get_text("tab_config"))
	if _server_tab and _server_tab.has_method("apply_model"):
		_server_tab.apply_model(model)
	if _tools_tab and _tools_tab.has_method("apply_model"):
		_tools_tab.apply_model(model)
	if _config_tab and _config_tab.has_method("apply_model"):
		_config_tab.apply_model(model)

	var current_tab = int(model.get("current_tab", 0))
	if current_tab >= 0 and current_tab < _tab_container.get_tab_count():
		_tab_container.current_tab = current_tab


func show_message(title: String, message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


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


func activate_host_dock_tab() -> void:
	call_deferred("_activate_host_dock_tab_deferred")


func _ensure_tabs() -> void:
	for child in _tab_container.get_children():
		child.queue_free()

	_server_tab = _instantiate_tab(_load_packed_scene(SERVER_TAB_SCENE_PATH), "ServerTab")
	_tools_tab = _instantiate_tab(_load_packed_scene(TOOLS_TAB_SCENE_PATH), "ToolsTab")
	_config_tab = _instantiate_tab(_load_packed_scene(CONFIG_TAB_SCENE_PATH), "ConfigTab")


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


func _on_server_tab_port_changed(value: int) -> void:
	port_changed.emit(value)


func _on_server_tab_auto_start_toggled(enabled: bool) -> void:
	auto_start_toggled.emit(enabled)


func _on_server_tab_log_level_changed(level: String) -> void:
	log_level_changed.emit(level)


func _on_server_tab_permission_level_changed(level: String) -> void:
	permission_level_changed.emit(level)


func _on_server_tab_language_changed(language_code: String) -> void:
	language_changed.emit(language_code)


func _on_server_tab_start_requested() -> void:
	start_requested.emit()


func _on_server_tab_restart_requested() -> void:
	restart_requested.emit()


func _on_server_tab_stop_requested() -> void:
	stop_requested.emit()


func _on_server_tab_full_reload_requested() -> void:
	full_reload_requested.emit()


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


func _on_config_tab_config_write_requested(config_type: String, filepath: String, config: String, client_name: String) -> void:
	config_write_requested.emit(config_type, filepath, config, client_name)


func _on_config_tab_copy_requested(text: String, source: String) -> void:
	copy_requested.emit(text, source)


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale
	custom_minimum_size = Vector2(280, 400) * scale

	var header = get_node("Header") as HBoxContainer
	header.custom_minimum_size.y = 40.0 * scale

	var header_margin = get_node("Header/HeaderMargin") as MarginContainer
	header_margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	header_margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	header_margin.add_theme_constant_override("margin_top", int(round(8 * scale)))
	header_margin.add_theme_constant_override("margin_bottom", int(round(8 * scale)))

	var header_content = get_node("Header/HeaderMargin/HeaderContent") as HBoxContainer
	header_content.add_theme_constant_override("separation", int(round(10 * scale)))

	_status_indicator.custom_minimum_size = Vector2(12, 12) * scale
	_self_diag_copy_button.custom_minimum_size.y = 28.0 * scale

	var self_diag_margin = get_node("SelfDiagnosticsPanel/SelfDiagnosticsMargin") as MarginContainer
	self_diag_margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	self_diag_margin.add_theme_constant_override("margin_top", int(round(10 * scale)))
	self_diag_margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	self_diag_margin.add_theme_constant_override("margin_bottom", int(round(10 * scale)))

	var self_diag_content = get_node("SelfDiagnosticsPanel/SelfDiagnosticsMargin/SelfDiagnosticsContent") as VBoxContainer
	self_diag_content.add_theme_constant_override("separation", int(round(6 * scale)))

	var self_diag_header = get_node("SelfDiagnosticsPanel/SelfDiagnosticsMargin/SelfDiagnosticsContent/SelfDiagnosticsHeader") as HBoxContainer
	self_diag_header.add_theme_constant_override("separation", int(round(8 * scale)))


func _load_packed_scene(path: String) -> PackedScene:
	var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
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


func _activate_host_dock_tab_deferred() -> void:
	var current: Node = self
	while current != null:
		var parent = current.get_parent()
		if parent is TabContainer:
			var tab_container := parent as TabContainer
			for index in range(tab_container.get_tab_count()):
				if tab_container.get_child(index) == current:
					tab_container.current_tab = index
					return
		current = parent


func _apply_self_diagnostics(model: Dictionary, localization) -> void:
	var diagnostics = model.get("self_diagnostics", {})
	var copy_text = str(model.get("self_diagnostic_copy_text", ""))
	_self_diag_copy_text = copy_text
	_self_diag_title.text = localization.get_text("self_diag_title")
	_self_diag_copy_button.text = localization.get_text("self_diag_copy")

	if not (diagnostics is Dictionary) or (diagnostics as Dictionary).is_empty():
		_self_diag_panel.visible = false
		return

	_self_diag_panel.visible = true
	var diag := diagnostics as Dictionary
	var status = str(diag.get("status", "ok"))
	var badge_color = _get_self_diag_status_color(status)
	_self_diag_badge.text = _get_self_diag_status_text(status, localization)
	_self_diag_badge.add_theme_color_override("font_color", badge_color)

	var active_incidents = int(diag.get("active_incident_count", 0))
	var tool_loader = diag.get("tool_loader", {})
	var tool_load_error_count = 0
	if tool_loader is Dictionary:
		tool_load_error_count = int((tool_loader as Dictionary).get("tool_load_error_count", 0))
	var last_operation_text = localization.get_text("self_diag_last_operation_none")
	var last_operation = diag.get("last_operation", {})
	if last_operation is Dictionary and not (last_operation as Dictionary).is_empty():
		last_operation_text = "%s (%s ms)" % [
			str((last_operation as Dictionary).get("kind", "")),
			str((last_operation as Dictionary).get("duration_ms", 0.0))
		]
	_self_diag_summary.text = "%s | %s | %s" % [
		localization.get_text("self_diag_active_incidents") % active_incidents,
		localization.get_text("self_diag_tool_load_errors") % tool_load_error_count,
		localization.get_text("self_diag_last_operation") % last_operation_text
	]

	var recent_lines: Array[String] = []
	for incident in diag.get("recent_incidents", []):
		if not (incident is Dictionary):
			continue
		var incident_dict := incident as Dictionary
		recent_lines.append("%s | %s | %s" % [
			_get_self_diag_category_text(str(incident_dict.get("category", "")), localization),
			_get_self_diag_code_text(str(incident_dict.get("code", "")), localization),
			str(incident_dict.get("message", ""))
		])
		if recent_lines.size() >= 3:
			break
	if recent_lines.is_empty():
		_self_diag_details.text = localization.get_text("self_diag_empty")
	else:
		_self_diag_details.text = "\n".join(recent_lines)


func _get_self_diag_status_text(status: String, localization) -> String:
	match status:
		"error":
			return localization.get_text("self_diag_status_error")
		"warning":
			return localization.get_text("self_diag_status_warning")
		_:
			return localization.get_text("self_diag_status_ok")


func _get_self_diag_status_color(status: String) -> Color:
	match status:
		"error":
			return Color(0.9, 0.3, 0.3)
		"warning":
			return Color(0.95, 0.7, 0.2)
		_:
			return Color(0.2, 0.8, 0.2)


func _get_self_diag_category_text(category: String, localization) -> String:
	var key = "self_diag_category_%s" % category
	var translated = localization.get_text(key)
	return translated if translated != key else category


func _get_self_diag_code_text(code: String, localization) -> String:
	var key = "self_diag_code_%s" % code
	var translated = localization.get_text(key)
	return translated if translated != key else code


func _on_self_diag_copy_pressed() -> void:
	if _self_diag_copy_text.is_empty():
		return
	copy_requested.emit(_self_diag_copy_text, "Plugin Self Diagnostics")
