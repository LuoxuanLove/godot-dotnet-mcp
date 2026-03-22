extends RefCounted

const ToolProfileCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_profile_catalog.gd")

var _state
var _localization
var _settings_store
var _tool_catalog
var _get_all_tools_by_category := Callable()
var _set_disabled_tools := Callable()
var _cleanup_disabled_tools := Callable()
var _save_settings := Callable()
var _refresh_dock := Callable()


func configure(state, localization, settings_store, tool_catalog, callbacks: Dictionary) -> void:
	_state = state
	_localization = localization
	_settings_store = settings_store
	_tool_catalog = tool_catalog
	_get_all_tools_by_category = callbacks.get("get_all_tools_by_category", Callable())
	_set_disabled_tools = callbacks.get("set_disabled_tools", Callable())
	_cleanup_disabled_tools = callbacks.get("cleanup_disabled_tools", Callable())
	_save_settings = callbacks.get("save_settings", Callable())
	_refresh_dock = callbacks.get("refresh_dock", Callable())


func apply_initial_tool_profile_if_needed() -> void:
	if _state == null or not bool(_state.needs_initial_tool_profile_apply):
		return
	var tool_names = _build_tool_name_index()
	if tool_names.is_empty():
		return

	_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
		str(_state.settings.get("tool_profile_id", "default")),
		ToolProfileCatalog.get_builtin_profiles(),
		_state.custom_tool_profiles,
		tool_names,
		_state.settings.get("disabled_tools", [])
	)
	_state.needs_initial_tool_profile_apply = false
	_call_set_disabled_tools(_state.settings.get("disabled_tools", []))
	_call_save_settings()


func list_profiles_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": {
			"builtin_profiles": ToolProfileCatalog.get_builtin_profiles(),
			"custom_profiles": _state.custom_tool_profiles
		}
	}


func apply_profile_from_tools(profile_id: String) -> Dictionary:
	if profile_id.is_empty():
		return {"success": false, "error": "Profile id is required"}
	if not _tool_catalog.has_tool_profile(profile_id, ToolProfileCatalog.get_builtin_profiles(), _state.custom_tool_profiles):
		return {"success": false, "error": "Unknown profile id: %s" % profile_id}
	_apply_tool_profile(profile_id, true)
	return {
		"success": true,
		"profile_id": str(_state.settings.get("tool_profile_id", profile_id))
	}


func save_profile_from_tools(profile_name: String) -> Dictionary:
	var result = _save_custom_profile(profile_name)
	if bool(result.get("success", false)):
		_call_refresh_dock()
	return result


func rename_profile_from_tools(profile_id: String, profile_name: String) -> Dictionary:
	var result = _rename_custom_profile(profile_id, profile_name)
	if bool(result.get("success", false)):
		_call_refresh_dock()
	return result


func delete_profile_from_tools(profile_id: String) -> Dictionary:
	var result = _delete_custom_profile(profile_id)
	if bool(result.get("success", false)):
		_call_refresh_dock()
	return result


func export_config_from_tools(file_path: String) -> Dictionary:
	var disabled_tools: Array = _state.settings.get("disabled_tools", [])
	var result = _settings_store.export_tool_config(
		file_path,
		str(_state.settings.get("tool_profile_id", "default")),
		disabled_tools
	)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_tool_config_error_text(str(result.get("error_code", "config_write_failed")))}

	return {
		"success": true,
		"data": {
			"path": str(result.get("file_path", file_path)),
			"profile_id": str(_state.settings.get("tool_profile_id", "default")),
			"disabled_tools": disabled_tools.duplicate(),
			"disabled_tool_count": disabled_tools.size()
		},
		"message": _get_text("tool_config_exported")
	}


func import_config_from_tools(file_path: String) -> Dictionary:
	var result = _settings_store.import_tool_config(file_path)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_tool_config_error_text(str(result.get("error_code", "config_parse_failed")))}

	var imported_data: Dictionary = result.get("data", {})
	var tool_names = _build_tool_name_index()
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
	if not _tool_catalog.has_tool_profile(resolved_profile_id, ToolProfileCatalog.get_builtin_profiles(), _state.custom_tool_profiles):
		resolved_profile_id = _tool_catalog.find_matching_profile_id(
			imported_disabled,
			ToolProfileCatalog.get_builtin_profiles(),
			_state.custom_tool_profiles,
			tool_names
		)
		if resolved_profile_id.is_empty():
			resolved_profile_id = "default"

	_state.settings["tool_profile_id"] = resolved_profile_id
	_state.settings["disabled_tools"] = imported_disabled
	_call_cleanup_disabled_tools()
	_call_save_settings()
	_call_refresh_dock()

	return {
		"success": true,
		"data": {
			"path": str(result.get("file_path", file_path)),
			"requested_profile_id": requested_profile_id,
			"resolved_profile_id": resolved_profile_id,
			"disabled_tools": _state.settings.get("disabled_tools", []).duplicate(),
			"disabled_tool_count": _state.settings.get("disabled_tools", []).size(),
			"ignored_tools": ignored_tools
		},
		"message": _get_text("tool_config_imported")
	}


func _apply_tool_profile(profile_id: String, refresh_ui: bool = true) -> void:
	var tool_names = _build_tool_name_index()
	_state.settings["tool_profile_id"] = profile_id
	_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
		profile_id,
		ToolProfileCatalog.get_builtin_profiles(),
		_state.custom_tool_profiles,
		tool_names,
		_state.settings.get("disabled_tools", [])
	)
	_call_set_disabled_tools(_state.settings.get("disabled_tools", []))
	_call_save_settings()
	if refresh_ui:
		_call_refresh_dock()


func _save_custom_profile(profile_name: String) -> Dictionary:
	if profile_name.is_empty():
		return {
			"success": false,
			"error": _get_text("tool_profile_name_required")
		}

	var result = _settings_store.save_custom_profile(
		ToolProfileCatalog.PROFILE_STORAGE_DIR,
		profile_name,
		_state.settings.get("disabled_tools", [])
	)
	if not bool(result.get("success", false)):
		return {
			"success": false,
			"error": _get_text("tool_profile_save_failed")
		}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(ToolProfileCatalog.PROFILE_STORAGE_DIR)
	_state.settings["tool_profile_id"] = "custom:%s" % str(result.get("slug", ""))
	_call_save_settings()
	return {
		"success": true,
		"profile_id": str(_state.settings.get("tool_profile_id", "")),
		"message": _get_text("tool_profile_saved") % profile_name
	}


func _rename_custom_profile(profile_id: String, profile_name: String) -> Dictionary:
	if _is_builtin_profile_id(profile_id):
		return {"success": false, "error": _get_text("tool_profile_builtin_protected")}

	var result = _settings_store.rename_custom_profile(
		ToolProfileCatalog.PROFILE_STORAGE_DIR,
		profile_id,
		profile_name
	)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_custom_profile_error_text(str(result.get("error_code", "rename_failed")))}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(ToolProfileCatalog.PROFILE_STORAGE_DIR)
	if str(_state.settings.get("tool_profile_id", "")) == profile_id:
		_state.settings["tool_profile_id"] = str(result.get("profile_id", profile_id))
	_call_set_disabled_tools(_state.settings.get("disabled_tools", []))
	_call_save_settings()
	return {
		"success": true,
		"profile_id": str(result.get("profile_id", profile_id)),
		"message": _get_text("tool_profile_renamed") % str(result.get("profile_name", profile_name.strip_edges()))
	}


func _delete_custom_profile(profile_id: String) -> Dictionary:
	if _is_builtin_profile_id(profile_id):
		return {"success": false, "error": _get_text("tool_profile_builtin_protected")}

	var result = _settings_store.delete_custom_profile(ToolProfileCatalog.PROFILE_STORAGE_DIR, profile_id)
	if not bool(result.get("success", false)):
		return {"success": false, "error": _get_custom_profile_error_text(str(result.get("error_code", "delete_failed")))}

	_state.custom_tool_profiles = _settings_store.load_custom_profiles(ToolProfileCatalog.PROFILE_STORAGE_DIR)
	if str(_state.settings.get("tool_profile_id", "")) == profile_id:
		var tool_names = _build_tool_name_index()
		_state.settings["tool_profile_id"] = "default"
		_state.settings["disabled_tools"] = _tool_catalog.get_disabled_tools_for_profile(
			"default",
			ToolProfileCatalog.get_builtin_profiles(),
			_state.custom_tool_profiles,
			tool_names,
			_state.settings.get("disabled_tools", [])
		)
	_call_set_disabled_tools(_state.settings.get("disabled_tools", []))
	_call_save_settings()
	return {
		"success": true,
		"profile_id": "default" if str(_state.settings.get("tool_profile_id", "")) == "default" else profile_id,
		"message": _get_text("tool_profile_deleted")
	}


func _is_builtin_profile_id(profile_id: String) -> bool:
	return not profile_id.begins_with("custom:")


func _get_custom_profile_error_text(error_code: String) -> String:
	match error_code:
		"empty_profile_name":
			return _get_text("tool_profile_name_required")
		"profile_name_conflict":
			return _get_text("tool_profile_name_conflict")
		"profile_not_found", "invalid_profile_id":
			return _get_text("tool_profile_not_found")
		_:
			if error_code.begins_with("rename"):
				return _get_text("tool_profile_rename_failed")
			return _get_text("tool_profile_delete_failed")


func _get_tool_config_error_text(error_code: String) -> String:
	match error_code:
		"config_path_required":
			return _get_text("tool_config_path_required")
		"config_parent_dir_create_failed":
			return _get_text("tool_config_parent_dir_create_failed")
		"config_write_failed":
			return _get_text("tool_config_write_failed")
		"config_not_found":
			return _get_text("tool_config_not_found")
		"config_open_failed":
			return _get_text("tool_config_open_failed")
		"config_profile_required", "config_disabled_tools_invalid", "config_parse_failed":
			return _get_text("tool_config_parse_failed")
		_:
			return _get_text("tool_config_write_failed")


func _build_tool_name_index() -> Array:
	if not _get_all_tools_by_category.is_valid():
		return []
	var tools_by_category = _get_all_tools_by_category.call()
	if not (tools_by_category is Dictionary):
		return []
	return _tool_catalog.build_tool_name_index(tools_by_category)


func _get_text(key: String) -> String:
	if _localization != null and _localization.has_method("get_text"):
		return _localization.get_text(key)
	return key


func _call_set_disabled_tools(disabled_tools: Array) -> void:
	if _set_disabled_tools.is_valid():
		_set_disabled_tools.call(disabled_tools)


func _call_cleanup_disabled_tools() -> void:
	if _cleanup_disabled_tools.is_valid():
		_cleanup_disabled_tools.call()


func _call_save_settings() -> void:
	if _save_settings.is_valid():
		_save_settings.call()


func _call_refresh_dock() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()
