@tool
extends RefCounted

## Shared atomic tool bridge for system implementations.
## call_atomic() is the single abstraction point for the v1 Backend Router.

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const AtomicBridgeContextResolverScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_context_resolver.gd")
const AtomicBridgeExecutionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_execution_service.gd")

var _runtime_context: Dictionary = {}
var _context_resolver = AtomicBridgeContextResolverScript.new()
var _execution_service = AtomicBridgeExecutionServiceScript.new()


func _init() -> void:
	_execution_service.configure_default(Callable(self, "_build_atomic_runtime_context"))


func success(data = null, message: String = "") -> Dictionary:
	return {"success": true, "data": data, "message": message}


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate()
	_execution_service.configure_runtime(_runtime_context)


func get_tool_loader():
	return _context_resolver.get_tool_loader(_runtime_context)


func get_gdscript_lsp_diagnostics_service():
	return _context_resolver.get_gdscript_lsp_diagnostics_service(_runtime_context)


func error(message: String, data = null, hints: Array = []) -> Dictionary:
	var result := {"success": false, "error": message}
	if data != null:
		result["data"] = data
	if not hints.is_empty():
		result["hints"] = hints
	return result


func call_atomic(full_name: String, args: Dictionary = {}) -> Dictionary:
	return _execution_service.call_atomic(full_name, args)


func call_atomic_async(full_name: String, args: Dictionary = {}) -> Dictionary:
	return await _execution_service.call_atomic_async(full_name, args)


func _build_atomic_runtime_context(category: String, _runtime_context_source: Dictionary) -> Dictionary:
	return _context_resolver.build_atomic_runtime_context(category, _runtime_context)
