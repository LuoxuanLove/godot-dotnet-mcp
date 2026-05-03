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
		return {"success": true, "message": "Plugin lifecycle reload scheduled", "deferred": true}


func run_case(tree: SceneTree) -> Dictionary:
	var plugin := FakePlugin.new()
	var server := Node.new()
	plugin.add_child(server)
	tree.root.add_child(plugin)

	var executor = ImplProjectScript.new()
	executor.bridge = FakeBridge.new()
	executor.configure_runtime({"server": server})

	var freshness_result: Dictionary = executor.execute("plugin_reload", {"action": "get_freshness"})
	if not bool(freshness_result.get("success", false)):
		return _failure("system_plugin_reload get_freshness should succeed.")
	var freshness: Dictionary = freshness_result.get("data", {})
	if not freshness.has("running_instance") or not freshness.has("comparison"):
		return _failure("system_plugin_reload get_freshness should expose freshness metadata.")

	var reload_result: Dictionary = executor.execute("plugin_reload", {"action": "full_reload_plugin"})
	var lifecycle_reload_called := plugin.lifecycle_reload_called
	plugin.queue_free()
	await tree.process_frame

	if not bool(reload_result.get("success", false)):
		return _failure("system_plugin_reload full_reload_plugin should schedule lifecycle reload.")
	if not lifecycle_reload_called:
		return _failure("system_plugin_reload should route to the plugin lifecycle reload bridge.")
	if not bool(reload_result.get("deferred", false)):
		return _failure("system_plugin_reload should return a deferred accepted response.")

	return {
		"name": "system_plugin_reload_contracts",
		"success": true,
		"error": "",
		"details": {"reload_message": str(reload_result.get("message", ""))}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_plugin_reload_contracts",
		"success": false,
		"error": message
	}
