extends RefCounted

const LocaleEn = preload("res://addons/godot_dotnet_mcp/localization/locale_en.gd")
const LocaleZhCn = preload("res://addons/godot_dotnet_mcp/localization/locale_zh_cn.gd")
const LocaleZhTw = preload("res://addons/godot_dotnet_mcp/localization/locale_zh_tw.gd")
const ServerPanelScene = preload("res://addons/godot_dotnet_mcp/ui/server_panel.tscn")


func run_case(_tree: SceneTree) -> Dictionary:
	if str(LocaleEn.TRANSLATIONS.get("tab_server", "")) != "Home":
		return _failure("English localization should expose the first Dock tab as Home after the service-page-to-homepage migration.")
	if str(LocaleZhCn.TRANSLATIONS.get("tab_server", "")) != "主页":
		return _failure("简体中文本地化应将第一个 Dock 页签显示为“主页”。")
	if str(LocaleZhTw.TRANSLATIONS.get("tab_server", "")) != "首頁":
		return _failure("繁體中文本地化應將第一個 Dock 頁籤顯示為“首頁”。")
	if str(LocaleEn.TRANSLATIONS.get("title", "")).find("Server") != -1:
		return _failure("English title should no longer present the Dock as a dedicated server page.")
	if str(LocaleZhCn.TRANSLATIONS.get("title", "")).find("服务") != -1:
		return _failure("简体中文标题不应再将 Dock 表述为单独的服务页。")
	if str(LocaleZhTw.TRANSLATIONS.get("title", "")).find("服務") != -1:
		return _failure("繁體中文標題不應再將 Dock 表述為單獨的服務頁。")
	for locale in [LocaleEn.TRANSLATIONS, LocaleZhCn.TRANSLATIONS, LocaleZhTw.TRANSLATIONS]:
		if locale.has("advanced_settings"):
			return _failure("Localization dictionaries should not keep the removed Advanced Settings label.")
	for key in [
		"tool_system_editor_state_name",
		"tool_system_userdata_maintenance_name",
		"tool_system_editor_log_name",
		"tool_action_get_output_name",
		"tool_action_ensure_layout_name",
		"tool_action_cleanup_legacy_cache_name"
	]:
		if not LocaleEn.TRANSLATIONS.has(key) or not LocaleZhCn.TRANSLATIONS.has(key) or not LocaleZhTw.TRANSLATIONS.has(key):
			return _failure("All supported locales should define visible Tools-page key: %s" % key)

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
			"en_tab": str(LocaleEn.TRANSLATIONS.get("tab_server", "")),
			"zh_tab": str(LocaleZhCn.TRANSLATIONS.get("tab_server", "")),
			"zh_tw_tab": str(LocaleZhTw.TRANSLATIONS.get("tab_server", "")),
			"en_title": str(LocaleEn.TRANSLATIONS.get("title", "")),
			"zh_title": str(LocaleZhCn.TRANSLATIONS.get("title", "")),
			"zh_tw_title": str(LocaleZhTw.TRANSLATIONS.get("title", ""))
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
