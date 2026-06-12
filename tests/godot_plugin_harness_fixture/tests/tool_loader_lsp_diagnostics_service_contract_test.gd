extends RefCounted

const LspDiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lsp_diagnostics_service.gd")


class FakeToolLoader:
	extends RefCounted

var _service = null


func run_case(_tree: SceneTree) -> Dictionary:
	var service = LspDiagnosticsServiceScript.new()
	_service = service
	var loader := FakeToolLoader.new()
	service.configure(loader)

	var diagnostics_service = service.get_service()
	if diagnostics_service == null:
		return _failure("LSP diagnostics service should lazily expose a diagnostics service instance.")

	var first_snapshot: Dictionary = service.get_debug_snapshot({"status": "ready"})
	if not bool(first_snapshot.get("has_tool_loader", false)):
		return _failure("LSP diagnostics service should pass the configured loader to the adapter.")
	if not bool(first_snapshot.get("service_available", false)):
		return _failure("LSP diagnostics debug snapshot should report a live service.")
	if str((first_snapshot.get("tool_loader_status", {}) as Dictionary).get("status", "")) != "ready":
		return _failure("LSP diagnostics debug snapshot should preserve loader status payloads.")
	var first_generation := int(first_snapshot.get("service_generation", 0))
	if first_generation <= 0:
		return _failure("LSP diagnostics service should expose adapter service generation.")

	service.tick(0.25)
	service.reset()
	var reset_snapshot: Dictionary = service.get_debug_snapshot({})
	var reset_generation := int(reset_snapshot.get("service_generation", 0))
	if reset_generation <= first_generation:
		return _failure("LSP diagnostics reset should rebuild the adapter service generation.")

	service.dispose()
	var disposed_snapshot: Dictionary = service.get_debug_snapshot({"status": "after_dispose"})
	if not bool(disposed_snapshot.get("has_tool_loader", false)):
		return _failure("LSP diagnostics service should retain the configured loader after adapter disposal.")
	if not bool(disposed_snapshot.get("service_available", false)):
		return _failure("LSP diagnostics service should recreate the adapter lazily after disposal.")
	if str((disposed_snapshot.get("tool_loader_status", {}) as Dictionary).get("status", "")) != "after_dispose":
		return _failure("LSP diagnostics service should preserve loader status after lazy recreation.")
	service.release_loader()
	var released_snapshot: Dictionary = service.get_debug_snapshot({})
	if bool(released_snapshot.get("has_tool_loader", true)):
		return _failure("LSP diagnostics release_loader should break the loader ownership reference.")
	service.dispose()

	return {
		"name": "tool_loader_lsp_diagnostics_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"first_generation": first_generation,
			"reset_generation": reset_generation,
			"recreated_generation": int(disposed_snapshot.get("service_generation", 0))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _service != null and _service.has_method("dispose"):
		_service.dispose()
	_service = null


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_lsp_diagnostics_service_contracts",
		"success": false,
		"error": message
	}
