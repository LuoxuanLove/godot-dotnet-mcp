extends RefCounted

const LocaleEn = preload("res://addons/godot_dotnet_mcp/localization/locale_en.gd")
const LocaleZhCn = preload("res://addons/godot_dotnet_mcp/localization/locale_zh_cn.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	if str(LocaleEn.TRANSLATIONS.get("tab_server", "")) != "Home":
		return _failure("English localization should expose the first Dock tab as Home after the service-page-to-homepage migration.")
	if str(LocaleZhCn.TRANSLATIONS.get("tab_server", "")) != "主页":
		return _failure("简体中文本地化应将第一个 Dock 页签显示为“主页”。")
	if str(LocaleEn.TRANSLATIONS.get("title", "")).find("Server") != -1:
		return _failure("English title should no longer present the Dock as a dedicated server page.")
	if str(LocaleZhCn.TRANSLATIONS.get("title", "")).find("服务") != -1:
		return _failure("简体中文标题不应再将 Dock 表述为单独的服务页。")

	return {
		"name": "home_tab_localization_contracts",
		"success": true,
		"error": "",
		"details": {
			"en_tab": str(LocaleEn.TRANSLATIONS.get("tab_server", "")),
			"zh_tab": str(LocaleZhCn.TRANSLATIONS.get("tab_server", "")),
			"en_title": str(LocaleEn.TRANSLATIONS.get("title", "")),
			"zh_title": str(LocaleZhCn.TRANSLATIONS.get("title", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "home_tab_localization_contracts",
		"success": false,
		"error": message
	}
