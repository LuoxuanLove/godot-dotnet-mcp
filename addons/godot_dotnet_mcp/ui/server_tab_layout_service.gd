extends RefCounted
class_name ServerTabLayoutService

const ServerTabLayoutNodes = preload("res://addons/godot_dotnet_mcp/ui/server_tab_layout_nodes.gd")


func apply_editor_scale(nodes: ServerTabLayoutNodes, scale: float) -> void:
	if nodes == null or not nodes.is_resolved():
		return

	nodes.margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	nodes.margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	nodes.margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	nodes.margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))

	nodes.content.add_theme_constant_override("separation", int(round(12 * scale)))

	nodes.status_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	nodes.status_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))
	nodes.overview_buttons.add_theme_constant_override("h_separation", int(round(8 * scale)))
	nodes.overview_buttons.add_theme_constant_override("v_separation", int(round(8 * scale)))
	nodes.self_diagnostics_header.add_theme_constant_override("separation", int(round(8 * scale)))
	nodes.central_server_content.add_theme_constant_override("separation", int(round(8 * scale)))
	nodes.central_server_status_row.add_theme_constant_override("h_separation", int(round(12 * scale)))
	nodes.central_server_status_row.add_theme_constant_override("v_separation", int(round(8 * scale)))
	nodes.central_server_buttons.add_theme_constant_override("h_separation", int(round(8 * scale)))
	nodes.central_server_buttons.add_theme_constant_override("v_separation", int(round(8 * scale)))
	nodes.settings_grid.add_theme_constant_override("h_separation", int(round(12 * scale)))
	nodes.settings_grid.add_theme_constant_override("v_separation", int(round(8 * scale)))
	nodes.log_level_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	nodes.log_level_row.add_theme_constant_override("v_separation", int(round(8 * scale)))
	nodes.permission_level_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	nodes.permission_level_row.add_theme_constant_override("v_separation", int(round(8 * scale)))
	nodes.language_row.add_theme_constant_override("h_separation", int(round(8 * scale)))
	nodes.language_row.add_theme_constant_override("v_separation", int(round(8 * scale)))
	nodes.advanced_content.add_theme_constant_override("separation", int(round(8 * scale)))


func apply_responsive_layout(nodes: ServerTabLayoutNodes, current_scale: float, current_layout_width: float) -> float:
	if nodes == null or not nodes.is_resolved():
		return current_layout_width

	var available_width = nodes.content.size.x
	if available_width <= 0.0:
		available_width = nodes.margin.size.x
	if available_width <= 0.0:
		return current_layout_width
	if is_equal_approx(current_layout_width, available_width):
		return current_layout_width

	var scale = current_scale if current_scale > 0.0 else 1.0
	var ultra_narrow_layout = available_width < 320.0 * scale
	var narrow_layout = available_width < 430.0 * scale
	var compact_layout = available_width < 520.0 * scale
	var horizontal_margin = 8.0 * scale if ultra_narrow_layout else (10.0 * scale if narrow_layout else 12.0 * scale)
	var vertical_margin = 10.0 * scale if ultra_narrow_layout else 12.0 * scale
	var section_spacing = 10.0 * scale if ultra_narrow_layout else 12.0 * scale
	var grid_h_spacing = 8.0 * scale if ultra_narrow_layout else 12.0 * scale
	var grid_v_spacing = 6.0 * scale if ultra_narrow_layout else 8.0 * scale
	var row_spacing = 6.0 * scale if ultra_narrow_layout else 8.0 * scale
	var content_width = min(available_width - horizontal_margin * 2.0, 560.0 * scale)
	content_width = max(content_width, 140.0 * scale)
	var label_width = 132.0 * scale if not narrow_layout else 96.0 * scale
	var field_width = max(120.0 * scale, content_width - label_width - int(round(8 * scale)))
	var status_grid_width = content_width
	var status_columns = 2 if not narrow_layout else 1
	var settings_columns = 2 if not narrow_layout else 1

	nodes.margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
	nodes.margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
	nodes.margin.add_theme_constant_override("margin_top", int(round(vertical_margin)))
	nodes.margin.add_theme_constant_override("margin_bottom", int(round(vertical_margin)))
	nodes.content.add_theme_constant_override("separation", int(round(section_spacing)))
	nodes.overview_buttons.add_theme_constant_override("h_separation", int(round(row_spacing)))
	nodes.overview_buttons.add_theme_constant_override("v_separation", int(round(row_spacing)))
	nodes.central_server_content.add_theme_constant_override("separation", int(round(section_spacing)))
	nodes.settings_content.add_theme_constant_override("separation", int(round(section_spacing)))
	nodes.status_grid.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	nodes.status_grid.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	nodes.central_server_status_row.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	nodes.central_server_status_row.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	nodes.central_server_buttons.add_theme_constant_override("h_separation", int(round(row_spacing)))
	nodes.central_server_buttons.add_theme_constant_override("v_separation", int(round(row_spacing)))
	nodes.settings_grid.add_theme_constant_override("h_separation", int(round(grid_h_spacing)))
	nodes.settings_grid.add_theme_constant_override("v_separation", int(round(grid_v_spacing)))
	nodes.log_level_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	nodes.log_level_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	nodes.permission_level_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	nodes.permission_level_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	nodes.language_row.add_theme_constant_override("h_separation", int(round(row_spacing)))
	nodes.language_row.add_theme_constant_override("v_separation", int(round(row_spacing)))
	nodes.advanced_content.add_theme_constant_override("separation", int(round(section_spacing * 0.75)))

	nodes.status_center.custom_minimum_size.x = status_grid_width
	nodes.overview_buttons_center.custom_minimum_size.x = content_width
	nodes.overview_buttons.custom_minimum_size.x = content_width
	nodes.central_server_center.custom_minimum_size.x = content_width
	nodes.central_server_content.custom_minimum_size.x = content_width
	nodes.central_server_buttons.custom_minimum_size.x = content_width
	nodes.settings_center.custom_minimum_size.x = content_width
	nodes.settings_content.custom_minimum_size.x = content_width
	nodes.section_divider.custom_minimum_size.x = content_width
	nodes.central_server_divider.custom_minimum_size.x = content_width
	nodes.status_grid.columns = status_columns
	nodes.overview_buttons.columns = 1 if narrow_layout else (2 if compact_layout else 3)
	nodes.central_server_status_row.columns = 2 if not narrow_layout else 1
	nodes.central_server_buttons.columns = 1 if ultra_narrow_layout else 2
	nodes.settings_grid.columns = settings_columns
	nodes.log_level_row.columns = settings_columns
	nodes.permission_level_row.columns = settings_columns
	nodes.language_row.columns = settings_columns

	for title_label in nodes.status_titles + nodes.settings_titles:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var keep_width = false
		if title_label in nodes.status_titles:
			keep_width = status_columns == 2
		else:
			keep_width = settings_columns == 2
		title_label.custom_minimum_size.x = label_width if keep_width else 0.0

	nodes.permission_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nodes.permission_level_label.custom_minimum_size.x = label_width if settings_columns == 2 else 0.0
	nodes.advanced_section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nodes.advanced_section_title.custom_minimum_size.x = content_width

	for value_label in nodes.status_values:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x = field_width if status_columns == 2 else content_width

	for title_label in nodes.central_server_titles:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.custom_minimum_size.x = label_width if nodes.central_server_status_row.columns == 2 else 0.0

	for value_label in nodes.central_server_values:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x = field_width if nodes.central_server_status_row.columns == 2 else content_width

	nodes.port_spin.custom_minimum_size.y = 32.0 * scale
	nodes.port_spin.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	nodes.log_level_option.custom_minimum_size.y = 32.0 * scale
	nodes.log_level_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	nodes.permission_level_option.custom_minimum_size.y = 32.0 * scale
	nodes.permission_level_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width
	nodes.language_option.custom_minimum_size.y = 32.0 * scale
	nodes.language_option.custom_minimum_size.x = field_width if settings_columns == 2 else content_width

	var button_width = content_width if nodes.overview_buttons.columns == 1 else (content_width - row_spacing * float(nodes.overview_buttons.columns - 1)) / float(nodes.overview_buttons.columns)
	var central_server_button_width = content_width if nodes.central_server_buttons.columns == 1 else (content_width - row_spacing * float(nodes.central_server_buttons.columns - 1)) / float(nodes.central_server_buttons.columns)
	for button in nodes.overview_action_buttons:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.x = button_width
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale

	for button in nodes.central_server_action_buttons:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.x = central_server_button_width
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale
	for button in nodes.self_diagnostic_action_buttons:
		button.custom_minimum_size.y = (30.0 if ultra_narrow_layout else 32.0) * scale
		button.custom_minimum_size.x = 72.0 * scale

	return available_width
