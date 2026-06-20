@tool
extends RefCounted
class_name PluginDeveloperSettingsService


func build_settings_response(context: Dictionary) -> Dictionary:
	var state = context.get("state", null)
	var localization = context.get("localization", null)
	if state == null or localization == null:
		return {"success": false, "error": "Plugin developer settings service is unavailable"}
	return {
		"success": true,
		"data": {
			"log_level": str(context.get("log_level", "")),
			"show_user_tools": true,
			"language": str(state.settings.get("language", "")),
			"resolved_language": state.resolve_active_language(localization),
			"tool_profile_id": str(state.settings.get("tool_profile_id", "default"))
		}
	}


func validate_language(localization, language_code: String) -> Dictionary:
	if language_code.is_empty():
		return {"success": false, "error": "Language code is required"}
	if not localization.get_available_languages().has(language_code):
		return {"success": false, "error": "Unsupported language: %s" % language_code}
	return {"success": true}


func build_language_set_response(state, localization) -> Dictionary:
	return {
		"success": true,
		"language": state.resolve_active_language(localization)
	}


func build_languages_response(state, localization) -> Dictionary:
	var languages: Array[Dictionary] = []
	var active_language = state.resolve_active_language(localization)
	var codes: Array = localization.get_available_language_codes()
	for code in codes:
		languages.append({
			"code": str(code),
			"name": localization.get_language_display_name(str(code), active_language)
		})
	return {
		"success": true,
		"data": {
			"current_language": active_language,
			"languages": languages
		}
	}


func build_profiles_response(state, builtin_profiles: Array) -> Dictionary:
	return {
		"success": true,
		"data": {
			"builtin_profiles": builtin_profiles,
			"custom_profiles": state.custom_tool_profiles
		}
	}
