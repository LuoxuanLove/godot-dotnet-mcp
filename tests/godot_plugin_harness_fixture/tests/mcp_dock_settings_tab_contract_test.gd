extends RefCounted

const MCPDockScene = preload("res://addons/godot_dotnet_mcp/ui/mcp_dock.tscn")

var _instance: VBoxContainer = null


class FakeLocalization extends RefCounted:
	const TEXTS := {
		"title": "Godot .NET MCP",
		"status_running": "Running",
		"status_stopped": "Stopped",
		"tab_server": "Home",
		"tab_tools": "Tools",
		"tab_resources": "Resources",
		"tab_prompts": "Prompts",
		"tab_config": "Config",
		"tab_settings": "Settings",
		"mcp_resources_title": "Resources",
		"mcp_resources_description": "Browse context resources.",
		"mcp_resources_counts": "Resources: %d | Templates: %d",
		"mcp_prompts_title": "Prompts",
		"mcp_prompts_description": "Browse workflows.",
		"mcp_prompts_counts": "Prompts: %d",
		"mcp_catalog_resources": "Resources",
		"mcp_catalog_resource_templates": "Resource Templates",
		"mcp_catalog_prompts": "Prompts",
		"mcp_catalog_empty": "No entries",
		"mcp_catalog_copy_id": "Copy ID",
		"mcp_catalog_kind": "Kind",
		"mcp_catalog_mime_type": "MIME",
		"mcp_catalog_arguments": "Arguments",
		"tools_enabled": "Tools: %d/%d enabled",
		"settings_general_title": "General",
		"settings_updates_title": "Updates",
		"settings_updates_description": "Discover safe update refs",
		"settings_update_source_label": "Update Source:",
		"settings_update_custom_branch": "Branch:",
		"settings_update_release_tag": "Tag:",
		"settings_update_check": "Check",
		"settings_update_prepare": "Prepare",
		"settings_update_apply": "Sync",
		"settings_update_refresh_list": "Refresh List",
		"settings_update_one_click": "One-click Update",
		"settings_update_remote_url": "Remote URL:",
		"settings_update_current_branch": "Current Branch:",
		"settings_update_current_version": "Current Version:",
		"settings_update_channel_stable": "Stable",
		"settings_update_channel_development": "Development",
		"settings_update_col_version": "Version ID",
		"settings_update_col_message": "Update",
		"settings_update_col_date": "Date",
		"settings_update_col_current": "Current",
		"settings_update_col_action": "Action",
		"settings_update_current_marker": "Current",
		"settings_update_switch": "Switch",
		"settings_update_last_trigger": "Last trigger:",
		"settings_update_last_refresh": "Last refresh:",
		"settings_update_rate_limit_reset": "Rate limit resets:",
		"settings_update_sync_loading": "Syncing",
		"settings_update_sync_refreshing_editor": "Refreshing editor",
		"settings_update_sync_success": "Synced",
		"settings_update_sync_error": "Sync failed",
		"settings_update_source_latest_dev": "Latest dev",
		"settings_update_source_custom_branch": "Custom branch",
		"settings_update_source_latest_stable": "Latest stable release",
		"settings_update_source_latest_release": "Latest release",
		"settings_update_source_release_tag": "Release tag",
		"settings_current_version": "Current version:",
		"settings_current_source": "Plugin Path:",
		"settings_current_commit": "Commit:",
		"settings_update_unavailable": "Unavailable",
		"settings_update_commit_unrecorded": "unrecorded",
		"settings_update_branch_unavailable": "No branches",
		"settings_update_release_unavailable": "No releases",
		"settings_update_refs_idle": "Select an update mode to discover branches, releases, and tags.",
		"settings_update_refs_loading": "Loading refs",
		"settings_update_refs_success": "Refs loaded",
		"settings_update_refs_error": "Refs failed",
		"settings_update_selected_target": "Selected target:",
		"settings_update_compare_summary": "Current plugin %s [%s] -> selected target %s [%s], commit difference: %s.",
		"settings_update_compare_difference": "current ahead %d / target ahead %d",
		"settings_update_compare_loading": "checking...",
		"port": "Port:",
		"log_level": "Log Level:",
		"language": "Language:",
		"log_level_debug": "Debug",
		"log_level_info": "Info"
	}

	func get_text(key: String) -> String:
		return str(TEXTS.get(key, key))

	func get_available_language_codes() -> Array:
		return ["en"]

	func get_language_display_name(language_code: String, _current_language: String) -> String:
		return language_code


class Recorder extends RefCounted:
	var port := 0
	var update_source := ""
	var update_custom_branch := ""
	var update_interaction_refresh_count := 0
	var update_check_count := 0
	var update_apply_count := 0
	var update_switch_kind := ""
	var update_switch_ref := ""
	var update_switch_commit := ""

	func on_port_changed(value: int) -> void:
		port = value

	func on_update_source_changed(value: String) -> void:
		update_source = value

	func on_update_custom_branch_changed(value: String) -> void:
		update_custom_branch = value

	func on_update_interaction_refresh_requested() -> void:
		update_interaction_refresh_count += 1

	func on_update_check_requested() -> void:
		update_check_count += 1

	func on_update_apply_requested() -> void:
		update_apply_count += 1

	func on_update_switch_requested(kind: String, target_ref: String, target_commit: String) -> void:
		update_switch_kind = kind
		update_switch_ref = target_ref
		update_switch_commit = target_commit


func run_case(tree: SceneTree) -> Dictionary:
	var source_guard := _assert_dock_applies_visible_tabs_only()
	if not source_guard.is_empty():
		return _failure(source_guard)
	_instance = MCPDockScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("MCP Dock scene should instantiate for Settings tab contract.")
	tree.root.add_child(_instance)
	await tree.process_frame

	var tab_container := _instance.get_node("TabContainer") as TabContainer
	if tab_container == null or tab_container.get_tab_count() != 6:
		return _failure("MCP Dock should create Home, Tools, Resources, Prompts, Config, and Settings tabs.")
	if tab_container.get_tab_control(2).name != "ResourcesTab" or tab_container.get_tab_control(3).name != "PromptsTab" or tab_container.get_tab_control(4).name != "ConfigTab" or tab_container.get_tab_control(5).name != "SettingsTab":
		return _failure("MCP Dock should preserve Resources/Prompts before Config and Settings before localization applies.")
	var server_tab := tab_container.get_tab_control(0)
	if server_tab == null or server_tab.find_child("SettingsCard", true, false) != null:
		return _failure("Home tab should not keep persistent SettingsCard controls.")
	if tab_container.get_tab_control(1).has_method("apply_model") or tab_container.get_tab_control(5).has_method("apply_model"):
		return _failure("MCP Dock should lazy-load heavy non-Home tabs instead of instantiating them during startup.")
	tab_container.current_tab = 2
	await tree.process_frame
	if tab_container.get_tab_control(2) == null or not tab_container.get_tab_control(2).has_method("apply_model"):
		return _failure("MCP Dock should instantiate Resources only when the Resources tab becomes visible.")
	if tab_container.get_tab_control(1).has_method("apply_model") or tab_container.get_tab_control(3).has_method("apply_model"):
		return _failure("MCP Dock should not instantiate sibling heavy tabs when Resources becomes visible.")
	tab_container.current_tab = 3
	await tree.process_frame
	if tab_container.get_tab_control(3) == null or not tab_container.get_tab_control(3).has_method("apply_model"):
		return _failure("MCP Dock should instantiate Prompts only when the Prompts tab becomes visible.")
	tab_container.current_tab = 1
	await tree.process_frame
	if tab_container.get_tab_control(1) == null or not tab_container.get_tab_control(1).has_method("apply_model"):
		return _failure("MCP Dock should instantiate Tools only when the Tools tab becomes visible.")
	if tab_container.get_tab_control(4).has_method("apply_model") or tab_container.get_tab_control(5).has_method("apply_model"):
		return _failure("MCP Dock should keep Config and Settings unloaded until those tabs are visible or targeted.")

	var recorder := Recorder.new()
	_instance.port_changed.connect(Callable(recorder, "on_port_changed"))
	_instance.update_source_changed.connect(Callable(recorder, "on_update_source_changed"))
	_instance.update_custom_branch_changed.connect(Callable(recorder, "on_update_custom_branch_changed"))
	_instance.update_interaction_refresh_requested.connect(Callable(recorder, "on_update_interaction_refresh_requested"))
	_instance.update_check_requested.connect(Callable(recorder, "on_update_check_requested"))
	_instance.update_apply_requested.connect(Callable(recorder, "on_update_apply_requested"))
	_instance.update_switch_requested.connect(Callable(recorder, "on_update_switch_requested"))
	_instance.apply_model({
		"localization": FakeLocalization.new(),
		"editor_scale": 1.0,
		"current_tab": 5,
		"is_running": false,
		"settings": {"port": 3100, "update_source": "custom_branch", "update_custom_branch": "dev", "update_release_tag": "v1.0.0"},
		"current_log_level": "info",
		"current_language": "en",
		"log_levels": ["debug", "info"],
		"update_refs_branches": ["dev", "feature/dock"],
		"update_refs_releases": ["v1.0.0", "v2.0.0"],
		"update_refs_state": "success",
		"update_refs_commits": {"dev": "1234567890abcdef"},
		"update_refs_versions": {"dev": "1.4.0"},
		"update_refs_branch_commit_rows": {
			"dev": [
				{"kind": "branch", "ref": "dev", "commit": "1234567890abcdef", "title": "Dock update", "date": "2026-07-04T12:00:00Z"},
				{"kind": "branch", "ref": "dev", "commit": "fedcba9876543210", "title": "Older dock update", "date": "2026-07-03T12:00:00Z"}
			]
		},
		"update_compare_state": "success",
		"update_compare_ahead_by": 1,
		"update_compare_behind_by": 0,
		"update_sync_state": "success",
		"update_sync_status": "Synced dev.",
		"plugin_version": "1.0.1",
		"plugin_freshness": {"sync": {"source_git_commit": "abcdef123456"}}
	})
	await tree.process_frame
	if tab_container.get_tab_title(0) != "Home" or tab_container.get_tab_title(2) != "Resources" or tab_container.get_tab_title(3) != "Prompts" or tab_container.get_tab_title(4) != "Config" or tab_container.get_tab_title(5) != "Settings":
		return _failure("MCP Dock should localize all six tab titles, including Resources and Prompts.")
	if tab_container.current_tab != 5:
		return _failure("MCP Dock should apply Settings tab model at tab index 5.")
	if tab_container.get_tab_control(5) == null or not tab_container.get_tab_control(5).has_method("apply_model"):
		return _failure("MCP Dock should instantiate the Settings tab when it becomes the active model target.")

	var port_spin := tab_container.get_tab_control(5).find_child("PortSpin", true, false) as SpinBox
	if port_spin == null or int(port_spin.value) != 3100:
		return _failure("Settings tab should receive the Dock model at index 5.")
	port_spin.value = 3200
	if recorder.port != 3200:
		return _failure("Settings tab port changes should route through the existing Dock port_changed signal.")
	var channel_tabs := tab_container.get_tab_control(5).find_child("UpdateChannelTabs", true, false) as TabBar
	var custom_branch_row := tab_container.get_tab_control(5).find_child("CustomBranchRow", true, false) as GridContainer
	var custom_branch_value := tab_container.get_tab_control(5).find_child("CustomBranchValue", true, false) as OptionButton
	var version_tree := tab_container.get_tab_control(5).find_child("VersionTree", true, false) as Tree
	var check_button := tab_container.get_tab_control(5).find_child("CheckButton", true, false) as Button
	var prepare_button := tab_container.get_tab_control(5).find_child("PrepareButton", true, false) as Button
	var apply_button := tab_container.get_tab_control(5).find_child("ApplyButton", true, false) as Button
	if channel_tabs == null or custom_branch_value == null or version_tree == null or check_button == null or prepare_button == null or apply_button == null:
		return _failure("Settings tab update controls should exist in the Settings tab.")
	if channel_tabs.get_tab_count() != 2 or channel_tabs.current_tab != 1 or channel_tabs.get_tab_title(0) != "Stable" or channel_tabs.get_tab_title(1) != "Development":
		return _failure("Settings tab should expose Stable and Development update channels in order.")
	if tab_container.get_tab_control(5).find_child("SourceOption", true, false) != null:
		return _failure("Settings tab should not expose the removed update source selector.")
	if custom_branch_value.get_item_count() < 2 or str(custom_branch_value.get_item_metadata(0)) != "dev" or str(custom_branch_value.get_item_metadata(custom_branch_value.selected)) != "dev":
		return _failure("Settings tab should keep dev first in the custom branch selector after Dock projection.")
	if custom_branch_row == null or not custom_branch_row.visible or tab_container.get_tab_control(5).find_child("ReleaseTagRow", true, false) != null:
		return _failure("Settings tab should show only the branch target row for custom branch update sources.")
	if tab_container.get_tab_control(5).find_child("ReleaseTagValue", true, false) != null or tab_container.get_tab_control(5).find_child("CustomBranchValue", true, false) is LineEdit:
		return _failure("Settings tab update refs should not use manual LineEdit controls.")
	if not version_tree.visible or version_tree.get_root() == null or version_tree.get_root().get_first_child() == null:
		return _failure("Settings tab should show branch commit rows in the Development channel.")
	if not check_button.visible or check_button.disabled or check_button.text != "Refresh List":
		return _failure("Settings tab Refresh List should be visible and enabled because refs refresh is manual.")
	if prepare_button.visible or not prepare_button.disabled or not prepare_button.text.is_empty():
		return _failure("Settings tab Prepare should remain hidden, disabled, and label-free after Dock projection.")
	if apply_button.text != "One-click Update":
		return _failure("Settings tab should render the one-click update action after Dock projection.")
	if apply_button.disabled:
		return _failure("Settings tab Sync should be enabled for selected branch targets.")
	var labels := tab_container.get_tab_control(5).find_children("*", "Label", true, false)
	if _find_label_containing(labels, "Select an update mode") != null:
		return _failure("Settings tab should normalize stale automatic discovery status copy after Dock projection.")
	if _find_label_containing(labels, "Current Version:") == null or _find_label_containing(labels, "1.0.1 (abcdef1)") == null:
		return _failure("Settings tab should display the compact update summary after Dock projection.")
	var details_button := tab_container.get_tab_control(5).find_child("DetailsButton", true, false) as Button
	var details_panel := tab_container.get_tab_control(5).find_child("DetailsPanel", true, false) as PanelContainer
	var details_text := tab_container.get_tab_control(5).find_child("UpdatesDetails", true, false) as Label
	if _find_label_containing(labels, "Synced dev.") == null or details_button == null or not details_button.visible or details_panel == null or details_panel.visible or details_text == null or not details_text.text.contains("Current plugin 1.0.1 [abcdef1] -> selected target 1.4.0 [1234567]") or details_text.text.contains("selected target dev") or not details_text.text.contains("current ahead 0 / target ahead 1"):
		return _failure("Settings tab should preserve compare hashes in collapsed details while keeping the main sync status concise.")
	custom_branch_value.emit_signal("pressed")
	if recorder.update_interaction_refresh_count != 0 or recorder.update_source != "" or recorder.update_custom_branch != "":
		return _failure("MCP Dock should not request update refresh when Settings selectors are opened.")
	prepare_button.text = "准备"
	prepare_button.visible = true
	prepare_button.disabled = false
	check_button.text = "检查"
	check_button.visible = true
	check_button.disabled = false
	apply_button.text = "应用"
	_instance.apply_model({
		"localization": FakeLocalization.new(),
		"editor_scale": 1.0,
		"current_tab": 5,
		"is_running": false,
		"settings": {"port": 3100, "update_source": "custom_branch", "update_custom_branch": "dev", "update_release_tag": "v1.0.0"},
		"current_log_level": "info",
		"current_language": "en",
		"log_levels": ["debug", "info"],
		"update_refs_branches": ["dev", "feature/dock"],
		"update_refs_releases": ["v1.0.0", "v2.0.0"],
		"update_refs_state": "success",
		"update_refs_commits": {"dev": "1234567890abcdef", "feature/dock": "fedcba9876543210"},
		"update_refs_branch_commit_rows": {
			"dev": [
				{"kind": "branch", "ref": "dev", "commit": "1234567890abcdef", "title": "Dock update", "date": "2026-07-04T12:00:00Z"}
			],
			"feature/dock": [
				{"kind": "branch", "ref": "feature/dock", "commit": "fedcba9876543210", "title": "Feature dock update", "date": "2026-07-05T12:00:00Z"}
			]
		},
		"plugin_version": "1.0.1",
		"plugin_freshness": {}
	})
	await tree.process_frame
	if not check_button.visible or check_button.disabled or check_button.text != "Refresh List" or prepare_button.visible or not prepare_button.disabled or not prepare_button.text.is_empty() or apply_button.text != "One-click Update":
		return _failure("MCP Dock should preserve visible manual Check while normalizing stale hidden update controls.")
	channel_tabs.current_tab = 0
	channel_tabs.emit_signal("tab_changed", 0)
	if custom_branch_row.visible:
		return _failure("Settings tab should hide editable target rows immediately when the Stable channel is selected.")
	channel_tabs.current_tab = 1
	channel_tabs.emit_signal("tab_changed", 1)
	if not custom_branch_row.visible:
		return _failure("Settings tab should restore branch row visibility immediately when the Development channel is selected.")
	custom_branch_value.select(1)
	custom_branch_value.emit_signal("item_selected", 1)
	var first_row := version_tree.get_root().get_first_child()
	version_tree.emit_signal("button_clicked", first_row, 4, 1, MOUSE_BUTTON_LEFT)
	if not recorder.update_switch_ref.is_empty():
		return _failure("Settings tab Switch should defer through MCP Dock until after Tree mouse selection events complete.")
	await tree.process_frame
	check_button.emit_signal("pressed")
	apply_button.emit_signal("pressed")
	if recorder.update_source != "custom_branch" or recorder.update_custom_branch != "feature/dock" or recorder.update_interaction_refresh_count != 0 or recorder.update_check_count != 1 or recorder.update_apply_count != 1 or recorder.update_switch_kind.is_empty() or recorder.update_switch_ref.is_empty():
		return _failure("Settings tab Check should route through MCP Dock only when the explicit button is pressed, while Switch routes from table rows.")

	return {"name": "mcp_dock_settings_tab_contracts", "success": true, "error": ""}


func cleanup_case(tree: SceneTree) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {"name": "mcp_dock_settings_tab_contracts", "success": false, "error": message}


func _find_label_containing(labels: Array, text: String) -> Label:
	for label in labels:
		if label is Label and (label as Label).text.contains(text):
			return label as Label
	return null


func _has_option_value(option_button: OptionButton, value: String) -> bool:
	for item_index in range(option_button.get_item_count()):
		if str(option_button.get_item_metadata(item_index)) == value:
			return true
	return false


func _assert_dock_applies_visible_tabs_only() -> String:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/ui/mcp_dock.gd")
	if source.find("func _apply_visible_tab_models(model: Dictionary) -> void:") == -1:
		return "MCP Dock should route model updates through visible-tab application."
	if source.find("_apply_tab_model(_server_tab, model)") == -1:
		return "MCP Dock should keep the lightweight Server tab updated during status refreshes."
	if source.find("var current_tab := _get_tab_for_index(current_index, true)") == -1 or source.find("_apply_tab_model(current_tab, model)") == -1:
		return "MCP Dock should update only the active tab besides the Server tab."
	if source.find("_apply_all_tab_models(model)") != -1:
		return "MCP Dock should not apply every model update to all heavy tabs."
	if source.find("_apply_tab_model(_get_tab_for_index(index), _last_model)") == -1:
		return "MCP Dock should apply the cached model when a tab becomes visible."
	if source.find("func _connect_signal_once(source: Object, signal_name: StringName, callback: Callable) -> void:") == -1:
		return "MCP Dock should connect lazy tab signals through an idempotent helper."
	if source.find("_tools_tab.tool_toggled.connect(") != -1 or source.find("_config_tab.cli_scope_changed.connect(") != -1 or source.find("_settings_tab.port_changed.connect(") != -1:
		return "MCP Dock should not use unguarded signal connections for lazily instantiated heavy tabs."
	return ""
