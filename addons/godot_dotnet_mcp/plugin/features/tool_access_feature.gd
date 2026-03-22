extends RefCounted

const PluginRuntimeState = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_runtime_state.gd")
const ToolPermissionPolicy = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_permission_policy.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _state
var _localization
var _tool_catalog
var _get_all_tools_by_category := Callable()
var _set_disabled_tools := Callable()
var _save_settings := Callable()
var _refresh_dock := Callable()
var _show_message := Callable()
var _change_language := Callable()


func configure(state, localization, tool_catalog, callbacks: Dictionary) -> void:
	_state = state
	_localization = localization
	_tool_catalog = tool_catalog
	_get_all_tools_by_category = callbacks.get("get_all_tools_by_category", Callable())
	_set_disabled_tools = callbacks.get("set_disabled_tools", Callable())
	_save_settings = callbacks.get("save_settings", Callable())
	_refresh_dock = callbacks.get("refresh_dock", Callable())
	_show_message = callbacks.get("show_message", Callable())
	_change_language = callbacks.get("change_language", Callable())


func handle_log_level_changed(level: String) -> void:
	if not _has_state():
		return
	_state.settings["log_level"] = level
	MCPDebugBuffer.set_minimum_level(level)
	_call_save_settings()
	_call_refresh_dock()


func handle_permission_level_changed(level: String) -> void:
	if not _has_state():
		return
	_state.settings["permission_level"] = ToolPermissionPolicy.normalize_permission_level(level)
	_call_save_settings()
	_call_refresh_dock()


func handle_show_user_tools_changed(enabled: bool) -> void:
	if not _has_state():
		return
	_state.settings["show_user_tools"] = enabled
	_call_save_settings()
	_call_refresh_dock()


func handle_tool_toggled(tool_name: String, enabled: bool) -> void:
	_apply_tool_enabled(tool_name, enabled, true)


func handle_category_toggled(category: String, enabled: bool) -> void:
	var tool_names = _build_tool_name_index()
	if not enabled and is_plugin_category_restricted(category):
		for tool_name in tool_names:
			if str(tool_name).begins_with(category + "_"):
				_set_tool_enabled(str(tool_name), false)
		_apply_disabled_tools_state()
		return

	if enabled and not can_enable_category(category):
		_call_show_message(get_permission_denied_message_for_category(category))
		_call_refresh_dock()
		return

	for tool_name in tool_names:
		if str(tool_name).begins_with(category + "_"):
			_set_tool_enabled(str(tool_name), enabled)
	_apply_disabled_tools_state()


func handle_domain_toggled(domain_key: String, enabled: bool) -> void:
	if enabled and not can_enable_domain(domain_key):
		_call_show_message(get_permission_denied_message_for_domain(domain_key))
		_call_refresh_dock()
		return

	var all_tools_by_category = _get_all_tools_by_category_safe()
	var target_categories: Array = []
	for domain_def in PluginRuntimeState.TOOL_DOMAIN_DEFS:
		if str(domain_def.get("key", "")) != domain_key:
			continue
		target_categories = domain_def.get("categories", []).duplicate()
		break

	if target_categories.is_empty():
		for category in all_tools_by_category.keys():
			var known_domain = _tool_catalog.find_domain_key_for_category(PluginRuntimeState.TOOL_DOMAIN_DEFS, str(category))
			if known_domain.is_empty():
				target_categories.append(str(category))

	for tool_name in _build_tool_name_index():
		for category in target_categories:
			if _tool_catalog.tool_belongs_to_category(str(tool_name), str(category)):
				_set_tool_enabled(str(tool_name), enabled)
				break

	_apply_disabled_tools_state()


func set_log_level_for_tools(level: String) -> Dictionary:
	handle_log_level_changed(level)
	return {"success": true, "log_level": str(_get_settings().get("log_level", level))}


func get_log_level_for_tools() -> String:
	return str(_get_settings().get("log_level", MCPDebugBuffer.get_minimum_level()))


func set_tool_enabled_from_tools(tool_name: String, enabled: bool) -> Dictionary:
	if enabled and not can_enable_tool(tool_name):
		return {"success": false, "error": get_permission_denied_message_for_tool(tool_name)}
	_apply_tool_enabled(tool_name, enabled, false)
	return {"success": true, "tool_name": tool_name, "enabled": enabled}


func set_category_enabled_from_tools(category: String, enabled: bool) -> Dictionary:
	if enabled and not can_enable_category(category):
		return {"success": false, "error": get_permission_denied_message_for_category(category)}
	handle_category_toggled(category, enabled)
	return {"success": true, "category": category, "enabled": enabled}


func set_domain_enabled_from_tools(domain_key: String, enabled: bool) -> Dictionary:
	if enabled and not can_enable_domain(domain_key):
		return {"success": false, "error": get_permission_denied_message_for_domain(domain_key)}
	handle_domain_toggled(domain_key, enabled)
	return {"success": true, "domain": domain_key, "enabled": enabled}


func set_show_user_tools_from_tools(enabled: bool) -> Dictionary:
	handle_show_user_tools_changed(enabled)
	return {"success": true, "show_user_tools": bool(_get_settings().get("show_user_tools", enabled))}


func get_developer_settings_for_tools() -> Dictionary:
	var settings = _get_settings()
	return {
		"success": true,
		"data": {
			"permission_level": get_permission_level(),
			"log_level": get_log_level_for_tools(),
			"show_user_tools": bool(settings.get("show_user_tools", true)),
			"language": str(settings.get("language", "")),
			"resolved_language": _resolve_active_language(),
			"tool_profile_id": str(settings.get("tool_profile_id", "default"))
		}
	}


func set_language_from_tools(language_code: String) -> Dictionary:
	if language_code.is_empty():
		return {"success": false, "error": "Language code is required"}
	if _localization == null or not _localization.get_available_languages().has(language_code):
		return {"success": false, "error": "Unsupported language: %s" % language_code}
	if not _change_language.is_valid():
		return {"success": false, "error": "Language change callback is unavailable"}
	_change_language.call(language_code)
	return {
		"success": true,
		"language": _resolve_active_language()
	}


func get_languages_for_tools() -> Dictionary:
	var languages: Array[Dictionary] = []
	var active_language = _resolve_active_language()
	var codes: Array = []
	if _localization != null:
		codes = _localization.get_available_language_codes()
	for code in codes:
		languages.append({
			"code": str(code),
			"name": _localization.get_language_display_name(str(code), active_language)
		})
	return {
		"success": true,
		"data": {
			"current_language": active_language,
			"languages": languages
		}
	}


func get_permission_level() -> String:
	return ToolPermissionPolicy.normalize_permission_level(str(_get_settings().get("permission_level", ToolPermissionPolicy.PERMISSION_EVOLUTION)))


func is_tool_category_visible_for_permission(category: String) -> bool:
	if category == "user":
		return bool(_get_settings().get("show_user_tools", true))
	if category == "plugin":
		return get_permission_level() == ToolPermissionPolicy.PERMISSION_DEVELOPER
	return is_tool_category_executable_for_permission(category)


func is_tool_category_executable_for_permission(category: String) -> bool:
	return ToolPermissionPolicy.permission_allows_category(get_permission_level(), category)


func get_permission_denied_message_for_category(category: String) -> String:
	return _get_text("permission_denied_category", "Permission denied: %s %s") % [get_permission_level(), category]


func get_permission_denied_message_for_tool(tool_name: String) -> String:
	var category = ToolPermissionPolicy.extract_category_from_tool_name(tool_name)
	if category.is_empty():
		return _get_text("permission_denied_tool", "Permission denied: %s %s") % [get_permission_level(), tool_name]
	return get_permission_denied_message_for_category(category)


func get_permission_denied_message_for_domain(domain_key: String) -> String:
	return _get_text("permission_denied_domain", "Permission denied: %s %s") % [get_permission_level(), domain_key]


func can_enable_tool(tool_name: String) -> bool:
	return ToolPermissionPolicy.permission_allows_tool(get_permission_level(), tool_name)


func can_enable_category(category: String) -> bool:
	return ToolPermissionPolicy.permission_allows_category(get_permission_level(), category)


func can_enable_domain(domain_key: String) -> bool:
	return ToolPermissionPolicy.permission_allows_domain(get_permission_level(), domain_key, PluginRuntimeState.TOOL_DOMAIN_DEFS)


func is_plugin_category_restricted(category: String) -> bool:
	return ToolPermissionPolicy.PLUGIN_CATEGORY_PERMISSION_LEVELS.has(category)


func cleanup_disabled_tools() -> void:
	if not _has_state():
		return
	var valid_tools := {}
	for tool_name in _build_tool_name_index():
		valid_tools[str(tool_name)] = true

	var filtered: Array = []
	for tool_name in _state.settings.get("disabled_tools", []):
		if valid_tools.has(str(tool_name)):
			filtered.append(str(tool_name))
	_state.settings["disabled_tools"] = filtered
	_call_set_disabled_tools(filtered)


func _apply_tool_enabled(tool_name: String, enabled: bool, notify_on_denied: bool) -> void:
	if enabled and not can_enable_tool(tool_name):
		if notify_on_denied:
			_call_show_message(get_permission_denied_message_for_tool(tool_name))
			_call_refresh_dock()
		return
	_set_tool_enabled(tool_name, enabled)
	_apply_disabled_tools_state()


func _apply_disabled_tools_state() -> void:
	_call_set_disabled_tools(_get_settings().get("disabled_tools", []))
	_call_save_settings()
	_call_refresh_dock()


func _set_tool_enabled(tool_name: String, enabled: bool) -> void:
	if not _has_state():
		return
	var disabled_tools: Array = _get_settings().get("disabled_tools", [])
	if enabled:
		disabled_tools.erase(tool_name)
	elif not disabled_tools.has(tool_name):
		disabled_tools.append(tool_name)
	_state.settings["disabled_tools"] = disabled_tools


func _build_tool_name_index() -> Array:
	if _tool_catalog == null:
		return []
	return _tool_catalog.build_tool_name_index(_get_all_tools_by_category_safe())


func _has_state() -> bool:
	return _state != null and is_instance_valid(_state)


func _get_settings() -> Dictionary:
	if _has_state():
		return _state.settings
	return {}


func _resolve_active_language() -> String:
	if _has_state() and _localization != null:
		return _state.resolve_active_language(_localization)
	if _localization != null:
		return _localization.get_language()
	return ""


func _get_text(key: String, fallback: String) -> String:
	if _localization != null:
		return _localization.get_text(key)
	return fallback


func _get_all_tools_by_category_safe() -> Dictionary:
	if not _get_all_tools_by_category.is_valid():
		return {}
	var tools_by_category = _get_all_tools_by_category.call()
	if tools_by_category is Dictionary:
		return tools_by_category
	return {}


func _call_set_disabled_tools(disabled_tools: Array) -> void:
	if _set_disabled_tools.is_valid():
		_set_disabled_tools.call(disabled_tools)


func _call_save_settings() -> void:
	if _save_settings.is_valid():
		_save_settings.call()


func _call_refresh_dock() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()


func _call_show_message(message: String) -> void:
	if _show_message.is_valid():
		_show_message.call(message)
