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
		"tab_config": "Config",
		"tab_settings": "Settings",
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
		"settings_update_refs_idle": "Click Check",
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
	var update_check_count := 0
	var update_apply_count := 0

	func on_port_changed(value: int) -> void:
		port = value

	func on_update_source_changed(value: String) -> void:
		update_source = value

	func on_update_custom_branch_changed(value: String) -> void:
		update_custom_branch = value

	func on_update_check_requested() -> void:
		update_check_count += 1

	func on_update_apply_requested() -> void:
		update_apply_count += 1


func run_case(tree: SceneTree) -> Dictionary:
	_instance = MCPDockScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("MCP Dock scene should instantiate for Settings tab contract.")
	tree.root.add_child(_instance)
	await tree.process_frame

	var tab_container := _instance.get_node("TabContainer") as TabContainer
	if tab_container == null or tab_container.get_tab_count() != 4:
		return _failure("MCP Dock should create exactly four tabs.")
	if tab_container.get_tab_control(2).name != "ConfigTab" or tab_container.get_tab_control(3).name != "SettingsTab":
		return _failure("MCP Dock should preserve Config at index 2 and Settings at index 3 before localization applies.")
	var server_tab := tab_container.get_tab_control(0)
	if server_tab == null or server_tab.find_child("SettingsCard", true, false) != null:
		return _failure("Home tab should not keep persistent SettingsCard controls.")

	var recorder := Recorder.new()
	_instance.port_changed.connect(Callable(recorder, "on_port_changed"))
	_instance.update_source_changed.connect(Callable(recorder, "on_update_source_changed"))
	_instance.update_custom_branch_changed.connect(Callable(recorder, "on_update_custom_branch_changed"))
	_instance.update_check_requested.connect(Callable(recorder, "on_update_check_requested"))
	_instance.update_apply_requested.connect(Callable(recorder, "on_update_apply_requested"))
	_instance.apply_model({
		"localization": FakeLocalization.new(),
		"editor_scale": 1.0,
		"current_tab": 3,
		"is_running": false,
		"settings": {"port": 3100, "update_source": "custom_branch", "update_custom_branch": "dev", "update_release_tag": "v1.0.0"},
		"current_log_level": "info",
		"current_language": "en",
		"log_levels": ["debug", "info"],
		"update_refs_branches": ["dev", "feature/dock"],
		"update_refs_releases": ["v1.0.0", "v2.0.0"],
		"update_refs_state": "success",
		"update_refs_commits": {"dev": "1234567890abcdef"},
		"update_refs_versions": {"dev": "1.2.0"},
		"update_compare_state": "success",
		"update_compare_ahead_by": 1,
		"update_compare_behind_by": 0,
		"update_sync_state": "success",
		"update_sync_status": "Synced dev.",
		"plugin_version": "1.0.1",
		"plugin_freshness": {"sync": {"source_git_commit": "abcdef123456"}}
	})
	await tree.process_frame
	if tab_container.get_tab_title(0) != "Home" or tab_container.get_tab_title(2) != "Config" or tab_container.get_tab_title(3) != "Settings":
		return _failure("MCP Dock should localize all four tab titles, including Settings.")
	if tab_container.current_tab != 3:
		return _failure("MCP Dock should apply Settings tab model at tab index 3.")

	var port_spin := tab_container.get_tab_control(3).find_child("PortSpin", true, false) as SpinBox
	if port_spin == null or int(port_spin.value) != 3100:
		return _failure("Settings tab should receive the Dock model at index 3.")
	port_spin.value = 3200
	if recorder.port != 3200:
		return _failure("Settings tab port changes should route through the existing Dock port_changed signal.")
	var source_option := tab_container.get_tab_control(3).find_child("SourceOption", true, false) as OptionButton
	var custom_branch_row := tab_container.get_tab_control(3).find_child("CustomBranchRow", true, false) as HBoxContainer
	var custom_branch_value := tab_container.get_tab_control(3).find_child("CustomBranchValue", true, false) as OptionButton
	var check_button := tab_container.get_tab_control(3).find_child("CheckButton", true, false) as Button
	var prepare_button := tab_container.get_tab_control(3).find_child("PrepareButton", true, false) as Button
	var apply_button := tab_container.get_tab_control(3).find_child("ApplyButton", true, false) as Button
	if source_option == null or custom_branch_value == null or check_button == null or prepare_button == null or apply_button == null:
		return _failure("Settings tab update source controls should exist in the Settings tab.")
	if source_option.get_item_count() != 3 or str(source_option.get_item_metadata(0)) != "latest_stable" or str(source_option.get_item_metadata(1)) != "latest_release" or str(source_option.get_item_metadata(2)) != "custom_branch":
		return _failure("Settings tab should expose latest stable, latest release, and custom branch source choices in order.")
	if _has_option_value(source_option, "release_tag") or _has_option_value(source_option, "latest_dev"):
		return _failure("Settings tab should not expose selectable release/tag or latest dev sources.")
	if custom_branch_value.get_item_count() < 2 or str(custom_branch_value.get_item_metadata(0)) != "dev" or str(custom_branch_value.get_item_metadata(custom_branch_value.selected)) != "dev":
		return _failure("Settings tab should keep dev first in the custom branch selector after Dock projection.")
	if custom_branch_row == null or not custom_branch_row.visible or tab_container.get_tab_control(3).find_child("ReleaseTagRow", true, false) != null:
		return _failure("Settings tab should show only the branch target row for custom branch update sources.")
	if tab_container.get_tab_control(3).find_child("ReleaseTagValue", true, false) != null or tab_container.get_tab_control(3).find_child("CustomBranchValue", true, false) is LineEdit:
		return _failure("Settings tab update refs should not use manual LineEdit controls.")
	if check_button.visible or not check_button.disabled or not check_button.text.is_empty():
		return _failure("Settings tab Check should remain hidden, disabled, and label-free because refs are discovered from source selection.")
	if prepare_button.visible or not prepare_button.disabled or not prepare_button.text.is_empty():
		return _failure("Settings tab Prepare should remain hidden, disabled, and label-free after Dock projection.")
	if apply_button.text != "Sync":
		return _failure("Settings tab Sync should preserve non-stale non-Chinese labels after Dock projection.")
	if apply_button.disabled:
		return _failure("Settings tab Sync should be enabled for selected branch targets.")
	var labels := tab_container.get_tab_control(3).find_children("*", "Label", true, false)
	if _find_label_containing(labels, "Click Check") != null:
		return _failure("Settings tab should normalize stale manual Check status copy after Dock projection.")
	if _find_label_containing(labels, "Current version: 1.0.1") != null or _find_label_containing(labels, "Plugin Path:") != null or _find_label_containing(labels, "Commit: abcdef123456") != null:
		return _failure("Settings tab should not display removed current version, plugin path, or commit summary rows after Dock projection.")
	if _find_label_containing(labels, "Synced dev.") == null or _find_label_containing(labels, "Current plugin 1.0.1 [abcdef1] -> selected target 1.2.0 [1234567]") == null or _find_label_containing(labels, "selected target dev") != null or _find_label_containing(labels, "current ahead 0 / target ahead 1") == null:
		return _failure("Settings tab should display sync success together with explicit current-to-target update hashes and commit difference direction.")
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
		"current_tab": 3,
		"is_running": false,
		"settings": {"port": 3100, "update_source": "custom_branch", "update_custom_branch": "dev", "update_release_tag": "v1.0.0"},
		"current_log_level": "info",
		"current_language": "en",
		"log_levels": ["debug", "info"],
		"update_refs_branches": ["dev", "feature/dock"],
		"update_refs_releases": ["v1.0.0", "v2.0.0"],
		"plugin_version": "1.0.1",
		"plugin_freshness": {}
	})
	await tree.process_frame
	if check_button.visible or not check_button.disabled or not check_button.text.is_empty() or prepare_button.visible or not prepare_button.disabled or not prepare_button.text.is_empty() or apply_button.text != "Sync":
		return _failure("MCP Dock should normalize stale Settings tab update button cache after model projection.")
	source_option.select(0)
	source_option.emit_signal("item_selected", 0)
	if custom_branch_row.visible:
		return _failure("Settings tab should hide editable target rows immediately when latest stable mode is selected.")
	source_option.select(1)
	source_option.emit_signal("item_selected", 1)
	if custom_branch_row.visible:
		return _failure("Settings tab should hide editable target rows immediately when latest release mode is selected.")
	source_option.select(2)
	source_option.emit_signal("item_selected", 2)
	if not custom_branch_row.visible:
		return _failure("Settings tab should restore branch row visibility immediately when custom branch mode is selected.")
	custom_branch_value.select(1)
	custom_branch_value.emit_signal("item_selected", 1)
	apply_button.emit_signal("pressed")
	if recorder.update_source != "custom_branch" or recorder.update_custom_branch != "feature/dock" or recorder.update_check_count != 0 or recorder.update_apply_count != 1:
		return _failure("Settings tab update setting and Sync changes should route through MCP Dock signals without a user-visible Check action.")

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
