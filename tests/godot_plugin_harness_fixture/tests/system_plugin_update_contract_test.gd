extends RefCounted

# {"name": "system_plugin_update_contracts"}

const ImplProjectScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd")


class FakeBridge extends RefCounted:
	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": message, "data": data}


class FakePlugin extends Node:
	var sync_requested := false
	var selected_sources: Array[Dictionary] = []
	var discovery_requests: Array[bool] = []

	func set_plugin_update_source_from_tools(source: String, custom_branch: String = "", release_tag: String = "") -> Dictionary:
		selected_sources.append({"source": source, "custom_branch": custom_branch, "release_tag": release_tag})
		return {"success": true, "data": {"source": source, "custom_branch": custom_branch, "release_tag": release_tag}}

	func discover_plugin_update_refs_from_tools(force_refresh: bool = true) -> Dictionary:
		discovery_requests.append(force_refresh)
		return {"success": true, "accepted": true}

	func start_plugin_update_sync_from_tools() -> Dictionary:
		sync_requested = true
		return {"success": true, "accepted": true, "loading": true}


func run_case(tree: SceneTree) -> Dictionary:
	var plugin := FakePlugin.new()
	var server := Node.new()
	plugin.add_child(server)
	tree.root.add_child(plugin)

	var executor = ImplProjectScript.new()
	executor.bridge = FakeBridge.new()
	executor.configure_runtime({"server": server})

	var removed_start_result: Dictionary = executor.execute("plugin_update", {"action": "start_sync"})
	if bool(removed_start_result.get("success", true)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update start_sync direct calls should return removal guidance.")
	if plugin.sync_requested:
		return await _cleanup_failure(tree, plugin, "system_plugin_update direct calls should not execute the update sync bridge.")
	if not _is_removed_plugin_maintenance_tool(removed_start_result, "system_plugin_update", "start_update"):
		return await _cleanup_failure(tree, plugin, "system_plugin_update start_sync guidance should point to system_plugin_maintenance(action=start_update).")

	var removed_current_result: Dictionary = executor.execute("plugin_update", {"action": "get_current"})
	if bool(removed_current_result.get("success", true)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update get_current direct calls should return removal guidance.")
	if not _is_removed_plugin_maintenance_tool(removed_current_result, "system_plugin_update", "status"):
		return await _cleanup_failure(tree, plugin, "system_plugin_update get_current guidance should point to system_plugin_maintenance(action=status).")

	var removed_set_source_result: Dictionary = executor.execute("plugin_update", {
		"action": "set_source",
		"source": "custom_branch",
		"custom_branch": "feature/update-tool",
		"release_tag": "v1.0.0"
	})
	if bool(removed_set_source_result.get("success", true)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update set_source direct calls should return removal guidance.")
	if not plugin.selected_sources.is_empty():
		return await _cleanup_failure(tree, plugin, "system_plugin_update set_source direct calls should not mutate update source.")
	if not _is_removed_plugin_maintenance_tool(removed_set_source_result, "system_plugin_update", "set_update_source"):
		return await _cleanup_failure(tree, plugin, "system_plugin_update set_source guidance should point to system_plugin_maintenance(action=set_update_source).")
	var replacement_args := _replacement_arguments(removed_set_source_result)
	if str(replacement_args.get("custom_branch", "")) != "feature/update-tool" or str(replacement_args.get("release_tag", "")) != "v1.0.0":
		return await _cleanup_failure(tree, plugin, "system_plugin_update set_source guidance should preserve branch and release tag arguments.")

	var removed_discover_result: Dictionary = executor.execute("plugin_update", {"action": "discover_refs", "force_refresh": false})
	if bool(removed_discover_result.get("success", true)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update discover_refs direct calls should return removal guidance.")
	if not plugin.discovery_requests.is_empty():
		return await _cleanup_failure(tree, plugin, "system_plugin_update discover_refs direct calls should not execute the discovery bridge.")
	if not _is_removed_plugin_maintenance_tool(removed_discover_result, "system_plugin_update", "refresh_update_refs"):
		return await _cleanup_failure(tree, plugin, "system_plugin_update discover_refs guidance should point to system_plugin_maintenance(action=refresh_update_refs).")
	var discover_replacement_args := _replacement_arguments(removed_discover_result)
	if bool(discover_replacement_args.get("force_refresh", true)):
		return await _cleanup_failure(tree, plugin, "system_plugin_update discover_refs guidance should preserve force_refresh=false.")

	plugin.queue_free()
	await tree.process_frame
	return {
		"name": "system_plugin_update_contracts",
		"success": true,
		"error": "",
		"details": {"removed_tool": "system_plugin_update"}
	}


func _replacement_arguments(result: Dictionary) -> Dictionary:
	var data = result.get("data", {})
	if not (data is Dictionary):
		return {}
	var replacement_tools = (data as Dictionary).get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return {}
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return {}
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	if replacement_arguments is Dictionary:
		return replacement_arguments
	return {}


func _is_removed_plugin_maintenance_tool(result: Dictionary, removed_tool: String, replacement_action: String) -> bool:
	var data = result.get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != removed_tool:
		return false
	var replacement_arguments := _replacement_arguments(result)
	return str(replacement_arguments.get("action", "")) == replacement_action and str(((data_dict.get("replacement_tools", []) as Array)[0] as Dictionary).get("name", "")) == "system_plugin_maintenance"


func _cleanup_failure(tree: SceneTree, plugin: Node, message: String) -> Dictionary:
	if plugin != null and is_instance_valid(plugin):
		plugin.queue_free()
	await tree.process_frame
	return _failure(message)


func _failure(message: String) -> Dictionary:
	return {"name": "system_plugin_update_contracts", "success": false, "error": message}
