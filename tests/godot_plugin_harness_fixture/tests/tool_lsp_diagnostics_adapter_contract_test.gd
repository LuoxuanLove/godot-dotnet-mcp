extends RefCounted

const AdapterScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_lsp_diagnostics_adapter.gd")


class FakeToolLoader extends RefCounted:
	func get_tool_loader_status() -> Dictionary:
		return {"initialized": true, "status": "ready"}


class FakeRuntimeBridge extends RefCounted:
	var tool_loader = null
	var diagnostics_service = null

	func set_tool_loader(loader) -> void:
		tool_loader = loader

	func set_gdscript_lsp_diagnostics_service(service) -> void:
		diagnostics_service = service

	func get_gdscript_lsp_diagnostics_service():
		return diagnostics_service


var _adapter = null


func run_case(_tree: SceneTree) -> Dictionary:
	_adapter = AdapterScript.new()
	var loader := FakeToolLoader.new()
	var runtime_bridge := FakeRuntimeBridge.new()
	_adapter.configure(loader, {"runtime_bridge": runtime_bridge})

	var first_service = _adapter.get_service()
	if first_service == null:
		return _failure("Adapter did not create a diagnostics service.")
	if runtime_bridge.diagnostics_service != first_service:
		return _failure("Adapter did not bind the diagnostics service onto the runtime bridge.")
	if runtime_bridge.tool_loader != loader:
		return _failure("Adapter did not bind the tool loader onto the runtime bridge.")

	var first_snapshot: Dictionary = _adapter.get_debug_snapshot({"initialized": true})
	if not bool(first_snapshot.get("service_available", false)):
		return _failure("Adapter debug snapshot should report the diagnostics service as available.")
	if int(first_snapshot.get("service_generation", 0)) != 1:
		return _failure("Adapter should start with diagnostics service generation 1 after the first reset.")

	_adapter.tick(0.0)
	_adapter.reset()
	var second_service = _adapter.get_service()
	if second_service == null or second_service == first_service:
		return _failure("Adapter reset should replace the diagnostics service instance.")
	if runtime_bridge.diagnostics_service != second_service:
		return _failure("Adapter reset did not refresh the runtime bridge binding.")

	var second_snapshot: Dictionary = _adapter.get_debug_snapshot({"initialized": true})
	if int(second_snapshot.get("service_generation", 0)) < 2:
		return _failure("Adapter reset should advance the diagnostics service generation.")

	_adapter.release()
	if runtime_bridge.diagnostics_service != null:
		return _failure("Adapter release should clear the runtime bridge diagnostics service binding.")
	if runtime_bridge.tool_loader != null:
		return _failure("Adapter release should clear the runtime bridge tool loader binding.")

	return {
		"name": "tool_lsp_diagnostics_adapter_contracts",
		"success": true,
		"error": "",
		"details": {
			"first_generation": int(first_snapshot.get("service_generation", 0)),
			"second_generation": int(second_snapshot.get("service_generation", 0))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	if _adapter != null and _adapter.has_method("dispose"):
		_adapter.dispose()
	_adapter = null


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_lsp_diagnostics_adapter_contracts",
		"success": false,
		"error": message
	}
