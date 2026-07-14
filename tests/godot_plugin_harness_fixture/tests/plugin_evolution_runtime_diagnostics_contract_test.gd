extends RefCounted

# {"name": "plugin_evolution_runtime_diagnostics_contracts"}

const PluginEvolutionExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/plugin_evolution/executor.gd")


class FakeToolLoader extends RefCounted:
	var runtime_snapshot: Array[Dictionary] = []

	func get_user_tool_runtime_snapshot() -> Array[Dictionary]:
		return runtime_snapshot.duplicate(true)


class FakePlugin extends Node:
	var received_limit := -1
	var received_runtime_state: Array = []

	func get_user_tool_diagnostics() -> Dictionary:
		return {"success": true}

	func get_user_tool_runtime_diagnostics_from_tools(limit: int = 10, runtime_state: Array = []) -> Dictionary:
		received_limit = limit
		received_runtime_state = runtime_state.duplicate(true)
		return {
			"success": true,
			"data": {
				"limit": limit,
				"runtime_state_count": runtime_state.size(),
				"runtime_state": runtime_state.duplicate(true),
				"failed_loads": [{
					"script_path": "res://addons/godot_dotnet_mcp/custom_tools/runtime_failed_user_tool.gd",
					"load_error": "Duplicate user tool logical name: duplicated_tool",
					"diagnostic_code": "duplicate_user_tool_logical_name",
					"recommended_action": "Rename one of the conflicting user tool declarations so each logical tool name is unique.",
					"next_tool_hint": "Run plugin_evolution_runtime_diagnostics after renaming to confirm the duplicate runtime failure cleared."
				}]
			}
		}


func run_case(tree: SceneTree) -> Dictionary:
	var plugin := FakePlugin.new()
	var server := Node.new()
	plugin.add_child(server)
	tree.root.add_child(plugin)

	var loader := FakeToolLoader.new()
	loader.runtime_snapshot = [{
		"script_path": "res://addons/godot_dotnet_mcp/custom_tools/runtime_failed_user_tool.gd",
		"runtime_domain": "user/runtime_failed_user_tool",
		"version": 3,
		"state": "reload_failed",
		"active_calls": 0,
		"pending_reload": false,
		"removed_pending": false,
		"last_loaded_at_unix": 0,
		"last_error": "Duplicate user tool logical name: duplicated_tool",
		"discovery_source": "watcher",
		"last_refresh_reason": "file_changed"
	}]

	var executor = PluginEvolutionExecutorScript.new()
	executor.configure_runtime({
		"server": server,
		"tool_loader": loader
	})

	var result: Dictionary = executor.execute("runtime_diagnostics", {"limit": 7})
	var received_limit := plugin.received_limit
	var received_runtime_state: Array = plugin.received_runtime_state.duplicate(true)
	plugin.queue_free()
	await tree.process_frame

	if not bool(result.get("success", false)):
		return _failure("runtime_diagnostics should succeed through the public plugin_evolution entry.")
	if received_limit != 7:
		return _failure("runtime_diagnostics should pass the requested limit through to the plugin bridge.")
	if received_runtime_state.size() != 1:
		return _failure("runtime_diagnostics should forward the live user-tool runtime snapshot to the plugin bridge.")
	if str(received_runtime_state[0].get("state", "")) != "reload_failed":
		return _failure("runtime_diagnostics should preserve runtime snapshot entries.")
	if int(result.get("data", {}).get("runtime_state_count", 0)) != 1:
		return _failure("runtime_diagnostics should preserve the runtime snapshot count in the returned payload.")
	var failed_loads = result.get("data", {}).get("failed_loads", [])
	if not (failed_loads is Array) or (failed_loads as Array).is_empty():
		return _failure("runtime_diagnostics should expose user-tool recovery diagnostics.")
	var first_failure: Dictionary = (failed_loads as Array)[0] as Dictionary
	if str(first_failure.get("diagnostic_code", "")) != "duplicate_user_tool_logical_name":
		return _failure("runtime_diagnostics should preserve recovery diagnostic codes through the public plugin_evolution entry.")
	if str(first_failure.get("recommended_action", "")).find("Rename") == -1:
		return _failure("runtime_diagnostics should preserve recovery recommendations through the public plugin_evolution entry.")

	return {
		"name": "plugin_evolution_runtime_diagnostics_contracts",
		"success": true,
		"error": "",
		"details": {
			"limit": received_limit,
			"runtime_state_count": received_runtime_state.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "plugin_evolution_runtime_diagnostics_contracts",
		"success": false,
		"error": message
	}
