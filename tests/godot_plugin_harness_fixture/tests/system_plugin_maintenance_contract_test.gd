extends RefCounted

# {"name": "system_plugin_maintenance_contracts"}

const ImplProjectScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd")


class FakeBridge extends RefCounted:
	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": message, "data": data}


class FakePlugin extends Node:
	var lifecycle_reload_called := false
	var selected_sources: Array[Dictionary] = []
	var sync_requested := false

	func request_plugin_lifecycle_reload_from_tools() -> Dictionary:
		lifecycle_reload_called = true
		var maintenance := {
			"active": true,
			"kind": "plugin_lifecycle_reload",
			"state": "scheduled",
			"transport_state": "disconnecting",
			"disconnect_expected": true,
			"reconnect_required": true,
			"refetch_tools_required": true,
			"retry_after_ms": 500,
			"safe_to_retry": false
		}
		return {
			"success": true,
			"message": "Plugin lifecycle reload scheduled",
			"deferred": true,
			"maintenance": maintenance,
			"maintenance_window": maintenance,
			"data": {"request_id": "reload-1", "maintenance_window": maintenance}
		}

	func get_plugin_update_current_from_tools() -> Dictionary:
		return {
			"success": true,
			"data": {
				"source_version": "1.2.0",
				"server_version": "1.2.0",
				"tool_schema_version": "2026-06-05.7",
				"lifecycle_reload": {"state": "idle"}
			}
		}

	func get_plugin_update_status_from_tools() -> Dictionary:
		return {
			"success": true,
			"data": {
				"status": "ready",
				"source": "custom_branch",
				"sync": {"state": "idle"},
				"lifecycle_reload": {"state": "idle"}
			}
		}

	func set_plugin_update_source_from_tools(source: String, custom_branch: String = "", release_tag: String = "") -> Dictionary:
		selected_sources.append({"source": source, "custom_branch": custom_branch, "release_tag": release_tag})
		return {"success": true, "data": {"source": source, "custom_branch": custom_branch, "release_tag": release_tag}}

	func start_plugin_update_sync_from_tools() -> Dictionary:
		sync_requested = true
		var maintenance := {
			"active": true,
			"kind": "plugin_update_sync",
			"state": "loading",
			"disconnect_expected": true,
			"reconnect_required": true,
			"refetch_tools_required": true
		}
		return {
			"success": true,
			"accepted": true,
			"loading": true,
			"maintenance_window": maintenance,
			"data": {"maintenance_window": maintenance, "sync": {"state": "loading"}}
		}


func run_case(tree: SceneTree) -> Dictionary:
	var plugin := FakePlugin.new()
	var server := Node.new()
	plugin.add_child(server)
	tree.root.add_child(plugin)

	var executor = ImplProjectScript.new()
	executor.bridge = FakeBridge.new()
	executor.configure_runtime({"server": server})

	var status_result: Dictionary = executor.execute("plugin_maintenance", {"action": "status"})
	if not bool(status_result.get("success", false)):
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance status should succeed.")
	var status_data: Dictionary = status_result.get("data", {})
	if not status_data.has("freshness") or not status_data.has("current") or not status_data.has("update_status"):
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance status should summarize freshness, current, and update status.")
	if str((status_data.get("current", {}) as Dictionary).get("source_version", "")) != "1.2.0":
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance status should include current plugin metadata.")
	if not bool(status_data.get("current_success", false)) or not bool(status_data.get("update_status_success", false)):
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance status should preserve delegated success flags.")
	if not (status_data.get("current_result", {}) is Dictionary) or not (status_data.get("update_status_result", {}) is Dictionary):
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance status should preserve delegated result envelopes.")

	var update_status_result: Dictionary = executor.execute("plugin_maintenance", {"action": "update_status"})
	if not bool(update_status_result.get("success", false)):
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance update_status should delegate to plugin update status.")

	var set_source_result: Dictionary = executor.execute("plugin_maintenance", {"action": "set_update_source", "source": "custom_branch", "custom_branch": "feature/plugin-maintenance-tool", "release_tag": "v1.2.0"})
	if not bool(set_source_result.get("success", false)) or plugin.selected_sources.size() != 1:
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance set_update_source should route selected source.")
	if str(plugin.selected_sources[0].get("custom_branch", "")) != "feature/plugin-maintenance-tool":
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance set_update_source should preserve the custom branch.")

	var start_result: Dictionary = executor.execute("plugin_maintenance", {"action": "start_update"})
	if not bool(start_result.get("success", false)) or not bool(start_result.get("accepted", false)) or not plugin.sync_requested:
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance start_update should delegate to update sync.")
	var sync_maintenance: Dictionary = start_result.get("maintenance_window", {})
	if str(sync_maintenance.get("kind", "")) != "plugin_update_sync":
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance start_update should preserve update maintenance metadata.")

	var reload_result: Dictionary = executor.execute("plugin_maintenance", {"action": "reload"})
	if not bool(reload_result.get("success", false)) or not bool(reload_result.get("deferred", false)) or not plugin.lifecycle_reload_called:
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance reload should schedule lifecycle reload.")
	var reload_maintenance: Dictionary = reload_result.get("maintenance_window", {})
	if str(reload_maintenance.get("kind", "")) != "plugin_lifecycle_reload":
		return await _cleanup_failure(tree, plugin, "system_plugin_maintenance reload should preserve lifecycle maintenance metadata.")

	plugin.queue_free()
	await tree.process_frame
	return {"name": "system_plugin_maintenance_contracts", "success": true, "error": ""}


func _cleanup_failure(tree: SceneTree, plugin: Node, message: String) -> Dictionary:
	if plugin != null and is_instance_valid(plugin):
		plugin.queue_free()
	await tree.process_frame
	return _failure(message)


func _failure(message: String) -> Dictionary:
	return {"name": "system_plugin_maintenance_contracts", "success": false, "error": message}
