extends RefCounted

# {"name": "plugin_update_endpoint_config_service_contracts"}

const PluginUpdateEndpointConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_endpoint_config_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_update_endpoint_config()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginUpdateEndpointConfigServiceScript.new()
	var refs_urls: Dictionary = service.get_refs_request_urls()
	if str(refs_urls.get("branches", "")) != "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/branches?per_page=100&page=1":
		return _failure("PluginUpdateEndpointConfigService should own the GitHub branches discovery URL.", refs_urls)
	if str(refs_urls.get("releases", "")).find("/releases?per_page=100&page=1") == -1:
		return _failure("PluginUpdateEndpointConfigService should own the GitHub releases discovery URL.", refs_urls)
	if str(refs_urls.get("tags", "")).find("/tags?per_page=100&page=1") == -1:
		return _failure("PluginUpdateEndpointConfigService should own the GitHub tags discovery URL.", refs_urls)
	if service.get_branch_commits_url_template().find("/commits?sha=%s&per_page=100&page=1") == -1:
		return _failure("PluginUpdateEndpointConfigService should use 100-item pages for local commit history.", {"template": service.get_branch_commits_url_template()})

	if service.get_refs_http_timeout() != 10.0:
		return _failure("PluginUpdateEndpointConfigService should preserve refs HTTP timeout.", {"timeout": service.get_refs_http_timeout()})
	if service.get_refs_body_size_limit() != 16777216:
		return _failure("PluginUpdateEndpointConfigService should preserve refs body size limit.", {"limit": service.get_refs_body_size_limit()})
	if service.get_refs_max_pages() != 20:
		return _failure("PluginUpdateEndpointConfigService should preserve refs pagination cap.", {"pages": service.get_refs_max_pages()})
	if service.get_sync_http_timeout() != 60.0:
		return _failure("PluginUpdateEndpointConfigService should preserve sync HTTP timeout.", {"timeout": service.get_sync_http_timeout()})
	if service.get_sync_body_size_limit() != 67108864:
		return _failure("PluginUpdateEndpointConfigService should preserve sync body size limit.", {"limit": service.get_sync_body_size_limit()})
	if service.get_sync_archive_path() != "user://godot_dotnet_mcp/update_branch.zip":
		return _failure("PluginUpdateEndpointConfigService should preserve sync archive path.", {"path": service.get_sync_archive_path()})
	if service.get_sync_marker_path() != "res://addons/godot_dotnet_mcp/.mcp_sync.json":
		return _failure("PluginUpdateEndpointConfigService should preserve sync marker path.", {"path": service.get_sync_marker_path()})
	if service.get_sync_addon_root() != "res://addons/godot_dotnet_mcp":
		return _failure("PluginUpdateEndpointConfigService should preserve sync addon root.", {"root": service.get_sync_addon_root()})
	if service.get_sync_editor_refresh_timeout_ms() != 15000:
		return _failure("PluginUpdateEndpointConfigService should preserve editor refresh timeout.", {"timeout": service.get_sync_editor_refresh_timeout_ms()})

	var archive_prefixes: Dictionary = service.get_archive_url_prefixes()
	for required_key in ["commit_codeload", "commit_github", "branch_codeload", "branch_github", "tag_codeload", "tag_github"]:
		if str(archive_prefixes.get(required_key, "")).is_empty():
			return _failure("PluginUpdateEndpointConfigService should expose all archive URL prefixes.", {"prefixes": archive_prefixes, "missing": required_key})
	if str(archive_prefixes.get("branch_codeload", "")) != "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/refs/heads/":
		return _failure("PluginUpdateEndpointConfigService should preserve branch codeload archive prefix.", archive_prefixes)

	var marker_context: Dictionary = service.build_sync_marker_context()
	if str(marker_context.get("source_repo_path", "")) != "https://github.com/LuoxuanLove/godot-dotnet-mcp":
		return _failure("PluginUpdateEndpointConfigService should own the sync source repository path.", marker_context)
	if str(marker_context.get("target_addon_path", "")) != "res://addons/godot_dotnet_mcp":
		return _failure("PluginUpdateEndpointConfigService should own the sync marker addon path.", marker_context)
	if marker_context.has("unix_time"):
		return _failure("PluginUpdateEndpointConfigService should not own dynamic sync marker timestamps.", marker_context)

	return {"name": "plugin_update_endpoint_config_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_update_endpoint_config() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_endpoint_config_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin update endpoint config sources should be readable."
	for required in [
		"PluginUpdateEndpointConfigServiceScript.new()",
		"_ensure_plugin_update_endpoint_config_service().get_refs_request_urls()",
		"_ensure_plugin_update_endpoint_config_service().get_branch_commits_url_template()",
		"_ensure_plugin_update_endpoint_config_service().get_branch_ref_url_template()",
		"_ensure_plugin_update_endpoint_config_service().get_target_plugin_cfg_branch_url_template()",
		"_ensure_plugin_update_endpoint_config_service().get_target_plugin_cfg_tag_url_template()",
		"_ensure_plugin_update_endpoint_config_service().get_refs_max_pages()",
		"_ensure_plugin_update_endpoint_config_service().get_sync_archive_path()",
		"_ensure_plugin_update_endpoint_config_service().get_sync_editor_refresh_timeout_ms()",
		"_ensure_plugin_update_endpoint_config_service().build_sync_marker_context()",
		"_ensure_plugin_update_endpoint_config_service().get_sync_marker_path()",
		"_ensure_plugin_update_endpoint_config_service().get_archive_url_prefixes()",
		"_ensure_plugin_update_endpoint_config_service().get_sync_addon_root()",
		"_ensure_plugin_update_http_request_service().start_refs_request(",
		"_ensure_plugin_update_http_request_service().start_sync_archive_request("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update endpoint config responsibility: %s" % required
	for forbidden in [
		"const UPDATE_REFS_BRANCHES_URL",
		"const UPDATE_SYNC_ARCHIVE_PATH",
		"const UPDATE_SYNC_REPO_URL",
		"const UPDATE_SYNC_ADDON_ROOT"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain update endpoint config constants: %s" % forbidden
	for required_service in [
		"func get_refs_request_urls()",
		"func get_archive_url_prefixes()",
		"func build_sync_marker_context()",
		"const UPDATE_REFS_BRANCHES_URL",
		"const UPDATE_SYNC_REPO_URL"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateEndpointConfigService should own endpoint config member: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_endpoint_config_service_contracts", "success": false, "error": message, "details": details}
