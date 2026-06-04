extends RefCounted

# {"name": "mcp_maintenance_contracts"}

const MCPMaintenanceContract = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_maintenance_contract.gd")
const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	LocalizationServiceScript.reset_instance()

	var loading_maintenance := MCPMaintenanceContract.build_update_sync_maintenance({
		"current": {"needs_lifecycle_reload": false},
		"lifecycle_reload": {"state": "idle", "pending": false},
		"sync": {"state": "loading"}
	})
	if not bool(loading_maintenance.get("active", false)) or not bool(loading_maintenance.get("reconnect_required", false)):
		return _failure("Update sync loading maintenance should require reconnect.")
	if str(loading_maintenance.get("transport_state", "")) != "updating" or str(loading_maintenance.get("reconnect_hint", "")).is_empty():
		return _failure("Update sync loading maintenance should expose updating state and localized guidance.")

	var stale_after_completion := MCPMaintenanceContract.build_from_freshness({
		"needs_lifecycle_reload": true,
		"lifecycle_reload": {
			"state": "completed",
			"pending": false,
			"completion_observed": true
		}
	})
	if str(stale_after_completion.get("transport_state", "")) != "stale_schema":
		return _failure("A stale plugin instance should keep stale_schema transport state after completed lifecycle reload.")
	if not bool(stale_after_completion.get("refetch_tools_required", false)):
		return _failure("A stale plugin instance should require clients to refetch tools.")

	var lifecycle_maintenance := MCPMaintenanceContract.build_from_lifecycle({
		"state": "scheduled",
		"pending": true,
		"last_request_id": "reload-1"
	}, {
		"needs_lifecycle_reload": false,
		"running_instance": {"nested": {"value": 1}}
	})
	if str(lifecycle_maintenance.get("transport_state", "")) != "disconnecting":
		return _failure("Scheduled lifecycle reload should report disconnecting transport state.")
	if str(lifecycle_maintenance.get("reconnect_hint", "")).is_empty():
		return _failure("Scheduled lifecycle reload should expose localized reconnect guidance.")

	return {
		"name": "mcp_maintenance_contracts",
		"success": true,
		"error": ""
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "mcp_maintenance_contracts",
		"success": false,
		"error": message
	}
