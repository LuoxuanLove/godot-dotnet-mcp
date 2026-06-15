@tool
extends RefCounted
class_name ToolLoaderLspDiagnosticsService

const ToolLspDiagnosticsAdapterScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_lsp_diagnostics_adapter.gd")

var _tool_loader = null
var _diagnostics_adapter = null


func configure(tool_loader) -> void:
	_tool_loader = tool_loader
	if _diagnostics_adapter != null and _diagnostics_adapter.has_method("configure"):
		_configure_adapter(_diagnostics_adapter)


func get_service():
	var diagnostics_adapter = ensure_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("get_service"):
		return diagnostics_adapter.get_service()
	return null


func get_debug_snapshot(tool_loader_status: Dictionary = {}) -> Dictionary:
	var diagnostics_adapter = ensure_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("get_debug_snapshot"):
		return diagnostics_adapter.get_debug_snapshot(tool_loader_status)
	return {
		"has_tool_loader": _tool_loader != null,
		"service_available": false,
		"service_generation": 0,
		"tool_loader_status": tool_loader_status.duplicate(true)
	}


func has_active_request() -> bool:
	if _diagnostics_adapter != null and _diagnostics_adapter.has_method("has_active_request"):
		return bool(_diagnostics_adapter.has_active_request())
	return false


func reset() -> void:
	var diagnostics_adapter = ensure_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("reset"):
		diagnostics_adapter.reset()


func dispose() -> void:
	if _diagnostics_adapter != null and _diagnostics_adapter.has_method("dispose"):
		_diagnostics_adapter.dispose()
	_diagnostics_adapter = null


func release_loader() -> void:
	dispose()
	_tool_loader = null


func tick(delta: float) -> void:
	var diagnostics_adapter = ensure_adapter()
	if diagnostics_adapter != null and diagnostics_adapter.has_method("tick"):
		diagnostics_adapter.tick(delta)


func ensure_adapter():
	if _diagnostics_adapter == null:
		_diagnostics_adapter = ToolLspDiagnosticsAdapterScript.new()
	if _diagnostics_adapter != null:
		_configure_adapter(_diagnostics_adapter)
	return _diagnostics_adapter


func _configure_adapter(diagnostics_adapter) -> void:
	if diagnostics_adapter != null and diagnostics_adapter.has_method("configure"):
		diagnostics_adapter.configure(_tool_loader, {
			"runtime_bridge": _get_runtime_bridge()
		})


func _get_runtime_bridge():
	if Engine.has_singleton("MCPRuntimeBridge"):
		return Engine.get_singleton("MCPRuntimeBridge")
	return null
