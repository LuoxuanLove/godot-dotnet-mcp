extends RefCounted

const LifecycleEndpointScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_endpoint.gd")
const LifecycleEndpointContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_endpoint_context.gd")


class FakeCallbacks:
	extends RefCounted

	func build_state() -> Dictionary:
		return {
			"isPlayingScene": false,
			"openScenes": ["res://scenes/main.tscn"],
			"dirtySceneCount": 0,
			"dirtyScenes": [],
			"currentScenePath": "res://scenes/main.tscn"
		}

	func execute_close(args: Dictionary) -> Dictionary:
		return {
			"success": true,
			"data": {
				"action": "close",
				"save": bool(args.get("save", false))
			},
			"message": "Editor close accepted"
		}

	func execute_restart(args: Dictionary) -> Dictionary:
		return {
			"success": true,
			"data": {
				"action": "restart",
				"save": bool(args.get("save", false))
			},
			"message": "Editor restart accepted"
		}

	func build_success(data, message: String) -> Dictionary:
		return {
			"success": true,
			"data": data,
			"message": message
		}

	func build_error(error_code: String, message: String, data: Dictionary = {}) -> Dictionary:
		return {
			"success": false,
			"error": error_code,
			"message": message,
			"data": data.duplicate(true),
			"status": 400
		}


func run_case(_tree: SceneTree) -> Dictionary:
	var endpoint = LifecycleEndpointScript.new()
	var callbacks = FakeCallbacks.new()
	var context = LifecycleEndpointContextScript.new()
	context.build_state = Callable(callbacks, "build_state")
	context.execute_close = Callable(callbacks, "execute_close")
	context.execute_restart = Callable(callbacks, "execute_restart")
	context.build_success = Callable(callbacks, "build_success")
	context.build_error = Callable(callbacks, "build_error")
	endpoint.configure(context)

	var invalid_json: Dictionary = endpoint.handle_post_request(JSON.stringify([]))
	if str(invalid_json.get("error", "")) != "invalid_argument":
		return _failure("Lifecycle endpoint did not reject a non-object POST body.")

	var missing_action: Dictionary = endpoint.handle_post_request(JSON.stringify({}))
	if str(missing_action.get("error", "")) != "invalid_argument":
		return _failure("Lifecycle endpoint did not require an action field for POST requests.")

	var status_response: Dictionary = endpoint.handle_request("status", {})
	if not bool(status_response.get("success", false)):
		return _failure("Lifecycle endpoint did not return success for status requests.")
	var status_data = status_response.get("data", {})
	if not (status_data is Dictionary) or str((status_data as Dictionary).get("currentScenePath", "")) != "res://scenes/main.tscn":
		return _failure("Lifecycle endpoint did not preserve the lifecycle state payload.")

	var close_response: Dictionary = endpoint.handle_post_request(JSON.stringify({
		"action": "close",
		"save": true
	}))
	var close_data = close_response.get("data", {})
	if not (close_data is Dictionary) or str((close_data as Dictionary).get("action", "")) != "close":
		return _failure("Lifecycle endpoint did not forward close requests to the close handler.")

	var unknown_action: Dictionary = endpoint.handle_request("bogus", {})
	var unknown_data = unknown_action.get("data", {})
	if str(unknown_action.get("error", "")) != "invalid_argument":
		return _failure("Lifecycle endpoint did not reject an unknown action.")
	if not (unknown_data is Dictionary) or str((unknown_data as Dictionary).get("hint", "")).find("status|close|restart") == -1:
		return _failure("Lifecycle endpoint did not preserve the unknown-action hint.")

	return {
		"name": "editor_lifecycle_endpoint_contracts",
		"success": true,
		"error": "",
		"details": {
			"current_scene_path": str((status_data as Dictionary).get("currentScenePath", "")),
			"close_action": str((close_data as Dictionary).get("action", "")),
			"unknown_error": str(unknown_action.get("error", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "editor_lifecycle_endpoint_contracts",
		"success": false,
		"error": message
	}
