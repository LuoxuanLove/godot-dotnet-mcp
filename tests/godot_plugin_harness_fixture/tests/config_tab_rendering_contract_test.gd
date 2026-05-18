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

	var base_model := {
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
				"guidance_text": "Capability: Full one-click config write and remove are available.",
				"primary_action_label_key": "config_client_action_apply",
				"primary_action_enabled": true,
				"writeable": true,
				"remove_supported": true,
				"remove_enabled": true
			}
		],
		"cli_clients": []
	}
	_instance.apply_model(base_model)
	await tree.process_frame

	var desktop_clients = _instance.get_node("Scroll/Margin/Content/DesktopCard/DesktopCardMargin/DesktopCardBody/DesktopClients") as VBoxContainer
	var cli_clients = _instance.get_node("Scroll/Margin/Content/CliCard/CliCardMargin/CliCardBody/CliClients") as VBoxContainer
	if desktop_clients == null or desktop_clients.get_child_count() != 1:
		return _failure("Config tab should render exactly one desktop client card for the selected platform.")
	if cli_clients == null or cli_clients.get_child_count() != 0:
		return _failure("Config tab should not create CLI client cards when the selected platform belongs to the desktop group.")

	var desktop_card = desktop_clients.get_child(0)
	var labels = desktop_card.find_children("*", "Label", true, false)
	if _find_label_containing(labels, "Installed to") == null or _find_label_containing(labels, "C:/Users/Test/AppData/Roaming/Cursor/User/mcp.json") == null:
		return _failure("Config tab should visibly render the concrete 'Installed to <path>' status for installed clients.")
	if _find_label_containing(labels, "Capability: Full one-click") == null:
		return _failure("Config tab should render presenter-provided capability guidance through the generic guidance text slot.")
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

	var content_panel := _find_content_panel_for_copy_button(copy_button)
	if content_panel == null:
		return _failure("Config tab copy button should be anchored inside the generated content panel.")
	var content_panel_ref: WeakRef = weakref(content_panel)
	var copy_button_ref: WeakRef = weakref(copy_button)
	_instance.call("_hide_content_copy_button_if_outside", content_panel_ref, copy_button_ref, true)
	if copy_button.visible:
		return _failure("Config tab content copy button should stay hidden while the mouse is outside the content panel.")
	_instance.call("_show_content_copy_button", copy_button_ref)
	if not copy_button.visible:
		return _failure("Config tab content copy button should become visible while the mouse hovers inside the content panel.")
	_instance.call("_show_content_copy_button", copy_button_ref)
	if not copy_button.visible:
		return _failure("Config tab content copy button should remain visible while hover state is refreshed.")
	_instance.call("_hide_content_copy_button_if_outside", content_panel_ref, copy_button_ref, true)
	if copy_button.visible:
		return _failure("Config tab content copy button should hide after the mouse leaves the content panel.")
	if copy_button.mouse_filter != Control.MOUSE_FILTER_PASS:
		return _failure("Config tab content copy button should receive clicks without breaking parent hover state.")
	_instance.apply_model(base_model)
	await tree.process_frame
	await tree.process_frame
	var same_model_desktop_clients = _instance.get_node("Scroll/Margin/Content/DesktopCard/DesktopCardMargin/DesktopCardBody/DesktopClients") as VBoxContainer
	var same_model_copy_button = _find_button(same_model_desktop_clients.get_child(0).find_children("*", "Button", true, false), "Copy")
	if same_model_copy_button != copy_button:
		return _failure("Config tab should not rebuild client cards when the rendered model signature is unchanged.")
	_instance.call("_show_content_copy_button", copy_button_ref)
	var changed_model: Dictionary = base_model.duplicate(true)
	changed_model["desktop_clients"][0]["install_status_text"] = "Installed to\nC:/Users/Test/AppData/Roaming/Cursor/User/changed-mcp.json"
	_instance.apply_model(changed_model)
	await tree.process_frame
	await tree.process_frame
	var rebuilt_desktop_clients = _instance.get_node("Scroll/Margin/Content/DesktopCard/DesktopCardMargin/DesktopCardBody/DesktopClients") as VBoxContainer
	var rebuilt_copy_button = _find_button(rebuilt_desktop_clients.get_child(0).find_children("*", "Button", true, false), "Copy")
	if rebuilt_copy_button == null or rebuilt_copy_button == copy_button:
		return _failure("Config tab content copy button should be recreated only after a rendered model change.")
	var rebuilt_content_panel := _find_content_panel_for_copy_button(rebuilt_copy_button)
	if rebuilt_content_panel == null:
		return _failure("Config tab rebuilt copy button should stay anchored inside the generated content panel.")
	if not rebuilt_copy_button.visible:
		return _failure("Config tab content copy button should preserve hover visibility across a rendered model rebuild.")

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
		if button != null and (button.text == text or button.tooltip_text == text):
			return button
	return null


func _find_content_panel_for_copy_button(button: Button) -> PanelContainer:
	var parent := button.get_parent()
	while parent != null:
		var panel := parent as PanelContainer
		if panel != null:
			return panel
		parent = parent.get_parent()
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
