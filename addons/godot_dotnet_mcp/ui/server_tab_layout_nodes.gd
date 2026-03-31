@tool
extends RefCounted
class_name ServerTabLayoutNodes

var margin: MarginContainer = null
var content: VBoxContainer = null
var self_diagnostics_header: HBoxContainer = null
var status_center: CenterContainer = null
var overview_buttons_center: CenterContainer = null
var overview_buttons: GridContainer = null
var central_server_center: CenterContainer = null
var central_server_content: VBoxContainer = null
var central_server_buttons: GridContainer = null
var settings_center: CenterContainer = null
var settings_content: VBoxContainer = null
var section_divider: HSeparator = null
var central_server_divider: HSeparator = null
var status_grid: GridContainer = null
var central_server_status_row: GridContainer = null
var settings_grid: GridContainer = null
var log_level_row: GridContainer = null
var advanced_content: VBoxContainer = null
var permission_level_row: GridContainer = null
var language_row: GridContainer = null
var advanced_section_title: Label = null
var permission_level_label: Label = null
var port_spin: SpinBox = null
var log_level_option: OptionButton = null
var permission_level_option: OptionButton = null
var language_option: OptionButton = null
var status_titles: Array[Label] = []
var settings_titles: Array[Label] = []
var status_values: Array[Label] = []
var central_server_titles: Array[Label] = []
var central_server_values: Array[Label] = []
var overview_action_buttons: Array[Button] = []
var central_server_action_buttons: Array[Button] = []
var self_diagnostic_action_buttons: Array[Button] = []


func populate_from(tab: Node):
	margin = _find_child(tab, "Margin") as MarginContainer
	content = _find_child(tab, "Content") as VBoxContainer
	self_diagnostics_header = _find_child(tab, "SelfDiagnosticsHeader") as HBoxContainer
	status_center = _find_child(tab, "StatusCenter") as CenterContainer
	overview_buttons_center = _find_child(tab, "OverviewButtonsCenter") as CenterContainer
	overview_buttons = _find_child(tab, "OverviewButtons") as GridContainer
	central_server_center = _find_child(tab, "CentralServerContentCenter") as CenterContainer
	central_server_content = _find_child(tab, "CentralServerContent") as VBoxContainer
	central_server_buttons = _find_child(tab, "CentralServerButtons") as GridContainer
	settings_center = _find_child(tab, "SettingsCenter") as CenterContainer
	settings_content = _find_child(tab, "SettingsContent") as VBoxContainer
	section_divider = _find_child(tab, "SectionDivider") as HSeparator
	central_server_divider = _find_child(tab, "CentralServerSectionDivider") as HSeparator
	status_grid = _find_child(tab, "StatusGrid") as GridContainer
	central_server_status_row = _find_child(tab, "CentralServerStatusRow") as GridContainer
	settings_grid = _find_child(tab, "SettingsGrid") as GridContainer
	log_level_row = _find_child(tab, "LogLevelRow") as GridContainer
	advanced_content = _find_child(tab, "AdvancedContent") as VBoxContainer
	permission_level_row = _find_child(tab, "PermissionLevelRow") as GridContainer
	language_row = _find_child(tab, "LanguageRow") as GridContainer
	advanced_section_title = _find_child(tab, "AdvancedSectionTitle") as Label
	permission_level_label = _find_child(tab, "PermissionLevelLabel") as Label
	port_spin = _find_child(tab, "PortSpin") as SpinBox
	log_level_option = _find_child(tab, "LogLevelOption") as OptionButton
	permission_level_option = _find_child(tab, "PermissionLevelOption") as OptionButton
	language_option = _find_child(tab, "LanguageOption") as OptionButton
	status_titles = [
		_find_child(tab, "ServerStateTitle") as Label,
		_find_child(tab, "EndpointTitle") as Label,
		_find_child(tab, "ConnectionsTitle") as Label,
		_find_child(tab, "RequestsTitle") as Label,
		_find_child(tab, "LastRequestTitle") as Label,
	]
	settings_titles = [
		_find_child(tab, "PortLabel") as Label,
		_find_child(tab, "LogLevelLabel") as Label,
		_find_child(tab, "LanguageLabel") as Label,
	]
	status_values = [
		_find_child(tab, "ServerStateValue") as Label,
		_find_child(tab, "EndpointValue") as Label,
		_find_child(tab, "ConnectionsValue") as Label,
		_find_child(tab, "RequestsValue") as Label,
		_find_child(tab, "LastRequestValue") as Label,
	]
	central_server_titles = [
		_find_child(tab, "CentralServerLocalStatusTitle") as Label,
		_find_child(tab, "CentralServerInstallVersionTitle") as Label,
		_find_child(tab, "CentralServerInstallDirTitle") as Label,
		_find_child(tab, "CentralServerInstallSourceTitle") as Label,
		_find_child(tab, "CentralServerStatusTitle") as Label,
		_find_child(tab, "CentralServerEndpointTitle") as Label,
		_find_child(tab, "CentralServerProjectTitle") as Label,
		_find_child(tab, "CentralServerSessionTitle") as Label,
		_find_child(tab, "CentralServerMessageTitle") as Label,
		_find_child(tab, "CentralServerLocalCommandTitle") as Label,
	]
	central_server_values = [
		_find_child(tab, "CentralServerLocalStatusValue") as Label,
		_find_child(tab, "CentralServerInstallVersionValue") as Label,
		_find_child(tab, "CentralServerInstallDirValue") as Label,
		_find_child(tab, "CentralServerInstallSourceValue") as Label,
		_find_child(tab, "CentralServerStatusValue") as Label,
		_find_child(tab, "CentralServerEndpointValue") as Label,
		_find_child(tab, "CentralServerProjectValue") as Label,
		_find_child(tab, "CentralServerSessionValue") as Label,
		_find_child(tab, "CentralServerMessageValue") as Label,
		_find_child(tab, "CentralServerLocalCommandValue") as Label,
	]
	overview_action_buttons = [
		_find_child(tab, "StartButton") as Button,
		_find_child(tab, "RestartButton") as Button,
		_find_child(tab, "FullReloadButton") as Button,
	]
	central_server_action_buttons = [
		_find_child(tab, "CentralServerDetectButton") as Button,
		_find_child(tab, "CentralServerInstallButton") as Button,
		_find_child(tab, "CentralServerStartButton") as Button,
		_find_child(tab, "CentralServerStopButton") as Button,
		_find_child(tab, "CentralServerOpenInstallDirButton") as Button,
		_find_child(tab, "CentralServerOpenLogsButton") as Button,
	]
	self_diagnostic_action_buttons = [
		_find_child(tab, "SelfDiagnosticsCopyButton") as Button,
		_find_child(tab, "SelfDiagnosticsClearButton") as Button,
	]
	return self


func is_resolved() -> bool:
	return margin != null \
		and content != null \
		and self_diagnostics_header != null \
		and status_center != null \
		and overview_buttons_center != null \
		and overview_buttons != null \
		and central_server_center != null \
		and central_server_content != null \
		and central_server_buttons != null \
		and settings_center != null \
		and settings_content != null \
		and section_divider != null \
		and central_server_divider != null \
		and status_grid != null \
		and central_server_status_row != null \
		and settings_grid != null \
		and log_level_row != null \
		and advanced_content != null \
		and permission_level_row != null \
		and language_row != null \
		and advanced_section_title != null \
		and permission_level_label != null \
		and port_spin != null \
		and log_level_option != null \
		and permission_level_option != null \
		and language_option != null \
		and _all_controls_resolved(status_titles) \
		and _all_controls_resolved(settings_titles) \
		and _all_controls_resolved(status_values) \
		and _all_controls_resolved(central_server_titles) \
		and _all_controls_resolved(central_server_values) \
		and _all_controls_resolved(overview_action_buttons) \
		and _all_controls_resolved(central_server_action_buttons) \
		and _all_controls_resolved(self_diagnostic_action_buttons)


static func _find_child(tab: Node, node_name: String) -> Node:
	return tab.find_child(node_name, true, false)


static func _all_controls_resolved(controls: Array) -> bool:
	for control in controls:
		if control == null:
			return false
	return true
