extends RefCounted

var _user_tool_service
var _show_message := Callable()
var _refresh_dock := Callable()
var _save_settings := Callable()
var _cleanup_disabled_tools := Callable()
var _create_reload_coordinator := Callable()
var _reload_all_domains := Callable()


func configure(user_tool_service, callbacks: Dictionary) -> void:
	_user_tool_service = user_tool_service
	_show_message = callbacks.get("show_message", Callable())
	_refresh_dock = callbacks.get("refresh_dock", Callable())
	_save_settings = callbacks.get("save_settings", Callable())
	_cleanup_disabled_tools = callbacks.get("cleanup_disabled_tools", Callable())
	_create_reload_coordinator = callbacks.get("create_reload_coordinator", Callable())
	_reload_all_domains = callbacks.get("reload_all_domains", Callable())


func handle_delete_requested(script_path: String) -> void:
	var result = _user_tool_service.delete_tool(script_path, true)
	if not bool(result.get("success", false)):
		_call_show_message(str(result.get("error", "Failed to delete user tool")))
		return
	if _reload_all_domains.is_valid():
		_reload_all_domains.call()
	if _cleanup_disabled_tools.is_valid():
		_cleanup_disabled_tools.call()
	if _save_settings.is_valid():
		_save_settings.call()
	_call_show_message(str(result.get("message", "User tool deleted")))
	_call_refresh_dock()


func get_user_tool_summaries() -> Array[Dictionary]:
	return _user_tool_service.list_user_tools()


func create_user_tool_from_tools(args: Dictionary) -> Dictionary:
	var result = _user_tool_service.create_tool_scaffold(
		str(args.get("tool_name", "")),
		str(args.get("display_name", "")),
		str(args.get("description", "")),
		bool(args.get("authorized", false)),
		str(args.get("agent_hint", ""))
	)
	if bool(result.get("success", false)):
		apply_user_tool_catalog_refresh(str((result.get("data", {}) as Dictionary).get("script_path", "")), "create_user_tool")
	return result


func delete_user_tool_from_tools(script_path: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	var result = _user_tool_service.delete_tool(script_path, authorized, agent_hint)
	if bool(result.get("success", false)):
		apply_user_tool_catalog_refresh(str((result.get("data", {}) as Dictionary).get("script_path", script_path)), "delete_user_tool")
	return result


func restore_user_tool_from_tools(authorized: bool, agent_hint: String = "") -> Dictionary:
	var result = _user_tool_service.restore_latest_backup(authorized, agent_hint)
	if bool(result.get("success", false)):
		apply_user_tool_catalog_refresh(str((result.get("data", {}) as Dictionary).get("script_path", "")), "restore_user_tool")
	return result


func apply_user_tool_catalog_refresh(script_path: String = "", reason: String = "user_tool_catalog_refresh") -> void:
	refresh_user_tool_registry()
	reload_user_tool_runtime(script_path, reason)
	rebuild_user_tool_ui_model()


func apply_external_user_tool_catalog_refresh(changed_paths: Array[String], reason: String = "external_watch") -> void:
	refresh_user_tool_registry()
	if changed_paths.is_empty():
		reload_user_tool_runtime("", reason)
	else:
		for script_path in changed_paths:
			reload_user_tool_runtime(str(script_path), reason)
	rebuild_user_tool_ui_model()


func refresh_user_tool_registry() -> Array[Dictionary]:
	return _user_tool_service.list_user_tools()


func reload_user_tool_runtime(script_path: String, reason: String) -> Dictionary:
	if not _create_reload_coordinator.is_valid():
		return {"success": false, "error": "Reload coordinator is unavailable"}
	var coordinator = _create_reload_coordinator.call()
	if coordinator == null:
		return {"success": false, "error": "Reload coordinator is unavailable"}
	if not script_path.is_empty():
		return coordinator.request_reload_by_script(script_path, reason)
	return coordinator.request_reload("user", reason)


func rebuild_user_tool_ui_model() -> void:
	if _cleanup_disabled_tools.is_valid():
		_cleanup_disabled_tools.call()
	if _save_settings.is_valid():
		_save_settings.call()
	_call_refresh_dock()


func get_user_tool_audit(limit: int = 20, filter_action: String = "", filter_session: String = "") -> Array[Dictionary]:
	return _user_tool_service.get_audit_entries(limit, filter_action, filter_session)


func get_user_tool_compatibility_from_tools() -> Dictionary:
	return {
		"success": true,
		"data": _user_tool_service.get_compatibility_report()
	}


func _call_show_message(message: String) -> void:
	if _show_message.is_valid():
		_show_message.call(message)


func _call_refresh_dock() -> void:
	if _refresh_dock.is_valid():
		_refresh_dock.call()
