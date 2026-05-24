extends RefCounted

const LocaleEn = preload("res://addons/godot_dotnet_mcp/localization/locale_en.gd")
const LocaleZhCn = preload("res://addons/godot_dotnet_mcp/localization/locale_zh_cn.gd")
const LocaleZhTw = preload("res://addons/godot_dotnet_mcp/localization/locale_zh_tw.gd")
const LocaleDe = preload("res://addons/godot_dotnet_mcp/localization/locale_de.gd")
const LocaleEs = preload("res://addons/godot_dotnet_mcp/localization/locale_es.gd")
const LocaleFr = preload("res://addons/godot_dotnet_mcp/localization/locale_fr.gd")
const LocaleJa = preload("res://addons/godot_dotnet_mcp/localization/locale_ja.gd")
const LocalePt = preload("res://addons/godot_dotnet_mcp/localization/locale_pt.gd")
const LocaleRu = preload("res://addons/godot_dotnet_mcp/localization/locale_ru.gd")
const ServerPanelScene = preload("res://addons/godot_dotnet_mcp/ui/server_panel.tscn")


func run_case(_tree: SceneTree) -> Dictionary:
	var en := LocaleEn.get_translations()
	var zh_cn := LocaleZhCn.get_translations()
	var zh_tw := LocaleZhTw.get_translations()
	var de := LocaleDe.get_translations()
	var es := LocaleEs.get_translations()
	var fr := LocaleFr.get_translations()
	var ja := LocaleJa.get_translations()
	var pt := LocalePt.get_translations()
	var ru := LocaleRu.get_translations()
	var supported_locales := [en, zh_cn, zh_tw, de, es, fr, ja, pt, ru]
	if str(en.get("tab_server", "")) != "Home":
		return _failure("English localization should expose the first Dock tab as Home after the service-page-to-homepage migration.")
	if str(zh_cn.get("tab_server", "")) != "主页":
		return _failure("简体中文本地化应将第一个 Dock 页签显示为“主页”。")
	if str(zh_tw.get("tab_server", "")) != "首頁":
		return _failure("繁體中文本地化應將第一個 Dock 頁籤顯示為“首頁”。")
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
		"tool_system_editor_log_name",
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
		if not en.has(key) or not zh_cn.has(key) or not zh_tw.has(key):
			return _failure("All supported locales should define visible Tools-page key: %s" % key)
	for key in [
		"tab_settings",
		"settings_general_title",
		"settings_updates_title",
		"settings_updates_description",
		"settings_current_version",
		"settings_current_source",
		"settings_current_commit",
		"settings_update_unavailable",
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
		"settings_update_sync_success",
		"settings_update_sync_error",
		"settings_update_branch_unavailable",
		"settings_update_release_unavailable",
		"settings_update_refs_idle",
		"settings_update_refs_loading",
		"settings_update_refs_success",
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
		for locale in supported_locales:
			if not locale.has(key):
				return _failure("All supported locales should define runtime Tools-page key: %s" % key)

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
