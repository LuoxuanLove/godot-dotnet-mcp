@tool
extends RefCounted

## Resolves shared context services for the AtomicBridge compatibility facade.

const GDScriptLspDiagnosticsService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd")


func get_tool_loader(runtime_context: Dictionary = {}):
	var runtime_bridge = _get_runtime_bridge()
	if runtime_bridge != null and runtime_bridge.has_method("get_tool_loader"):
		var loader = runtime_bridge.get_tool_loader()
		if loader != null:
			return loader
	return runtime_context.get("tool_loader", null)


func get_gdscript_lsp_diagnostics_service(runtime_context: Dictionary = {}):
	var loader = get_tool_loader(runtime_context)
	if loader != null and loader.has_method("get_gdscript_lsp_diagnostics_service"):
		var loader_service = loader.get_gdscript_lsp_diagnostics_service()
		if loader_service != null:
			return loader_service
	var runtime_bridge = _get_runtime_bridge()
	if runtime_bridge != null and runtime_bridge.has_method("get_gdscript_lsp_diagnostics_service"):
		var service = runtime_bridge.get_gdscript_lsp_diagnostics_service()
		if service != null:
			return service
	return GDScriptLspDiagnosticsService.get_singleton()


func _get_runtime_bridge():
	if Engine.has_singleton("MCPRuntimeBridge"):
		return Engine.get_singleton("MCPRuntimeBridge")
	return null
