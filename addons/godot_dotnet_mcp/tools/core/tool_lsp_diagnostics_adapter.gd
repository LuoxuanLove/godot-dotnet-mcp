@tool
extends RefCounted
class_name MCPToolLspDiagnosticsAdapter

const GDScriptLspDiagnosticsServicePath = "res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd"

var _tool_loader: Object
var _diagnostics_service
var _generation := 0
var _runtime_bridge_override: Object


func configure(tool_loader: Object, options: Dictionary = {}) -> void:
	_tool_loader = tool_loader
	_runtime_bridge_override = options.get("runtime_bridge", null)


func dispose() -> void:
	release()
	_tool_loader = null
	_runtime_bridge_override = null


func get_service():
	if _diagnostics_service != null and is_instance_valid(_diagnostics_service):
		return _diagnostics_service
	reset()
	return _diagnostics_service


func get_debug_snapshot(tool_loader_status: Dictionary) -> Dictionary:
	var service = get_service()
	var snapshot: Dictionary = {
		"has_tool_loader": _tool_loader != null,
		"service_available": service != null,
		"service_generation": _generation,
		"tool_loader_status": tool_loader_status.duplicate(true)
	}
	if service != null and service.has_method("get_debug_snapshot"):
		snapshot["service"] = service.get_debug_snapshot()
	return snapshot


func reset() -> void:
	if _diagnostics_service != null and is_instance_valid(_diagnostics_service):
		if _diagnostics_service.has_method("clear"):
			_diagnostics_service.clear()
	var diagnostics_script = ResourceLoader.load(
		GDScriptLspDiagnosticsServicePath,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	if diagnostics_script == null:
		_diagnostics_service = null
		return
	_diagnostics_service = diagnostics_script.new()
	_generation += 1
	_bind_runtime_bridge()


func release() -> void:
	if _diagnostics_service != null and is_instance_valid(_diagnostics_service):
		if _diagnostics_service.has_method("clear"):
			_diagnostics_service.clear()
	_diagnostics_service = null
	var runtime_bridge = _get_runtime_bridge()
	if runtime_bridge != null:
		if runtime_bridge.has_method("set_gdscript_lsp_diagnostics_service"):
			runtime_bridge.set_gdscript_lsp_diagnostics_service(null)
		if runtime_bridge.has_method("set_tool_loader"):
			runtime_bridge.set_tool_loader(null)


func tick(delta: float) -> void:
	var diagnostics_service = get_service()
	if diagnostics_service != null and diagnostics_service.has_method("tick"):
		diagnostics_service.tick(delta)


func _bind_runtime_bridge() -> void:
	var runtime_bridge = _get_runtime_bridge()
	if runtime_bridge == null:
		return
	if runtime_bridge.has_method("set_gdscript_lsp_diagnostics_service"):
		runtime_bridge.set_gdscript_lsp_diagnostics_service(_diagnostics_service)
	if _tool_loader != null and runtime_bridge.has_method("set_tool_loader"):
		runtime_bridge.set_tool_loader(_tool_loader)


func _get_runtime_bridge():
	if _runtime_bridge_override != null:
		return _runtime_bridge_override
	if not Engine.has_singleton("MCPRuntimeBridge"):
		return null
	return Engine.get_singleton("MCPRuntimeBridge")
