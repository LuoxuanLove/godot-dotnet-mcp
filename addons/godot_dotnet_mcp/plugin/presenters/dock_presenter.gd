extends RefCounted

const ClientConfigPresenterScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/client_config_presenter.gd")

var _client_config_presenter = ClientConfigPresenterScript.new()


func dispose() -> void:
	_client_config_presenter = null


func build_model(context: Dictionary) -> Dictionary:
	var state = context.get("state")
	var settings: Dictionary = context.get("settings", {})
	var localization = context.get("localization")
	var tool_catalog = context.get("tool_catalog")
	var server_controller = context.get("server_controller")
	var user_tool_service = context.get("user_tool_service")
	var config_service = context.get("config_service")
	var all_tools_by_category: Dictionary = context.get("all_tools_by_category", {})
	var tools_by_category: Dictionary = context.get("tools_by_category", {})
	var profile_id = _resolve_tool_profile_id(
		settings,
		tool_catalog,
		all_tools_by_category,
		context.get("builtin_profiles", []),
		context.get("custom_profiles", {})
	)
	var tool_names = tool_catalog.build_tool_name_index(all_tools_by_category)
	var current_tab = int(state.current_tab)

	var user_tools: Array = []
	var desktop_clients: Array[Dictionary] = []
	var cli_clients: Array[Dictionary] = []
	var config_platforms: Array[Dictionary] = []
	var config_connection_mode := {}

	if current_tab == 1 and user_tool_service != null:
		user_tools = user_tool_service.list_user_tools()

	if current_tab == 2:
		var client_install_statuses: Dictionary = context.get("client_install_statuses", {})
		var runtime_process: Dictionary = {}
		desktop_clients = _client_config_presenter.build_desktop_client_models(
			settings,
			str(state.current_cli_scope),
			runtime_process,
			client_install_statuses,
			localization,
			config_service
		)
		cli_clients = _client_config_presenter.build_cli_client_models(
			settings,
			str(state.current_cli_scope),
			runtime_process,
			client_install_statuses,
			localization,
			config_service
		)
		config_platforms = _client_config_presenter.build_config_platform_models(desktop_clients, cli_clients)
		state.current_config_platform = _client_config_presenter.resolve_current_config_platform(
			str(state.current_config_platform),
			config_platforms
		)
		settings["current_config_platform"] = state.current_config_platform
		config_connection_mode = _client_config_presenter.build_config_connection_mode(settings, runtime_process, localization)

	return {
		"localization": localization,
		"settings": settings,
		"current_language": _resolve_current_language(state, localization),
		"current_tab": state.current_tab,
		"log_levels": context.get("log_levels", []),
		"current_log_level": str(context.get("current_log_level", "")),
		"current_cli_scope": state.current_cli_scope,
		"current_config_platform": state.current_config_platform,
		"tool_profile_id": profile_id,
		"editor_scale": float(context.get("editor_scale", 1.0)),
		"is_running": server_controller.is_running(),
		"stats": server_controller.get_connection_stats(),
		"domain_states": server_controller.get_domain_states(),
		"reload_status": server_controller.get_reload_status(),
		"performance": server_controller.get_performance_summary(),
		"languages": localization.get_available_languages(),
		"tools_by_category": tools_by_category,
		"tool_presentation": context.get("tool_presentation", {}),
		"presentationVersion": int(context.get("tool_presentation", {}).get("presentationVersion", 1)) if context.get("tool_presentation", {}) is Dictionary else 1,
		"toolTree": context.get("tool_presentation", {}).get("toolTree", []) if context.get("tool_presentation", {}) is Dictionary else [],
		"toolGroups": context.get("tool_presentation", {}).get("toolGroups", []) if context.get("tool_presentation", {}) is Dictionary else [],
		"tool_load_errors": server_controller.get_tool_load_errors(),
		"self_diagnostics": context.get("self_diagnostics", {}),
		"self_diagnostic_copy_text": str(context.get("self_diagnostic_copy_text", "")),
		"builtin_profiles": context.get("builtin_profiles", []),
		"custom_profiles": context.get("custom_profiles", {}),
		"domain_defs": context.get("domain_defs", {}),
		"profile_description": _get_tool_profile_description(
			profile_id,
			tool_names,
			context.get("builtin_profiles", []),
			context.get("custom_profiles", {}),
			settings,
			localization,
			tool_catalog
		),
		"user_tools": user_tools,
		"user_tool_watch": context.get("user_tool_watch", {}),
		"desktop_clients": desktop_clients,
		"cli_clients": cli_clients,
		"config_platforms": config_platforms,
		"config_connection_mode": config_connection_mode,
		"plugin_freshness": context.get("plugin_freshness", {}),
		"plugin_version": str(context.get("plugin_version", "")),
		"update_refs_state": str(context.get("update_refs_state", "idle")),
		"update_refs_status": str(context.get("update_refs_status", "")),
		"update_refs_error": str(context.get("update_refs_error", "")),
		"update_refs_branches": context.get("update_refs_branches", []),
		"update_refs_releases": context.get("update_refs_releases", []),
		"update_refs_latest_stable_release": str(context.get("update_refs_latest_stable_release", "")),
		"update_refs_latest_release": str(context.get("update_refs_latest_release", "")),
		"update_refs_release_source": str(context.get("update_refs_release_source", "")),
		"update_refs_commits": context.get("update_refs_commits", {}),
		"update_refs_versions": context.get("update_refs_versions", {}),
		"update_compare_state": str(context.get("update_compare_state", "idle")),
		"update_compare_error": str(context.get("update_compare_error", "")),
		"update_compare_base_commit": str(context.get("update_compare_base_commit", "")),
		"update_compare_target_ref": str(context.get("update_compare_target_ref", "")),
		"update_compare_target_commit": str(context.get("update_compare_target_commit", "")),
		"update_compare_ahead_by": int(context.get("update_compare_ahead_by", -1)),
		"update_compare_behind_by": int(context.get("update_compare_behind_by", -1)),
		"update_sync_state": str(context.get("update_sync_state", "idle")),
		"update_sync_status": str(context.get("update_sync_status", "")),
		"update_sync_error": str(context.get("update_sync_error", "")),
		"update_sync_target_ref": str(context.get("update_sync_target_ref", "")),
		"update_sync_target_kind": str(context.get("update_sync_target_kind", ""))
	}


func _resolve_current_language(state, localization) -> String:
	if state != null:
		var settings = state.settings if state.settings is Dictionary else {}
		var configured_language = str(settings.get("language", ""))
		if not configured_language.is_empty():
			return configured_language
	if localization != null:
		return str(localization.get_language())
	return "en"


func build_client_transport_model(settings: Dictionary, runtime_process: Dictionary) -> Dictionary:
	return _client_config_presenter.build_client_transport_model(settings, runtime_process)


func get_client_install_message_text(client_id: String, status: String, localization) -> String:
	return _client_config_presenter.get_client_install_message_text(client_id, status, localization)


func _resolve_tool_profile_id(
	settings: Dictionary,
	tool_catalog,
	all_tools_by_category: Dictionary,
	builtin_profiles: Array,
	custom_profiles: Dictionary
) -> String:
	var tool_names = tool_catalog.build_tool_name_index(all_tools_by_category)
	var profile_id = str(settings.get("tool_profile_id", "default"))
	if tool_catalog.has_tool_profile(profile_id, builtin_profiles, custom_profiles):
		return profile_id

	profile_id = tool_catalog.find_matching_profile_id(
		settings.get("disabled_tools", []),
		builtin_profiles,
		custom_profiles,
		tool_names
	)
	if profile_id.is_empty():
		profile_id = "default"
	settings["tool_profile_id"] = profile_id
	return profile_id


func _get_tool_profile_description(
	profile_id: String,
	tool_names: Array,
	builtin_profiles: Array,
	custom_profiles: Dictionary,
	settings: Dictionary,
	localization,
	tool_catalog
) -> String:
	var description = ""
	for profile in builtin_profiles:
		if str(profile.get("id", "")) == profile_id:
			description = localization.get_text(str(profile.get("desc_key", "")))
			break

	if description.is_empty() and custom_profiles.has(profile_id):
		description = localization.get_text("tool_profile_custom_desc") % [str(custom_profiles[profile_id].get("name", profile_id))]

	if description.is_empty():
		description = localization.get_text("tool_profile_default_desc")

	if not tool_catalog.profile_matches_state(
		profile_id,
		settings.get("disabled_tools", []),
		builtin_profiles,
		custom_profiles,
		tool_names
	):
		description = "%s %s" % [description, localization.get_text("tool_profile_modified_desc")]

	return description
