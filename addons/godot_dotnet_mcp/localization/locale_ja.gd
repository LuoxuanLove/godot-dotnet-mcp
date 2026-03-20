@tool
extends RefCounted

const LocaleEn = preload("res://addons/godot_dotnet_mcp/localization/locale_en.gd")

const TRANSLATIONS: Dictionary = {
	"language_name": "\u65e5\u672c\u8a9e",
}


static func get_translations() -> Dictionary:
	var translations := {}
	if LocaleEn != null:
		translations = LocaleEn.get_translations().duplicate(true)
	translations.merge(TRANSLATIONS, true)
	return translations
