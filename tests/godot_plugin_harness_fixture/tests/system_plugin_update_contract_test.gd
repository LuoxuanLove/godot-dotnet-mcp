extends RefCounted

# {"name": "system_plugin_update_contracts"}

const ImplProjectScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd")


class FakeBridge extends RefCounted:
	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": message, "data": data}


class FakePlugin extends Node:
	var selected_sources: Array[Dictionary] = []
	var discover_force_refresh_values: Array[bool] = []
	var sync_requested := false

	func get_plugin_update_current_from_tools() -> Dictionary:
		return {
			"success": true,
			"data": {
				"source_version": "1.0.0",
				"server_version": "1.0.0",
				"protocol_version": "2025-06-18",
				"tool_schema_version": "1",
				"source_fingerprint": "abcdef0123456789abcdef",
				"source_fingerprint_short": "abcdef0123456789",
				"source_git_commit": "commit-sha",
				"source_ref_kind": "branch",
				"source_ref": "dev",
				"lifecycle_reload": {"state": "idle"}
			},
			"message": "current"
		}

	func get_plugin_update_status_from_tools() -> Dictionary:
		return {
			"success": true,
			"data": {
				"status": "ready",
				"source": "custom_branch",
				"target": {"kind": "branch", "ref": "dev", "commit": "target-sha"},
				"current": {"source_version": "1.0.0", "source_git_commit": "commit-sha"},
				"refs": {"state": "success"},
				"sync": {"state": "idle"},
				"lifecycle_reload": {"state": "idle"}
			},
			"message": "status"
		}

	func set_plugin_update_source_from_tools(source: String, custom_branch: String = "", release_tag: String = "") -> Dictionary:
		selected_sources.append({"source": source, "custom_branch": custom_branch, "release_tag": release_tag})
		return {"success": true, "accepted": false, "status": "selected", "data": {"source": source, "custom_branch": custom_branch, "release_tag": release_tag}}

	func discover_plugin_update_refs_from_tools(force_refresh: bool = true) -> Dictionary:
		discover_force_refresh_values.append(force_refresh)
		return {"success": true, "accepted": true, "loading": true, "status": "accepted", "data": {"refs": {"state": "loading"}}}

	func start_plugin_update_sync_from_tools() -> Dictionary:
		sync_requested = true
		return {"success": true, "accepted": true, "loading": true, "status": "accepted", "data": {"sync": {"state": "loading"}, "lifecycle_reload": {"state": "idle"}}}


func run_case(tree: SceneTree) -> Dictionary:
	var plugin := FakePlugin.new()
	var server := Node.new()
	plugin.add_child(server)
	tree.root.add_child(plugin)

	var executor = ImplProjectScript.new()
	executor.bridge = FakeBridge.new()
	executor.configure_runtime({"server": server})

	var current_result: Dictionary = executor.execute("plugin_update", {"action": "get_current"})
	if not bool(current_result.get("success", false)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update get_current should succeed.")
	var current: Dictionary = current_result.get("data", {})
	for required_field in ["source_version", "server_version", "protocol_version", "tool_schema_version", "source_fingerprint", "source_fingerprint_short", "source_git_commit", "lifecycle_reload"]:
		if not current.has(required_field):
			return await _cleanup_failure(tree, plugin, "system_plugin_update get_current should expose %s." % required_field)

	var status_result: Dictionary = executor.execute("plugin_update", {"action": "get_status"})
	if not bool(status_result.get("success", false)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update get_status should succeed.")
	var status: Dictionary = status_result.get("data", {})
	for required_status_field in ["source", "target", "current", "refs", "sync", "lifecycle_reload"]:
		if not status.has(required_status_field):
			return await _cleanup_failure(tree, plugin, "system_plugin_update get_status should expose %s." % required_status_field)

	var set_source_result: Dictionary = executor.execute("plugin_update", {"action": "set_source", "source": "custom_branch", "custom_branch": "feature/update-tool", "release_tag": "v1.0.0"})
	if not bool(set_source_result.get("success", false)) or plugin.selected_sources.size() != 1:
		return await _cleanup_failure(tree, plugin, "system_plugin_update set_source should route selected source to the plugin bridge.")
	if str(plugin.selected_sources[0].get("source", "")) != "custom_branch" or str(plugin.selected_sources[0].get("custom_branch", "")) != "feature/update-tool":
		return await _cleanup_failure(tree, plugin, "system_plugin_update set_source should preserve the selected custom branch.")
	if str(plugin.selected_sources[0].get("release_tag", "")) != "v1.0.0":
		return await _cleanup_failure(tree, plugin, "system_plugin_update set_source should forward the selected release tag.")

	var discover_result: Dictionary = executor.execute("plugin_update", {"action": "discover_refs", "force_refresh": false})
	if not bool(discover_result.get("success", false)) or not bool(discover_result.get("accepted", false)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update discover_refs should return an accepted async response.")
	if plugin.discover_force_refresh_values != [false]:
		return await _cleanup_failure(tree, plugin, "system_plugin_update discover_refs should forward force_refresh.")

	var sync_result: Dictionary = executor.execute("plugin_update", {"action": "start_sync"})
	if not bool(sync_result.get("success", false)) or not bool(sync_result.get("accepted", false)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update start_sync should return an accepted async response.")
	if not plugin.sync_requested:
		return await _cleanup_failure(tree, plugin, "system_plugin_update start_sync should route to the plugin sync bridge.")

	plugin.queue_free()
	await tree.process_frame
	return {"name": "system_plugin_update_contracts", "success": true, "error": ""}


func _cleanup_failure(tree: SceneTree, plugin: Node, message: String) -> Dictionary:
	if plugin != null and is_instance_valid(plugin):
		plugin.queue_free()
	await tree.process_frame
	return _failure(message)


func _failure(message: String) -> Dictionary:
	return {"name": "system_plugin_update_contracts", "success": false, "error": message}
