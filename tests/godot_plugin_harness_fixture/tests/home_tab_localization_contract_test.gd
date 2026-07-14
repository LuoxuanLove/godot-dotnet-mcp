extends RefCounted

const LocaleEn = preload("res://addons/godot_dotnet_mcp/localization/locale_en.gd")
const LocaleZhCn = preload("res://addons/godot_dotnet_mcp/localization/locale_zh_cn.gd")
const LocaleZhTw = preload("res://addons/godot_dotnet_mcp/localization/locale_zh_tw.gd")
const LocaleDe = preload("res://addons/godot_dotnet_mcp/localization/locale_de.gd")
const LocaleEs = preload("res://addons/godot_dotnet_mcp/localization/locale_es.gd")
const LocaleFr = preload("res://addons/godot_dotnet_mcp/localization/locale_fr.gd")
const LocaleJa = preload("res://addons/godot_dotnet_mcp/localization/locale_ja.gd")
const LocaleKo = preload("res://addons/godot_dotnet_mcp/localization/locale_ko.gd")
const LocalePt = preload("res://addons/godot_dotnet_mcp/localization/locale_pt.gd")
const LocaleRu = preload("res://addons/godot_dotnet_mcp/localization/locale_ru.gd")
const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const ServerPanelScene = preload("res://addons/godot_dotnet_mcp/ui/server_panel.tscn")


func run_case(_tree: SceneTree) -> Dictionary:
	var en := _get_translations(LocaleEn)
	var zh_cn := _get_translations(LocaleZhCn)
	var zh_tw := _get_translations(LocaleZhTw)
	var de := _get_translations(LocaleDe)
	var es := _get_translations(LocaleEs)
	var fr := _get_translations(LocaleFr)
	var ja := _get_translations(LocaleJa)
	var ko := _get_translations(LocaleKo)
	var pt := _get_translations(LocalePt)
	var ru := _get_translations(LocaleRu)
	var supported_locales := [en, zh_cn, zh_tw, de, es, fr, ja, ko, pt, ru]
	var localization = LocalizationServiceScript.new()
	localization._init_translations()
	var supported_locale_codes := localization.get_available_language_codes()
	if str(en.get("tab_server", "")) != "Home":
		return _failure("English localization should expose the first Dock tab as Home after the service-page-to-homepage migration.")
	if str(zh_cn.get("tab_server", "")) != "主页":
		return _failure("简体中文本地化应将第一个 Dock 页签显示为“主页”。")
	if str(zh_tw.get("tab_server", "")) != "首頁":
		return _failure("繁體中文本地化應將第一個 Dock 頁籤顯示為“首頁”。")
	if str(ko.get("tab_server", "")) != "홈":
		return _failure("Korean localization should expose the first Dock tab as 홈.")
	if str(ko.get("language_name", "")) != "한국어":
		return _failure("Korean localization should expose a readable native language name.")
	if str(fr.get("language_name", "")) != "Français":
		return _failure("French localization should expose a readable native language name.")
	if str(fr.get("status_stopped", "")) != "Arrêté":
		return _failure("French localization should preserve accented status labels.")
	if str(fr.get("self_diag_cleared", "")) != "L’autodiagnostic du plugin a été effacé.":
		return _failure("French localization should preserve curly apostrophes and accented self-diagnostic text.")
	if str(fr.get("cat_node", "")) != "Nœud":
		return _failure("French localization should preserve ligatures.")
	var french_mojibake_markers := ["莽", "锚", "茅", "鈥", "檃", "脡", "猫", "聽", "芒", "禄", "艙", "脿", "么"]
	for value in fr.values():
		if not (value is String):
			continue
		var french_text := str(value)
		for marker in french_mojibake_markers:
			if french_text.contains(marker):
				return _failure("French localization should not contain mojibake marker: %s" % marker)
	for locale in supported_locales:
		if str(locale.get("title", "")) != "Godot .NET MCP":
			return _failure("All supported locales should expose the Dock header title as Godot .NET MCP.")
		if str(locale.get("dialog_title", "")) != "Godot .NET MCP":
			return _failure("All supported locales should expose dialog titles as Godot .NET MCP.")
	for locale in [en, zh_cn, zh_tw]:
		if locale.has("advanced_settings"):
			return _failure("Localization dictionaries should not keep the removed Advanced Settings label.")
	for key in [
		"tool_system_editor_state_name",
		"tool_system_project_files_name",
		"tool_system_scene_tree_name",
		"tool_system_userdata_maintenance_name",
		"cat_dap",
		"tool_system_dap_debugger_name",
		"tool_dap_debugger_name",
		"tool_action_set_settings_name",
		"tool_action_initialize_name",
		"tool_action_launch_name",
		"tool_action_attach_name",
		"tool_action_configuration_done_name",
		"tool_action_disconnect_name",
		"tool_action_terminate_name",
		"tool_action_threads_name",
		"tool_action_set_breakpoint_name",
		"tool_action_remove_breakpoint_name",
		"tool_action_list_breakpoints_name",
		"tool_action_pause_name",
		"tool_action_continue_name",
		"tool_action_step_over_name",
		"tool_action_stack_trace_name",
		"tool_action_output_name",
		"tool_param_system_dap_debugger_action_desc",
		"tool_param_system_dap_debugger_session_id_desc",
		"tool_param_system_dap_debugger_host_desc",
		"tool_param_system_dap_debugger_port_desc",
		"tool_param_system_dap_debugger_timeout_ms_desc",
		"tool_param_system_dap_debugger_settings_desc",
		"tool_param_system_dap_debugger_include_raw_desc",
		"tool_param_system_dap_debugger_adapter_args_desc",
		"tool_param_system_dap_debugger_program_desc",
		"tool_param_system_dap_debugger_cwd_desc",
		"tool_param_system_dap_debugger_restart_desc",
		"tool_param_system_dap_debugger_terminate_debuggee_desc",
		"tool_param_system_dap_debugger_source_path_desc",
		"tool_param_system_dap_debugger_line_desc",
		"tool_param_system_dap_debugger_thread_id_desc",
		"tool_action_get_output_name",
		"tool_action_ensure_layout_name",
		"tool_action_list_capture_cache_name",
		"tool_action_cleanup_capture_cache_name",
		"tool_action_cleanup_legacy_cache_name",
		"log_level_debug",
		"log_level_info",
		"log_level_warning",
		"log_level_error",
		"config_client_windsurf",
		"config_client_cline",
		"config_client_roo_code",
		"config_client_qwen",
		"config_client_cherry_studio"
	]:
		for locale_code in supported_locale_codes:
			if localization.get_text_for(locale_code, key) == key:
				return _failure("All supported locales should resolve visible Tools-page key: %s" % key)
	for key in [
		"tab_resources",
		"tab_prompts",
		"mcp_resources_title",
		"mcp_resources_description",
		"mcp_resources_counts",
		"mcp_prompts_title",
		"mcp_prompts_description",
		"mcp_prompts_counts",
		"mcp_catalog_resources",
		"mcp_catalog_resource_templates",
		"mcp_catalog_prompts",
		"mcp_catalog_empty",
		"mcp_catalog_copy_id",
		"mcp_catalog_kind",
		"mcp_catalog_mime_type",
		"mcp_catalog_arguments",
		"mcp_catalog_preview",
		"mcp_catalog_preview_title",
		"mcp_catalog_preview_empty",
		"mcp_catalog_preview_error",
		"mcp_catalog_copy_preview",
		"mcp_catalog_argument_placeholder",
		"mcp_catalog_template_preview_unavailable",
	]:
		for locale_code in supported_locale_codes:
			if localization.get_text_for(locale_code, key) == key:
				return _failure("All supported locales should resolve visible MCP catalog key: %s" % key)
	for key in [
		"tab_settings",
		"settings_general_title",
		"settings_updates_title",
		"settings_current_version",
		"settings_current_source",
		"settings_current_commit",
		"settings_update_unavailable",
		"settings_update_commit_unrecorded",
		"settings_update_branch_head",
		"settings_update_source_label",
		"settings_update_source_latest_dev",
		"settings_update_source_custom_branch",
		"settings_update_source_branch",
		"settings_update_source_latest_stable",
		"settings_update_source_latest_release",
		"settings_update_source_release_tag",
		"settings_update_custom_branch",
		"settings_update_release_tag",
		"settings_update_placeholder_status",
		"settings_update_check",
		"settings_update_prepare",
		"settings_update_apply",
		"settings_update_sync_no_branch",
		"settings_update_sync_no_target",
		"settings_update_sync_loading",
		"settings_update_sync_refreshing_editor",
		"settings_update_sync_success",
		"settings_update_sync_error",
		"settings_update_parse_failure",
		"settings_update_http_failure",
		"settings_update_rate_limit_failure",
		"settings_update_verify_unavailable",
		"settings_update_branch_unavailable",
		"settings_update_release_unavailable",
		"settings_update_refs_idle",
		"settings_update_refs_loading",
		"settings_update_refs_success",
		"settings_update_refs_success_details",
		"settings_update_compare_summary",
		"settings_update_compare_difference",
		"settings_update_compare_loading",
		"settings_update_refs_error",
		"settings_update_selected_target",
		"tool_action_step_name",
		"tool_action_capture_name",
		"tool_action_input_name",
		"tool_system_runtime_control_name",
		"tool_system_runtime_control_desc",
		"tool_system_runtime_step_name",
		"tool_system_runtime_step_desc",
		"tool_runtime_control_name",
		"tool_runtime_control_desc",
		"tool_runtime_capture_name",
		"tool_runtime_capture_desc",
		"tool_runtime_input_name",
		"tool_runtime_input_desc",
		"tool_runtime_step_name",
		"tool_runtime_step_desc"
	]:
		for locale_code in supported_locale_codes:
			if localization.get_text_for(locale_code, key) == key:
				return _failure("All supported locales should resolve runtime Tools-page key: %s" % key)

	for locale_info in [
		{"name": "en", "path": "res://addons/godot_dotnet_mcp/localization/locale_en.gd"},
		{"name": "zh_CN", "path": "res://addons/godot_dotnet_mcp/localization/locale_zh_cn.gd"},
		{"name": "zh_TW", "path": "res://addons/godot_dotnet_mcp/localization/locale_zh_tw.gd"},
		{"name": "ko", "path": "res://addons/godot_dotnet_mcp/localization/locale_ko.gd"}
	]:
		var duplicate_key = _find_duplicate_locale_key(str(locale_info["path"]))
		if not duplicate_key.is_empty():
			return _failure("Locale source should not define duplicate translation keys in %s: %s" % [str(locale_info["name"]), duplicate_key])

	var server_panel = ServerPanelScene.instantiate() as Control
	if server_panel == null:
		return _failure("Server/Home panel scene should instantiate for removed Advanced Settings audit.")
	var forbidden := _find_forbidden_advanced_control(server_panel)
	server_panel.queue_free()
	if not forbidden.is_empty():
		return _failure("Server/Home panel should not contain removed Advanced Settings or permission controls: %s" % forbidden)

	return {
		"name": "home_tab_localization_contracts",
		"success": true,
		"error": "",
		"details": {
			"en_tab": str(en.get("tab_server", "")),
			"zh_tab": str(zh_cn.get("tab_server", "")),
			"zh_tw_tab": str(zh_tw.get("tab_server", "")),
			"en_title": str(en.get("title", "")),
			"zh_title": str(zh_cn.get("title", "")),
			"zh_tw_title": str(zh_tw.get("title", ""))
		}
	}


func _get_translations(locale_script: Script) -> Dictionary:
	var translations = locale_script.get("TRANSLATIONS")
	if translations is Dictionary:
		return (translations as Dictionary).duplicate(true)
	return {}


func _find_duplicate_locale_key(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var source := FileAccess.get_file_as_string(path)
	var key_pattern := RegEx.new()
	if key_pattern.compile("(?m)^\\s*\\\"([^\\\"]+)\\\"\\s*:") != OK:
		return ""
	var seen := {}
	for result in key_pattern.search_all(source):
		var key := result.get_string(1)
		if seen.has(key):
			return key
		seen[key] = true
	return ""


func _find_forbidden_advanced_control(node: Node) -> String:
	var name_text := str(node.name).to_lower()
	if name_text.contains("advanced") or name_text.contains("permission"):
		return str(node.get_path())
	if node is Label:
		var label := node as Label
		var text := label.text.to_lower()
		if text.contains("advanced settings") or text.contains("permission") or text.contains("高级设置") or text.contains("權限"):
			return str(node.get_path())
	if node is Button:
		var button := node as Button
		var text := button.text.to_lower()
		if text.contains("advanced settings") or text.contains("permission") or text.contains("高级设置") or text.contains("權限"):
			return str(node.get_path())
	for child in node.get_children():
		var found := _find_forbidden_advanced_control(child)
		if not found.is_empty():
			return found
	return ""


func _failure(message: String) -> Dictionary:
	return {
		"name": "home_tab_localization_contracts",
		"success": false,
		"error": message
	}
