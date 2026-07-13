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
	var missing_by_locale := _find_missing_keys(locale_translations, localization.get_available_language_codes(), all_keys)
	if not missing_by_locale.is_empty():
		return _failure("Supported locale dictionaries are missing raw translation keys: %s" % _format_missing_keys(missing_by_locale))
	var untranslated_by_locale := _find_placeholder_keys(localization, localization.get_available_language_codes(), all_keys)
	if not untranslated_by_locale.is_empty():
		return _failure("Supported locale dictionaries contain placeholder or generated translation text: %s" % _format_missing_keys(untranslated_by_locale))
	var inconsistent_update_guidance := _find_inconsistent_update_action_guidance(locale_translations)
	if not inconsistent_update_guidance.is_empty():
		return _failure("Settings update guidance should use the localized visible action names: %s" % _format_missing_keys(inconsistent_update_guidance))

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
	if locale_script.has_method("get_translations"):
		var merged_translations = locale_script.call("get_translations")
		if merged_translations is Dictionary:
			return (merged_translations as Dictionary).duplicate(true)
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


func _find_missing_keys(locale_translations: Dictionary, locale_codes: Array[String], all_keys: Array[String]) -> Dictionary:
	var missing_by_locale := {}
	for locale_code in locale_codes:
		var locale_name := str(locale_code)
		var translations: Dictionary = locale_translations.get(locale_name, {})
		var missing: Array[String] = []
		for key in all_keys:
			if not translations.has(key):
				missing.append(key)
		if not missing.is_empty():
			missing_by_locale[locale_name] = missing
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


func _find_inconsistent_update_action_guidance(locale_translations: Dictionary) -> Dictionary:
	var inconsistent_by_locale := {}
	var refresh_guidance_keys := [
		"settings_update_placeholder_status",
		"settings_update_branch_unavailable",
		"settings_update_release_unavailable",
		"settings_update_refs_idle"
	]
	for raw_locale_code in locale_translations.keys():
		var locale_code := str(raw_locale_code)
		var translations: Dictionary = locale_translations.get(locale_code, {})
		var refresh_label := str(translations.get("settings_update_refresh_list", "")).strip_edges()
		var one_click_label := str(translations.get("settings_update_one_click", "")).strip_edges()
		var switch_label := str(translations.get("settings_update_switch", "")).strip_edges()
		var inconsistent_keys: Array[String] = []
		for key in refresh_guidance_keys:
			if refresh_label.is_empty() or not str(translations.get(key, "")).contains(refresh_label):
				inconsistent_keys.append(key)
		if one_click_label.is_empty() or not str(translations.get("settings_update_placeholder_status", "")).contains(one_click_label):
			inconsistent_keys.append("settings_update_placeholder_status")
		var update_description := str(translations.get("settings_updates_description", ""))
		if refresh_label.is_empty() or one_click_label.is_empty() or switch_label.is_empty() or not update_description.contains(refresh_label) or not update_description.contains(one_click_label) or not update_description.contains(switch_label):
			inconsistent_keys.append("settings_updates_description")
		if not inconsistent_keys.is_empty():
			inconsistent_by_locale[locale_code] = inconsistent_keys
	return inconsistent_by_locale


func _looks_like_generated_fallback(text: String) -> bool:
	for prefix in ["Deutsch: ", "Español: ", "Français: ", "日本語: ", "Português: ", "Русский: ", "简体中文: ", "繁體中文: ", "한국어: "]:
		if text.begins_with(prefix):
			return true
	return false


func _looks_like_placeholder_translation(text: String) -> bool:
	if text.begins_with("Localized "):
		return true
	if text.contains("????"):
		return true
	for marker in ["쓰기s", "읽기-back", "열기ed", "구성uration", "설정ting", "설정up", "디버그gee", "오류s", "작업s", "생성 and", "읽기 or", "실행 and", "구성ure"]:
		if text.contains(marker):
			return true
	return false


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
