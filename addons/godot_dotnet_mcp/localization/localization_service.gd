@tool
extends RefCounted
class_name LocalizationService

static var _instance: LocalizationService = null

var _current_language := "en"
var _translations: Dictionary = {}

const AVAILABLE_LANGUAGES: Dictionary = {
	"en": "English",
	"zh_CN": "Chinese (Simplified)",
	"zh_TW": "Chinese (Traditional)",
	"ja": "Japanese",
	"ru": "Russian",
	"fr": "French",
	"pt": "Portuguese",
	"es": "Spanish",
	"de": "German"
}

const LANGUAGE_ORDER: Array[String] = [
	"en",
	"zh_CN",
	"zh_TW",
	"ja",
	"fr",
	"de",
	"es",
	"pt",
	"ru"
]

const LANGUAGE_NATIVE_NAMES: Dictionary = {
	"en": "English",
	"zh_CN": "简体中文",
	"zh_TW": "繁體中文",
	"ja": "日本語",
	"ru": "Русский",
	"fr": "Français",
	"pt": "Português",
	"es": "Español",
	"de": "Deutsch"
}

const LANGUAGE_FILES: Dictionary = {
	"en": "res://addons/godot_dotnet_mcp/localization/locale_en.gd",
	"zh_CN": "res://addons/godot_dotnet_mcp/localization/locale_zh_cn.gd",
	"zh_TW": "res://addons/godot_dotnet_mcp/localization/locale_zh_tw.gd",
	"ja": "res://addons/godot_dotnet_mcp/localization/locale_ja.gd",
	"ru": "res://addons/godot_dotnet_mcp/localization/locale_ru.gd",
	"fr": "res://addons/godot_dotnet_mcp/localization/locale_fr.gd",
	"pt": "res://addons/godot_dotnet_mcp/localization/locale_pt.gd",
	"es": "res://addons/godot_dotnet_mcp/localization/locale_es.gd",
	"de": "res://addons/godot_dotnet_mcp/localization/locale_de.gd"
}

const SUPPLEMENTAL_TRANSLATIONS: Dictionary = {}


static func get_instance() -> LocalizationService:
	if _instance == null:
		_instance = LocalizationService.new()
		_instance._init_translations()
	return _instance


static func reset_instance() -> void:
	_instance = null


func _init_translations() -> void:
	_translations.clear()
	for lang_code in LANGUAGE_FILES:
		var file_path := str(LANGUAGE_FILES[lang_code])
		if not ResourceLoader.exists(file_path):
			continue
		var translations_value = _load_language_translations(file_path)
		if not (translations_value is Dictionary):
			continue
		_translations[lang_code] = _build_language_map(
			translations_value,
			SUPPLEMENTAL_TRANSLATIONS.get(lang_code, {})
		)

	_current_language = _detect_system_language()


func _load_language_translations(file_path: String):
	var lang_script = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if lang_script == null:
		return {}

	var translations = lang_script.get("TRANSLATIONS")
	if translations is Dictionary:
		return (translations as Dictionary).duplicate(true)

	return {}


func _build_language_map(base_translations, supplemental_translations) -> Dictionary:
	var merged := {}

	if base_translations is Dictionary:
		merged = (base_translations as Dictionary).duplicate(true)

	if supplemental_translations is Dictionary:
		var supplemental_copy := (supplemental_translations as Dictionary).duplicate(true)
		for key in supplemental_copy.keys():
			merged[key] = supplemental_copy[key]

	return merged


func _detect_system_language() -> String:
	var locale := OS.get_locale()
	if AVAILABLE_LANGUAGES.has(locale):
		return locale

	var lang_code := locale.split("_")[0]
	match lang_code:
		"zh":
			var lower_locale := locale.to_lower()
			if lower_locale.contains("tw") or lower_locale.contains("hk") or lower_locale.contains("hant"):
				return "zh_TW"
			return "zh_CN"
		"ja":
			return "ja"
		"ru":
			return "ru"
		"fr":
			return "fr"
		"pt":
			return "pt"
		"es":
			return "es"
		"de":
			return "de"
		_:
			return "en"


func set_language(lang_code: String) -> void:
	if lang_code.is_empty():
		_current_language = _detect_system_language()
		return
	if AVAILABLE_LANGUAGES.has(lang_code):
		_current_language = lang_code


func get_language() -> String:
	return _current_language


func get_available_languages() -> Dictionary:
	return AVAILABLE_LANGUAGES


func get_available_language_codes() -> Array[String]:
	var ordered_codes: Array[String] = []
	for code in LANGUAGE_ORDER:
		if AVAILABLE_LANGUAGES.has(code):
			ordered_codes.append(code)
	for code in AVAILABLE_LANGUAGES.keys():
		var lang_code = str(code)
		if not ordered_codes.has(lang_code):
			ordered_codes.append(lang_code)
	return ordered_codes


func get_language_display_name(lang_code: String, current_lang: String = "") -> String:
	var native_name = str(LANGUAGE_NATIVE_NAMES.get(lang_code, AVAILABLE_LANGUAGES.get(lang_code, lang_code)))
	var english_name = str(AVAILABLE_LANGUAGES.get(lang_code, native_name))
	return "%s (%s)" % [english_name, native_name]


func get_text_for(lang_code: String, key: String) -> String:
	var resolved_lang := lang_code if not lang_code.is_empty() else _current_language
	var current_translations: Dictionary = _translations.get(resolved_lang, {})
	if current_translations.has(key):
		return str(current_translations[key])

	if resolved_lang != "en":
		var english_translations: Dictionary = _translations.get("en", {})
		if english_translations.has(key):
			return str(english_translations[key])

	return key


func get_text(key: String) -> String:
	return get_text_for(_current_language, key)


static func translate(key: String) -> String:
	return get_instance().get_text(key)
