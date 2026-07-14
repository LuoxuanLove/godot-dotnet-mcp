extends RefCounted

# {"name": "plugin_update_compare_service_contracts"}

const PluginUpdateCompareServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_compare_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_update_compare()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginUpdateCompareServiceScript.new()
	var branch_url := service.build_target_version_url("refactor/v2.0.0", "branch", "https://raw.example/heads/%s/plugin.cfg", "https://raw.example/tags/%s/plugin.cfg")
	if branch_url != "https://raw.example/heads/refactor/v2.0.0/plugin.cfg":
		return _failure("PluginUpdateCompareService should preserve branch slashes for raw plugin.cfg URLs.", {"url": branch_url})
	var tag_url := service.build_target_version_url("v2.0.0", "tag", "https://raw.example/heads/%s/plugin.cfg", "https://raw.example/tags/%s/plugin.cfg")
	if tag_url != "https://raw.example/tags/v2.0.0/plugin.cfg":
		return _failure("PluginUpdateCompareService should use tag URL templates for tag targets.", {"url": tag_url})
	if service.parse_plugin_cfg_version("version='2.1.0-preview'\n") != "2.1.0-preview":
		return _failure("PluginUpdateCompareService should parse plugin.cfg versions.")
	if service.resolve_current_commit({"sync": {"source_git_commit": " current-sha "}}) != "current-sha":
		return _failure("PluginUpdateCompareService should resolve current commits from freshness metadata.")

	var target := {"kind": "branch", "ref": "dev", "commit": "target"}
	var exact_snapshot: Dictionary = service.build_local_compare_snapshot("target", target, {})
	if str(exact_snapshot.get("state", "")) != "success" or int(exact_snapshot.get("ahead_by", -1)) != 0 or int(exact_snapshot.get("behind_by", -1)) != 0:
		return _failure("PluginUpdateCompareService should short-circuit exact commit matches.", exact_snapshot)

	var forward_histories := {
		"current": {"head_commit": "current", "commits": ["current", "base"], "complete": true},
		"target": {"head_commit": "target", "commits": ["target", "current", "base"], "complete": true}
	}
	var forward_snapshot: Dictionary = service.build_local_compare_snapshot("current", target, forward_histories)
	if str(forward_snapshot.get("state", "")) != "success" or int(forward_snapshot.get("ahead_by", -1)) != 1 or int(forward_snapshot.get("behind_by", -1)) != 0:
		return _failure("PluginUpdateCompareService should calculate target-ahead commits locally.", forward_snapshot)

	var reverse_snapshot: Dictionary = service.build_local_compare_snapshot("target", {"kind": "branch", "ref": "old", "commit": "current"}, forward_histories)
	if str(reverse_snapshot.get("state", "")) != "success" or int(reverse_snapshot.get("ahead_by", -1)) != 0 or int(reverse_snapshot.get("behind_by", -1)) != 1:
		return _failure("PluginUpdateCompareService should calculate local rollback direction.", reverse_snapshot)

	var divergent_histories := {
		"current": {"head_commit": "current", "commits": ["current", "left", "base"], "complete": true},
		"target": {"head_commit": "target", "commits": ["target", "right", "base"], "complete": true}
	}
	var divergent_snapshot: Dictionary = service.build_local_compare_snapshot("current", target, divergent_histories)
	if str(divergent_snapshot.get("state", "")) != "success" or int(divergent_snapshot.get("ahead_by", -1)) != 2 or int(divergent_snapshot.get("behind_by", -1)) != 2:
		return _failure("PluginUpdateCompareService should calculate divergent local histories.", divergent_snapshot)

	var incomplete_snapshot: Dictionary = service.build_local_compare_snapshot("current", target, {"current": {"head_commit": "current", "commits": ["current"], "complete": false}})
	if str(incomplete_snapshot.get("state", "")) != "unavailable" or str(incomplete_snapshot.get("error", "")) != "local_history_incomplete":
		return _failure("PluginUpdateCompareService should reject missing local history.", incomplete_snapshot)
	var no_common_snapshot: Dictionary = service.build_local_compare_snapshot("current", target, {
		"current": {"head_commit": "current", "commits": ["current", "left"], "complete": true},
		"target": {"head_commit": "target", "commits": ["target", "right"], "complete": true}
	})
	if str(no_common_snapshot.get("state", "")) != "unavailable" or str(no_common_snapshot.get("error", "")) != "local_history_no_common_commit":
		return _failure("PluginUpdateCompareService should refuse histories without a common commit.", no_common_snapshot)

	return {"name": "plugin_update_compare_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_update_compare() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_compare_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin update compare sources should be readable."
	for required in [
		"_ensure_plugin_update_compare_service().build_target_version_url(",
		"_ensure_plugin_update_compare_service().parse_plugin_cfg_version(",
		"_ensure_plugin_update_compare_service().build_local_compare_snapshot(",
		"_ensure_plugin_update_compare_service().resolve_current_commit("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update comparison responsibility: %s" % required
	for forbidden in ["UpdateCompareRequest", "get_compare_url_template", "parse_compare_response", "build_compare_cache_key"]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not issue a remote compare request: %s" % forbidden
	for required_service in [
		"func build_local_compare_snapshot(base_commit: String, target: Dictionary, commit_histories = {})",
		"func resolve_current_commit(freshness) -> String"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateCompareService should own local comparison: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_compare_service_contracts", "success": false, "error": message, "details": details}
