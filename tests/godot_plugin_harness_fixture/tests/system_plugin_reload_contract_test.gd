extends RefCounted

# {"name": "system_plugin_reload_contracts"}

const ImplProjectScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_project.gd")


class FakeBridge extends RefCounted:
	func success(data = {}, message: String = "") -> Dictionary:
		return {"success": true, "data": data, "message": message}

	func error(message: String, data = {}) -> Dictionary:
		return {"success": false, "error": message, "data": data}


class FakePlugin extends Node:
	var lifecycle_reload_called := false

	func request_plugin_lifecycle_reload_from_tools() -> Dictionary:
		lifecycle_reload_called = true
		return {"success": true, "message": "Plugin lifecycle reload scheduled"}


func run_case(tree: SceneTree) -> Dictionary:
	var plugin := FakePlugin.new()
	var server := Node.new()
	plugin.add_child(server)
	tree.root.add_child(plugin)

	var executor = ImplProjectScript.new()
	executor.bridge = FakeBridge.new()
	executor.configure_runtime({"server": server})

	var removed_result: Dictionary = executor.execute("plugin_reload", {"action": "full_reload_plugin"})
	var lifecycle_reload_called := plugin.lifecycle_reload_called
	plugin.queue_free()
	await tree.process_frame

	if bool(removed_result.get("success", true)):
		return _failure("system_plugin_reload direct calls should return removal guidance.")
	if lifecycle_reload_called:
		return _failure("system_plugin_reload direct calls should not execute the lifecycle reload bridge.")
	if not _is_removed_plugin_maintenance_tool(removed_result, "system_plugin_reload", "reload"):
		return _failure("system_plugin_reload removal guidance should point to system_plugin_maintenance(action=reload).")

	return {
		"name": "system_plugin_reload_contracts",
		"success": true,
		"error": "",
		"details": {"removed_tool": "system_plugin_reload"}
	}


func _is_removed_plugin_maintenance_tool(result: Dictionary, removed_tool: String, replacement_action: String) -> bool:
	var data = result.get("data", {})
	if not (data is Dictionary):
		return false
	var data_dict := data as Dictionary
	if str(data_dict.get("error_type", "")) != "removed_public_tool":
		return false
	if str(data_dict.get("removed_tool", "")) != removed_tool:
		return false
	var replacement_tools = data_dict.get("replacement_tools", [])
	if not (replacement_tools is Array) or (replacement_tools as Array).is_empty():
		return false
	var replacement = (replacement_tools as Array)[0]
	if not (replacement is Dictionary):
		return false
	var replacement_arguments = (replacement as Dictionary).get("arguments", {})
	return str((replacement as Dictionary).get("name", "")) == "system_plugin_maintenance" and replacement_arguments is Dictionary and str((replacement_arguments as Dictionary).get("action", "")) == replacement_action


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_plugin_reload_contracts",
		"success": false,
		"error": message
	}
