@tool
extends RefCounted
class_name PluginProfileConfigService


func apply_tool_profile(context: Dictionary, profile_id: String) -> Dictionary:
	var tool_catalog = context.get("tool_catalog", null)
	var server_controller = context.get("server_controller", null)
	var state = context.get("state", null)
	var settings_store = context.get("settings_store", null)
	if tool_catalog == null or server_controller == null or state == null or settings_store == null:
		return {"success": false, "error": "Plugin profile config service is unavailable"}
	var tool_names = tool_catalog.build_tool_name_index(server_controller.get_all_tools_by_category())
	state.settings["tool_profile_id"] = profile_id
	state.settings["disabled_tools"] = tool_catalog.get_disabled_tools_for_profile(
		profile_id,
		context.get("builtin_profiles", []),
		state.custom_tool_profiles,
		tool_names,
		state.settings.get("disabled_tools", [])
	)
	server_controller.set_disabled_tools(state.settings["disabled_tools"])
	settings_store.save_plugin_settings(str(context.get("settings_path", "")), state.settings)
	return {"success": true, "profile_id": str(state.settings.get("tool_profile_id", profile_id))}


func save_custom_profile(context: Dictionary, profile_name: String) -> Dictionary:
	var state = context.get("state", null)
	var settings_store = context.get("settings_store", null)
	var localization = context.get("localization", null)
	if state == null or settings_store == null or localization == null:
		return {"success": false, "error": "Plugin profile config service is unavailable"}
	if profile_name.is_empty():
		return {"success": false, "error": localization.get_text("tool_profile_name_required")}

	var result = settings_store.save_custom_profile(
		str(context.get("profile_dir", "")),
		profile_name,
		state.settings.get("disabled_tools", [])
	)
	if not bool(result.get("success", false)):
		return {"success": false, "error": localization.get_text("tool_profile_save_failed")}

	state.custom_tool_profiles = settings_store.load_custom_profiles(str(context.get("profile_dir", "")))
	state.settings["tool_profile_id"] = "custom:%s" % str(result.get("slug", ""))
	settings_store.save_plugin_settings(str(context.get("settings_path", "")), state.settings)
	return {
		"success": true,
		"profile_id": str(state.settings.get("tool_profile_id", "")),
		"message": localization.get_text("tool_profile_saved") % profile_name
	}


func rename_custom_profile(context: Dictionary, profile_id: String, profile_name: String) -> Dictionary:
	var state = context.get("state", null)
	var settings_store = context.get("settings_store", null)
	var localization = context.get("localization", null)
	var server_controller = context.get("server_controller", null)
	if state == null or settings_store == null or localization == null or server_controller == null:
		return {"success": false, "error": "Plugin profile config service is unavailable"}
	if _is_builtin_profile_id(profile_id):
		return {"success": false, "error": localization.get_text("tool_profile_builtin_protected")}

	var result = settings_store.rename_custom_profile(str(context.get("profile_dir", "")), profile_id, profile_name)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_custom_profile_error_text(localization, str(result.get("error_code", "rename_failed")))}

	state.custom_tool_profiles = settings_store.load_custom_profiles(str(context.get("profile_dir", "")))
	if str(state.settings.get("tool_profile_id", "")) == profile_id:
		state.settings["tool_profile_id"] = str(result.get("profile_id", profile_id))
	server_controller.set_disabled_tools(state.settings.get("disabled_tools", []))
	settings_store.save_plugin_settings(str(context.get("settings_path", "")), state.settings)
	return {
		"success": true,
		"profile_id": str(result.get("profile_id", profile_id)),
		"message": localization.get_text("tool_profile_renamed") % str(result.get("profile_name", profile_name.strip_edges()))
	}


func delete_custom_profile(context: Dictionary, profile_id: String) -> Dictionary:
	var state = context.get("state", null)
	var settings_store = context.get("settings_store", null)
	var localization = context.get("localization", null)
	var server_controller = context.get("server_controller", null)
	var tool_catalog = context.get("tool_catalog", null)
	if state == null or settings_store == null or localization == null or server_controller == null or tool_catalog == null:
		return {"success": false, "error": "Plugin profile config service is unavailable"}
	if _is_builtin_profile_id(profile_id):
		return {"success": false, "error": localization.get_text("tool_profile_builtin_protected")}

	var result = settings_store.delete_custom_profile(str(context.get("profile_dir", "")), profile_id)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_custom_profile_error_text(localization, str(result.get("error_code", "delete_failed")))}

	state.custom_tool_profiles = settings_store.load_custom_profiles(str(context.get("profile_dir", "")))
	if str(state.settings.get("tool_profile_id", "")) == profile_id:
		var tool_names = tool_catalog.build_tool_name_index(server_controller.get_all_tools_by_category())
		state.settings["tool_profile_id"] = "default"
		state.settings["disabled_tools"] = tool_catalog.get_disabled_tools_for_profile(
			"default",
			context.get("builtin_profiles", []),
			state.custom_tool_profiles,
			tool_names,
			state.settings.get("disabled_tools", [])
		)
	server_controller.set_disabled_tools(state.settings.get("disabled_tools", []))
	settings_store.save_plugin_settings(str(context.get("settings_path", "")), state.settings)
	return {
		"success": true,
		"profile_id": "default" if str(state.settings.get("tool_profile_id", "")) == "default" else profile_id,
		"message": localization.get_text("tool_profile_deleted")
	}


func export_config(context: Dictionary, file_path: String) -> Dictionary:
	var state = context.get("state", null)
	var settings_store = context.get("settings_store", null)
	var localization = context.get("localization", null)
	if state == null or settings_store == null or localization == null:
		return {"success": false, "error": "Plugin profile config service is unavailable"}
	var disabled_tools: Array = state.settings.get("disabled_tools", [])
	var result = settings_store.export_tool_config(file_path, str(state.settings.get("tool_profile_id", "default")), disabled_tools)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_tool_config_error_text(localization, str(result.get("error_code", "config_write_failed")))}

	return {
		"success": true,
		"data": {
			"path": str(result.get("file_path", file_path)),
			"profile_id": str(state.settings.get("tool_profile_id", "default")),
			"disabled_tools": disabled_tools.duplicate(),
			"disabled_tool_count": disabled_tools.size()
		},
		"message": localization.get_text("tool_config_exported")
	}


func import_config(context: Dictionary, file_path: String) -> Dictionary:
	var state = context.get("state", null)
	var settings_store = context.get("settings_store", null)
	var localization = context.get("localization", null)
	var server_controller = context.get("server_controller", null)
	var tool_catalog = context.get("tool_catalog", null)
	if state == null or settings_store == null or localization == null or server_controller == null or tool_catalog == null:
		return {"success": false, "error": "Plugin profile config service is unavailable"}
	var result = settings_store.import_tool_config(file_path)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_tool_config_error_text(localization, str(result.get("error_code", "config_parse_failed")))}

	var imported_data: Dictionary = result.get("data", {})
	var tool_names = tool_catalog.build_tool_name_index(server_controller.get_all_tools_by_category())
	var valid_tools := {}
	for tool_name in tool_names:
		valid_tools[str(tool_name)] = true

	var imported_disabled: Array[String] = []
	var ignored_tools: Array[String] = []
	for tool_name in imported_data.get("disabled_tools", []):
		var normalized_tool_name = str(tool_name)
		if valid_tools.has(normalized_tool_name):
			imported_disabled.append(normalized_tool_name)
		else:
			ignored_tools.append(normalized_tool_name)
	imported_disabled.sort()
	ignored_tools.sort()

	var requested_profile_id = str(imported_data.get("profile_id", "default"))
	var resolved_profile_id = requested_profile_id
	if not tool_catalog.has_tool_profile(resolved_profile_id, context.get("builtin_profiles", []), state.custom_tool_profiles):
		resolved_profile_id = tool_catalog.find_matching_profile_id(
			imported_disabled,
			context.get("builtin_profiles", []),
			state.custom_tool_profiles,
			tool_names
		)
		if resolved_profile_id.is_empty():
			resolved_profile_id = "default"

	state.settings["tool_profile_id"] = resolved_profile_id
	state.settings["disabled_tools"] = imported_disabled
	settings_store.save_plugin_settings(str(context.get("settings_path", "")), state.settings)

	return {
		"success": true,
		"data": {
			"path": str(result.get("file_path", file_path)),
			"requested_profile_id": requested_profile_id,
			"resolved_profile_id": resolved_profile_id,
			"disabled_tools": state.settings.get("disabled_tools", []).duplicate(),
			"disabled_tool_count": state.settings.get("disabled_tools", []).size(),
			"ignored_tools": ignored_tools
		},
		"message": localization.get_text("tool_config_imported")
	}


func map_custom_profile_error(localization, error_code: String) -> String:
	return _get_custom_profile_error_text(localization, error_code)


func map_tool_config_error(localization, error_code: String) -> String:
	return _get_tool_config_error_text(localization, error_code)


func _is_builtin_profile_id(profile_id: String) -> bool:
	return not profile_id.begins_with("custom:")


func _get_custom_profile_error_text(localization, error_code: String) -> String:
	match error_code:
		"empty_profile_name":
			return localization.get_text("tool_profile_name_required")
		"profile_name_conflict":
			return localization.get_text("tool_profile_name_conflict")
		"profile_not_found", "invalid_profile_id":
			return localization.get_text("tool_profile_not_found")
		_:
			if error_code.begins_with("rename"):
				return localization.get_text("tool_profile_rename_failed")
			return localization.get_text("tool_profile_delete_failed")


func _get_tool_config_error_text(localization, error_code: String) -> String:
	match error_code:
		"config_path_required":
			return localization.get_text("tool_config_path_required")
		"config_not_found":
			return localization.get_text("tool_config_not_found")
		"config_profile_required", "config_disabled_tools_invalid", "config_parse_failed":
			return localization.get_text("tool_config_validation_failed")
		"config_dir_create_failed", "config_write_failed", "config_open_failed":
			return localization.get_text("tool_config_write_failed")
		_:
			return localization.get_text("tool_config_validation_failed")
