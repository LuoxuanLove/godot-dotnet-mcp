extends RefCounted

# {"name": "locale_key_parity_contracts"}

const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var locale_translations := _load_supported_locale_translations()
	if locale_translations.is_empty():
		return _failure("No supported locale dictionaries were loaded for parity validation.")
	var all_keys := _collect_union_keys(locale_translations)
	if all_keys.is_empty():
		return _failure("Supported locale dictionaries should expose at least one translation key.")
	var localization = LocalizationServiceScript.new()
	localization._init_translations()
	var missing_by_locale := _find_missing_keys(localization, localization.get_available_language_codes(), all_keys)
	if not missing_by_locale.is_empty():
		return _failure("Supported locale dictionaries are missing translation keys after fallback resolution: %s" % _format_missing_keys(missing_by_locale))
	var untranslated_by_locale := _find_placeholder_keys(localization, localization.get_available_language_codes(), all_keys)
	if not untranslated_by_locale.is_empty():
		return _failure("Supported locale dictionaries contain placeholder or generated translation text: %s" % _format_missing_keys(untranslated_by_locale))

	return {
		"name": "locale_key_parity_contracts",
		"success": true,
		"error": "",
		"details": {
			"locale_count": locale_translations.size(),
			"translation_key_count": all_keys.size()
		}
	}


func _load_supported_locale_translations() -> Dictionary:
	var locale_translations := {}
	for locale_code in LocalizationServiceScript.LANGUAGE_FILES.keys():
		var file_path := str(LocalizationServiceScript.LANGUAGE_FILES[locale_code])
		var locale_script = ResourceLoader.load(file_path, "Script", ResourceLoader.CACHE_MODE_REPLACE)
		if locale_script is Script:
			locale_translations[str(locale_code)] = _get_raw_translations(locale_script as Script)
		else:
			locale_translations[str(locale_code)] = {}
	return locale_translations


func _get_raw_translations(locale_script: Script) -> Dictionary:
	var translations = locale_script.get("TRANSLATIONS")
	if translations is Dictionary:
		return (translations as Dictionary).duplicate(true)
	return {}


func _collect_union_keys(locale_translations: Dictionary) -> Array[String]:
	var seen := {}
	for translations in locale_translations.values():
		if not (translations is Dictionary):
			continue
		for key in (translations as Dictionary).keys():
			seen[str(key)] = true
	var keys: Array[String] = []
	for key in seen.keys():
		keys.append(str(key))
	keys.sort()
	return keys


func _find_missing_keys(localization, locale_codes: Array[String], all_keys: Array[String]) -> Dictionary:
	var missing_by_locale := {}
	for locale_code in locale_codes:
		var missing: Array[String] = []
		for key in all_keys:
			if localization.get_text_for(locale_code, key) == key:
				missing.append(key)
		if not missing.is_empty():
			missing_by_locale[str(locale_code)] = missing
	return missing_by_locale


func _find_placeholder_keys(localization, locale_codes: Array[String], all_keys: Array[String]) -> Dictionary:
	var placeholder_by_locale := {}
	for locale_code in locale_codes:
		var locale_name := str(locale_code)
		if locale_name == "en":
			continue
		var placeholders: Array[String] = []
		for key in all_keys:
			var localized_text: String = str(localization.get_text_for(locale_name, key))
			if _looks_like_generated_fallback(localized_text):
				placeholders.append(key)
			elif _looks_like_placeholder_translation(localized_text):
				placeholders.append(key)
		if not placeholders.is_empty():
			placeholder_by_locale[locale_name] = placeholders
	return placeholder_by_locale


func _looks_like_generated_fallback(text: String) -> bool:
	for prefix in ["Deutsch: ", "Español: ", "Français: ", "日本語: ", "Português: ", "Русский: ", "简体中文: ", "繁體中文: ", "한국어: "]:
		if text.begins_with(prefix):
			return true
	return false


func _looks_like_placeholder_translation(text: String) -> bool:
	return text.begins_with("Localized ")


func _format_missing_keys(missing_by_locale: Dictionary) -> String:
	var parts: Array[String] = []
	var locale_codes: Array[String] = []
	for locale_code in missing_by_locale.keys():
		locale_codes.append(str(locale_code))
	locale_codes.sort()
	for locale_code in locale_codes:
		var missing: Array = missing_by_locale.get(locale_code, [])
		var shown := []
		for key in missing.slice(0, 20):
			shown.append(str(key))
		var suffix := "" if missing.size() <= 20 else " (+%d more)" % (missing.size() - 20)
		parts.append("%s: %s%s" % [locale_code, ", ".join(shown), suffix])
	return "; ".join(parts)


func _failure(message: String) -> Dictionary:
	return {
		"name": "locale_key_parity_contracts",
		"success": false,
		"error": message
	}
