@tool
extends VBoxContainer

signal port_changed(value: int)
signal log_level_changed(level: String)
signal language_changed(language_code: String)
signal update_source_changed(source: String)
signal update_custom_branch_changed(branch: String)
signal update_interaction_refresh_requested
signal update_check_requested
signal update_apply_requested
signal update_compare_target_selected(kind: String, target_ref: String, target_commit: String)
signal update_switch_requested(kind: String, target_ref: String, target_commit: String)

const SettingsTabModelProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/ui/settings_tab_model_projection.gd")
const LAYOUT_WIDTH_BUCKET := 48.0
const SETTING_LABEL_WIDTH := 112.0
const SETTING_FIELD_WIDTH := 180.0
const UPDATE_SELECTOR_POPUP_MAX_VISIBLE_ITEMS := 12
const UPDATE_SELECTOR_POPUP_ROW_HEIGHT := 28.0
const UPDATE_SELECTOR_POPUP_VERTICAL_PADDING := 12.0
const UPDATE_SWITCH_BUTTON_ID := 1

@onready var _margin: MarginContainer = %Margin
@onready var _content: VBoxContainer = %Content
@onready var _general_card: PanelContainer = %GeneralCard
@onready var _general_card_margin: MarginContainer = %GeneralCardMargin
@onready var _general_card_body: VBoxContainer = %GeneralCardBody
@onready var _general_title: Label = %GeneralTitle
@onready var _general_form: GridContainer = %GeneralForm
@onready var _port_label: Label = %PortLabel
@onready var _port_spin: SpinBox = %PortSpin
@onready var _log_level_label: Label = %LogLevelLabel
@onready var _log_level_option: OptionButton = %LogLevelOption
@onready var _language_label: Label = %LanguageLabel
@onready var _language_option: OptionButton = %LanguageOption
@onready var _updates_card: PanelContainer = %UpdatesCard
@onready var _updates_card_margin: MarginContainer = %UpdatesCardMargin
@onready var _updates_card_body: VBoxContainer = %UpdatesCardBody
@onready var _updates_title: Label = %UpdatesTitle
@onready var _current_summary_grid: GridContainer = %CurrentSummaryGrid
@onready var _current_branch_label: Label = %CurrentBranchLabel
@onready var _current_branch_value: Label = %CurrentBranchValue
@onready var _current_version_label: Label = %CurrentVersionLabel
@onready var _current_version_value: Label = %CurrentVersionValue
@onready var _update_channel_tabs: TabBar = %UpdateChannelTabs
@onready var _update_channel_status: Label = %UpdateChannelStatus
@onready var _custom_branch_row: GridContainer = %CustomBranchRow
@onready var _custom_branch_label: Label = %CustomBranchLabel
@onready var _custom_branch_value: OptionButton = %CustomBranchValue
@onready var _update_action_grid: GridContainer = %UpdateActionGrid
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_margin: MarginContainer = %StatusMargin
@onready var _updates_status: Label = %UpdatesStatus
@onready var _updates_progress: ProgressBar = %UpdatesProgress
@onready var _version_toolbar: GridContainer = %VersionToolbar
@onready var _updates_audit: Label = %UpdatesAudit
@onready var _version_tree: Tree = %VersionTree
@onready var _version_empty_label: Label = %VersionEmptyLabel
@onready var _check_button: Button = %CheckButton
@onready var _prepare_button: Button = %PrepareButton
@onready var _apply_button: Button = %ApplyButton

var _language_syncing := false
var _log_level_syncing := false
var _channel_syncing := false
var _custom_branch_syncing := false
var _version_tree_syncing := false
var _current_scale := -1.0
var _current_layout_key := -1
var _layout_update_queued := false
var _fallback_switch_icon: Texture2D = null
var _projection_service := SettingsTabModelProjectionServiceScript.new()
var _version_switch_queued := false
var _pending_version_switch_row: Dictionary = {}


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	resized.connect(_on_resized)
	_port_spin.value_changed.connect(_on_port_spin_changed)
	_log_level_option.item_selected.connect(_on_log_level_option_selected)
	_language_option.item_selected.connect(_on_language_option_selected)
	_update_channel_tabs.tab_changed.connect(_on_update_channel_tab_changed)
	_custom_branch_value.item_selected.connect(_on_custom_branch_option_selected)
	_version_tree.button_clicked.connect(_on_version_tree_button_clicked)
	_version_tree.cell_selected.connect(_on_version_tree_cell_selected)
	_check_button.pressed.connect(_on_check_button_pressed)
	_apply_button.pressed.connect(_on_apply_button_pressed)
	_check_button.text = "Refresh List"
	_check_button.visible = true
	_check_button.disabled = true
	_prepare_button.text = ""
	_prepare_button.visible = false
	_prepare_button.disabled = true
	_apply_button.text = "One-click Update"
	_apply_button.disabled = true
	_apply_fill_width_flags()


func apply_model(model: Dictionary) -> void:
	if not is_node_ready() or not _has_required_controls():
		return
	var localization = model.get("localization")
	if localization == null:
		return
	var editor_scale := float(model.get("editor_scale", 1.0))
	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

	var projection: Dictionary = _projection_service.project(model)
	var settings: Dictionary = projection.get("settings", {})
	var options: Dictionary = projection.get("options", {})
	var updates: Dictionary = projection.get("updates", {})

	_general_title.text = localization.get_text("settings_general_title")
	_port_label.text = localization.get_text("port")
	_log_level_label.text = localization.get_text("log_level")
	_language_label.text = localization.get_text("language")
	_updates_title.text = localization.get_text("settings_updates_title")
	_current_branch_label.text = _localized(localization, "settings_update_current_branch", "Current Branch:")
	_current_version_label.text = _localized(localization, "settings_update_current_version", "Current Version:")
	_custom_branch_label.text = localization.get_text("settings_update_custom_branch")
	_check_button.text = str(updates.get("refresh_text", "Refresh List"))
	_check_button.visible = true
	_prepare_button.text = ""
	_apply_button.text = _get_update_apply_text(localization)

	_port_spin.set_value_no_signal(int(settings.get("port", 3000)))
	_log_level_syncing = true
	_apply_projected_options(_log_level_option, options.get("log_levels", []))
	_log_level_syncing = false
	_language_syncing = true
	_apply_projected_options(_language_option, options.get("languages", []))
	_language_syncing = false
	_channel_syncing = true
	_apply_update_channel_tabs(str(updates.get("active_channel", "stable")), localization)
	_channel_syncing = false
	_custom_branch_syncing = true
	_apply_projected_options(_custom_branch_value, options.get("update_branches", []))
	_custom_branch_syncing = false
	_apply_update_selector_popup_limits()

	_current_branch_value.text = str(updates.get("current_branch", ""))
	_current_version_value.text = _format_current_version_summary(updates, localization)
	_current_branch_label.visible = str(updates.get("active_channel", "stable")) == "development"
	_current_branch_value.visible = _current_branch_label.visible
	_current_branch_value.tooltip_text = _current_branch_value.text
	_current_version_value.tooltip_text = _current_version_value.text
	_updates_status.text = _join_visible_update_status(
		str(updates.get("status_text", "")),
		str(updates.get("details_text", ""))
	)
	_status_panel.visible = not _updates_status.text.strip_edges().is_empty()
	_updates_status.tooltip_text = _updates_status.text
	_updates_audit.text = str(updates.get("audit_text", ""))
	_updates_audit.visible = not _updates_audit.text.strip_edges().is_empty()
	_updates_audit.tooltip_text = _updates_audit.text
	_updates_progress.visible = bool(updates.get("progress_visible", false))
	_updates_progress.value = clampf(float(updates.get("progress", 0.0)), 0.0, 1.0) * 100.0
	_apply_update_source_rows(str(updates.get("source", "latest_stable")))
	_apply_version_rows(updates.get("version_rows", []), str(updates.get("empty_text", "")), localization)
	_check_button.disabled = not bool(updates.get("check_enabled", false))
	_prepare_button.disabled = true
	_prepare_button.visible = false
	_apply_button.disabled = not bool(updates.get("apply_enabled", false))


func _has_required_controls() -> bool:
	for control in [
		_margin,
		_content,
		_general_card,
		_general_form,
		_general_title,
		_port_label,
		_port_spin,
		_log_level_label,
		_log_level_option,
		_language_label,
		_language_option,
		_updates_card,
		_updates_title,
		_current_summary_grid,
		_current_branch_label,
		_current_branch_value,
		_current_version_label,
		_current_version_value,
		_update_channel_tabs,
		_update_channel_status,
		_version_toolbar,
		_custom_branch_row,
		_custom_branch_label,
		_custom_branch_value,
		_update_action_grid,
		_status_panel,
		_updates_status,
		_updates_progress,
		_updates_audit,
		_version_tree,
		_version_empty_label,
		_check_button,
		_prepare_button,
		_apply_button,
	]:
		if control == null:
			return false
	return true


func _apply_fill_width_flags() -> void:
	for control in [
		_content,
		_general_card,
		_updates_card,
		_port_spin,
		_log_level_option,
		_language_option,
		_custom_branch_value,
		_update_action_grid,
		_status_panel,
		_updates_progress,
		_version_toolbar,
		_version_tree,
		_check_button,
		_prepare_button,
		_apply_button,
	]:
		if control != null:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _get_update_apply_text(localization) -> String:
	var text := _localized(localization, "settings_update_one_click", "One-click Update")
	if text == "settings_update_one_click":
		return "One-click Update"
	return text


func _join_visible_update_status(primary_status: String, diagnostic_text: String) -> String:
	var primary := primary_status.strip_edges()
	var diagnostic := diagnostic_text.strip_edges()
	if diagnostic.is_empty() or diagnostic == primary:
		return primary
	if primary.is_empty():
		return diagnostic
	return "%s\n%s" % [primary, diagnostic]


func _localized(localization, key: String, fallback: String) -> String:
	if localization == null:
		return fallback
	var text := str(localization.get_text(key)).strip_edges()
	if text.is_empty() or text == key:
		return fallback
	return text


func _format_current_version_summary(updates: Dictionary, localization) -> String:
	var version := str(updates.get("current_version", "")).strip_edges()
	var commit := str(updates.get("current_commit", "")).strip_edges()
	if version.is_empty():
		version = _localized(localization, "settings_update_unavailable", "Unavailable")
	if commit.is_empty():
		return version
	return "%s (%s)" % [version, commit.substr(0, mini(7, commit.length()))]


func _apply_update_channel_tabs(active_channel: String, localization) -> void:
	_update_channel_tabs.set_tab_title(0, _localized(localization, "settings_update_channel_stable", "Release"))
	_update_channel_tabs.set_tab_title(1, _localized(localization, "settings_update_channel_development", "Development"))
	var target_index := 1 if active_channel == "development" else 0
	if _update_channel_tabs.current_tab != target_index:
		_update_channel_tabs.current_tab = target_index
	_update_channel_status.text = _get_update_channel_status_text(active_channel, localization)
	_update_channel_status.visible = false


func _get_update_channel_status_text(active_channel: String, localization) -> String:
	if active_channel == "development":
		return _localized(localization, "settings_update_channel_development_selected", "Development selected")
	return _localized(localization, "settings_update_channel_stable_selected", "Stable selected")


func _apply_version_rows(rows_value, empty_text: String, localization) -> void:
	_version_tree_syncing = true
	_version_tree.clear()
	_version_tree.columns = 3
	_version_tree.set_column_title(0, _localized(localization, "settings_update_col_version", "Version ID"))
	_version_tree.set_column_title(1, _localized(localization, "settings_update_col_message", "Update"))
	_version_tree.set_column_title(2, _localized(localization, "settings_update_col_action", "Action"))
	_version_tree.column_titles_visible = true
	_version_tree.set_column_expand(0, false)
	_version_tree.set_column_custom_minimum_width(0, int(round(96.0 * _effective_scale())))
	_version_tree.set_column_expand(1, true)
	_version_tree.set_column_expand(2, false)
	_version_tree.set_column_custom_minimum_width(2, int(round(84.0 * _effective_scale())))
	var root := _version_tree.create_item()
	if root == null:
		_version_tree.visible = false
		_version_empty_label.visible = true
		_version_empty_label.text = empty_text
		_version_tree_syncing = false
		return
	var row_count := 0
	if rows_value is Array:
		for raw_row in rows_value as Array:
			if raw_row is Dictionary:
				if _add_version_tree_row(root, raw_row as Dictionary, localization):
					row_count += 1
	_version_tree.visible = row_count > 0
	_version_empty_label.visible = row_count == 0
	_version_empty_label.text = empty_text
	_version_tree_syncing = false


func _add_version_tree_row(root: TreeItem, row: Dictionary, localization) -> bool:
	if root == null:
		return false
	var item := _version_tree.create_item(root)
	if item == null:
		return false
	item.set_text(0, str(row.get("id", "")))
	item.set_text(1, str(row.get("title", "")))
	var date_text := str(row.get("date", "")).strip_edges()
	if not date_text.is_empty():
		item.set_tooltip_text(1, date_text)
	item.set_metadata(0, row.duplicate(true))
	if bool(row.get("current", false)):
		var highlight := _get_accent_color()
		for column in range(0, 3):
			item.set_custom_color(column, highlight)
		item.set_text(2, _localized(localization, "settings_update_current_marker", "Current"))
	elif bool(row.get("switch_enabled", true)):
		var switch_text := _localized(localization, "settings_update_switch", "Switch")
		item.set_text(2, switch_text)
		item.add_button(2, _get_switch_icon(), UPDATE_SWITCH_BUTTON_ID, false, switch_text)
	if bool(row.get("selected", false)):
		item.select(0)
	return true


func _apply_update_source_rows(source: String) -> void:
	if _custom_branch_row != null:
		_custom_branch_row.visible = source == "custom_branch"


func _apply_update_selector_popup_limits() -> void:
	_apply_option_popup_height_limit(_custom_branch_value, UPDATE_SELECTOR_POPUP_MAX_VISIBLE_ITEMS)


func _apply_option_popup_height_limit(option_button: OptionButton, max_visible_items: int) -> void:
	if option_button == null or max_visible_items <= 0:
		return
	var popup := option_button.get_popup()
	if popup == null:
		return
	var max_size := popup.max_size
	max_size.y = _get_option_popup_height_limit(max_visible_items)
	popup.max_size = max_size


func _get_option_popup_height_limit(max_visible_items: int) -> int:
	var scale := _current_scale if _current_scale > 0.0 else 1.0
	var row_height := UPDATE_SELECTOR_POPUP_ROW_HEIGHT * scale
	var vertical_padding := UPDATE_SELECTOR_POPUP_VERTICAL_PADDING * scale
	return int(ceil(row_height * float(max_visible_items) + vertical_padding))


func _apply_projected_options(option_button: OptionButton, projected_items: Array) -> void:
	option_button.clear()
	var selected_index := -1
	for item_index in range(projected_items.size()):
		var item: Dictionary = projected_items[item_index]
		option_button.add_item(str(item.get("text", "")), item_index)
		option_button.set_item_metadata(item_index, item.get("value", ""))
		option_button.set_item_disabled(item_index, bool(item.get("disabled", false)))
		if bool(item.get("selected", false)):
			selected_index = item_index
	if selected_index >= 0:
		option_button.select(selected_index)
	elif option_button.get_item_count() > 0:
		option_button.select(0)


func _on_port_spin_changed(value: float) -> void:
	port_changed.emit(int(value))


func _on_language_option_selected(index: int) -> void:
	if _language_syncing:
		return
	language_changed.emit(str(_language_option.get_item_metadata(index)))


func _on_log_level_option_selected(index: int) -> void:
	if _log_level_syncing:
		return
	log_level_changed.emit(str(_log_level_option.get_item_metadata(index)))


func _on_update_channel_tab_changed(index: int) -> void:
	if _channel_syncing:
		return
	var source := "custom_branch" if index == 1 else "latest_stable"
	_apply_update_source_rows(source)
	update_source_changed.emit(source)


func _on_custom_branch_option_selected(index: int) -> void:
	if _custom_branch_syncing:
		return
	var branch := str(_custom_branch_value.get_item_metadata(index))
	if branch.is_empty():
		return
	update_custom_branch_changed.emit(branch)


func _on_check_button_pressed() -> void:
	update_check_requested.emit()


func _on_apply_button_pressed() -> void:
	update_apply_requested.emit()


func _on_version_tree_button_clicked(item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	if _version_tree_syncing or id != UPDATE_SWITCH_BUTTON_ID:
		return
	_queue_version_switch(item)


func _on_version_tree_cell_selected() -> void:
	if _version_tree_syncing:
		return
	var row := _get_version_target_row(_version_tree.get_selected())
	if row.is_empty():
		return
	update_compare_target_selected.emit(str(row.get("kind", "branch")), str(row.get("ref", "")), str(row.get("commit", "")))


func _queue_version_switch(item: TreeItem) -> void:
	var row := _get_version_switch_row(item)
	if row.is_empty():
		return
	_pending_version_switch_row = row
	if _version_switch_queued:
		return
	_version_switch_queued = true
	call_deferred("_emit_queued_version_switch")


func _emit_queued_version_switch() -> void:
	_version_switch_queued = false
	var row := _pending_version_switch_row.duplicate(true)
	_pending_version_switch_row.clear()
	if row.is_empty():
		return
	update_switch_requested.emit(str(row.get("kind", "branch")), str(row.get("ref", "")), str(row.get("commit", "")))


func _get_version_switch_row(item: TreeItem) -> Dictionary:
	var row := _get_version_target_row(item)
	if row.is_empty() or not bool(row.get("switch_enabled", true)):
		return {}
	return row


func _get_version_target_row(item: TreeItem) -> Dictionary:
	if item == null:
		return {}
	var metadata = item.get_metadata(0)
	if not (metadata is Dictionary):
		return {}
	var row := metadata as Dictionary
	if str(row.get("ref", "")).strip_edges().is_empty():
		return {}
	return row.duplicate(true)


func _get_switch_icon() -> Texture2D:
	if has_theme_icon("Reload", "EditorIcons"):
		return get_theme_icon("Reload", "EditorIcons")
	if has_theme_icon("GuiRedo", "EditorIcons"):
		return get_theme_icon("GuiRedo", "EditorIcons")
	if _fallback_switch_icon == null:
		var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		image.fill(Color(1.0, 1.0, 1.0, 0.01))
		_fallback_switch_icon = ImageTexture.create_from_image(image)
	return _fallback_switch_icon


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale
	_current_layout_key = -1
	_margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	_content.add_theme_constant_override("separation", int(round(12 * scale)))
	_apply_visual_style(scale)
	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	var available_width: float = _content.size.x
	if available_width <= 0.0:
		available_width = size.x
	if available_width <= 0.0:
		return
	var scale: float = _current_scale if _current_scale > 0.0 else 1.0
	var bucket_size: float = max(16.0, LAYOUT_WIDTH_BUCKET * scale)
	var layout_bucket: int = int(floor(available_width / bucket_size))
	var ultra_narrow_layout: bool = available_width < 360.0 * scale
	var narrow_layout: bool = available_width < 560.0 * scale
	var layout_key := layout_bucket * 100 + (1 if ultra_narrow_layout else 0) + (2 if narrow_layout else 0)
	if _current_layout_key == layout_key:
		return
	_current_layout_key = layout_key

	var horizontal_margin: float = 10.0 * scale if ultra_narrow_layout else (12.0 * scale if narrow_layout else 14.0 * scale)
	var row_spacing: float = 6.0 * scale if ultra_narrow_layout else 8.0 * scale
	var label_width: float = SETTING_LABEL_WIDTH * scale
	var field_width: float = SETTING_FIELD_WIDTH * scale
	for card_margin in [_general_card_margin, _updates_card_margin]:
		card_margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
		card_margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
		card_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
		card_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	for grid in [_general_form, _current_summary_grid, _custom_branch_row, _update_action_grid, _version_toolbar]:
		grid.add_theme_constant_override("h_separation", int(round(row_spacing)))
		grid.add_theme_constant_override("v_separation", int(round(row_spacing)))
	_general_form.columns = 1 if ultra_narrow_layout else 2
	_current_summary_grid.columns = 2 if narrow_layout else 4
	_custom_branch_row.columns = 1 if ultra_narrow_layout else 2
	_update_action_grid.columns = 1 if ultra_narrow_layout else 2
	_version_toolbar.columns = 1 if ultra_narrow_layout else 2
	for label in [_port_label, _log_level_label, _language_label, _current_branch_label, _current_version_label, _custom_branch_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size.x = 0.0 if ultra_narrow_layout else label_width
	for field in [_port_spin, _log_level_option, _language_option, _custom_branch_value]:
		field.custom_minimum_size.x = 0.0 if ultra_narrow_layout else field_width
		field.custom_minimum_size.y = 0.0
	for button in [_check_button, _prepare_button, _apply_button]:
		button.custom_minimum_size.x = 0.0
		button.custom_minimum_size.y = 0.0
	_version_tree.custom_minimum_size.y = (180.0 if ultra_narrow_layout else 220.0) * scale


func _apply_visual_style(scale: float) -> void:
	begin_bulk_theme_override()
	_general_card.add_theme_stylebox_override("panel", _make_theme_panel_style(scale))
	_updates_card.add_theme_stylebox_override("panel", _make_theme_panel_style(scale))
	_status_panel.add_theme_stylebox_override("panel", _make_inset_panel_style())
	_apply_channel_tab_style(scale)
	for card_body in [_general_card_body, _updates_card_body]:
		card_body.add_theme_constant_override("separation", int(round(10 * scale)))
	for inset_margin in [_status_margin]:
		inset_margin.add_theme_constant_override("margin_left", int(round(10 * scale)))
		inset_margin.add_theme_constant_override("margin_right", int(round(10 * scale)))
		inset_margin.add_theme_constant_override("margin_top", int(round(8 * scale)))
		inset_margin.add_theme_constant_override("margin_bottom", int(round(8 * scale)))
	for title in [_general_title, _updates_title]:
		title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
		title.remove_theme_font_size_override("font_size")
	for label in [_port_label, _log_level_label, _language_label, _current_branch_label, _current_version_label, _custom_branch_label]:
		label.add_theme_color_override("font_color", _get_muted_text_color())
	for label in [_updates_status, _current_branch_value, _current_version_value]:
		label.add_theme_color_override("font_color", _get_description_text_color())
	_updates_audit.add_theme_color_override("font_color", _get_meta_text_color())
	end_bulk_theme_override()


func _apply_channel_tab_style(scale: float) -> void:
	if _update_channel_tabs == null:
		return
	_update_channel_tabs.add_theme_stylebox_override("tab_selected", _make_channel_tab_style(scale, true))
	_update_channel_tabs.add_theme_stylebox_override("tab_hovered", _make_channel_tab_style(scale, false, true))
	_update_channel_tabs.add_theme_stylebox_override("tab_unselected", _make_channel_tab_style(scale, false))
	_update_channel_tabs.add_theme_color_override("font_selected_color", _get_accent_color())
	_update_channel_tabs.add_theme_color_override("font_hovered_color", get_theme_color("font_color", "Label"))
	_update_channel_tabs.add_theme_color_override("font_unselected_color", get_theme_color("font_color", "Label"))


func _make_channel_tab_style(scale: float, selected: bool, hovered: bool = false) -> StyleBox:
	var style := StyleBoxFlat.new()
	var accent := _get_accent_color()
	var base := get_theme_color("dark_color_2", "Editor") if has_theme_color("dark_color_2", "Editor") else Color(0.12, 0.12, 0.12, 1.0)
	style.bg_color = accent.darkened(0.65) if selected else (base.lightened(0.12) if hovered else base)
	style.border_color = accent if selected else base.lightened(0.35)
	style.border_width_bottom = int(round((3.0 if selected else 1.0) * scale))
	style.corner_radius_top_left = int(round(4.0 * scale))
	style.corner_radius_top_right = int(round(4.0 * scale))
	style.content_margin_left = 12.0 * scale
	style.content_margin_right = 12.0 * scale
	style.content_margin_top = 6.0 * scale
	style.content_margin_bottom = 6.0 * scale
	return style


func _make_theme_panel_style(_scale: float) -> StyleBox:
	var style := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBox
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _make_inset_panel_style() -> StyleBox:
	var style := get_theme_stylebox("panel", "Tree").duplicate() as StyleBox
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	if style is StyleBoxFlat:
		var flat_style := style as StyleBoxFlat
		flat_style.border_color = get_theme_color("separator_color", "Editor")
		flat_style.set_border_width_all(1)
	return style


func _get_muted_text_color() -> Color:
	return _get_meta_text_color()


func _get_description_text_color() -> Color:
	var base := get_theme_color("font_color", "Label")
	var disabled := get_theme_color("font_disabled_color", "Editor")
	return base.lerp(disabled, 0.18)


func _get_meta_text_color() -> Color:
	var base := get_theme_color("font_color", "Label")
	var disabled := get_theme_color("font_disabled_color", "Editor")
	return base.lerp(disabled, 0.48)


func _effective_scale() -> float:
	return _current_scale if _current_scale > 0.0 else 1.0


func _get_accent_color() -> Color:
	if has_theme_color("accent_color", "Editor"):
		return get_theme_color("accent_color", "Editor")
	return Color(0.35, 0.62, 1.0, 1.0)


func _on_resized() -> void:
	if _layout_update_queued:
		return
	_layout_update_queued = true
	call_deferred("_apply_queued_responsive_layout")


func _apply_queued_responsive_layout() -> void:
	_layout_update_queued = false
	_apply_responsive_layout()
