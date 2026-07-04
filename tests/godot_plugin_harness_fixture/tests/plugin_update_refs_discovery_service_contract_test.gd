extends RefCounted

# {"name": "plugin_update_refs_discovery_service_contracts"}

const PluginUpdateRefsDiscoveryServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_refs_discovery_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_plugin_entrypoint_delegates_update_refs_discovery()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var service = PluginUpdateRefsDiscoveryServiceScript.new()
	var parsed := service.parse_refs_json_array('[{"name":"dev"},{"name":"refactor/v2.0.0"}]'.to_utf8_buffer())
	if not bool(parsed.get("success", false)) or (parsed.get("items", []) as Array).size() != 2:
		return _failure("PluginUpdateRefsDiscoveryService should parse GitHub list responses.", parsed)
	var parse_error := service.parse_refs_json_array('{"name":"dev"}'.to_utf8_buffer())
	if bool(parse_error.get("success", false)) or str(parse_error.get("error", "")) != "Expected a JSON array":
		return _failure("PluginUpdateRefsDiscoveryService should reject non-array refs responses.", parse_error)

	var next_url := service.extract_next_url(PackedStringArray([
		'link: <https://api.example.test/branches?page=2>; rel="next", <https://api.example.test/branches?page=3>; rel="last"'
	]))
	if next_url != "https://api.example.test/branches?page=2":
		return _failure("PluginUpdateRefsDiscoveryService should extract GitHub Link rel=next URLs.", {"url": next_url})

	var pending := {
		"branches": ["dev"],
		"releases": [],
		"stable_releases": [],
		"tags": [],
		"commits": {}
	}
	pending = service.append_names(pending, "branches", ["dev", "refactor/v2.0.0", ""])
	pending = service.append_commits(pending, [
		{"name": "dev", "commit": {"sha": "dev-sha"}},
		{"name": "refactor/v2.0.0", "commit": {"sha": "branch-sha"}},
		{"name": "ignored", "commit": {}}
	], "name")
	pending = service.append_names(pending, "releases", service.collect_names([
		{"tag_name": "v2.0.0"},
		{"tag_name": "v2.1.0-preview"}
	], "tag_name"))
	pending = service.append_names(pending, "stable_releases", service.collect_stable_release_names([
		{"tag_name": "v2.0.0", "prerelease": false},
		{"tag_name": "v2.1.0-preview", "prerelease": true}
	]))
	pending = service.append_names(pending, "tags", ["v1.3.0", "v2.0.0"])
	pending = service.append_commits(pending, [
		{"tag_name": "v2.0.0", "target_commitish": "release-sha"}
	], "tag_name")

	var snapshot: Dictionary = service.build_final_snapshot(pending)
	if snapshot.get("branches", []) != ["dev", "refactor/v2.0.0"]:
		return _failure("PluginUpdateRefsDiscoveryService should keep unique branch order.", snapshot)
	var commits: Dictionary = snapshot.get("commits", {})
	if str(commits.get("dev", "")) != "dev-sha" or str(commits.get("v2.0.0", "")) != "release-sha":
		return _failure("PluginUpdateRefsDiscoveryService should collect branch and release commits.", snapshot)
	if snapshot.get("releases", []) != ["v2.0.0", "v2.1.0-preview", "v1.3.0"]:
		return _failure("PluginUpdateRefsDiscoveryService should combine releases and tags without duplicates.", snapshot)
	if str(snapshot.get("latest_stable_release", "")) != "v2.0.0" or str(snapshot.get("latest_release", "")) != "v2.0.0":
		return _failure("PluginUpdateRefsDiscoveryService should derive latest release metadata.", snapshot)
	if str(snapshot.get("release_source", "")) != "releases_and_tags":
		return _failure("PluginUpdateRefsDiscoveryService should declare release source.", snapshot)

	var duplicated: Dictionary = service.duplicate_commits({"dev": "one", 2: "two"})
	if str(duplicated.get("2", "")) != "two":
		return _failure("PluginUpdateRefsDiscoveryService should stringify commit keys.", duplicated)

	var request_pending := {
		"serial": 7,
		"background": true,
		"branch_done": false,
		"release_done": true,
		"tag_done": false,
		"errors": []
	}
	request_pending = service.record_active_request(
		request_pending,
		"branches",
		"https://api.example.test/branches",
		7,
		1000,
		12000,
		"UpdateRefsBranchesRequest",
		1
	)
	var waiting_kinds := service.get_waiting_kinds(request_pending)
	if waiting_kinds != ["branches", "tags"]:
		return _failure("PluginUpdateRefsDiscoveryService should report unfinished refs kinds.", {"waiting": waiting_kinds})
	var early_stale := service.find_stale_active_requests(request_pending, 12999)
	if not early_stale.is_empty():
		return _failure("PluginUpdateRefsDiscoveryService should not expire active refs before timeout.", {"stale": early_stale})
	var stale_requests := service.find_stale_active_requests(request_pending, 13000)
	if stale_requests.size() != 1 or str(stale_requests[0].get("kind", "")) != "branches":
		return _failure("PluginUpdateRefsDiscoveryService should find stale active refs requests.", {"stale": stale_requests})
	if int(stale_requests[0].get("timeout_msec", 0)) != 12000 or int(stale_requests[0].get("page", 0)) != 1:
		return _failure("PluginUpdateRefsDiscoveryService should preserve stale refs timeout metadata.", {"stale": stale_requests})
	var pending_status := service.build_pending_status(request_pending, 13000)
	if int(pending_status.get("serial", 0)) != 7 or not bool(pending_status.get("background", false)):
		return _failure("PluginUpdateRefsDiscoveryService should expose pending refs metadata.", pending_status)
	var active_requests: Array = pending_status.get("active_requests", [])
	if active_requests.size() != 1 or int((active_requests[0] as Dictionary).get("elapsed_msec", 0)) != 12000:
		return _failure("PluginUpdateRefsDiscoveryService should include active refs request elapsed time.", pending_status)
	request_pending = service.clear_active_request(request_pending, "branches")
	var cleared_status := service.build_pending_status(request_pending, 13000)
	if not (cleared_status.get("active_requests", []) as Array).is_empty():
		return _failure("PluginUpdateRefsDiscoveryService should clear completed refs requests.", cleared_status)

	return {"name": "plugin_update_refs_discovery_service_contracts", "success": true, "error": ""}


func _verify_plugin_entrypoint_delegates_update_refs_discovery() -> String:
	var plugin_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin.gd")
	var service_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_update_refs_discovery_service.gd")
	if plugin_source.is_empty() or service_source.is_empty():
		return "Plugin update refs discovery sources should be readable."
	for required in [
		"PluginUpdateRefsDiscoveryServiceScript.new()",
		"_ensure_plugin_update_refs_discovery_service().extract_next_url(",
		"_ensure_plugin_update_refs_discovery_service().append_names(",
		"_ensure_plugin_update_refs_discovery_service().append_commits(",
		"_ensure_plugin_update_refs_discovery_service().build_final_snapshot(",
		"_ensure_plugin_update_refs_discovery_service().parse_refs_json_array(",
		"_format_stale_update_refs_request_error("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update refs discovery responsibility: %s" % required
	for forbidden in [
		"func _extract_update_ref_commit(item: Dictionary) -> String:\n\tvar commit_value",
		"func _append_unique_update_ref(",
		"func _parse_update_refs_json_array(body: PackedByteArray) -> Dictionary:\n\tvar json := JSON.new()",
		"func _extract_update_refs_next_url(headers: PackedStringArray) -> String:\n\tfor header in headers:",
		"func _extract_update_stable_release_names(items: Array) -> Array[String]:\n\tvar names"
	]:
		if plugin_source.find(forbidden) != -1:
			return "plugin.gd should not retain update refs discovery internals: %s" % forbidden
	for required_service in [
		"func parse_refs_json_array(body: PackedByteArray)",
		"func extract_next_url(headers: PackedStringArray)",
		"func build_final_snapshot(pending: Dictionary)",
		"func find_stale_active_requests(pending: Dictionary, now_msec: int)",
		"func build_pending_status(pending: Dictionary, now_msec: int)",
		"func collect_stable_release_names(items: Array)",
		"func append_unique_ref(values: Array[String], value: String)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateRefsDiscoveryService should own update refs method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_refs_discovery_service_contracts", "success": false, "error": message, "details": details}
