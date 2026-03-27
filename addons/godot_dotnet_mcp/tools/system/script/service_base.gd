@tool
extends RefCounted

const GDScriptLspDiagnosticsService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var bridge
var _tool_loader_context


func configure_runtime(context: Dictionary) -> void:
	_tool_loader_context = context.get("tool_loader", null)
	MCPDebugBuffer.record("info", "system", "script service configure_runtime tool_loader=%s" % str(_tool_loader_context != null))


func _get_gdscript_lsp_diagnostics_service():
	if bridge != null and bridge.has_method("get_tool_loader"):
		var loader = bridge.get_tool_loader()
		if loader != null and loader.has_method("get_gdscript_lsp_diagnostics_service"):
			var loader_service = loader.get_gdscript_lsp_diagnostics_service()
			if loader_service != null:
				return loader_service
	if bridge != null and bridge.has_method("get_gdscript_lsp_diagnostics_service"):
		var service = bridge.get_gdscript_lsp_diagnostics_service()
		if service != null:
			return service
	if _tool_loader_context != null and _tool_loader_context.has_method("get_gdscript_lsp_diagnostics_service"):
		return _tool_loader_context.get_gdscript_lsp_diagnostics_service()
	return GDScriptLspDiagnosticsService.get_singleton()


func _build_diagnostics_status_summary(diagnostics_result: Dictionary) -> Dictionary:
	return {
		"source": "godot_lsp",
		"available": bool(diagnostics_result.get("available", false)),
		"pending": bool(diagnostics_result.get("pending", false)),
		"finished": bool(diagnostics_result.get("finished", false)),
		"phase": str(diagnostics_result.get("phase", diagnostics_result.get("state", "unknown")))
	}
