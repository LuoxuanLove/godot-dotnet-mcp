extends RefCounted

const SettingsPanelScene = preload("res://addons/godot_dotnet_mcp/ui/settings_panel.tscn")

var _instance: VBoxContainer = null


class FakeLocalization extends RefCounted:
	var _texts := {
		"settings_general_title": "General",
		"settings_updates_title": "Updates",
		"settings_updates_description": "检查会从 GitHub 发现分支和发布；准备和应用暂未实现。",
		"settings_update_source_label": "Update Source:",
		"settings_update_custom_branch": "Branch:",
		"settings_update_release_tag": "Tag:",
		"settings_update_check": "Check",
		"settings_update_prepare": "Prepare",
		"settings_update_apply": "应用",
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
		"log_level_info": "Info",
		"log_level_warning": "Warning",
		"log_level_error": "Error"
	}

	func get_text(key: String) -> String:
		return str(_texts.get(key, key))

	func get_available_language_codes() -> Array:
		return ["en", "zh_CN"]

	func get_language_display_name(language_code: String, _current_language: String) -> String:
		return "English" if language_code == "en" else "Chinese"


class Recorder extends RefCounted:
	var port := 0
	var log_level := ""
	var language := ""
	var update_source := ""
	var update_custom_branch := ""
	var update_interaction_refresh_count := 0
	var update_check_count := 0
	var update_apply_count := 0

	func on_port_changed(value: int) -> void:
		port = value

	func on_log_level_changed(value: String) -> void:
		log_level = value

	func on_language_changed(value: String) -> void:
		language = value

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


func run_case(tree: SceneTree) -> Dictionary:
	_instance = SettingsPanelScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("Settings tab rendering test could not instantiate the settings panel scene.")
	tree.root.add_child(_instance)
	await tree.process_frame

	var recorder = Recorder.new()
	_instance.port_changed.connect(Callable(recorder, "on_port_changed"))
	_instance.log_level_changed.connect(Callable(recorder, "on_log_level_changed"))
	_instance.language_changed.connect(Callable(recorder, "on_language_changed"))
	_instance.update_source_changed.connect(Callable(recorder, "on_update_source_changed"))
	_instance.update_custom_branch_changed.connect(Callable(recorder, "on_update_custom_branch_changed"))
	_instance.update_interaction_refresh_requested.connect(Callable(recorder, "on_update_interaction_refresh_requested"))
	_instance.update_check_requested.connect(Callable(recorder, "on_update_check_requested"))
	_instance.update_apply_requested.connect(Callable(recorder, "on_update_apply_requested"))

	_instance.apply_model({
		"localization": FakeLocalization.new(),
		"editor_scale": 1.0,
		"settings": {
			"port": 4102,
			"update_source": "release_tag",
			"update_custom_branch": "dev",
			"update_release_tag": "v1.0.0"
		},
		"current_log_level": "error",
		"current_language": "zh_CN",
		"log_levels": ["debug", "info", "warning", "error"],
		"update_refs_branches": ["dev", "feature/settings"],
		"update_refs_releases": ["v1.0.0", "v1.2.3"],
		"update_refs_state": "success",
		"update_refs_latest_release": "v1.2.3",
		"update_refs_commits": {"v1.2.3": "fedcba987654"},
		"update_refs_versions": {"v1.2.3": "1.2.3"},
		"update_compare_state": "success",
		"update_compare_ahead_by": 2,
		"update_compare_behind_by": 0,
		"update_sync_state": "success",
		"update_sync_status": "Synced v1.2.3.",
		"plugin_version": "1.0.1",
		"plugin_freshness": {
			"running_instance": {"source_root": "res://addons/godot_dotnet_mcp"},
			"sync": {"source_git_commit": "abcdef123456"}
		}
	})
	await tree.process_frame

	var port_spin := _instance.get_node("Scroll/Margin/Content/GeneralCard/GeneralCardMargin/GeneralCardBody/PortRow/PortSpin") as SpinBox
	var log_option := _instance.get_node("Scroll/Margin/Content/GeneralCard/GeneralCardMargin/GeneralCardBody/LogLevelRow/LogLevelOption") as OptionButton
	var language_option := _instance.get_node("Scroll/Margin/Content/GeneralCard/GeneralCardMargin/GeneralCardBody/LanguageRow/LanguageOption") as OptionButton
	var source_option := _instance.get_node("Scroll/Margin/Content/UpdatesCard/UpdatesCardMargin/UpdatesCardBody/UpdateSourceRow/SourceOption") as OptionButton
	var custom_branch_row := _instance.get_node("Scroll/Margin/Content/UpdatesCard/UpdatesCardMargin/UpdatesCardBody/CustomBranchRow") as HBoxContainer
	var custom_branch := _instance.get_node("Scroll/Margin/Content/UpdatesCard/UpdatesCardMargin/UpdatesCardBody/CustomBranchRow/CustomBranchValue") as OptionButton
	if _instance.find_child("ReleaseTagRow", true, false) != null or _instance.find_child("ReleaseTagValue", true, false) != null or _instance.find_child("CustomBranchValue", true, false) is LineEdit:
		return _failure("Settings tab should not render removed release/tag controls or manual LineEdit controls for update refs.")
	if port_spin == null or int(port_spin.value) != 4102:
		return _failure("Settings tab should render the persisted port value.")
	if log_option == null or log_option.get_item_count() != 4 or str(log_option.get_item_metadata(log_option.selected)) != "error":
		return _failure("Settings tab should render and select the current log level.")
	if language_option == null or language_option.get_item_count() != 2 or str(language_option.get_item_metadata(language_option.selected)) != "zh_CN":
		return _failure("Settings tab should render and select the current language.")
	if source_option == null or source_option.get_item_count() != 3 or str(source_option.get_item_metadata(source_option.selected)) != "latest_release" or str(source_option.get_item_metadata(0)) != "latest_stable" or str(source_option.get_item_metadata(1)) != "latest_release" or str(source_option.get_item_metadata(2)) != "custom_branch":
		return _failure("Settings tab should render latest stable, latest release, then custom branch sources without adding Config-tab UI.")
	if custom_branch == null or custom_branch.get_item_count() < 2 or str(custom_branch.get_item_metadata(0)) != "dev" or str(custom_branch.get_item_metadata(custom_branch.selected)) != "dev":
		return _failure("Settings tab should render discovered custom branch options with dev pinned first.")
	if custom_branch_row.visible:
		return _failure("Settings tab should hide manual target selectors for latest release source.")
	if recorder.update_source != "" or recorder.update_custom_branch != "" or recorder.update_interaction_refresh_count != 0 or recorder.update_check_count != 0:
		return _failure("Settings tab should not emit update setting changes while applying a model.")

	var labels := _instance.find_children("*", "Label", true, false)
	if _find_label_containing(labels, "准备和应用暂未实现") != null:
		return _failure("Settings tab should normalize stale update description copy from cached localization.")
	if _find_label_containing(labels, "Select an update mode") != null:
		return _failure("Settings tab should normalize stale automatic discovery status copy from cached localization.")
	if _find_label_containing(labels, "点击检查更新") == null:
		return _failure("Settings tab should display the manual update refresh description copy.")
	if _find_label_containing(labels, "Current version: 1.0.1") != null or _find_label_containing(labels, "Plugin Path: res://addons/godot_dotnet_mcp") != null or _find_label_containing(labels, "Commit: abcdef123456") != null:
		return _failure("Settings tab should not display removed current version, plugin path, or commit summary rows.")
	if _find_label_containing(labels, "Synced v1.2.3.") == null or _find_label_containing(labels, "Current plugin 1.0.1 [abcdef1] -> selected target 1.2.3 [fedcba9]") == null or _find_label_containing(labels, "current ahead 0 / target ahead 2") == null:
		return _failure("Settings tab should display sync success together with explicit current-to-target update hashes and commit difference direction.")
	var check_button := _instance.find_child("CheckButton", true, false) as Button
	if check_button == null or not check_button.visible or check_button.disabled or check_button.text != "Check":
		return _failure("Settings update Check should be visible and enabled so refs refresh only when the user clicks it.")
	var prepare_button := _instance.find_child("PrepareButton", true, false) as Button
	var apply_button := _instance.find_child("ApplyButton", true, false) as Button
	if prepare_button == null or prepare_button.visible or not prepare_button.disabled:
		return _failure("Settings update Prepare should remain hidden and disabled.")
	if apply_button == null or apply_button.disabled or apply_button.text != "同步":
		return _failure("Settings update Sync button should be enabled for the resolved latest release target.")

	port_spin.value = 4200
	log_option.select(0)
	log_option.emit_signal("item_selected", 0)
	language_option.select(0)
	language_option.emit_signal("item_selected", 0)
	if recorder.port != 4200 or recorder.log_level != "debug" or recorder.language != "en":
		return _failure("Settings tab should emit the existing persistence signals for port, log level, and language.")
	source_option.emit_signal("pressed")
	custom_branch.emit_signal("pressed")
	if recorder.update_interaction_refresh_count != 0 or recorder.update_source != "" or recorder.update_custom_branch != "":
		return _failure("Settings tab should not request update refresh when selectors are opened.")
	source_option.select(0)
	source_option.emit_signal("item_selected", 0)
	if custom_branch_row.visible:
		return _failure("Settings tab should hide editable target rows after changing update source to latest stable.")
	source_option.select(2)
	source_option.emit_signal("item_selected", 2)
	if not custom_branch_row.visible:
		return _failure("Settings tab should immediately show the branch selector after changing update source to custom branch.")
	custom_branch.select(1)
	custom_branch.emit_signal("item_selected", 1)
	check_button.emit_signal("pressed")
	apply_button.emit_signal("pressed")
	if recorder.update_source != "custom_branch" or recorder.update_custom_branch != "feature/settings" or recorder.update_interaction_refresh_count != 0 or recorder.update_check_count != 1 or recorder.update_apply_count != 1:
		return _failure("Settings tab should emit Check only from the explicit update refresh button.")

	var branch_values: Array[String] = ["dev"]
	for index in range(24):
		branch_values.append("feature/long-selector-%02d" % index)
	_instance.apply_model({
		"localization": FakeLocalization.new(),
		"editor_scale": 1.0,
		"settings": {
			"port": 4102,
			"update_source": "custom_branch",
			"update_custom_branch": "feature/long-selector-23"
		},
		"current_log_level": "error",
		"current_language": "zh_CN",
		"log_levels": ["debug", "info", "warning", "error"],
		"update_refs_branches": branch_values,
		"plugin_version": "1.0.1",
		"plugin_freshness": {}
	})
	await tree.process_frame
	if custom_branch.get_item_count() != branch_values.size() or str(custom_branch.get_item_metadata(custom_branch.selected)) != "feature/long-selector-23":
		return _failure("Settings tab should preserve every discovered branch option while selecting the persisted branch.")
	if custom_branch.get_popup().max_size.y != 348 or source_option.get_popup().max_size.y != 348:
		return _failure("Settings tab update selectors should cap popup height instead of letting long ref lists cover the editor.")

	return {"name": "settings_tab_rendering_contracts", "success": true, "error": ""}


func cleanup_case(tree: SceneTree) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	await tree.process_frame


func _find_label_containing(labels: Array, text: String) -> Label:
	for label in labels:
		if label is Label and (label as Label).text.contains(text):
			return label as Label
	return null

func _failure(message: String) -> Dictionary:
	return {"name": "settings_tab_rendering_contracts", "success": false, "error": message}
