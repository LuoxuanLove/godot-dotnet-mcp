@tool
extends VBoxContainer

signal start_requested
signal restart_requested
signal stop_requested
signal full_reload_requested
signal clear_self_diagnostics_requested
signal copy_requested(text: String, source: String)

const ServerTabModelProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/ui/server_tab_model_projection.gd")
const LAYOUT_WIDTH_BUCKET := 48.0
const STATUS_LABEL_WIDTH := 96.0

@onready var _self_diag_title: Label = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody/SelfDiagnosticsHeader/SelfDiagnosticsTitle") as Label
@onready var _self_diag_badge: Label = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody/SelfDiagnosticsHeader/SelfDiagnosticsBadge") as Label
@onready var _self_diag_copy_button: Button = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody/SelfDiagnosticsHeader/SelfDiagnosticsCopyButton") as Button
@onready var _self_diag_clear_button: Button = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody/SelfDiagnosticsHeader/SelfDiagnosticsClearButton") as Button
@onready var _self_diag_summary: Label = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody/SelfDiagnosticsSummary") as Label
@onready var _self_diag_details: Label = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody/SelfDiagnosticsDetails") as Label
@onready var _self_diag_divider: HSeparator = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody/SelfDiagnosticsDivider") as HSeparator
@onready var _overview_buttons: HBoxContainer = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/OverviewButtonsCenter/OverviewButtons") as HBoxContainer
@onready var _state_value: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/ServerStateRow/ServerStateValue") as Label
@onready var _endpoint_value: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/EndpointRow/EndpointValue") as Label
@onready var _connections_value: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/ConnectionsRow/ConnectionsValue") as Label
@onready var _requests_value: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/RequestsRow/RequestsValue") as Label
@onready var _last_request_value: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/LastRequestRow/LastRequestValue") as Label
@onready var _start_button: Button = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/OverviewButtonsCenter/OverviewButtons/StartButton") as Button
@onready var _restart_button: Button = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/OverviewButtonsCenter/OverviewButtons/RestartButton") as Button
@onready var _full_reload_button: Button = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/OverviewButtonsCenter/OverviewButtons/FullReloadButton") as Button
@onready var _status_section_title: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusSectionTitle") as Label
@onready var _server_state_title: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/ServerStateRow/ServerStateTitle") as Label
@onready var _endpoint_title: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/EndpointRow/EndpointTitle") as Label
@onready var _connections_title: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/ConnectionsRow/ConnectionsTitle") as Label
@onready var _requests_title: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/RequestsRow/RequestsTitle") as Label
@onready var _last_request_title: Label = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/LastRequestRow/LastRequestTitle") as Label
@onready var _diagnostics_card: PanelContainer = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard") as PanelContainer
@onready var _status_card: PanelContainer = get_node_or_null("Scroll/Margin/Content/StatusCard") as PanelContainer
@onready var _diagnostics_card_margin: MarginContainer = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin") as MarginContainer
@onready var _status_card_margin: MarginContainer = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin") as MarginContainer
@onready var _diagnostics_card_body: VBoxContainer = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody") as VBoxContainer
@onready var _status_card_body: VBoxContainer = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody") as VBoxContainer
@onready var _margin: MarginContainer = _get_margin_node()
@onready var _content: VBoxContainer = _get_content_node()
@onready var _status_center: Control = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter") as Control
@onready var _overview_buttons_center: Control = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/OverviewButtonsCenter") as Control
@onready var _status_grid: VBoxContainer = get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid") as VBoxContainer
@onready var _status_rows: Array[HBoxContainer] = [
	get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/ServerStateRow") as HBoxContainer,
	get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/EndpointRow") as HBoxContainer,
	get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/ConnectionsRow") as HBoxContainer,
	get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/RequestsRow") as HBoxContainer,
	get_node_or_null("Scroll/Margin/Content/StatusCard/StatusCardMargin/StatusCardBody/StatusCenter/StatusGrid/LastRequestRow") as HBoxContainer,
]

var _current_scale := -1.0
var _current_layout_key := -1
var _layout_update_queued := false
var _self_diag_copy_text := ""
var _is_running := false
var _pending_model: Dictionary = {}
var _pending_model_apply_queued := false
var _projection_service := ServerTabModelProjectionServiceScript.new()


func _ready() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	resized.connect(_on_resized)
	_start_button.pressed.connect(_on_start_button_pressed)
	_restart_button.pressed.connect(_on_restart_button_pressed)
	_full_reload_button.pressed.connect(_on_full_reload_button_pressed)
	_self_diag_copy_button.pressed.connect(_on_self_diag_copy_pressed)
	_self_diag_clear_button.pressed.connect(_on_self_diag_clear_pressed)
	_apply_fill_width_flags()
	_queue_pending_model_apply()


func _apply_fill_width_flags() -> void:
	var fill_controls: Array[Control] = [
		_content,
		_status_center,
		_overview_buttons_center,
		_overview_buttons,
		_status_grid,
		_state_value,
		_endpoint_value,
		_connections_value,
		_requests_value,
		_last_request_value,
		_start_button,
		_restart_button,
		_full_reload_button,
	]
	for control in fill_controls:
		if control != null:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for status_row in _status_rows:
		if status_row != null:
			status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func apply_model(model: Dictionary) -> void:
	if not is_node_ready() or not _has_required_controls():
		_pending_model = model.duplicate(true)
		_queue_pending_model_apply()
		return

	var localization = model.get("localization")
	var is_running := bool(model.get("is_running", false))
	var editor_scale := float(model.get("editor_scale", 1.0))
	_is_running = is_running

	if not is_equal_approx(_current_scale, editor_scale):
		_apply_editor_scale(editor_scale)
	else:
		_apply_responsive_layout()

	var projection: Dictionary = _projection_service.project(model)
	var overview: Dictionary = projection.get("overview", {})
	var self_diagnostics: Dictionary = projection.get("self_diagnostics", {})

	_self_diag_title.text = localization.get_text("self_diag_title")
	_self_diag_copy_button.text = localization.get_text("self_diag_copy")
	_self_diag_clear_button.text = localization.get_text("self_diag_clear")
	_status_section_title.text = localization.get_text("plugin_overview_title")
	_server_state_title.text = localization.get_text("plugin_overview_health_label")
	_endpoint_title.text = localization.get_text("plugin_overview_service_label")
	_connections_title.text = "%s:" % localization.get_text("total_connections_short")
	_requests_title.text = localization.get_text("plugin_overview_config_label")
	_last_request_title.text = localization.get_text("plugin_overview_activity_label")

	_state_value.text = str(overview.get("health_text", ""))
	_endpoint_value.text = str(overview.get("service_text", ""))
	_connections_value.text = str(overview.get("connections_text", ""))
	_requests_value.text = str(overview.get("config_text", ""))
	_last_request_value.text = str(overview.get("activity_text", ""))

	_start_button.disabled = false
	_restart_button.disabled = not is_running
	_start_button.text = localization.get_text("btn_close") if is_running else localization.get_text("btn_start")
	_restart_button.text = localization.get_text("btn_restart")
	_full_reload_button.text = localization.get_text("btn_reload_plugin")

	_self_diag_copy_text = str(self_diagnostics.get("copy_text", ""))
	_apply_projected_self_diagnostics(self_diagnostics, localization)


func _apply_pending_model() -> void:
	_pending_model_apply_queued = false
	if _pending_model.is_empty():
		return
	if not is_node_ready() or not _has_required_controls():
		return
	var pending_model := _pending_model
	_pending_model = {}
	apply_model(pending_model)


func _queue_pending_model_apply() -> void:
	if _pending_model_apply_queued:
		return
	_pending_model_apply_queued = true
	_apply_pending_model.call_deferred()


func _has_required_controls() -> bool:
	for control in [
		_self_diag_title,
		_self_diag_copy_button,
		_self_diag_clear_button,
		_status_section_title,
		_server_state_title,
		_endpoint_title,
		_connections_title,
		_requests_title,
		_last_request_title,
		_state_value,
		_endpoint_value,
		_connections_value,
		_requests_value,
		_last_request_value,
		_start_button,
		_restart_button,
		_full_reload_button,
	]:
		if control == null:
			return false
	return true

func _apply_projected_self_diagnostics(self_diagnostics: Dictionary, localization) -> void:
	var badge_text = str(self_diagnostics.get("badge_text", ""))
	_self_diag_badge.text = badge_text
	_self_diag_summary.text = str(self_diagnostics.get("summary_text", localization.get_text("self_diag_empty")))
	_self_diag_details.text = str(self_diagnostics.get("details_text", ""))
	_self_diag_clear_button.disabled = bool(self_diagnostics.get("clear_disabled", true))
	if badge_text.is_empty():
		return
	_self_diag_badge.add_theme_color_override("font_color", self_diagnostics.get("badge_color", get_theme_color("accent_color", "Editor")))

func _on_start_button_pressed() -> void:
	if _is_running:
		stop_requested.emit()
	else:
		start_requested.emit()


func _on_restart_button_pressed() -> void:
	restart_requested.emit()


func _on_full_reload_button_pressed() -> void:
	full_reload_requested.emit()


func _get_margin_node() -> MarginContainer:
	return get_node_or_null("Scroll/Margin") as MarginContainer


func _get_content_node() -> VBoxContainer:
	return get_node_or_null("Scroll/Margin/Content") as VBoxContainer


func _apply_editor_scale(scale: float) -> void:
	_current_scale = scale
	_current_layout_key = -1

	if _margin == null or _content == null:
		return

	_margin.add_theme_constant_override("margin_left", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_right", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
	_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))

	_content.add_theme_constant_override("separation", int(round(12 * scale)))

	_apply_visual_style(scale)

	var self_diag_header = get_node_or_null("Scroll/Margin/Content/DiagnosticsCard/DiagnosticsCardMargin/DiagnosticsCardBody/SelfDiagnosticsHeader") as HBoxContainer
	if _status_grid != null:
		_status_grid.add_theme_constant_override("separation", int(round(8 * scale)))
	for status_row in _status_rows:
		if status_row != null:
			status_row.add_theme_constant_override("separation", int(round(12 * scale)))
	if _overview_buttons != null:
		_overview_buttons.add_theme_constant_override("separation", int(round(8 * scale)))
	if self_diag_header != null:
		self_diag_header.add_theme_constant_override("separation", int(round(8 * scale)))

	_apply_responsive_layout()


func _apply_responsive_layout() -> void:
	if _content == null:
		return

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
	var compact_layout: bool = available_width < 720.0 * scale
	var layout_mode := 0
	if ultra_narrow_layout:
		layout_mode += 1
	if narrow_layout:
		layout_mode += 2
	if compact_layout:
		layout_mode += 4
	var layout_key := layout_bucket * 100 + layout_mode * 10
	if _current_layout_key == layout_key:
		return
	_current_layout_key = layout_key

	var horizontal_margin: float = 10.0 * scale if ultra_narrow_layout else (12.0 * scale if narrow_layout else 14.0 * scale)
	var vertical_margin: float = 12.0 * scale
	var section_spacing: float = 10.0 * scale if ultra_narrow_layout else 12.0 * scale
	var grid_h_spacing: float = 8.0 * scale if ultra_narrow_layout else 12.0 * scale
	var grid_v_spacing: float = 6.0 * scale if ultra_narrow_layout else 8.0 * scale
	var row_spacing: float = 6.0 * scale if ultra_narrow_layout else 8.0 * scale
	var label_width: float = STATUS_LABEL_WIDTH * scale

	if _margin != null:
		_margin.add_theme_constant_override("margin_left", int(round(horizontal_margin)))
		_margin.add_theme_constant_override("margin_right", int(round(horizontal_margin)))
		_margin.add_theme_constant_override("margin_top", int(round(vertical_margin)))
		_margin.add_theme_constant_override("margin_bottom", int(round(vertical_margin)))
	_content.add_theme_constant_override("separation", int(round(section_spacing)))
	if _overview_buttons != null:
		_overview_buttons.add_theme_constant_override("separation", int(round(row_spacing)))
	if _status_grid != null:
		_status_grid.add_theme_constant_override("separation", int(round(grid_v_spacing)))
	for status_row in _status_rows:
		if status_row != null:
			status_row.add_theme_constant_override("separation", int(round(grid_h_spacing)))

	if _status_center != null:
		_status_center.custom_minimum_size.x = 0.0
	if _overview_buttons_center != null:
		_overview_buttons_center.custom_minimum_size.x = 0.0
	if _overview_buttons != null:
		_overview_buttons.custom_minimum_size.x = 0.0
	if _status_grid != null:
		_status_grid.custom_minimum_size.x = 0.0

	var status_titles = [_server_state_title, _endpoint_title, _connections_title, _requests_title, _last_request_title]
	for title_label in status_titles:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.custom_minimum_size.x = label_width

	for value_label in [_state_value, _endpoint_value, _connections_value, _requests_value, _last_request_value]:
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x = 0.0

	for button in [_start_button, _restart_button, _full_reload_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size.x = 0.0
		button.custom_minimum_size.y = 0.0
	for button in [_self_diag_copy_button, _self_diag_clear_button]:
		button.custom_minimum_size.y = 0.0
		button.custom_minimum_size.x = 72.0 * scale


func _apply_visual_style(scale: float) -> void:
	begin_bulk_theme_override()
	_diagnostics_card.add_theme_stylebox_override("panel", _make_theme_panel_style(scale))
	_status_card.add_theme_stylebox_override("panel", _make_theme_panel_style(scale))
	for card_margin in [_diagnostics_card_margin, _status_card_margin]:
		card_margin.add_theme_constant_override("margin_left", int(round(14 * scale)))
		card_margin.add_theme_constant_override("margin_right", int(round(14 * scale)))
		card_margin.add_theme_constant_override("margin_top", int(round(12 * scale)))
		card_margin.add_theme_constant_override("margin_bottom", int(round(12 * scale)))
	for card_body in [_diagnostics_card_body, _status_card_body]:
		card_body.add_theme_constant_override("separation", int(round(10 * scale)))
	for title in [_self_diag_title, _status_section_title]:
		title.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
		title.remove_theme_font_size_override("font_size")
	for label in [_server_state_title, _endpoint_title, _connections_title, _requests_title, _last_request_title]:
		label.add_theme_color_override("font_color", _get_muted_text_color())
	for label in [_state_value, _endpoint_value, _connections_value, _requests_value, _last_request_value, _self_diag_summary, _self_diag_details]:
		label.add_theme_color_override("font_color", get_theme_color("font_color", "Label"))
	end_bulk_theme_override()


func _make_theme_panel_style(scale: float) -> StyleBox:
	var style := get_theme_stylebox("panel", "PanelContainer").duplicate() as StyleBox
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _get_muted_text_color() -> Color:
	return get_theme_color("font_disabled_color", "Editor")


func _on_resized() -> void:
	if _layout_update_queued:
		return
	_layout_update_queued = true
	call_deferred("_apply_queued_responsive_layout")


func _apply_queued_responsive_layout() -> void:
	_layout_update_queued = false
	_apply_responsive_layout()


func _on_self_diag_copy_pressed() -> void:
	if _self_diag_copy_text.is_empty():
		return
	var source_name := "Plugin Self Diagnostics"
	if _state_value != null:
		source_name = _self_diag_title.text.strip_edges()
	if source_name.is_empty():
		source_name = "Plugin Self Diagnostics"
	copy_requested.emit(_self_diag_copy_text, source_name)


func _on_self_diag_clear_pressed() -> void:
	clear_self_diagnostics_requested.emit()
