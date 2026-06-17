extends RefCounted

const SessionRegistryServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/editor_debugger_session_registry_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var service = SessionRegistryServiceScript.new()

	var initial_result: Dictionary = service.prune_stale_wired_sessions({
		1: true,
		2: true
	}, [1, 2], 1)
	var initial_wired: Dictionary = initial_result.get("wired_sessions", {})
	if not initial_wired.has(1) or not initial_wired.has(2):
		return _failure("Session registry service should preserve live wired sessions.")
	if int(initial_result.get("last_active_session_id", -1)) != 1:
		return _failure("Session registry service should preserve the active session when it is still live.")

	var pruned_result: Dictionary = service.prune_stale_wired_sessions({
		1: true,
		2: true
	}, [2], 1)
	var pruned_wired: Dictionary = pruned_result.get("wired_sessions", {})
	if pruned_wired.has(1) or not pruned_wired.has(2):
		return _failure("Session registry service should prune stale wired sessions and retain live ones.")
	if int(pruned_result.get("last_active_session_id", 0)) != -1:
		return _failure("Session registry service should clear the active session id when it was pruned.")

	var invalid_result: Dictionary = service.prune_stale_wired_sessions({
		"broken": true,
		3: true
	}, [3], 3)
	var invalid_wired: Dictionary = invalid_result.get("wired_sessions", {})
	if invalid_wired.has("broken") or not invalid_wired.has(3):
		return _failure("Session registry service should drop invalid wired session ids while preserving valid live ones.")

	return {
		"name": "editor_debugger_session_registry_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"initial_count": initial_wired.size(),
			"pruned_count": pruned_wired.size(),
			"invalid_count": invalid_wired.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "editor_debugger_session_registry_service_contracts",
		"success": false,
		"error": message
	}
