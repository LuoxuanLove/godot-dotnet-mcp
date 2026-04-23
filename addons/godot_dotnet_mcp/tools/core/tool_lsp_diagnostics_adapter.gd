@tool
extends RefCounted

const GDScriptLspDiagnosticsServicePath := "res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd"

var _tool_loader = null
var _runtime_bridge = null
var _service = null
var _service_generation := 0


func configure(tool_loader, context: Dictionary = {}) -> void:
	_tool_loader = tool_loader
	_runtime_bridge = context.get("runtime_bridge", null)
	if _runtime_bridge == null and Engine.has_singleton("MCPRuntimeBridge"):
		_runtime_bridge = Engine.get_singleton("MCPRuntimeBridge")
	_bind_runtime_bridge()
	if _service == null or not is_instance_valid(_service):
		reset()


func get_service():
	if _service == null or not is_instance_valid(_service):
		reset()
	return _service


func tick(delta: float) -> void:
	var service = get_service()
	if service != null and service.has_method("tick"):
		service.tick(delta)


func reset() -> void:
	if _service != null and is_instance_valid(_service) and _service.has_method("clear"):
		_service.clear()
	var diagnostics_script = ResourceLoader.load(
		GDScriptLspDiagnosticsServicePath,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	if diagnostics_script == null:
		_service = null
		_bind_runtime_bridge()
		return
	_service = diagnostics_script.new()
	_service_generation += 1
	_bind_runtime_bridge()


func release() -> void:
	if _service != null and is_instance_valid(_service) and _service.has_method("clear"):
		_service.clear()
	_service = null
	if _runtime_bridge != null:
		if _runtime_bridge.has_method("set_gdscript_lsp_diagnostics_service"):
			_runtime_bridge.set_gdscript_lsp_diagnostics_service(null)
		if _runtime_bridge.has_method("set_tool_loader"):
			_runtime_bridge.set_tool_loader(null)


func get_debug_snapshot(tool_loader_status: Dictionary = {}) -> Dictionary:
	var service = get_service()
	var snapshot: Dictionary = {
		"has_tool_loader": _tool_loader != null,
		"service_available": service != null,
		"service_generation": _service_generation,
		"tool_loader_status": tool_loader_status.duplicate(true)
	}
	if service != null and service.has_method("get_debug_snapshot"):
		snapshot["service"] = service.get_debug_snapshot()
	return snapshot


func dispose() -> void:
	release()


func _bind_runtime_bridge() -> void:
	if _runtime_bridge == null:
		return
	if _runtime_bridge.has_method("set_tool_loader"):
		_runtime_bridge.set_tool_loader(_tool_loader)
	if _runtime_bridge.has_method("set_gdscript_lsp_diagnostics_service"):
		_runtime_bridge.set_gdscript_lsp_diagnostics_service(_service)
