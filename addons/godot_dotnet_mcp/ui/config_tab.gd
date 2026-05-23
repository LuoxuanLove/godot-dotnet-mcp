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
signal copy_requested(text: String, source: String)

@onready var _config_header: Label = %ConfigHeader
@onready var _config_desc: Label = %ConfigDescription
@onready var _config_intro_card: PanelContainer = %ConfigIntroCard
@onready var _platform_label: Label = %PlatformLabel
@onready var _platform_option: OptionButton = %PlatformOption
@onready var _platform_desktop_separator: HSeparator = %PlatformDesktopSeparator
@onready var _desktop_card: PanelContainer = %DesktopCard
@onready var _desktop_header: Label = %DesktopHeader
@onready var _desktop_header_divider: HSeparator = %DesktopHeaderDivider
@onready var _desktop_desc: Label = %DesktopDescription
@onready var _desktop_clients: VBoxContainer = %DesktopClients
@onready var _separator: HSeparator = %Separator
@onready var _cli_card: PanelContainer = %CliCard
@onready var _cli_header: Label = %CliHeader
@onready var _cli_header_divider: HSeparator = %CliHeaderDivider
@onready var _cli_desc: Label = %CliDescription
@onready var _scope_label: Label = %ScopeLabel
@onready var _scope_option: OptionButton = %ScopeOption
@onready var _cli_clients: VBoxContainer = %CliClients
@onready var _config_intro_margin: MarginContainer = %ConfigIntroMargin
@onready var _desktop_card_margin: MarginContainer = %DesktopCardMargin
@onready var _cli_card_margin: MarginContainer = %CliCardMargin
@onready var _config_intro_body: VBoxContainer = %ConfigIntroBody
@onready var _desktop_card_body: VBoxContainer = %DesktopCardBody
@onready var _cli_card_body: VBoxContainer = %CliCardBody

var _current_scale := -1.0
var _is_rebuilding_platforms := false
var _current_model: Dictionary = {}
var _current_layout_width := -1.0
var _action_grid_columns_refresh_queued := false


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_platform_option.item_selected.connect(_on_platform_option_selected)
	_scope_option.item_selected.connect(_on_scope_option_selected)
	resized.connect(_on_resized)

func apply_model(model: Dictionary) -> void:
	_current_model = model
	var localization = model.get("localization")
	var selected_platform = str(model.get("current_config_platform", ""))
	var editor_scale = float(model.get("editor_scale", 1.0))
	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

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
	_queue_refresh_action_grid_columns()


func _rebuild_client_cards(container: VBoxContainer, clients: Array, supports_write: bool, localization) -> void:
	var signature := _make_client_cards_signature(clients, supports_write, localization)
	if str(container.get_meta("client_cards_signature", "")) == signature:
		_queue_refresh_action_grid_columns()
		return
	var hovered_client_ids := _collect_hovered_content_client_ids(container)
	for child in container.get_children():
		child.queue_free()
	for client in clients:
		container.add_child(_create_client_card(client, supports_write, localization, hovered_client_ids))
	container.set_meta("client_cards_signature", signature)
	var viewport := get_viewport()
	if viewport != null:
		viewport.call_deferred("update_mouse_cursor_state")
	_queue_refresh_action_grid_columns()


func _create_client_card(client: Dictionary, supports_write: bool, localization, hovered_client_ids: Array) -> Control:
	var client_id := str(client.get("id", ""))
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_framed_panel_style())

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(round(12 * _current_scale)))
	margin.add_theme_constant_override("margin_top", int(round(12 * _current_scale)))
	margin.add_theme_constant_override("margin_right", int(round(12 * _current_scale)))
	margin.add_theme_constant_override("margin_bottom", int(round(12 * _current_scale)))
	panel.add_child(margin)

	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(round(6 * _current_scale)))
	margin.add_child(body)

	var title = Label.new()
	title.text = localization.get_text(str(client.get("name_key", "")))
	title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	title.remove_theme_font_size_override("font_size")
	body.add_child(title)

	var summary_text = str(client.get("summary_text", "")).strip_edges()
	var summary_key = str(client.get("summary_key", ""))
	if summary_text.is_empty() and not summary_key.is_empty():
		summary_text = localization.get_text(summary_key)
	if not summary_text.is_empty():
		var summary = Label.new()
		summary.text = summary_text
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_color_override("font_color", _get_description_text_color())
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
		install_message_label.add_theme_color_override("font_color", _get_hint_text_color())
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
		explanation.add_theme_color_override("font_color", _get_hint_text_color())
		body.add_child(explanation)

	var guidance_text = str(client.get("guidance_text", "")).strip_edges()
	if not guidance_text.is_empty():
		var guidance = Label.new()
		guidance.text = guidance_text
		guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guidance.add_theme_color_override("font_color", _get_description_text_color())
		body.add_child(guidance)

	var content_text = str(client.get("content", ""))
	if not content_text.is_empty():
		var content_panel = PanelContainer.new()
		content_panel.name = "ClientConfigContentPanel"
		content_panel.set_meta("client_id", client_id)
		content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_panel.clip_contents = true
		content_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		content_panel.add_theme_stylebox_override("panel", _make_theme_style("read_only", "TextEdit", int(round(8 * _current_scale)), int(round(6 * _current_scale))))

		var line_count := content_text.count("\n") + 1
		var longest_line := 0
		for line in content_text.split("\n"):
			longest_line = max(longest_line, String(line).length())
		var estimated_wrap_lines = max(line_count, int(ceil(float(longest_line) / 64.0)))
		var content_height = max(68.0, 18.0 + float(estimated_wrap_lines) * 24.0) * _current_scale
		content_panel.custom_minimum_size.y = content_height
		var content_overlay = Control.new()
		content_overlay.name = "ClientConfigContentOverlay"
		content_overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_overlay.custom_minimum_size.y = content_height
		content_overlay.clip_contents = true
		content_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
		content_panel.add_child(content_overlay)

		var content_margin = MarginContainer.new()
		content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_margin.add_theme_constant_override("margin_left", int(round(8 * _current_scale)))
		content_margin.add_theme_constant_override("margin_top", int(round(6 * _current_scale)))
		content_margin.add_theme_constant_override("margin_right", int(round(54 * _current_scale)))
		content_margin.add_theme_constant_override("margin_bottom", int(round(6 * _current_scale)))
		content_overlay.add_child(content_margin)

		var content = Label.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.custom_minimum_size.x = 0.0
		content.text = content_text
		content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		content.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		content.add_theme_color_override("font_color", get_theme_color("font_readonly_color", "TextEdit"))
		content.add_theme_font_override("font", get_theme_font("font", "TextEdit"))
		content.add_theme_font_size_override("font_size", get_theme_font_size("font_size", "TextEdit"))
		content_margin.add_child(content)

		var content_copy_button = Button.new()
		content_copy_button.name = "ClientConfigContentCopyButton"
		content_copy_button.visible = false
		content_copy_button.focus_mode = Control.FOCUS_NONE
		content_copy_button.mouse_filter = Control.MOUSE_FILTER_PASS
		content_copy_button.set_meta("client_id", client_id)
		content_copy_button.tooltip_text = localization.get_text("btn_copy")
		content_copy_button.custom_minimum_size = Vector2(26.0, 26.0) * _current_scale
		if has_theme_icon("ActionCopy", "EditorIcons"):
			content_copy_button.icon = get_theme_icon("ActionCopy", "EditorIcons")
		else:
			content_copy_button.text = localization.get_text("btn_copy")
		var copy_button_margin := int(round(12 * _current_scale))
		var copy_button_size := int(round(26 * _current_scale))
		content_copy_button.anchor_left = 1.0
		content_copy_button.anchor_right = 1.0
		content_copy_button.anchor_top = 0.0
		content_copy_button.anchor_bottom = 0.0
		content_copy_button.offset_left = -copy_button_size - copy_button_margin
		content_copy_button.offset_right = -copy_button_margin
		content_copy_button.offset_top = copy_button_margin
		content_copy_button.offset_bottom = copy_button_margin + copy_button_size
		content_copy_button.pressed.connect(Callable(self, "_on_copy_client_pressed").bind(content_text, localization.get_text(str(client.get("name_key", "")))))
		content_overlay.add_child(content_copy_button)
		_connect_content_copy_button_hover(content_panel, content_overlay, content_copy_button)
		if hovered_client_ids.has(client_id):
			content_copy_button.visible = true
		body.add_child(content_panel)

		var content_actions_gap = Control.new()
		content_actions_gap.custom_minimum_size.y = max(10.0, round(10.0 * _current_scale))
		body.add_child(content_actions_gap)

	var action_buttons: Array[Button] = []

	var primary_action_label_key = str(client.get("primary_action_label_key", ""))
	if not primary_action_label_key.is_empty():
		var primary_button = Button.new()
		primary_button.text = localization.get_text(primary_action_label_key)
		primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		primary_button.custom_minimum_size.y = 0.0
		primary_button.disabled = not bool(client.get("primary_action_enabled", false))
		primary_button.pressed.connect(Callable(self, "_on_client_action_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(primary_button)

	if bool(client.get("launch_supported", false)):
		var launch_button = Button.new()
		launch_button.text = localization.get_text(str(client.get("launch_action_label_key", "config_client_action_open_project")))
		launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		launch_button.custom_minimum_size.y = 0.0
		launch_button.disabled = not bool(client.get("launch_enabled", true))
		launch_button.pressed.connect(Callable(self, "_on_launch_client_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(launch_button)

	if bool(client.get("path_pick_supported", false)):
		var pick_button = Button.new()
		pick_button.text = localization.get_text(str(client.get("path_pick_action_label_key", "config_client_action_choose_program_path")))
		pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick_button.custom_minimum_size.y = 0.0
		pick_button.disabled = not bool(client.get("path_pick_enabled", true))
		pick_button.pressed.connect(Callable(self, "_on_pick_client_path_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(pick_button)

	if bool(client.get("path_clear_supported", false)):
		var clear_button = Button.new()
		clear_button.text = localization.get_text("config_client_action_clear_custom_path")
		clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clear_button.custom_minimum_size.y = 0.0
		clear_button.disabled = not bool(client.get("path_clear_enabled", true))
		clear_button.pressed.connect(Callable(self, "_on_clear_client_path_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(clear_button)

	if bool(client.get("open_config_dir_supported", false)):
		var open_dir_button = Button.new()
		open_dir_button.text = localization.get_text("config_client_action_open_config_dir")
		open_dir_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_dir_button.custom_minimum_size.y = 0.0
		open_dir_button.disabled = not bool(client.get("open_config_dir_enabled", true))
		open_dir_button.pressed.connect(Callable(self, "_on_open_client_config_dir_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(open_dir_button)

	if bool(client.get("open_config_file_supported", false)):
		var open_file_button = Button.new()
		open_file_button.text = localization.get_text("config_client_action_open_config_file")
		open_file_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_file_button.custom_minimum_size.y = 0.0
		open_file_button.disabled = not bool(client.get("open_config_file_enabled", true))
		open_file_button.pressed.connect(Callable(self, "_on_open_client_config_file_pressed").bind(str(client.get("id", ""))))
		action_buttons.append(open_file_button)

	if bool(client.get("writeable", false)):
		var write_button = Button.new()
		write_button.text = localization.get_text("btn_write_config")
		write_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		write_button.custom_minimum_size.y = 0.0
		write_button.pressed.connect(Callable(self, "_on_write_client_pressed").bind(client, localization.get_text(str(client.get("name_key", "")))))
		action_buttons.append(write_button)

	if bool(client.get("remove_supported", false)):
		var remove_button = Button.new()
		remove_button.text = localization.get_text("btn_remove_plugin_config")
		remove_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		remove_button.custom_minimum_size.y = 0.0
		remove_button.disabled = not bool(client.get("remove_enabled", false))
		remove_button.pressed.connect(Callable(self, "_on_remove_client_pressed").bind(client, localization.get_text(str(client.get("name_key", "")))))
		action_buttons.append(remove_button)

	var actions_grid = GridContainer.new()
	actions_grid.name = "ClientActionGrid"
	actions_grid.set_meta("is_client_action_grid", true)
	actions_grid.columns = _get_action_column_count(action_buttons.size())
	actions_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_grid.add_theme_constant_override("h_separation", int(round(8 * _current_scale)))
	actions_grid.add_theme_constant_override("v_separation", int(round(8 * _current_scale)))
	var actions: Control = actions_grid
	body.add_child(actions)
	for button in action_buttons:
		actions.add_child(button)

	return panel


func _connect_content_copy_button_hover(content_panel: PanelContainer, content_overlay: Control, copy_button: Button) -> void:
	var panel_ref: WeakRef = weakref(content_panel)
	var button_ref: WeakRef = weakref(copy_button)
	var show_callable: Callable = Callable(self, "_show_content_copy_button").bind(button_ref)
	var hide_callable: Callable = Callable(self, "_request_content_copy_button_hide").bind(panel_ref, button_ref)
	content_panel.mouse_entered.connect(show_callable)
	content_overlay.mouse_entered.connect(show_callable)
	copy_button.mouse_entered.connect(show_callable)
	content_panel.mouse_exited.connect(hide_callable)
	content_overlay.mouse_exited.connect(hide_callable)
	copy_button.mouse_exited.connect(hide_callable)


func _show_content_copy_button(button_ref: WeakRef) -> void:
	var copy_button = button_ref.get_ref() as Button
	if copy_button != null and is_instance_valid(copy_button):
		copy_button.visible = true


func _request_content_copy_button_hide(panel_ref: WeakRef, button_ref: WeakRef) -> void:
	call_deferred("_hide_content_copy_button_if_outside", panel_ref, button_ref)


func _hide_content_copy_button_if_outside(panel_ref: WeakRef, button_ref: WeakRef, force_hide := false) -> void:
	var content_panel = panel_ref.get_ref() as PanelContainer
	var copy_button = button_ref.get_ref() as Button
	if content_panel == null or copy_button == null or not is_instance_valid(content_panel) or not is_instance_valid(copy_button):
		return
	if force_hide or not _is_mouse_inside_content_copy_target(content_panel, copy_button):
		copy_button.visible = false


func _is_mouse_inside_content_copy_target(content_panel: PanelContainer, copy_button: Button) -> bool:
	if not content_panel.is_visible_in_tree():
		return false
	var viewport: Viewport = get_viewport()
	if viewport != null:
		var hovered_control: Control = viewport.gui_get_hovered_control()
		if hovered_control != null:
			if _is_control_self_or_ancestor(content_panel, hovered_control) or _is_control_self_or_ancestor(copy_button, hovered_control):
				return true
	return _is_global_mouse_inside_content_copy_target(content_panel, copy_button)


func _is_control_self_or_ancestor(root: Control, candidate: Control) -> bool:
	return root == candidate or root.is_ancestor_of(candidate)


func _is_global_mouse_inside_content_copy_target(content_panel: PanelContainer, copy_button: Button) -> bool:
	var mouse_position := get_global_mouse_position()
	var padding := max(2.0, 2.0 * _current_scale)
	if content_panel.get_global_rect().grow(padding).has_point(mouse_position):
		return true
	return copy_button.is_visible_in_tree() and copy_button.get_global_rect().grow(padding).has_point(mouse_position)


func _collect_hovered_content_client_ids(container: VBoxContainer) -> Array:
	var hovered_ids: Array = []
	for panel_variant in container.find_children("ClientConfigContentPanel", "PanelContainer", true, false):
		var content_panel = panel_variant as PanelContainer
		if content_panel == null:
			continue
		var copy_button = content_panel.find_child("ClientConfigContentCopyButton", true, false) as Button
		if copy_button == null:
			continue
		if copy_button.visible or _is_mouse_inside_content_copy_target(content_panel, copy_button):
			var client_id := str(content_panel.get_meta("client_id", ""))
			if not client_id.is_empty() and not hovered_ids.has(client_id):
				hovered_ids.append(client_id)
	return hovered_ids


func _make_client_cards_signature(clients: Array, supports_write: bool, localization) -> String:
	var localized_keys := [
		"config_client_install_status_label",
		"config_client_runtime_status_label",
		"config_client_entry_status_label",
		"config_client_path_source_label",
		"config_file_path",
		"btn_write_config",
		"btn_remove_plugin_config",
		"btn_copy",
		"config_client_action_choose_program_path",
		"config_client_action_clear_custom_path",
		"config_client_action_open_config_dir",
		"config_client_action_open_config_file",
		"config_client_action_open_project"
	]
	var localization_signature := {}
	for key in localized_keys:
		localization_signature[key] = localization.get_text(key)
	var client_signatures: Array = []
	for client_variant in clients:
		var client := client_variant as Dictionary
		if client == null:
			continue
		client_signatures.append(_make_client_card_signature(client, localization))
	return JSON.stringify({
		"scale": _current_scale,
		"supports_write": supports_write,
		"localization": localization_signature,
		"clients": client_signatures
	})


func _make_client_card_signature(client: Dictionary, localization) -> Dictionary:
	var key_fields := [
		"id",
		"name_key",
		"summary_text",
		"summary_key",
		"install_status_text",
		"runtime_status_text",
		"entry_status_text",
		"path_source_text",
		"path_label_text",
		"path",
		"detail_label_text",
		"detail_value",
		"explanation_text",
		"guidance_text",
		"content",
		"primary_action_label_key",
		"primary_action_enabled",
		"launch_supported",
		"launch_action_label_key",
		"launch_enabled",
		"path_pick_supported",
		"path_pick_action_label_key",
		"path_pick_enabled",
		"path_clear_supported",
		"path_clear_enabled",
		"open_config_dir_supported",
		"open_config_dir_enabled",
		"open_config_file_supported",
		"open_config_file_enabled",
		"writeable",
		"remove_supported",
		"remove_enabled"
	]
	var signature := {}
	for field in key_fields:
		signature[field] = client.get(field)
	var label_keys := [
		str(client.get("name_key", "")),
		str(client.get("summary_key", "")),
		str(client.get("primary_action_label_key", "")),
		str(client.get("launch_action_label_key", "")),
		str(client.get("path_pick_action_label_key", ""))
	]
	var localized_labels := {}
	for key in label_keys:
		if not key.is_empty():
			localized_labels[key] = localization.get_text(key)
	signature["localized_labels"] = localized_labels
	return signature


func _create_info_block(label_text: String, value_text: String) -> Control:
	var block = HBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", int(round(8 * _current_scale)))

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 168.0 * _current_scale
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	label.add_theme_color_override("font_color", _get_meta_label_text_color())
	block.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
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

	_apply_responsive_layout()
	_apply_visual_style(scale)

	for section_path in [
		"Scroll/Margin/Content/DesktopCard/DesktopCardMargin/DesktopCardBody/DesktopClients",
		"Scroll/Margin/Content/CliCard/CliCardMargin/CliCardBody/CliClients"
	]:
		var section = get_node(section_path) as VBoxContainer
		section.add_theme_constant_override("separation", int(round(8 * scale)))

	var platform_row = get_node("Scroll/Margin/Content/ConfigIntroCard/ConfigIntroMargin/ConfigIntroBody/PlatformRow") as HBoxContainer
	platform_row.add_theme_constant_override("separation", int(round(8 * scale)))

	var row = get_node("Scroll/Margin/Content/CliCard/CliCardMargin/CliCardBody/ScopeRow") as HBoxContainer
	row.add_theme_constant_override("separation", int(round(8 * scale)))
	_platform_option.custom_minimum_size.y = 0.0
	_platform_option.custom_minimum_size.x = 0.0
	_scope_option.custom_minimum_size.y = 0.0
	_scope_option.custom_minimum_size.x = 0.0


func _apply_responsive_layout() -> void:
	var scale: float = _current_scale if _current_scale > 0.0 else 1.0
	var margin = _get_margin_node()
	var content = _get_content_node()
	if margin == null or content == null:
		return
	var available_width: float = content.size.x
	if available_width <= 0.0:
		available_width = size.x
	if available_width <= 0.0:
		return
	if is_equal_approx(_current_layout_width, available_width):
		return
	_current_layout_width = available_width

	var narrow_layout: bool = available_width < 360.0 * scale
	var horizontal_margin: float = 10.0 * scale if narrow_layout else 14.0 * scale
	var vertical_margin: float = 12.0 * scale
	margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
	margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
	margin.add_theme_constant_override("margin_top", int(round(vertical_margin)))
	margin.add_theme_constant_override("margin_bottom", int(round(vertical_margin)))
	content.add_theme_constant_override("separation", int(round((12.0 if narrow_layout else 16.0) * scale)))

	for label in [_config_desc, _desktop_desc, _cli_desc]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 0.0
	for label in [_platform_label, _scope_label]:
		label.clip_text = narrow_layout
		label.custom_minimum_size.x = 0.0


func _queue_refresh_action_grid_columns() -> void:
	if _action_grid_columns_refresh_queued:
		return
	_action_grid_columns_refresh_queued = true
	_refresh_action_grid_columns.call_deferred()


func _refresh_action_grid_columns(width_override := -1.0) -> void:
	_action_grid_columns_refresh_queued = false
	for grid_variant in find_children("ClientActionGrid", "GridContainer", true, false):
		var grid = grid_variant as GridContainer
		if grid == null or not bool(grid.get_meta("is_client_action_grid", false)):
			continue
		grid.columns = _get_action_column_count(grid.get_child_count(), width_override)


func _get_action_column_count(button_count: int, width_override := -1.0) -> int:
	if button_count <= 1:
		return 1
	var scale: float = _current_scale if _current_scale > 0.0 else 1.0
	var available_width: float = width_override
	if available_width <= 0.0:
		var content = _get_content_node()
		if content != null and content.size.x > 0.0:
			available_width = content.size.x
	if available_width <= 0.0:
		available_width = size.x
	return 1 if available_width < 420.0 * scale else 2

func _on_resized() -> void:
	_current_layout_width = -1.0
	_apply_responsive_layout()
	_refresh_action_grid_columns()


func _apply_visual_style(scale: float) -> void:
	begin_bulk_theme_override()
	_config_intro_card.add_theme_stylebox_override("panel", _make_framed_panel_style())
	_desktop_card.add_theme_stylebox_override("panel", _make_framed_panel_style())
	_cli_card.add_theme_stylebox_override("panel", _make_framed_panel_style())
	for margin in [_config_intro_margin, _desktop_card_margin, _cli_card_margin]:
		margin.add_theme_constant_override("margin_left", int(round(14 * scale)))
		margin.add_theme_constant_override("margin_right", int(round(14 * scale)))
		margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
		margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	for body in [_config_intro_body, _desktop_card_body, _cli_card_body]:
		body.add_theme_constant_override("separation", int(round(10 * scale)))
	for title in [_config_header, _desktop_header, _cli_header]:
		title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
		title.remove_theme_font_size_override("font_size")
	for desc in [_config_desc, _desktop_desc, _cli_desc]:
		desc.add_theme_color_override("font_color", _get_description_text_color())
	for label in [_platform_label, _scope_label]:
		label.add_theme_color_override("font_color", _get_meta_label_text_color())
	var separator_style := StyleBoxLine.new()
	separator_style.color = get_theme_color("separator_color", "Editor")
	separator_style.thickness = max(1, int(round(scale)))
	_platform_desktop_separator.custom_minimum_size.y = max(6.0, round(6.0 * scale))
	_platform_desktop_separator.add_theme_stylebox_override("separator", separator_style)
	end_bulk_theme_override()


func _make_theme_style(style_name: String, theme_type: String, horizontal_margin: int, vertical_margin: int) -> StyleBox:
	var style := get_theme_stylebox(style_name, theme_type).duplicate() as StyleBox
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


func _make_framed_panel_style() -> StyleBox:
	var style := _make_theme_style("panel", "Tree", 0, 0)
	if style is StyleBoxFlat:
		var flat_style := style as StyleBoxFlat
		flat_style.border_color = get_theme_color("separator_color", "Editor")
		flat_style.set_border_width_all(1)
	return style


func _get_muted_text_color() -> Color:
	return _get_meta_label_text_color()


func _get_description_text_color() -> Color:
	var base := get_theme_color("font_color", "Label")
	var disabled := get_theme_color("font_disabled_color", "Editor")
	return base.lerp(disabled, 0.18)


func _get_hint_text_color() -> Color:
	var base := get_theme_color("font_color", "Label")
	var disabled := get_theme_color("font_disabled_color", "Editor")
	return base.lerp(disabled, 0.34)


func _get_meta_label_text_color() -> Color:
	var base := get_theme_color("font_color", "Label")
	var disabled := get_theme_color("font_disabled_color", "Editor")
	return base.lerp(disabled, 0.48)


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
	_desktop_card.visible = show_desktop
	_desktop_header.visible = show_desktop
	_desktop_header_divider.visible = false
	_desktop_desc.visible = show_desktop
	_desktop_clients.visible = show_desktop
	_separator.visible = false
	_cli_card.visible = show_cli
	_cli_header.visible = show_cli
	_cli_header_divider.visible = false
	_cli_desc.visible = show_cli
	_scope_label.visible = show_claude_scope
	_scope_option.visible = show_claude_scope
	var scope_row = get_node("Scroll/Margin/Content/CliCard/CliCardMargin/CliCardBody/ScopeRow") as HBoxContainer
	scope_row.visible = show_claude_scope
