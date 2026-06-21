extends RefCounted

# {"name": "plugin_update_request_planning_service_contracts"}

const PluginUpdateRequestPlanningServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_request_planning_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_update_request_planning()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginUpdateRequestPlanningServiceScript.new()
	var refs := {
		"latest_stable_release": "v2.0.0",
		"latest_release": "v2.1.0-preview",
		"commits": {
			"refactor/v2.0.0": "branch-sha",
			"v2.0.0": "tag-sha"
		}
	}
	var branch_target: Dictionary = service.resolve_sync_target({
		"update_source": "custom_branch",
		"update_custom_branch": "refactor/v2.0.0"
	}, refs)
	if branch_target != {"kind": "branch", "ref": "refactor/v2.0.0", "commit": "branch-sha"}:
		return _failure("PluginUpdateRequestPlanningService should resolve custom branch targets.", {"target": branch_target})
	var legacy_dev_target: Dictionary = service.resolve_sync_target({
		"update_source": "latest_dev",
		"update_custom_branch": ""
	}, refs)
	if legacy_dev_target != {"kind": "branch", "ref": "dev", "commit": ""}:
		return _failure("PluginUpdateRequestPlanningService should preserve legacy latest_dev settings as dev custom-branch targets.", {"target": legacy_dev_target})
	var legacy_branch_target: Dictionary = service.resolve_sync_target({
		"update_source": "branch",
		"update_custom_branch": "refactor/v2.0.0"
	}, refs)
	if legacy_branch_target != branch_target:
		return _failure("PluginUpdateRequestPlanningService should preserve legacy branch settings as custom-branch targets.", {"target": legacy_branch_target})
	if not service.should_resolve_branch_commit_before_archive({"kind": "branch", "ref": "feature/no-commit", "commit": ""}):
		return _failure("PluginUpdateRequestPlanningService should request branch commit resolution when commit is missing.")
	if service.should_resolve_branch_commit_before_archive({"kind": "tag", "ref": "v2.0.0", "commit": ""}):
		return _failure("PluginUpdateRequestPlanningService should not resolve tag commits before archive download.")

	var stable_target: Dictionary = service.resolve_sync_target({"update_source": "latest_stable"}, refs)
	if str(stable_target.get("kind", "")) != "tag" or str(stable_target.get("ref", "")) != "v2.0.0":
		return _failure("PluginUpdateRequestPlanningService should resolve latest stable release targets.", {"target": stable_target})
	var latest_target: Dictionary = service.resolve_sync_target({
		"update_source": "latest_release",
		"update_release_tag": "v2.0.0"
	}, refs)
	if str(latest_target.get("ref", "")) != "v2.0.0":
		return _failure("PluginUpdateRequestPlanningService should prefer selected release tags.", {"target": latest_target})

	var branch_url := service.get_branch_ref_url("refactor/v2.0.0", "https://api.example.test/branches/%s")
	if branch_url != "https://api.example.test/branches/refactor%2Fv2.0.0":
		return _failure("PluginUpdateRequestPlanningService should URI-encode branch ref API paths.", {"url": branch_url})
	if service.encode_archive_ref_path("refactor/v2.0.0") != "refactor/v2.0.0":
		return _failure("PluginUpdateRequestPlanningService should preserve branch slashes for archive paths.")

	var parse_ok := service.parse_branch_ref_response('{"commit":{"sha":"resolved-sha"}}'.to_utf8_buffer())
	if not bool(parse_ok.get("success", false)) or str(parse_ok.get("commit", "")) != "resolved-sha":
		return _failure("PluginUpdateRequestPlanningService should parse GitHub branch commit responses.", parse_ok)
	var parse_error := service.parse_branch_ref_response('{"commit":{}}'.to_utf8_buffer())
	if bool(parse_error.get("success", false)) or str(parse_error.get("error", "")).is_empty():
		return _failure("PluginUpdateRequestPlanningService should explain malformed branch commit responses.", parse_error)

	var prefixes := {
		"commit_codeload": "https://codeload.example/zip/",
		"commit_github": "https://github.example/archive/",
		"branch_codeload": "https://codeload.example/zip/heads/",
		"branch_github": "https://github.example/archive/heads/",
		"tag_codeload": "https://codeload.example/zip/tags/",
		"tag_github": "https://github.example/archive/tags/"
	}
	var attempts: Array = service.build_archive_request_attempts(branch_target, prefixes)
	if attempts.size() != 2 or str((attempts[0] as Dictionary).get("label", "")) != "codeload commit archive":
		return _failure("PluginUpdateRequestPlanningService should prefer commit archives for resolved branches.", {"attempts": attempts})
	var branch_attempts: Array = service.build_archive_request_attempts({"kind": "branch", "ref": "feature/ui", "commit": ""}, prefixes)
	if branch_attempts.size() != 2 or not str((branch_attempts[0] as Dictionary).get("url", "")).ends_with("/feature/ui"):
		return _failure("PluginUpdateRequestPlanningService should build branch fallback archive attempts.", {"attempts": branch_attempts})
	var tag_attempts: Array = service.build_archive_request_attempts({"kind": "tag", "ref": "v2.0.0", "commit": ""}, prefixes)
	if tag_attempts.size() != 2 or str((tag_attempts[1] as Dictionary).get("label", "")) != "github tag archive":
		return _failure("PluginUpdateRequestPlanningService should build tag archive attempts.", {"attempts": tag_attempts})

	if not service.should_try_next_archive_attempt("Branch archive does not contain addons/godot_dotnet_mcp.", branch_attempts, 0):
		return _failure("PluginUpdateRequestPlanningService should retry archive attempts for wrong archive shape.")
	if service.should_try_next_archive_attempt("HTTP 404", branch_attempts, 0):
		return _failure("PluginUpdateRequestPlanningService should not retry arbitrary archive errors after download.")
	var failure_message := service.format_archive_failures(["first", "second"])
	if failure_message.find("2 attempt(s)") == -1 or failure_message.find("first; second") == -1:
		return _failure("PluginUpdateRequestPlanningService should summarize archive request failures.", {"message": failure_message})

	var marker: Dictionary = service.build_sync_marker(branch_target, 12, {
		"unix_time": 123,
		"source_repo_path": "https://github.example/repo",
		"target_addon_path": "res://addons/plugin"
	})
	if int(marker.get("last_sync_at_unix", 0)) != 123 or int(marker.get("written_files", 0)) != 12 or str(marker.get("source_git_commit", "")) != "branch-sha":
		return _failure("PluginUpdateRequestPlanningService should build stable sync marker payloads.", marker)

	return {"name": "plugin_update_request_planning_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_update_request_planning() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_request_planning_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin update request planning sources should be readable."
	for required in [
		"PluginUpdateRequestPlanningServiceScript.new()",
		"_ensure_plugin_update_request_planning_service().resolve_sync_target(",
		"_ensure_plugin_update_request_planning_service().should_resolve_branch_commit_before_archive(",
		"_ensure_plugin_update_request_planning_service().get_branch_ref_url(",
		"_ensure_plugin_update_request_planning_service().parse_branch_ref_response(",
		"_ensure_plugin_update_request_planning_service().build_archive_request_attempts(",
		"_ensure_plugin_update_request_planning_service().build_sync_marker("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update request planning responsibility: %s" % required
	for forbidden in [
		"func _resolve_update_ref_commit(",
		"func _encode_update_archive_ref_path(",
		"func _parse_update_branch_ref_response(",
		"Branch response did not include commit.sha",
		"return target_ref.strip_edges().uri_encode().replace(\"%2F\", \"/\")",
		"source_repo_path\": \"https://github.com/LuoxuanLove/godot-dotnet-mcp\""
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain update request planning internals: %s" % forbidden
	for required_service in [
		"func resolve_sync_target(settings: Dictionary, refs_context: Dictionary)",
		"func resolve_ref_commit(target_ref: String, commits_value)",
		"func encode_archive_ref_path(target_ref: String)",
		"func parse_branch_ref_response(body: PackedByteArray)",
		"func build_archive_request_attempts(target: Dictionary, url_prefixes: Dictionary)",
		"func build_sync_marker(target: Dictionary, written: int, marker_context: Dictionary)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateRequestPlanningService should own update planning method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_request_planning_service_contracts", "success": false, "error": message, "details": details}
