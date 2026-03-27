extends RefCounted

const HttpServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")
const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const DefaultPermissionProviderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/default_tool_permission_provider.gd")


class FakeServerContext extends RefCounted:
	var _permission_provider

	func _init(permission_provider) -> void:
		_permission_provider = permission_provider

	func get_plugin_permission_provider():
		return _permission_provider


var _http_server = null
var _tool_loader = null
var _stdio_server = null


func run_case(_tree: SceneTree) -> Dictionary:
	_http_server = HttpServerScript.new()
	_http_server.initialize(0, "127.0.0.1", false)
	var http_loader = _http_server.get_tool_loader()
	if http_loader == null:
		return _failure("HTTP server did not initialize its tool loader.")
	var http_service = _http_server.get_gdscript_lsp_diagnostics_service()
	if http_service == null:
		return _failure("HTTP server did not expose the loader-owned GDScript LSP diagnostics service.")
	if http_service != http_loader.get_gdscript_lsp_diagnostics_service():
		return _failure("HTTP server should expose the exact diagnostics service instance owned by the loader adapter.")

	var permission_provider = DefaultPermissionProviderScript.new()
	permission_provider.configure({
		"permission_level": "evolution",
		"show_user_tools": true
	})
	_tool_loader = ToolLoaderScript.new()
	_tool_loader.configure(FakeServerContext.new(permission_provider))
	var summary: Dictionary = _tool_loader.initialize([])
	if int(summary.get("tool_count", 0)) <= 0:
		return _failure("Standalone tool loader did not initialize for stdio access testing.")

	_stdio_server = StdioServerScript.new()
	if _stdio_server.get_gdscript_lsp_diagnostics_service() != null:
		return _failure("Stdio server should not expose a diagnostics service before a tool loader is injected.")
	_stdio_server.initialize(_tool_loader, false)
	var stdio_service = _stdio_server.get_gdscript_lsp_diagnostics_service()
	if stdio_service == null:
		return _failure("Stdio server did not expose the loader-owned GDScript LSP diagnostics service.")
	if stdio_service != _tool_loader.get_gdscript_lsp_diagnostics_service():
		return _failure("Stdio server should expose the exact diagnostics service instance owned by the injected loader.")

	return {
		"name": "lsp_service_access_contracts",
		"success": true,
		"error": "",
		"details": {
			"http_loader_has_service": http_service != null,
			"stdio_loader_has_service": stdio_service != null
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _http_server != null:
		if _http_server.has_method("stop"):
			_http_server.stop()
		if _http_server.has_method("dispose"):
			_http_server.dispose()
		_http_server.free()
	_http_server = null
	if _stdio_server != null:
		if _stdio_server.has_method("stop"):
			_stdio_server.stop()
		_stdio_server.free()
	_stdio_server = null
	if _tool_loader != null and _tool_loader.has_method("shutdown"):
		_tool_loader.shutdown()
	_tool_loader = null
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {
		"name": "lsp_service_access_contracts",
		"success": false,
		"error": message
	}
