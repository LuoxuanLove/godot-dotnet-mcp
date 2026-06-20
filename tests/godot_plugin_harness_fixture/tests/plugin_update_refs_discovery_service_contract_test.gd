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
		"_ensure_plugin_update_refs_discovery_service().parse_refs_json_array("
	]:
		if plugin_source.find(required) == -1:
			return "plugin.gd should delegate update refs discovery responsibility: %s" % required
	for forbidden in [
		"func _extract_update_ref_commit(item: Dictionary) -> String:\n\tvar commit_value",
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
		"func collect_stable_release_names(items: Array)"
	]:
		if service_source.find(required_service) == -1:
			return "PluginUpdateRefsDiscoveryService should own update refs method: %s" % required_service
	return ""


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {"name": "plugin_update_refs_discovery_service_contracts", "success": false, "error": message, "details": details}
