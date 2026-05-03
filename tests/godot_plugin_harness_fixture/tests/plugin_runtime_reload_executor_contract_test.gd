extends RefCounted

# {"name": "plugin_runtime_reload_executor_contracts"}

const PluginRuntimeExecutor = preload("res://addons/godot_dotnet_mcp/tools/plugin_runtime/executor.gd")


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

	var executor = PluginRuntimeExecutor.new()
	executor.configure_runtime({"server": server, "tool_loader": RefCounted.new()})
	var result: Dictionary = executor.execute("reload", {"action": "full_reload_plugin"})
	var lifecycle_reload_called := plugin.lifecycle_reload_called
	plugin.queue_free()
	await tree.process_frame

	if not bool(result.get("success", false)):
		return _failure("full_reload_plugin should call the lifecycle reload bridge successfully.")
	if not lifecycle_reload_called:
		return _failure("full_reload_plugin should route to request_plugin_lifecycle_reload_from_tools, not runtime_full_reload.")
	if not bool(result.get("deferred", false)):
		return _failure("Lifecycle plugin reload should return a deferred accepted response.")

	return {
		"name": "plugin_runtime_reload_executor_contracts",
		"success": true,
		"error": "",
		"details": {"message": str(result.get("message", ""))}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_runtime_reload_executor_contracts",
		"success": false,
		"error": message
	}
