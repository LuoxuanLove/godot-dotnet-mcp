extends RefCounted

# {"name": "mcp_tool_loader_supervisor_contracts"}

const SupervisorScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_loader_supervisor.gd")


class TestSupervisor extends SupervisorScript:
	var live_revision := 1

	func seed_summary() -> void:
		_tool_loader_last_summary = {
			"tool_count": 2,
			"exposed_tool_count": 1,
			"category_count": 1,
			"tool_load_error_count": 0,
			"catalog_revision": 1
		}

	func _get_tool_loader_catalog_revision() -> int:
		return live_revision


func run_case(_tree: SceneTree) -> Dictionary:
	var supervisor = TestSupervisor.new()
	supervisor.seed_summary()
	var first_status: Dictionary = supervisor.get_light_status()
	if int(first_status.get("catalog_revision", 0)) != 1:
		return _failure("Supervisor light status should expose the initialized loader catalog revision.")

	# Simulate a loader-side catalog mutation that does not rebuild the supervisor
	# summary. Dock refresh cache keys use light status and must still observe it.
	supervisor.live_revision = 7
	var live_status: Dictionary = supervisor.get_light_status()
	if int(live_status.get("catalog_revision", 0)) != 7:
		return _failure("Supervisor light status should publish the live loader catalog revision, not stale summary data.")

	return {
		"name": "mcp_tool_loader_supervisor_contracts",
		"success": true,
		"error": "",
		"details": {
			"catalog_revision": int(live_status.get("catalog_revision", 0))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "mcp_tool_loader_supervisor_contracts",
		"success": false,
		"error": message
	}
