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


func build_atomic_runtime_context(category: String, runtime_context: Dictionary = {}) -> Dictionary:
	var context := runtime_context.duplicate()
	context["category"] = category
	var plugin = resolve_plugin_host(context)
	if plugin != null:
		context["plugin_host"] = plugin
		if not context.has("editor_interface") and plugin.has_method("get_editor_interface"):
			context["editor_interface"] = plugin.get_editor_interface()
	return context


func resolve_plugin_host(context: Dictionary = {}):
	var plugin = context.get("plugin_host", null)
	if plugin != null and is_instance_valid(plugin):
		return plugin
	var getter = context.get("get_plugin_host", Callable())
	if getter is Callable and getter.is_valid():
		plugin = getter.call()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	var server = context.get("server", null)
	if server != null and is_instance_valid(server) and server.has_method("get_parent"):
		plugin = server.get_parent()
		if plugin != null and is_instance_valid(plugin):
			return plugin
	return null


func _get_runtime_bridge():
	if Engine.has_singleton("MCPRuntimeBridge"):
		return Engine.get_singleton("MCPRuntimeBridge")
	return null
