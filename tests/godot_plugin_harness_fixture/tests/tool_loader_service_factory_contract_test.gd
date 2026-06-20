extends RefCounted

# {"name": "tool_loader_service_factory_contracts"}

const ToolLoaderServiceFactoryScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_service_factory.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _verify_tool_loader_delegates_service_construction()
	if not source_guard.is_empty():
		return _failure(source_guard)

	var factory = ToolLoaderServiceFactoryScript.new()
	var existing_state_store := RefCounted.new()
	var existing_runtime_manager := RefCounted.new()
	var services: Dictionary = factory.ensure_services({
		"state_store": existing_state_store,
		"runtime_manager": existing_runtime_manager
	})
	if services.get("state_store", null) != existing_state_store:
		return _failure("ToolLoaderServiceFactory should preserve an existing state store instance.")
	if services.get("runtime_manager", null) != existing_runtime_manager:
		return _failure("ToolLoaderServiceFactory should preserve an existing runtime manager instance.")
	for required_key in [
		"registry",
		"public_surface_policy",
		"execution_observer",
		"status_service",
		"diagnostics_service",
		"entry_service",
		"runtime_context_service",
		"catalog_projection_service",
		"execution_service",
		"tick_service",
		"enablement_service",
		"reload_service",
		"user_reload_service",
		"runtime_state_service",
		"lifecycle_service",
		"access_service",
		"lsp_diagnostics_service",
		"execution_context_service",
		"context_service",
		"query_service",
		"lifecycle_tick_budget_service"
	]:
		if services.get(required_key, null) == null:
			return _failure("ToolLoaderServiceFactory should create missing loader service: %s" % required_key)

	var second_services: Dictionary = factory.ensure_services(services)
	for key in services.keys():
		if second_services.get(key, null) != services.get(key, null):
			return _failure("ToolLoaderServiceFactory should be idempotent for service key: %s" % str(key))

	return {"name": "tool_loader_service_factory_contracts", "success": true, "error": ""}


func _verify_tool_loader_delegates_service_construction() -> String:
	var loader_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
	var factory_source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/core/tool_loader_service_factory.gd")
	if loader_source.is_empty() or factory_source.is_empty():
		return "Tool loader and service factory sources should be readable."
	for required in [
		"ToolLoaderServiceFactoryScript",
		"_service_factory.ensure_services(_build_service_factory_context())",
		"func _build_service_factory_context()"
	]:
		if loader_source.find(required) == -1:
			return "MCPToolLoader should delegate service construction through the factory: %s" % required
	for forbidden in [
		"const ToolPublicSurfacePolicyScript = preload(",
		"const ToolExecutionObserverScript = preload(",
		"const ToolRuntimeManagerScript = preload(",
		"const ToolLoaderStatusServiceScript = preload(",
		"const ToolLoaderLifecycleServiceScript = preload(",
		"const ToolLoaderStateStoreScript = preload(",
		"ToolLoaderStateStoreScript.new()",
		"ToolLoaderLifecycleTickBudgetServiceScript.new()"
	]:
		if loader_source.find(forbidden) != -1:
			return "MCPToolLoader should not retain service construction internals: %s" % forbidden
	for required_factory in [
		"func ensure_services(current: Dictionary)",
		"const ToolLoaderStateStoreScript",
		"const ToolLoaderLifecycleTickBudgetServiceScript",
		"func _ensure(current: Dictionary"
	]:
		if factory_source.find(required_factory) == -1:
			return "ToolLoaderServiceFactory should own service construction member: %s" % required_factory
	return ""


func _failure(message: String) -> Dictionary:
	return {"name": "tool_loader_service_factory_contracts", "success": false, "error": message}
