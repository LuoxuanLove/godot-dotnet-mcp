@tool
extends VBoxContainer

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
signal config_validate_requested(platform_id: String)
signal copy_requested(text: String, source: String)

@onready var _config_header: Label = %ConfigHeader
@onready var _config_desc: Label = %ConfigDescription
@onready var _mode_header_divider: HSeparator = %ModeHeaderDivider
@onready var _mode_header: Label = %ModeHeader
@onready var _mode_desc: Label = %ModeDescription
@onready var _mode_actions: HBoxContainer = %ModeActions
@onready var _validate_config_button: Button = %ValidateConfigButton
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
	_validate_config_button.pressed.connect(_on_validate_config_button_pressed)


func apply_model(model: Dictionary) -> void:
	var localization = model.get("localization")
	var selected_platform = str(model.get("current_config_platform", ""))
	var editor_scale = float(model.get("editor_scale", 1.0))
	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)

	_config_header.text = localization.get_text("config_header")
	_config_desc.text = localization.get_text("config_header_desc")
	var connection_mode: Dictionary = model.get("config_connection_mode", {})
	_mode_header.text = localization.get_text("config_mode_title")
	_mode_desc.text = str(connection_mode.get("description", ""))
	_validate_config_button.text = localization.get_text("config_validate_button")
	_validate_config_button.disabled = not bool(connection_mode.get("validate_enabled", false))
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
	body.add_theme_constant_override("separation", int(round(10 * _current_scale)))
	margin.add_child(body)

	var title = Label.new()
	title.text = localization.get_text(str(client.get("name_key", "")))
	body.add_child(title)

	var summary_text = str(client.get("summary_text", "")).strip_edges()
	var summary_key = str(client.get("summary_key", ""))
	if summary_text.is_empty() and not summary_key.is_empty():
		summary_text = localization.get_text(summary_key)
	if not summary_text.is_empty():
		var summary = Label.new()
		summary.text = summary_text
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
		body.add_child(summary)

	var install_status = str(client.get("install_status_text", "")).strip_edges()
	if not install_status.is_empty():
		body.add_child(_create_info_block(
			localization.get_text("config_client_install_status_label"),
			install_status
		))

	var runtime_status = str(client.get("runtime_status_text", "")).strip_edges()
	if not runtime_status.is_empty():
		body.add_child(_create_info_block(
			localization.get_text("config_client_runtime_status_label"),
			runtime_status
		))

	var entry_status = str(client.get("entry_status_text", "")).strip_edges()
	if not entry_status.is_empty():
		body.add_child(_create_info_block(
			localization.get_text("config_client_entry_status_label"),
			entry_status
		))

	var path_source = str(client.get("path_source_text", "")).strip_edges()
	if not path_source.is_empty():
		body.add_child(_create_info_block(
			localization.get_text("config_client_path_source_label"),
			path_source
		))

	var install_message = str(client.get("install_message_text", "")).strip_edges()
	if not install_message.is_empty():
		var install_message_label = Label.new()
		install_message_label.text = install_message
		install_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		install_message_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		body.add_child(install_message_label)

	var path_value = str(client.get("path", "")).strip_edges()
	if not path_value.is_empty():
		body.add_child(_create_info_block(
			str(client.get("path_label_text", localization.get_text("config_file_path"))),
			path_value
		))

	var detail_label_text = str(client.get("detail_label_text", "")).strip_edges()
	var detail_value = str(client.get("detail_value", "")).strip_edges()
	if not detail_label_text.is_empty() and not detail_value.is_empty():
		body.add_child(_create_info_block(detail_label_text, detail_value))

	var explanation_text = str(client.get("explanation_text", "")).strip_edges()
	if not explanation_text.is_empty():
		var explanation = Label.new()
		explanation.text = explanation_text
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		explanation.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		body.add_child(explanation)

	var guidance_text = str(client.get("guidance_text", "")).strip_edges()
	if not guidance_text.is_empty():
		var guidance = Label.new()
		guidance.text = guidance_text
		guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guidance.add_theme_color_override("font_color", Color(0.62, 0.78, 0.96))
		body.add_child(guidance)

	var content_text = str(client.get("content", ""))
	if not content_text.is_empty():
		var content = TextEdit.new()
		content.editable = false
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.scroll_fit_content_height = true
		var tall_content = supports_write or bool(client.get("writeable", false)) or bool(client.get("remove_supported", false))
		content.custom_minimum_size.y = (92.0 if tall_content else 60.0) * _current_scale
		content.text = content_text
		body.add_child(content)

	var action_buttons: Array[Button] = []

	var primary_action_label_key = str(client.get("primary_action_label_key", ""))
	if not primary_action_label_key.is_empty():
		var primary_button = Button.new()
		primary_button.text = localization.get_text(primary_action_label_key)
		primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		primary_button.custom_minimum_size.y = 30.0 * _current_scale
		primary_button.disabled = not bool(client.get("primary_action_enabled", false))
		primary_button.pressed.connect(Callable(self, "_on_client_action_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(primary_button)

	if bool(client.get("launch_supported", false)):
		var launch_button = Button.new()
		launch_button.text = localization.get_text(str(client.get("launch_action_label_key", "config_client_action_open_project")))
		launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		launch_button.custom_minimum_size.y = 30.0 * _current_scale
		launch_button.disabled = not bool(client.get("launch_enabled", true))
		launch_button.pressed.connect(Callable(self, "_on_launch_client_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(launch_button)

	if bool(client.get("path_pick_supported", false)):
		var pick_button = Button.new()
		pick_button.text = localization.get_text(str(client.get("path_pick_action_label_key", "config_client_action_choose_program_path")))
		pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick_button.custom_minimum_size.y = 30.0 * _current_scale
		pick_button.disabled = not bool(client.get("path_pick_enabled", true))
		pick_button.pressed.connect(Callable(self, "_on_pick_client_path_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(pick_button)

	if bool(client.get("path_clear_supported", false)):
		var clear_button = Button.new()
		clear_button.text = localization.get_text("config_client_action_clear_custom_path")
		clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clear_button.custom_minimum_size.y = 30.0 * _current_scale
		clear_button.disabled = not bool(client.get("path_clear_enabled", true))
		clear_button.pressed.connect(Callable(self, "_on_clear_client_path_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(clear_button)

	if bool(client.get("open_config_dir_supported", false)):
		var open_dir_button = Button.new()
		open_dir_button.text = localization.get_text("config_client_action_open_config_dir")
		open_dir_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_dir_button.custom_minimum_size.y = 30.0 * _current_scale
		open_dir_button.disabled = not bool(client.get("open_config_dir_enabled", true))
		open_dir_button.pressed.connect(Callable(self, "_on_open_client_config_dir_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(open_dir_button)

	if bool(client.get("open_config_file_supported", false)):
		var open_file_button = Button.new()
		open_file_button.text = localization.get_text("config_client_action_open_config_file")
		open_file_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_file_button.custom_minimum_size.y = 30.0 * _current_scale
		open_file_button.disabled = not bool(client.get("open_config_file_enabled", true))
		open_file_button.pressed.connect(Callable(self, "_on_open_client_config_file_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(open_file_button)

	if bool(client.get("writeable", false)):
		var write_button = Button.new()
		write_button.text = localization.get_text("btn_write_config")
		write_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		write_button.custom_minimum_size.y = 30.0 * _current_scale
		write_button.pressed.connect(Callable(self, "_on_write_client_pressed").bind(client, localization.get_text(str(client.get("name_key", "")))))
		action_buttons.append(write_button)

	if bool(client.get("remove_supported", false)):
		var remove_button = Button.new()
		remove_button.text = localization.get_text("btn_remove_plugin_config")
		remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remove_button.custom_minimum_size.y = 30.0 * _current_scale
		remove_button.disabled = not bool(client.get("remove_enabled", false))
		remove_button.pressed.connect(Callable(self, "_on_remove_client_pressed").bind(client, localization.get_text(str(client.get("name_key", "")))))
		action_buttons.append(remove_button)

	if not content_text.is_empty():
		var copy_button = Button.new()
		copy_button.text = localization.get_text("btn_copy")
		copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy_button.custom_minimum_size.y = 30.0 * _current_scale
		copy_button.pressed.connect(Callable(self, "_on_copy_client_pressed").bind(content_text, localization.get_text(str(client.get("name_key", "")))))
		action_buttons.append(copy_button)

	var actions: Control
	if action_buttons.size() > 2:
		var actions_grid = GridContainer.new()
		actions_grid.columns = 2
		actions_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_grid.add_theme_constant_override("h_separation", int(round(8 * _current_scale)))
		actions_grid.add_theme_constant_override("v_separation", int(round(8 * _current_scale)))
		actions = actions_grid
	else:
		var actions_row = HBoxContainer.new()
		actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_row.add_theme_constant_override("separation", int(round(8 * _current_scale)))
		actions = actions_row
	body.add_child(actions)
	for button in action_buttons:
		actions.add_child(button)

	return panel


func _create_info_block(label_text: String, value_text: String) -> Control:
	var block = VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", int(round(3 * _current_scale)))

	var label = Label.new()
	label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
	block.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(value)

	return block


func _on_scope_option_selected(index: int) -> void:
	cli_scope_changed.emit("user" if index == 0 else "project")


func _on_platform_option_selected(index: int) -> void:
	if _is_rebuilding_platforms:
		return
	config_platform_changed.emit(str(_platform_option.get_item_metadata(index)))


func _get_platform_option_text(platform: Dictionary, localization) -> String:
	var name_text = localization.get_text(str(platform.get("name_key", "")))
	var prefix_key = str(platform.get("display_name_key", "")).strip_edges()
	if prefix_key.is_empty():
		return name_text
	var prefix_text = localization.get_text(prefix_key)
	if prefix_text == prefix_key or prefix_text.is_empty():
		return name_text
	return "%s %s" % [prefix_text, name_text]


func _on_write_client_pressed(client: Dictionary, client_name: String) -> void:
	config_write_requested.emit(str(client.get("id", "")), str(client.get("path", "")), str(client.get("content", "")), client_name)


func _on_copy_client_pressed(content: String, client_name: String) -> void:
	copy_requested.emit(content, client_name)


func _on_remove_client_pressed(client: Dictionary, client_name: String) -> void:
	config_remove_requested.emit(str(client.get("id", "")), str(client.get("path", "")), client_name)


func _on_client_action_pressed(client_id: String) -> void:
	config_client_action_requested.emit(client_id)


func _on_launch_client_pressed(client_id: String) -> void:
	config_client_launch_requested.emit(client_id)


func _on_pick_client_path_pressed(client_id: String) -> void:
	config_client_path_pick_requested.emit(client_id)


func _on_clear_client_path_pressed(client_id: String) -> void:
	config_client_path_clear_requested.emit(client_id)


func _on_open_client_config_dir_pressed(client_id: String) -> void:
	config_client_open_config_dir_requested.emit(client_id)


func _on_open_client_config_file_pressed(client_id: String) -> void:
	config_client_open_config_file_requested.emit(client_id)


func _on_validate_config_button_pressed() -> void:
	var selected_index = _platform_option.selected
	if selected_index < 0:
		return
	config_validate_requested.emit(str(_platform_option.get_item_metadata(selected_index)))


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

	var mode_actions = get_node("Scroll/Margin/Content/ModeActions") as HBoxContainer
	mode_actions.add_theme_constant_override("separation", int(round(8 * scale)))

	var row = get_node("Scroll/Margin/Content/ScopeRow") as HBoxContainer
	row.add_theme_constant_override("separation", int(round(8 * scale)))
	_platform_option.custom_minimum_size.y = 32.0 * scale
	_scope_option.custom_minimum_size.y = 32.0 * scale
	_validate_config_button.custom_minimum_size.y = 32.0 * scale
	_validate_config_button.custom_minimum_size.x = 180.0 * scale


func _rebuild_platform_options(platforms: Array, selected_platform: String, localization) -> void:
	_is_rebuilding_platforms = true
	_platform_option.clear()
	var selected_index := -1
	for index in range(platforms.size()):
		var platform = platforms[index]
		_platform_option.add_item(_get_platform_option_text(platform, localization), index)
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
