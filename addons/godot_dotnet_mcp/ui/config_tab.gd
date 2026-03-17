@tool
extends VBoxContainer

signal cli_scope_changed(scope: String)
signal config_platform_changed(platform_id: String)
signal config_write_requested(config_type: String, filepath: String, config: String, client_name: String)
signal copy_requested(text: String, source: String)

@onready var _config_header: Label = %ConfigHeader
@onready var _config_desc: Label = %ConfigDescription
@onready var _platform_label: Label = %PlatformLabel
@onready var _platform_option: OptionButton = %PlatformOption
@onready var _desktop_header: Label = %DesktopHeader
@onready var _desktop_header_divider: HSeparator = %DesktopHeaderDivider
@onready var _desktop_desc: Label = %DesktopDescription
@onready var _desktop_clients: VBoxContainer = %DesktopClients
@onready var _separator: HSeparator = %Separator
@onready var _cli_header: Label = %CliHeader
@onready var _cli_header_divider: HSeparator = %CliHeaderDivider
@onready var _cli_desc: Label = %CliDescription
@onready var _scope_label: Label = %ScopeLabel
@onready var _scope_option: OptionButton = %ScopeOption
@onready var _cli_clients: VBoxContainer = %CliClients

var _current_scale := -1.0
var _is_rebuilding_platforms := false


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_platform_option.item_selected.connect(_on_platform_option_selected)
	_scope_option.item_selected.connect(_on_scope_option_selected)


func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	var selected_platform = str(model.get("current_config_platform", ""))
	var editor_scale = float(model.get("editor_scale", 1.0))
	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)

	_config_header.text = localization.get_text("config_header")
	_config_desc.text = localization.get_text("config_header_desc")
	_platform_label.text = localization.get_text("config_platform")
	_scope_label.text = localization.get_text("config_scope_claude")

	var desktop_clients: Array = model.get("desktop_clients", [])
	var cli_clients: Array = model.get("cli_clients", [])
	var platform_defs: Array = model.get("config_platforms", [])
	var selected_client = _find_client_by_id(selected_platform, desktop_clients, cli_clients)
	var selected_group = _resolve_selected_group(selected_platform, platform_defs)

	_rebuild_platform_options(platform_defs, selected_platform, localization)
	_apply_section_visibility(selected_group, str(selected_client.get("id", "")))

	_desktop_header.text = localization.get_text("config_section_desktop")
	_desktop_desc.text = localization.get_text("config_section_desktop_desc")
	_cli_header.text = localization.get_text("cli_config")
	_cli_desc.text = localization.get_text("cli_config_desc")

	_scope_option.clear()
	_scope_option.add_item(localization.get_text("scope_user"), 0)
	_scope_option.add_item(localization.get_text("scope_project"), 1)
	_scope_option.select(0 if str(model.get("current_cli_scope", "user")) == "user" else 1)

	_rebuild_client_cards(
		_desktop_clients,
		[selected_client] if selected_group == "desktop" and not selected_client.is_empty() else [],
		true,
		localization
	)
	_rebuild_client_cards(
		_cli_clients,
		[selected_client] if selected_group == "cli" and not selected_client.is_empty() else [],
		false,
		localization
	)


func _rebuild_client_cards(container: VBoxContainer, clients: Array, supports_write: bool, localization) -> void:
	for child in container.get_children():
		child.queue_free()
	for client in clients:
		container.add_child(_create_client_card(client, supports_write, localization))


func _create_client_card(client: Dictionary, supports_write: bool, localization) -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(round(10 * _current_scale)))
	margin.add_theme_constant_override("margin_top", int(round(10 * _current_scale)))
	margin.add_theme_constant_override("margin_right", int(round(10 * _current_scale)))
	margin.add_theme_constant_override("margin_bottom", int(round(10 * _current_scale)))
	panel.add_child(margin)

	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(round(8 * _current_scale)))
	margin.add_child(body)

	var title = Label.new()
	title.text = localization.get_text(str(client.get("name_key", "")))
	body.add_child(title)

	var summary_key = str(client.get("summary_key", ""))
	if not summary_key.is_empty():
		var summary = Label.new()
		summary.text = localization.get_text(summary_key)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		body.add_child(summary)

	if supports_write:
		var path_label = Label.new()
		path_label.text = "%s\n%s" % [localization.get_text("config_file_path"), str(client.get("path", ""))]
		path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(path_label)

	var content = TextEdit.new()
	content.editable = false
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.scroll_fit_content_height = true
	content.custom_minimum_size.y = (92.0 if supports_write else 60.0) * _current_scale
	content.text = str(client.get("content", ""))
	body.add_child(content)

	var actions = HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", int(round(8 * _current_scale)))
	body.add_child(actions)

	if supports_write and bool(client.get("writeable", false)):
		var write_button = Button.new()
		write_button.text = localization.get_text("btn_write_config")
		write_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		write_button.custom_minimum_size.y = 30.0 * _current_scale
		write_button.pressed.connect(Callable(self, "_on_write_client_pressed").bind(client, localization.get_text(str(client.get("name_key", "")))))
		actions.add_child(write_button)

	var copy_button = Button.new()
	copy_button.text = localization.get_text("btn_copy")
	copy_button.custom_minimum_size.y = 30.0 * _current_scale
	copy_button.pressed.connect(Callable(self, "_on_copy_client_pressed").bind(str(client.get("content", "")), localization.get_text(str(client.get("name_key", "")))))
	actions.add_child(copy_button)

	return panel


func _on_scope_option_selected(index: int) -> void:
	cli_scope_changed.emit("user" if index == 0 else "project")


func _on_platform_option_selected(index: int) -> void:
	if _is_rebuilding_platforms:
		return
	config_platform_changed.emit(str(_platform_option.get_item_metadata(index)))


func _on_write_client_pressed(client: Dictionary, client_name: String) -> void:
	config_write_requested.emit(str(client.get("id", "")), str(client.get("path", "")), str(client.get("content", "")), client_name)


func _on_copy_client_pressed(content: String, client_name: String) -> void:
	copy_requested.emit(content, client_name)


func _get_margin_node() -> MarginContainer:
	return get_node_or_null("Scroll/Margin") as MarginContainer


func _get_content_node() -> VBoxContainer:
	return get_node_or_null("Scroll/Margin/Content") as VBoxContainer


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale

	var margin = _get_margin_node()
	var content = _get_content_node()
	if margin == null or content == null:
		return

	margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))

	content.add_theme_constant_override("separation", int(round(16 * scale)))

	for section_path in [
		"Scroll/Margin/Content/DesktopClients",
		"Scroll/Margin/Content/CliClients"
	]:
		var section = get_node(section_path) as VBoxContainer
		section.add_theme_constant_override("separation", int(round(8 * scale)))

	var platform_row = get_node("Scroll/Margin/Content/PlatformRow") as HBoxContainer
	platform_row.add_theme_constant_override("separation", int(round(8 * scale)))

	var row = get_node("Scroll/Margin/Content/ScopeRow") as HBoxContainer
	row.add_theme_constant_override("separation", int(round(8 * scale)))
	_platform_option.custom_minimum_size.y = 32.0 * scale
	_scope_option.custom_minimum_size.y = 32.0 * scale


func _rebuild_platform_options(platforms: Array, selected_platform: String, localization) -> void:
	_is_rebuilding_platforms = true
	_platform_option.clear()
	var selected_index := -1
	for index in range(platforms.size()):
		var platform = platforms[index]
		_platform_option.add_item(localization.get_text(str(platform.get("name_key", ""))), index)
		_platform_option.set_item_metadata(index, str(platform.get("id", "")))
		if str(platform.get("id", "")) == selected_platform:
			selected_index = index

	if selected_index == -1 and _platform_option.get_item_count() > 0:
		selected_index = 0

	if selected_index >= 0:
		_platform_option.select(selected_index)
	_is_rebuilding_platforms = false


func _find_client_by_id(client_id: String, desktop_clients: Array, cli_clients: Array) -> Dictionary:
	for client in desktop_clients:
		if str(client.get("id", "")) == client_id:
			return client
	for client in cli_clients:
		if str(client.get("id", "")) == client_id:
			return client
	return {}


func _resolve_selected_group(selected_platform: String, platform_defs: Array) -> String:
	for platform in platform_defs:
		if str(platform.get("id", "")) == selected_platform:
			return str(platform.get("group", ""))
	return ""


func _apply_section_visibility(selected_group: String, selected_client_id: String) -> void:
	var show_desktop = selected_group == "desktop"
	var show_cli = selected_group == "cli"
	var show_claude_scope = show_cli and selected_client_id == "claude_code"
	_desktop_header.visible = show_desktop
	_desktop_header_divider.visible = show_desktop
	_desktop_desc.visible = show_desktop
	_desktop_clients.visible = show_desktop
	_separator.visible = false
	_cli_header.visible = show_cli
	_cli_header_divider.visible = show_cli
	_cli_desc.visible = show_cli
	_scope_label.visible = show_claude_scope
	_scope_option.visible = show_claude_scope
	var scope_row = get_node("Scroll/Margin/Content/ScopeRow") as HBoxContainer
	scope_row.visible = show_claude_scope
