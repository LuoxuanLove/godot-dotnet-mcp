extends RefCounted

const ConfigPanelScene = preload("res://addons/godot_dotnet_mcp/ui/config_panel.tscn")

var _instance: VBoxContainer = null


class FakeLocalization extends RefCounted:
	var _texts := {
		"config_header": "Config",
		"config_header_desc": "Manage client configuration",
		"config_platform": "Platform",
		"config_scope_claude": "Scope",
		"config_section_desktop": "Desktop Clients",
		"config_section_desktop_desc": "Desktop client integrations",
		"cli_config": "CLI Clients",
		"cli_config_desc": "CLI client integrations",
		"scope_user": "User",
		"scope_project": "Project",
		"config_platform_desktop": "Desktop",
		"config_client_cursor": "Cursor",
		"config_client_install_status_label": "Install Status",
		"config_client_runtime_status_label": "Runtime Status",
		"config_client_entry_status_label": "Entry Status",
		"config_client_path_source_label": "Path Source",
		"config_file_path": "Config File",
		"config_client_action_apply": "Apply",
		"btn_write_config": "Write Config",
		"btn_remove_plugin_config": "Remove Config",
		"btn_copy": "Copy"
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))


class Recorder extends RefCounted:
	var action_client_id := ""
	var write_client_id := ""
	var remove_client_id := ""
	var copied_text := ""

	func on_client_action(client_id: String) -> void:
		action_client_id = client_id

	func on_write(config_type: String, _filepath: String, _config: String, _client_name: String) -> void:
		write_client_id = config_type

	func on_remove(config_type: String, _filepath: String, _client_name: String) -> void:
		remove_client_id = config_type

	func on_copy(text: String, _source: String) -> void:
		copied_text = text


func run_case(tree: SceneTree) -> Dictionary:
	_instance = ConfigPanelScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("Config tab rendering test could not instantiate the config panel scene.")
	tree.root.add_child(_instance)
	await tree.process_frame

	var recorder = Recorder.new()
	_instance.config_client_action_requested.connect(Callable(recorder, "on_client_action"))
	_instance.config_write_requested.connect(Callable(recorder, "on_write"))
	_instance.config_remove_requested.connect(Callable(recorder, "on_remove"))
	_instance.copy_requested.connect(Callable(recorder, "on_copy"))

	_instance.apply_model({
		"localization": FakeLocalization.new(),
		"editor_scale": 1.0,
		"current_config_platform": "cursor",
		"config_platforms": [
			{
				"id": "cursor",
				"group": "desktop",
				"name_key": "config_client_cursor",
				"display_name_key": "config_platform_desktop"
			}
		],
		"current_cli_scope": "user",
		"desktop_clients": [
			{
				"id": "cursor",
				"name_key": "config_client_cursor",
				"summary_text": "Desktop client summary",
				"install_status_text": "Installed to\nC:/Users/Test/AppData/Roaming/Cursor/User/mcp.json",
				"path": "C:/Users/Test/AppData/Roaming/Cursor/User/mcp.json",
				"content": "{\"mcpServers\":{}}",
				"primary_action_label_key": "config_client_action_apply",
				"primary_action_enabled": true,
				"writeable": true,
				"remove_supported": true,
				"remove_enabled": true
			}
		],
		"cli_clients": []
	})
	await tree.process_frame

	var desktop_clients = _instance.get_node("Scroll/Margin/Content/DesktopClients") as VBoxContainer
	var cli_clients = _instance.get_node("Scroll/Margin/Content/CliClients") as VBoxContainer
	if desktop_clients == null or desktop_clients.get_child_count() != 1:
		return _failure("Config tab should render exactly one desktop client card for the selected platform.")
	if cli_clients == null or cli_clients.get_child_count() != 0:
		return _failure("Config tab should not create CLI client cards when the selected platform belongs to the desktop group.")

	var desktop_card = desktop_clients.get_child(0)
	var labels = desktop_card.find_children("*", "Label", true, false)
	if _find_label_containing(labels, "Installed to") == null or _find_label_containing(labels, "C:/Users/Test/AppData/Roaming/Cursor/User/mcp.json") == null:
		return _failure("Config tab should visibly render the concrete 'Installed to <path>' status for installed clients.")
	var buttons = desktop_card.find_children("*", "Button", true, false)
	if buttons.size() < 4:
		return _failure("Config tab client card should render action buttons for apply/write/remove/copy.")

	var apply_button = _find_button(buttons, "Apply")
	var write_button = _find_button(buttons, "Write Config")
	var remove_button = _find_button(buttons, "Remove Config")
	var copy_button = _find_button(buttons, "Copy")
	if apply_button == null or write_button == null or remove_button == null or copy_button == null:
		return _failure("Config tab client card should expose stable action button labels after rendering.")

	apply_button.emit_signal("pressed")
	write_button.emit_signal("pressed")
	remove_button.emit_signal("pressed")
	copy_button.emit_signal("pressed")

	if recorder.action_client_id != "cursor":
		return _failure("Config tab should forward the primary client action through the original signal.")
	if recorder.write_client_id != "cursor":
		return _failure("Config tab should forward write actions through the original signal.")
	if recorder.remove_client_id != "cursor":
		return _failure("Config tab should forward remove actions through the original signal.")
	if recorder.copied_text != "{\"mcpServers\":{}}":
		return _failure("Config tab should forward copy actions through the original signal.")

	return {
		"name": "config_tab_rendering_contracts",
		"success": true,
		"error": "",
		"details": {
			"desktop_card_count": desktop_clients.get_child_count(),
			"button_count": buttons.size()
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	await tree.process_frame
	await tree.process_frame


func _find_button(buttons: Array, text: String) -> Button:
	for button_variant in buttons:
		var button = button_variant as Button
		if button != null and button.text == text:
			return button
	return null


func _find_label_containing(labels: Array, text: String) -> Label:
	for label_variant in labels:
		var label = label_variant as Label
		if label != null and label.text.find(text) != -1:
			return label
	return null


func _failure(message: String) -> Dictionary:
	return {
		"name": "config_tab_rendering_contracts",
		"success": false,
		"error": message
	}
