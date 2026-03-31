extends RefCounted

const LifecycleActionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_action_service.gd")
const LifecycleActionContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_editor_lifecycle_action_context.gd")


class FakeCallbacks:
	extends RefCounted

	var scheduled_actions: Array[String] = []

	func build_state() -> Dictionary:
		return {
			"isPlayingScene": false,
			"openScenes": ["res://scenes/main.tscn"],
			"dirtySceneCount": 1,
			"dirtyScenes": ["res://scenes/main.tscn"],
			"currentScenePath": "res://scenes/main.tscn"
		}

	func build_state_with_hint(hint: String) -> Dictionary:
		var state := build_state()
		state["hint"] = hint
		return state

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

	func schedule_action(action: String) -> void:
		scheduled_actions.append(action)

	func get_plugin_host():
		return null

	func log(_message: String, _level: String) -> void:
		pass


func run_case(_tree: SceneTree) -> Dictionary:
	var service = LifecycleActionServiceScript.new()
	var callbacks = FakeCallbacks.new()
	var context = LifecycleActionContextScript.new()
	context.build_state = Callable(callbacks, "build_state")
	context.build_state_with_hint = Callable(callbacks, "build_state_with_hint")
	context.build_success = Callable(callbacks, "build_success")
	context.build_error = Callable(callbacks, "build_error")
	context.schedule_action = Callable(callbacks, "schedule_action")
	context.get_plugin_host = Callable(callbacks, "get_plugin_host")
	context.log = Callable(callbacks, "log")
	service.configure(context)

	var close_confirmation: Dictionary = service.execute_close({})
	if str(close_confirmation.get("error", "")) != "editor_confirmation_required":
		return _failure("Lifecycle action service did not require explicit confirmation for close.")
	var close_hint_data = close_confirmation.get("data", {})
	if not (close_hint_data is Dictionary) or str((close_hint_data as Dictionary).get("hint", "")).find("save=true") == -1:
		return _failure("Lifecycle action service did not return the close confirmation hint.")

	var restart_confirmation: Dictionary = service.execute_restart({
		"force": true
	})
	if str(restart_confirmation.get("error", "")) != "editor_confirmation_required":
		return _failure("Lifecycle action service did not reject force-only restart requests.")

	var accepted_close: Dictionary = service.execute_close({
		"save": true
	})
	if not bool(accepted_close.get("success", false)):
		return _failure("Lifecycle action service did not accept save=true close requests.")
	var accepted_close_data = accepted_close.get("data", {})
	if not (accepted_close_data is Dictionary) or str((accepted_close_data as Dictionary).get("action", "")) != "close":
		return _failure("Lifecycle action service did not preserve the accepted close action.")
	if callbacks.scheduled_actions.is_empty() or callbacks.scheduled_actions[0] != "close":
		return _failure("Lifecycle action service did not schedule the accepted close action.")

	return {
		"name": "editor_lifecycle_action_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"scheduled_count": callbacks.scheduled_actions.size(),
			"accepted_action": str((accepted_close_data as Dictionary).get("action", "")),
			"close_confirmation_error": str(close_confirmation.get("error", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "editor_lifecycle_action_service_contracts",
		"success": false,
		"error": message
	}
