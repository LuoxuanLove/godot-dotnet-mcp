@tool
extends RefCounted
class_name MCPToolLoader

const MCPToolDiagnosticService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_diagnostic_service.gd")
const MCPToolExposureService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_exposure_service.gd")
const MCPToolMetricsService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_metrics_service.gd")
const MCPToolRuntimeService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_runtime_service.gd")
const MCPToolReloadService = preload("res://addons/godot_dotnet_mcp/tools/core/tool_reload_service.gd")
const MCPToolRegistryStore = preload("res://addons/godot_dotnet_mcp/tools/core/tool_registry_store.gd")
const MCPToolLspDiagnosticsAdapter = preload("res://addons/godot_dotnet_mcp/tools/core/tool_lsp_diagnostics_adapter.gd")
const MCPToolExecutionGateway = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_gateway.gd")
const MCPToolBootstrapCoordinator = preload("res://addons/godot_dotnet_mcp/tools/core/tool_bootstrap_coordinator.gd")
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

var _diagnostic_service: MCPToolDiagnosticService = MCPToolDiagnosticService.new()
var _exposure_service: MCPToolExposureService = MCPToolExposureService.new()
var _metrics_service: MCPToolMetricsService = MCPToolMetricsService.new()
var _runtime_service: MCPToolRuntimeService = MCPToolRuntimeService.new()
var _reload_service: MCPToolReloadService = MCPToolReloadService.new()
var _store: MCPToolRegistryStore = MCPToolRegistryStore.new()
var _lsp_adapter: MCPToolLspDiagnosticsAdapter = MCPToolLspDiagnosticsAdapter.new()
var _execution_gateway: MCPToolExecutionGateway = MCPToolExecutionGateway.new()
var _bootstrap: Object = MCPToolBootstrapCoordinator.new()


func configure(server_context: Object) -> void:
	_bootstrap.call(
		"configure",
		self,
		_store,
		_diagnostic_service,
		_exposure_service,
		_metrics_service,
		_runtime_service,
		_reload_service,
		_execution_gateway,
		_lsp_adapter
	)
	_bootstrap.call("configure_services", server_context)


func initialize(disabled_tools: Array = [], force_reload_scripts: bool = false) -> Dictionary:
	return _bootstrap.call("initialize", disabled_tools, force_reload_scripts)


func reload_registry(disabled_tools: Array = []) -> Dictionary:
	return initialize(disabled_tools)


func set_disabled_tools(disabled_tools: Array) -> void:
	_bootstrap.call("set_disabled_tools", disabled_tools)


func get_tools_by_category() -> Dictionary:
	var visible := _exposure_service.build_tools_by_category(_store.get_ordered_categories(), true)
	if visible.is_empty() and not _store.get_entries_copy().is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible tools by category resolved to empty; returning fail-closed visible set")
	return visible


func get_all_tools_by_category() -> Dictionary:
	return _exposure_service.build_tools_by_category(_store.get_ordered_categories(), false)


func get_tool_definitions() -> Array[Dictionary]:
	var visible := _exposure_service.build_tool_definitions(_store.get_ordered_categories(), true)
	if visible.is_empty() and not _store.get_entries_copy().is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible tool definitions resolved to empty; returning fail-closed visible set")
	return visible


func get_all_tool_definitions() -> Array[Dictionary]:
	return _exposure_service.build_tool_definitions(_store.get_ordered_categories(), false)


func get_exposed_tool_definitions() -> Array[Dictionary]:
	return _exposure_service.build_exposed_tool_definitions(_store.get_ordered_categories(), true)


func is_tool_exposed(tool_name: String) -> bool:
	return _exposure_service.is_tool_exposed(tool_name, _store.get_ordered_categories(), true)


func get_tool_load_errors() -> Array[Dictionary]:
	return _diagnostic_service.get_tool_load_errors()


func get_domain_states() -> Array[Dictionary]:
	var visible := _exposure_service.build_domain_states(_store.get_ordered_categories(), true)
	if visible.is_empty() and not _store.get_entries_copy().is_empty():
		MCPDebugBuffer.record("warning", "tool_loader",
			"Visible domain states resolved to empty; returning fail-closed visible set")
	return visible


func get_all_domain_states() -> Array[Dictionary]:
	return _exposure_service.build_domain_states(_store.get_ordered_categories(), false)


func get_reload_status() -> Dictionary:
	return _store.get_reload_status()


func get_tool_loader_status() -> Dictionary:
	return _exposure_service.build_tool_loader_status(_store.get_ordered_categories(), _diagnostic_service.get_tool_load_error_count())


func get_performance_summary() -> Dictionary:
	return _metrics_service.build_performance_summary()


func get_tool_usage_stats() -> Array[Dictionary]:
	return _metrics_service.build_tool_usage_stats()


func shutdown() -> void:
	_bootstrap.call("shutdown")


func execute_tool(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	return await execute_tool_async(category, tool_name, args)


func execute_tool_async(category: String, tool_name: String, args: Dictionary) -> Dictionary:
	return await _execution_gateway.execute_tool_async(category, tool_name, args)


func tick(delta: float) -> void:
	_execution_gateway.tick(delta)


func get_gdscript_lsp_diagnostics_service():
	return _lsp_adapter.get_service()


func get_lsp_diagnostics_debug_snapshot() -> Dictionary:
	return _lsp_adapter.get_debug_snapshot(get_tool_loader_status())


func reload_domain(category: String) -> Dictionary:
	return _bootstrap.call("reload_domain", category)


func reload_all_domains() -> Dictionary:
	return _bootstrap.call("reload_all_domains")


func request_reload_by_script(script_path: String, reason: String = "manual") -> Dictionary:
	return _execution_gateway.request_reload_by_script(script_path, reason)


func get_user_tool_runtime_snapshot() -> Array[Dictionary]:
	return _execution_gateway.get_user_tool_runtime_snapshot()


func get_disabled_tools() -> Array:
	return _store.get_disabled_tools()


func is_tool_enabled(tool_name: String) -> bool:
	return _store.is_tool_enabled(tool_name)
