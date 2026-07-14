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

	var version := service.parse_plugin_cfg_version('[plugin]\nname="Godot .NET MCP"\nversion = \"2.0.0\"\n')
	if version != "2.0.0":
		return _failure("PluginUpdateCompareService should parse quoted plugin.cfg versions.", {"version": version})
	var single_quote_version := service.parse_plugin_cfg_version("version='2.1.0-preview'\n")
	if single_quote_version != "2.1.0-preview":
		return _failure("PluginUpdateCompareService should parse single-quoted plugin.cfg versions.", {"version": single_quote_version})
	if not service.parse_plugin_cfg_version("name=\"Godot .NET MCP\"").is_empty():
		return _failure("PluginUpdateCompareService should ignore plugin.cfg content without version.")

	var branch_target := {"kind": "branch", "ref": "dev", "commit": "target-sha"}
	if service.resolve_compare_head(branch_target) != "target-sha":
		return _failure("PluginUpdateCompareService should compare resolved branch targets by commit.")
	var tag_target := {"kind": "tag", "ref": "v2.0.0", "commit": "annotated-tag-object-sha"}
	if service.resolve_compare_head(tag_target) != "v2.0.0":
		return _failure("PluginUpdateCompareService should compare release tags by ref name.")

	var current_commit := service.resolve_current_commit({"sync": {"source_git_commit": " current-sha "}})
	if current_commit != "current-sha":
		return _failure("PluginUpdateCompareService should resolve current commit from freshness sync metadata.", {"commit": current_commit})
	if not service.resolve_current_commit({"sync": "invalid"}).is_empty():
		return _failure("PluginUpdateCompareService should ignore malformed freshness sync metadata.")

	var loading_snapshot: Dictionary = service.build_compare_start_snapshot("base-sha", branch_target)
	if str(loading_snapshot.get("state", "")) != "loading" or str(loading_snapshot.get("compare_head", "")) != "target-sha":
		return _failure("PluginUpdateCompareService should request compare checks for different branch commits.", loading_snapshot)
	var equal_snapshot: Dictionary = service.build_compare_start_snapshot("target-sha", branch_target)
	if str(equal_snapshot.get("state", "")) != "success" or str(equal_snapshot.get("source", "")) != "local_exact" or int(equal_snapshot.get("ahead_by", -1)) != 0 or int(equal_snapshot.get("behind_by", -1)) != 0:
		return _failure("PluginUpdateCompareService should short-circuit equal commits as success.", equal_snapshot)
	var cache_key := service.build_compare_cache_key("base-sha", "branch", "dev", "target-sha")
	var compare_cache := {cache_key: {
		"base_commit": "base-sha",
		"target_kind": "branch",
		"target_ref": "dev",
		"target_commit": "target-sha",
		"ahead_by": 4,
		"behind_by": 1
	}}
	var cached_snapshot: Dictionary = service.build_compare_start_snapshot("base-sha", branch_target, compare_cache)
	if str(cached_snapshot.get("state", "")) != "success" or str(cached_snapshot.get("source", "")) != "cache" or int(cached_snapshot.get("ahead_by", -1)) != 4 or int(cached_snapshot.get("behind_by", -1)) != 1:
		return _failure("PluginUpdateCompareService should reuse only exact base/target compare cache entries.", cached_snapshot)
	var moved_target: Dictionary = service.build_compare_start_snapshot("base-sha", {"kind": "branch", "ref": "dev", "commit": "moved-sha"}, compare_cache)
	if str(moved_target.get("state", "")) != "loading":
		return _failure("PluginUpdateCompareService should reject stale compare cache entries after a branch moves.", moved_target)
	var forged_cache := {cache_key: {
		"base_commit": "base-sha",
		"target_kind": "branch",
		"target_ref": "dev",
		"target_commit": "different-sha",
		"ahead_by": 4,
		"behind_by": 0
	}}
	var forged_snapshot: Dictionary = service.build_compare_start_snapshot("base-sha", branch_target, forged_cache)
	if str(forged_snapshot.get("state", "")) != "loading":
		return _failure("PluginUpdateCompareService should verify cached metadata instead of trusting an externally supplied cache key.", forged_snapshot)
	var empty_tag_key := service.build_compare_cache_key("base-sha", "tag", "v2.0.0", "")
	var empty_tag_snapshot: Dictionary = service.build_compare_start_snapshot("base-sha", {"kind": "tag", "ref": "v2.0.0", "commit": ""}, {empty_tag_key: {"base_commit": "base-sha", "target_kind": "tag", "target_ref": "v2.0.0", "target_commit": "", "ahead_by": 1, "behind_by": 0}})
	if str(empty_tag_snapshot.get("state", "")) != "loading":
		return _failure("PluginUpdateCompareService should not cache a movable tag comparison without an exact target commit.", empty_tag_snapshot)
	var unavailable_snapshot: Dictionary = service.build_compare_start_snapshot("", branch_target)
	if str(unavailable_snapshot.get("state", "")) != "unavailable":
		return _failure("PluginUpdateCompareService should mark missing base commits unavailable.", unavailable_snapshot)

	var parsed := service.parse_compare_response('{"ahead_by":3,"behind_by":1}'.to_utf8_buffer())
	if not bool(parsed.get("success", false)) or int(parsed.get("ahead_by", -1)) != 3 or int(parsed.get("behind_by", -1)) != 1:
		return _failure("PluginUpdateCompareService should parse GitHub compare responses.", parsed)
	var parse_error := service.parse_compare_response('[1,2]'.to_utf8_buffer())
	if bool(parse_error.get("success", false)) or str(parse_error.get("error", "")) != "Expected a JSON object":
		return _failure("PluginUpdateCompareService should reject non-object compare responses.", parse_error)
	for invalid_body in ['{}', '{"ahead_by":1}', '{"ahead_by":-1,"behind_by":0}']:
		var invalid_result := service.parse_compare_response(invalid_body.to_utf8_buffer())
		if bool(invalid_result.get("success", false)):
			return _failure("PluginUpdateCompareService should reject missing or negative compare counts.", invalid_result)

	return {"name": "plugin_update_compare_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_update_compare() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_compare_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin update compare sources should be readable."
	for required in [
		"PluginUpdateCompareServiceScript.new()",
		"_ensure_plugin_update_compare_service().build_target_version_url(",
		"_ensure_plugin_update_compare_service().parse_plugin_cfg_version(",
		"_ensure_plugin_update_compare_service().build_compare_start_snapshot(",
		"_ensure_plugin_update_compare_service().resolve_compare_head(",
		"_ensure_plugin_update_compare_service().resolve_current_commit(",
		"_ensure_plugin_update_compare_service().parse_compare_response("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update compare responsibility: %s" % required
	for forbidden in [
		"func _parse_update_compare_json(body: PackedByteArray) -> Dictionary:\n\tvar json := JSON.new()",
		"func _parse_update_target_plugin_cfg_version(content: String) -> String:\n\tfor line in content.split",
		"func _resolve_current_update_commit() -> String:\n\tvar freshness :=",
		"func _resolve_update_compare_head(target: Dictionary) -> String:\n\tvar target_ref :="
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain update compare internals: %s" % forbidden
	for required_service in [
		"func build_target_version_url(target_ref: String, target_kind: String, branch_template: String, tag_template: String)",
		"func parse_plugin_cfg_version(content: String)",
		"func build_compare_cache_key(base_commit: String, target_kind: String, target_ref: String, target_commit: String)",
		"func build_compare_start_snapshot(base_commit: String, target: Dictionary, compare_cache: Dictionary = {})",
		"func parse_compare_response(body: PackedByteArray)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateCompareService should own compare method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_compare_service_contracts", "success": false, "error": message, "details": details}
