@tool
extends RefCounted

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var bridge
var _tool_loader_context


func configure_runtime(context: Dictionary) -> void:
	_tool_loader_context = context.get("tool_loader", null)
	MCPDebugBuffer.record("info", "system", "script service configure_runtime tool_loader=%s" % str(_tool_loader_context != null))


func _get_gdscript_lsp_diagnostics_service():
	var loader = null
	if bridge != null and bridge.has_method("get_tool_loader"):
		loader = bridge.get_tool_loader()
	if _tool_loader_context != null and _tool_loader_context.has_method("get_gdscript_lsp_diagnostics_service"):
		loader = _tool_loader_context
	if loader != null and loader.has_method("get_gdscript_lsp_diagnostics_service"):
		var service = loader.get_gdscript_lsp_diagnostics_service()
		if service != null:
			return service
	return null


func _build_diagnostics_status_summary(diagnostics_result: Dictionary) -> Dictionary:
	return {
		"source": "godot_lsp",
		"available": bool(diagnostics_result.get("available", false)),
		"pending": bool(diagnostics_result.get("pending", false)),
		"finished": bool(diagnostics_result.get("finished", false)),
		"phase": str(diagnostics_result.get("phase", diagnostics_result.get("state", "unknown")))
	}
