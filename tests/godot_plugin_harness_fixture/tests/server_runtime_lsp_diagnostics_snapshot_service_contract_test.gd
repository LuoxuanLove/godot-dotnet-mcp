extends RefCounted

const SnapshotServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/server_runtime_lsp_diagnostics_snapshot_service.gd")


class FakeDiagnosticsService extends RefCounted:
	func get_debug_snapshot() -> Dictionary:
		return {
			"request_count": 2,
			"active_key": "res://player.gd",
			"cache_entry_count": 1,
			"last_completed_status": {"error": ""},
			"status": {"phase": "idle"},
			"client": {"transport": "stdio"}
		}


class FakeLoaderWithSnapshot extends RefCounted:
	func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
		return {
			"has_tool_loader": true,
			"service_available": true,
			"service_generation": 3,
			"tool_loader_status": {"status": "ready"},
			"service": {
				"request_count": 4,
				"active_key": "res://enemy.gd",
				"cache_entry_count": 2,
				"last_completed_status": {"error": ""},
				"status": {"phase": "ready"},
				"client": {"transport": "tcp"}
			}
		}


class FakeLoaderWithService extends RefCounted:
	func get_gdscript_lsp_diagnostics_service():
		return FakeDiagnosticsService.new()


func run_case(_tree: SceneTree) -> Dictionary:
	var service = SnapshotServiceScript.new()
	var missing_snapshot: Dictionary = service.build_snapshot(null)
	if str(missing_snapshot.get("error", "")) != "Tool loader is unavailable":
		return _failure("Snapshot service should explain when the tool loader is unavailable.")

	var direct_snapshot: Dictionary = service.build_snapshot(FakeLoaderWithSnapshot.new())
	if direct_snapshot.has("error") and not str(direct_snapshot.get("error", "")).is_empty():
		return _failure("Snapshot service should clear the error field when a direct loader snapshot is available.")
	var direct_loader = direct_snapshot.get("loader", {})
	var direct_service = direct_snapshot.get("service", {})
	if not bool((direct_loader as Dictionary).get("available", false)):
		return _failure("Snapshot service should report the loader as available when the loader provides a snapshot.")
	if int((direct_loader as Dictionary).get("service_generation", 0)) != 3:
		return _failure("Snapshot service should preserve the diagnostics service generation from the loader snapshot.")
	if int((direct_service as Dictionary).get("cache_entry_count", 0)) != 2:
		return _failure("Snapshot service should preserve service cache entry count from the loader snapshot.")

	var fallback_snapshot: Dictionary = service.build_snapshot(FakeLoaderWithService.new())
	var client_snapshot = fallback_snapshot.get("client", {})
	if not bool((fallback_snapshot.get("service", {}) as Dictionary).get("available", false)):
		return _failure("Snapshot service should synthesize an available service summary from the fallback diagnostics service.")
	if not bool((client_snapshot as Dictionary).get("available", false)):
		return _failure("Snapshot service should mark the fallback diagnostics client as available when client data exists.")

	return {
		"name": "server_runtime_lsp_diagnostics_snapshot_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"direct_generation": int((direct_loader as Dictionary).get("service_generation", 0)),
			"fallback_request_count": int(((fallback_snapshot.get("service", {}) as Dictionary).get("request_count", 0)))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "server_runtime_lsp_diagnostics_snapshot_service_contracts",
		"success": false,
		"error": message
	}
