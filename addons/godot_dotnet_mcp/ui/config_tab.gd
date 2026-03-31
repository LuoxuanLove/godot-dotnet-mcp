@tool
extends VBoxContainer

const ConfigTabClientCardFactory = preload("res://addons/godot_dotnet_mcp/ui/config_tab_client_card_factory.gd")

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
var _client_card_factory = ConfigTabClientCardFactory.new()


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
		container.add_child(_client_card_factory.build_client_card(
			client,
			supports_write,
			localization,
			_current_scale,
			Callable(self, "_on_client_card_action")
		))


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


func _on_client_card_action(action_name: String, client: Dictionary, client_name: String) -> void:
	var client_id = str(client.get("id", ""))
	match action_name:
		"client_action":
			config_client_action_requested.emit(client_id)
		"launch":
			config_client_launch_requested.emit(client_id)
		"path_pick":
			config_client_path_pick_requested.emit(client_id)
		"path_clear":
			config_client_path_clear_requested.emit(client_id)
		"open_config_dir":
			config_client_open_config_dir_requested.emit(client_id)
		"open_config_file":
			config_client_open_config_file_requested.emit(client_id)
		"write":
			config_write_requested.emit(client_id, str(client.get("path", "")), str(client.get("content", "")), client_name)
		"remove":
			config_remove_requested.emit(client_id, str(client.get("path", "")), client_name)
		"copy":
			copy_requested.emit(str(client.get("content", "")), client_name)


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
