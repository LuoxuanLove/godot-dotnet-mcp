@tool
extends RefCounted
class_name ServerTabViewBindingService


func apply_titles(
	status_section_title: Label,
	settings_section_title: Label,
	advanced_section_title: Label,
	server_state_title: Label,
	endpoint_title: Label,
	connections_title: Label,
	requests_title: Label,
	last_request_title: Label,
	port_label: Label,
	log_level_label: Label,
	permission_level_label: Label,
	language_label: Label,
	titles: Dictionary
) -> void:
	status_section_title.text = str(titles.get("status_section_title", ""))
	settings_section_title.text = str(titles.get("settings_section_title", ""))
	advanced_section_title.text = str(titles.get("advanced_section_title", ""))
	server_state_title.text = str(titles.get("server_state_title", ""))
	endpoint_title.text = str(titles.get("endpoint_title", ""))
	connections_title.text = str(titles.get("connections_title", ""))
	requests_title.text = str(titles.get("requests_title", ""))
	last_request_title.text = str(titles.get("last_request_title", ""))
	port_label.text = str(titles.get("port_label", ""))
	log_level_label.text = str(titles.get("log_level_label", ""))
	permission_level_label.text = str(titles.get("permission_level_label", ""))
	language_label.text = str(titles.get("language_label", ""))


func apply_overview(
	state_value: Label,
	endpoint_value: Label,
	connections_value: Label,
	requests_value: Label,
	last_request_value: Label,
	overview: Dictionary
) -> void:
	state_value.text = str(overview.get("health_text", ""))
	endpoint_value.text = str(overview.get("service_text", ""))
	connections_value.text = str(overview.get("central_server_text", ""))
	requests_value.text = str(overview.get("config_text", ""))
	last_request_value.text = str(overview.get("activity_text", ""))


func apply_option_model(option: OptionButton, option_model: Dictionary) -> void:
	option.clear()
	var items: Array = option_model.get("items", [])
	for index in range(items.size()):
		var item: Dictionary = items[index]
		option.add_item(str(item.get("text", "")), index)
		option.set_item_metadata(index, item.get("value", ""))
	var selected_index = int(option_model.get("selected_index", -1))
	if selected_index >= 0:
		option.select(selected_index)


func apply_self_diagnostics_projection(
	title: Label,
	badge: Label,
	copy_button: Button,
	clear_button: Button,
	summary: Label,
	details: Label,
	projection: Dictionary
) -> void:
	title.text = str(projection.get("title", ""))
	copy_button.text = str(projection.get("copy_button_text", ""))
	clear_button.text = str(projection.get("clear_button_text", ""))
	badge.text = str(projection.get("badge_text", ""))
	if projection.has("badge_color") and projection.get("badge_color") is Color:
		badge.add_theme_color_override("font_color", projection.get("badge_color"))
	else:
		badge.remove_theme_color_override("font_color")
	summary.text = str(projection.get("summary", ""))
	details.text = str(projection.get("details", ""))
	clear_button.disabled = bool(projection.get("clear_disabled", true))


func apply_central_server_attach_projection(
	section_title: Label,
	status_title: Label,
	endpoint_title: Label,
	project_title: Label,
	session_title: Label,
	message_title: Label,
	status_value: Label,
	endpoint_value: Label,
	project_value: Label,
	session_value: Label,
	message_value: Label,
	projection: Dictionary
) -> void:
	section_title.text = str(projection.get("section_title", ""))
	status_title.text = str(projection.get("status_title", ""))
	endpoint_title.text = str(projection.get("endpoint_title", ""))
	project_title.text = str(projection.get("project_title", ""))
	session_title.text = str(projection.get("session_title", ""))
	message_title.text = str(projection.get("message_title", ""))
	status_value.text = str(projection.get("status_value", ""))
	endpoint_value.text = str(projection.get("endpoint_value", ""))
	project_value.text = str(projection.get("project_value", ""))
	session_value.text = str(projection.get("session_value", ""))
	message_value.text = str(projection.get("message_value", ""))


func apply_central_server_process_projection(
	local_status_title: Label,
	local_status_value: Label,
	local_command_title: Label,
	local_command_value: Label,
	install_version_title: Label,
	install_version_value: Label,
	install_dir_title: Label,
	install_dir_value: Label,
	install_source_title: Label,
	install_source_value: Label,
	detect_button: Button,
	install_button: Button,
	start_button: Button,
	stop_button: Button,
	open_install_dir_button: Button,
	open_logs_button: Button,
	projection: Dictionary
) -> void:
	local_status_title.text = str(projection.get("local_status_title", ""))
	local_command_title.text = str(projection.get("local_command_title", ""))
	install_version_title.text = str(projection.get("install_version_title", ""))
	install_dir_title.text = str(projection.get("install_dir_title", ""))
	install_source_title.text = str(projection.get("install_source_title", ""))
	detect_button.text = str(projection.get("detect_button_text", ""))
	install_button.text = str(projection.get("install_button_text", ""))
	start_button.text = str(projection.get("start_button_text", ""))
	stop_button.text = str(projection.get("stop_button_text", ""))
	open_install_dir_button.text = str(projection.get("open_install_dir_button_text", ""))
	open_logs_button.text = str(projection.get("open_logs_button_text", ""))
	local_status_value.text = str(projection.get("local_status_value", ""))
	install_version_value.text = str(projection.get("install_version_value", ""))
	install_dir_value.text = str(projection.get("install_dir_value", ""))
	install_source_value.text = str(projection.get("install_source_value", ""))
	local_command_value.text = str(projection.get("local_command_value", ""))
	install_button.disabled = bool(projection.get("install_button_disabled", true))
	start_button.disabled = bool(projection.get("start_button_disabled", true))
	stop_button.disabled = bool(projection.get("stop_button_disabled", true))
	open_install_dir_button.disabled = bool(projection.get("open_install_dir_button_disabled", true))
	open_logs_button.disabled = bool(projection.get("open_logs_button_disabled", true))
