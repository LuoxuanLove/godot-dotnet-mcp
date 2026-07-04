@tool
extends RefCounted

const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")
const ToolPublicSurfacePolicyScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_public_surface_policy.gd")
const ToolExecutionObserverScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_observer.gd")
const ToolRuntimeManagerScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_runtime_manager.gd")
const ToolLoaderStatusServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_status_service.gd")
const ToolLoaderDiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_diagnostics_service.gd")
const ToolRegistryEntryServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_registry_entry_service.gd")
const ToolLoaderRuntimeContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_runtime_context_service.gd")
const ToolLoaderCatalogProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_catalog_projection_service.gd")
const ToolExecutionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_execution_service.gd")
const ToolLoaderTickServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_tick_service.gd")
const ToolLoaderEnablementServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_enablement_service.gd")
const ToolLoaderReloadServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_reload_service.gd")
const ToolLoaderUserReloadServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_user_reload_service.gd")
const ToolLoaderRuntimeStateServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_runtime_state_service.gd")
const ToolLoaderLifecycleServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lifecycle_service.gd")
const ToolLoaderStateStoreScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_state_store.gd")
const ToolLoaderAccessServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_access_service.gd")
const ToolLoaderLspDiagnosticsServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lsp_diagnostics_service.gd")
const ToolLoaderExecutionContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_execution_context_service.gd")
const ToolLoaderContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_context_service.gd")
const ToolLoaderQueryServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_query_service.gd")
const ToolLoaderLifecycleTickBudgetServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lifecycle_tick_budget_service.gd")


func ensure_services(current: Dictionary) -> Dictionary:
	return {
		"registry": _ensure(current, "registry", ToolCatalogManifest),
		"state_store": _ensure(current, "state_store", ToolLoaderStateStoreScript),
		"public_surface_policy": _ensure(current, "public_surface_policy", ToolPublicSurfacePolicyScript),
		"execution_observer": _ensure(current, "execution_observer", ToolExecutionObserverScript),
		"runtime_manager": _ensure(current, "runtime_manager", ToolRuntimeManagerScript),
		"status_service": _ensure(current, "status_service", ToolLoaderStatusServiceScript),
		"diagnostics_service": _ensure(current, "diagnostics_service", ToolLoaderDiagnosticsServiceScript),
		"entry_service": _ensure(current, "entry_service", ToolRegistryEntryServiceScript),
		"runtime_context_service": _ensure(current, "runtime_context_service", ToolLoaderRuntimeContextServiceScript),
		"catalog_projection_service": _ensure(current, "catalog_projection_service", ToolLoaderCatalogProjectionServiceScript),
		"execution_service": _ensure(current, "execution_service", ToolExecutionServiceScript),
		"tick_service": _ensure(current, "tick_service", ToolLoaderTickServiceScript),
		"enablement_service": _ensure(current, "enablement_service", ToolLoaderEnablementServiceScript),
		"reload_service": _ensure(current, "reload_service", ToolLoaderReloadServiceScript),
		"user_reload_service": _ensure(current, "user_reload_service", ToolLoaderUserReloadServiceScript),
		"runtime_state_service": _ensure(current, "runtime_state_service", ToolLoaderRuntimeStateServiceScript),
		"lifecycle_service": _ensure(current, "lifecycle_service", ToolLoaderLifecycleServiceScript),
		"access_service": _ensure(current, "access_service", ToolLoaderAccessServiceScript),
		"lsp_diagnostics_service": _ensure(current, "lsp_diagnostics_service", ToolLoaderLspDiagnosticsServiceScript),
		"execution_context_service": _ensure(current, "execution_context_service", ToolLoaderExecutionContextServiceScript),
		"context_service": _ensure(current, "context_service", ToolLoaderContextServiceScript),
		"query_service": _ensure(current, "query_service", ToolLoaderQueryServiceScript),
		"lifecycle_tick_budget_service": _ensure(current, "lifecycle_tick_budget_service", ToolLoaderLifecycleTickBudgetServiceScript)
	}


func _ensure(current: Dictionary, key: String, script: GDScript):
	var existing = current.get(key, null)
	if existing != null:
		return existing
	return script.new()
