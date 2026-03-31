@tool
extends RefCounted


func build_client_card(client: Dictionary, supports_write: bool, localization, scale: float, handle_action: Callable) -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(round(10 * scale)))
	margin.add_theme_constant_override("margin_top", int(round(10 * scale)))
	margin.add_theme_constant_override("margin_right", int(round(10 * scale)))
	margin.add_theme_constant_override("margin_bottom", int(round(10 * scale)))
	panel.add_child(margin)

	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(round(10 * scale)))
	margin.add_child(body)

	var client_name = localization.get_text(str(client.get("name_key", "")))
	var title = Label.new()
	title.text = client_name
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

	_append_info_block(body, localization.get_text("config_client_install_status_label"), str(client.get("install_status_text", "")).strip_edges(), scale)
	_append_info_block(body, localization.get_text("config_client_runtime_status_label"), str(client.get("runtime_status_text", "")).strip_edges(), scale)
	_append_info_block(body, localization.get_text("config_client_entry_status_label"), str(client.get("entry_status_text", "")).strip_edges(), scale)
	_append_info_block(body, localization.get_text("config_client_path_source_label"), str(client.get("path_source_text", "")).strip_edges(), scale)

	var install_message = str(client.get("install_message_text", "")).strip_edges()
	if not install_message.is_empty():
		var install_message_label = Label.new()
		install_message_label.text = install_message
		install_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		install_message_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
		body.add_child(install_message_label)

	var path_value = str(client.get("path", "")).strip_edges()
	if not path_value.is_empty():
		_append_info_block(body, str(client.get("path_label_text", localization.get_text("config_file_path"))), path_value, scale)

	var detail_label_text = str(client.get("detail_label_text", "")).strip_edges()
	var detail_value = str(client.get("detail_value", "")).strip_edges()
	if not detail_label_text.is_empty() and not detail_value.is_empty():
		_append_info_block(body, detail_label_text, detail_value, scale)

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
		content.custom_minimum_size.y = (92.0 if tall_content else 60.0) * scale
		content.text = content_text
		body.add_child(content)

	var action_buttons: Array[Button] = []
	_append_action_button(
		action_buttons,
		str(client.get("primary_action_label_key", "")),
		bool(client.get("primary_action_enabled", false)),
		scale,
		localization,
		handle_action,
		"client_action",
		client,
		client_name
	)
	if bool(client.get("launch_supported", false)):
		_append_action_button(
			action_buttons,
			str(client.get("launch_action_label_key", "config_client_action_open_project")),
			bool(client.get("launch_enabled", true)),
			scale,
			localization,
			handle_action,
			"launch",
			client,
			client_name
		)
	if bool(client.get("path_pick_supported", false)):
		_append_action_button(
			action_buttons,
			str(client.get("path_pick_action_label_key", "config_client_action_choose_program_path")),
			bool(client.get("path_pick_enabled", true)),
			scale,
			localization,
			handle_action,
			"path_pick",
			client,
			client_name
		)
	if bool(client.get("path_clear_supported", false)):
		_append_action_button(action_buttons, "config_client_action_clear_custom_path", bool(client.get("path_clear_enabled", true)), scale, localization, handle_action, "path_clear", client, client_name)
	if bool(client.get("open_config_dir_supported", false)):
		_append_action_button(action_buttons, "config_client_action_open_config_dir", bool(client.get("open_config_dir_enabled", true)), scale, localization, handle_action, "open_config_dir", client, client_name)
	if bool(client.get("open_config_file_supported", false)):
		_append_action_button(action_buttons, "config_client_action_open_config_file", bool(client.get("open_config_file_enabled", true)), scale, localization, handle_action, "open_config_file", client, client_name)
	if bool(client.get("writeable", false)):
		_append_action_button(action_buttons, "btn_write_config", true, scale, localization, handle_action, "write", client, client_name)
	if bool(client.get("remove_supported", false)):
		_append_action_button(action_buttons, "btn_remove_plugin_config", bool(client.get("remove_enabled", false)), scale, localization, handle_action, "remove", client, client_name)
	if not content_text.is_empty():
		_append_action_button(action_buttons, "btn_copy", true, scale, localization, handle_action, "copy", client, client_name)

	var actions = _create_action_container(action_buttons.size(), scale)
	body.add_child(actions)
	for button in action_buttons:
		actions.add_child(button)

	return panel


func _append_info_block(container: VBoxContainer, label_text: String, value_text: String, scale: float) -> void:
	if value_text.is_empty():
		return
	container.add_child(_create_info_block(label_text, value_text, scale))


func _create_info_block(label_text: String, value_text: String, scale: float) -> Control:
	var block = VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", int(round(3 * scale)))

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


func _append_action_button(
	action_buttons: Array[Button],
	label_key: String,
	enabled: bool,
	scale: float,
	localization,
	handle_action: Callable,
	action_name: String,
	client: Dictionary,
	client_name: String
) -> void:
	if label_key.is_empty():
		return
	var button = Button.new()
	button.text = localization.get_text(label_key)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 30.0 * scale
	button.disabled = not enabled
	button.pressed.connect(handle_action.bind(action_name, client, client_name))
	action_buttons.append(button)


func _create_action_container(button_count: int, scale: float) -> Control:
	if button_count > 2:
		var actions_grid = GridContainer.new()
		actions_grid.columns = 2
		actions_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions_grid.add_theme_constant_override("h_separation", int(round(8 * scale)))
		actions_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))
		return actions_grid

	var actions_row = HBoxContainer.new()
	actions_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_row.add_theme_constant_override("separation", int(round(8 * scale)))
	return actions_row
