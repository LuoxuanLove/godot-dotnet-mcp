extends SceneTree

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const HttpServerContractTest = "res://tests/http_server_contract_test.gd"
const HttpRequestRouterContractTest = "res://tests/http_request_router_contract_test.gd"
const HttpRequestDecoderContractTest = "res://tests/http_request_decoder_contract_test.gd"
const HttpResponseServiceContractTest = "res://tests/http_response_service_contract_test.gd"
const JsonRpcRouterContractTest = "res://tests/json_rpc_router_contract_test.gd"
const EditorLifecycleActionServiceContractTest = "res://tests/editor_lifecycle_action_service_contract_test.gd"
const RuntimeControlContractTest = "res://tests/runtime_control_contract_test.gd"
const RuntimeControlRequestCoordinatorContractTest = "res://tests/runtime_control_request_coordinator_contract_test.gd"
const RuntimeControlReplyResolverContractTest = "res://tests/runtime_control_reply_resolver_contract_test.gd"
const RuntimeBridgeContractTest = "res://tests/runtime_bridge_contract_test.gd"
const RuntimeFallbackStoreContractTest = "res://tests/runtime_fallback_store_contract_test.gd"
const RuntimeReplyServiceContractTest = "res://tests/runtime_reply_service_contract_test.gd"
const UserToolWatchServiceContractTest = "res://tests/user_tool_watch_service_contract_test.gd"
const ScriptToolExecutorContractTest = "res://tests/script_tool_executor_contract_test.gd"
const ScriptEditServiceContractTest = "res://tests/script_edit_service_contract_test.gd"
const NodeToolExecutorContractTest = "res://tests/node_tool_executor_contract_test.gd"
const AnimationToolExecutorContractTest = "res://tests/animation_tool_executor_contract_test.gd"
const PhysicsToolExecutorContractTest = "res://tests/physics_tool_executor_contract_test.gd"
const SceneToolExecutorContractTest = "res://tests/scene_tool_executor_contract_test.gd"
const DebugToolExecutorContractTest = "res://tests/debug_tool_executor_contract_test.gd"
const EditorToolExecutorContractTest = "res://tests/editor_tool_executor_contract_test.gd"
const LightingToolExecutorContractTest = "res://tests/lighting_tool_executor_contract_test.gd"
const GeometryToolExecutorContractTest = "res://tests/geometry_tool_executor_contract_test.gd"
const FilesystemToolExecutorContractTest = "res://tests/filesystem_tool_executor_contract_test.gd"
const ProjectToolExecutorContractTest = "res://tests/project_tool_executor_contract_test.gd"
const MaterialToolExecutorContractTest = "res://tests/material_tool_executor_contract_test.gd"
const UIToolExecutorContractTest = "res://tests/ui_tool_executor_contract_test.gd"
const ParticleToolExecutorContractTest = "res://tests/particle_tool_executor_contract_test.gd"
const ResourceToolExecutorContractTest = "res://tests/resource_tool_executor_contract_test.gd"
const ShaderToolExecutorContractTest = "res://tests/shader_tool_executor_contract_test.gd"
const TilemapToolExecutorContractTest = "res://tests/tilemap_tool_executor_contract_test.gd"
const SignalToolExecutorContractTest = "res://tests/signal_tool_executor_contract_test.gd"
const GroupToolExecutorContractTest = "res://tests/group_tool_executor_contract_test.gd"
const AudioToolExecutorContractTest = "res://tests/audio_tool_executor_contract_test.gd"
const NavigationToolExecutorContractTest = "res://tests/navigation_tool_executor_contract_test.gd"
const PluginBootstrapContractTest = "res://tests/plugin_bootstrap_contract_test.gd"
const PluginDockCoordinatorContractTest = "res://tests/plugin_dock_coordinator_contract_test.gd"
const PluginRuntimeCoordinatorContractTest = "res://tests/plugin_runtime_coordinator_contract_test.gd"
const ClientConfigSerializerContractTest = "res://tests/client_config_serializer_contract_test.gd"
const ClientConfigInspectionServiceContractTest = "res://tests/client_config_inspection_service_contract_test.gd"
const ClientConfigFileTransactionContractTest = "res://tests/client_config_file_transaction_contract_test.gd"
const ClientConfigLauncherAdapterContractTest = "res://tests/client_config_launcher_adapter_contract_test.gd"
const EditorLifecycleStateBuilderContractTest = "res://tests/editor_lifecycle_state_builder_contract_test.gd"
const SystemProjectExecutorContractTest = "res://tests/system_project_executor_contract_test.gd"
const SystemScriptExecutorContractTest = "res://tests/system_script_executor_contract_test.gd"
const ToolLspDiagnosticsAdapterContractTest = "res://tests/tool_lsp_diagnostics_adapter_contract_test.gd"
const GDScriptLspDiagnosticsServiceContractTest = "res://tests/gdscript_lsp_diagnostics_service_contract_test.gd"
const LspClientContractTest = "res://tests/lsp_client_contract_test.gd"
const LspServiceAccessContractTest = "res://tests/lsp_service_access_contract_test.gd"
const SystemIndexImplContractTest = "res://tests/system_index_impl_contract_test.gd"
const SystemRuntimeImplContractTest = "res://tests/system_runtime_impl_contract_test.gd"
const ToolLoaderContractTest = "res://tests/tool_loader_contract_test.gd"
const ToolsTabInteractionSupportContractTest = "res://tests/tools_tab_interaction_support_contract_test.gd"
const ToolsTabSearchServiceContractTest = "res://tests/tools_tab_search_service_contract_test.gd"
const ToolsTabPreviewBuilderContractTest = "res://tests/tools_tab_preview_builder_contract_test.gd"


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	var results: Array[Dictionary] = []
	var success := true
	var cases := [
		{
			"name": "runtime_bridge_invalid_action_fallback",
			"script": RuntimeBridgeContractTest
		},
		{
			"name": "runtime_control_contracts",
			"script": RuntimeControlContractTest
		},
		{
			"name": "runtime_control_request_coordinator_contracts",
			"script": RuntimeControlRequestCoordinatorContractTest
		},
		{
			"name": "runtime_control_reply_resolver_contracts",
			"script": RuntimeControlReplyResolverContractTest
		},
		{
			"name": "runtime_fallback_store_contracts",
			"script": RuntimeFallbackStoreContractTest
		},
		{
			"name": "runtime_reply_service_contracts",
			"script": RuntimeReplyServiceContractTest
		},
		{
			"name": "user_tool_watch_service_contracts",
			"script": UserToolWatchServiceContractTest
		},
		{
			"name": "script_tool_executor_contracts",
			"script": ScriptToolExecutorContractTest
		},
		{
			"name": "script_edit_service_contracts",
			"script": ScriptEditServiceContractTest
		},
		{
			"name": "node_tool_executor_contracts",
			"script": NodeToolExecutorContractTest
		},
		{
			"name": "animation_tool_executor_contracts",
			"script": AnimationToolExecutorContractTest
		},
		{
			"name": "physics_tool_executor_contracts",
			"script": PhysicsToolExecutorContractTest
		},
		{
			"name": "scene_tool_executor_contracts",
			"script": SceneToolExecutorContractTest
		},
		{
			"name": "debug_tool_executor_contracts",
			"script": DebugToolExecutorContractTest
		},
		{
			"name": "editor_tool_executor_contracts",
			"script": EditorToolExecutorContractTest
		},
		{
			"name": "lighting_tool_executor_contracts",
			"script": LightingToolExecutorContractTest
		},
		{
			"name": "geometry_tool_executor_contracts",
			"script": GeometryToolExecutorContractTest
		},
		{
			"name": "filesystem_tool_executor_contracts",
			"script": FilesystemToolExecutorContractTest
		},
		{
			"name": "project_tool_executor_contracts",
			"script": ProjectToolExecutorContractTest
		},
		{
			"name": "material_tool_executor_contracts",
			"script": MaterialToolExecutorContractTest
		},
		{
			"name": "ui_tool_executor_contracts",
			"script": UIToolExecutorContractTest
		},
		{
			"name": "particle_tool_executor_contracts",
			"script": ParticleToolExecutorContractTest
		},
		{
			"name": "resource_tool_executor_contracts",
			"script": ResourceToolExecutorContractTest
		},
		{
			"name": "shader_tool_executor_contracts",
			"script": ShaderToolExecutorContractTest
		},
		{
			"name": "tilemap_tool_executor_contracts",
			"script": TilemapToolExecutorContractTest
		},
		{
			"name": "signal_tool_executor_contracts",
			"script": SignalToolExecutorContractTest
		},
		{
			"name": "group_tool_executor_contracts",
			"script": GroupToolExecutorContractTest
		},
		{
			"name": "audio_tool_executor_contracts",
			"script": AudioToolExecutorContractTest
		},
		{
			"name": "navigation_tool_executor_contracts",
			"script": NavigationToolExecutorContractTest
		},
		{
			"name": "plugin_bootstrap_contracts",
			"script": PluginBootstrapContractTest
		},
		{
			"name": "plugin_dock_coordinator_contracts",
			"script": PluginDockCoordinatorContractTest
		},
		{
			"name": "plugin_runtime_coordinator_contracts",
			"script": PluginRuntimeCoordinatorContractTest
		},
		{
			"name": "client_config_serializer_contracts",
			"script": ClientConfigSerializerContractTest
		},
		{
			"name": "client_config_inspection_service_contracts",
			"script": ClientConfigInspectionServiceContractTest
		},
		{
			"name": "client_config_file_transaction_contracts",
			"script": ClientConfigFileTransactionContractTest
		},
		{
			"name": "client_config_launcher_adapter_contracts",
			"script": ClientConfigLauncherAdapterContractTest
		},
		{
			"name": "http_server_contracts",
			"script": HttpServerContractTest
		},
		{
			"name": "http_request_router_contracts",
			"script": HttpRequestRouterContractTest
		},
		{
			"name": "http_request_decoder_contracts",
			"script": HttpRequestDecoderContractTest
		},
		{
			"name": "http_response_service_contracts",
			"script": HttpResponseServiceContractTest
		},
		{
			"name": "json_rpc_router_contracts",
			"script": JsonRpcRouterContractTest
		},
		{
			"name": "editor_lifecycle_action_service_contracts",
			"script": EditorLifecycleActionServiceContractTest
		},
		{
			"name": "editor_lifecycle_state_builder_contracts",
			"script": EditorLifecycleStateBuilderContractTest
		},
		{
			"name": "system_project_executor_contracts",
			"script": SystemProjectExecutorContractTest
		},
		{
			"name": "system_script_executor_contracts",
			"script": SystemScriptExecutorContractTest
		},
		{
			"name": "tool_lsp_diagnostics_adapter_contracts",
			"script": ToolLspDiagnosticsAdapterContractTest
		},
		{
			"name": "gdscript_lsp_diagnostics_service_contracts",
			"script": GDScriptLspDiagnosticsServiceContractTest
		},
		{
			"name": "lsp_client_contracts",
			"script": LspClientContractTest
		},
		{
			"name": "lsp_service_access_contracts",
			"script": LspServiceAccessContractTest
		},
		{
			"name": "system_runtime_impl_contracts",
			"script": SystemRuntimeImplContractTest
		},
		{
			"name": "system_index_impl_contracts",
			"script": SystemIndexImplContractTest
		},
		{
			"name": "tool_loader_contracts",
			"script": ToolLoaderContractTest
		},
		{
			"name": "tools_tab_interaction_support_contracts",
			"script": ToolsTabInteractionSupportContractTest
		},
		{
			"name": "tools_tab_search_service_contracts",
			"script": ToolsTabSearchServiceContractTest
		},
		{
			"name": "tools_tab_preview_builder_contracts",
			"script": ToolsTabPreviewBuilderContractTest
		}
	]
	var only_case := OS.get_environment("GODOT_PLUGIN_HARNESS_ONLY_CASE").strip_edges()
	for case_info in cases:
		if only_case != "" and str(case_info.get("name", "")) != only_case:
			continue
		var case_script_path := str(case_info.get("script", ""))
		if case_script_path.is_empty():
			continue
		var case_name := str(case_info.get("name", "unknown_case"))
		var case_script = load(case_script_path)
		if case_script == null:
			results.append({
				"name": case_name,
				"success": false,
				"error": "Failed to load test script: %s" % case_script_path
			})
			success = false
			continue
		var case_instance = case_script.new()
		print("HARNESS_CASE_START:%s" % case_name)
		var result: Dictionary = await case_instance.run_case(self)
		if case_instance.has_method("cleanup_case"):
			await case_instance.cleanup_case(self)
		case_instance = null
		await process_frame
		await process_frame
		results.append(result)
		if not bool(result.get("success", false)):
			success = false
		print("HARNESS_CASE_DONE:%s:%s" % [case_name, str(bool(result.get("success", false)))])

	await _suite_final_cleanup()
	print(JSON.stringify({
		"success": success,
		"results": results
	}))
	quit(0 if success else 1)


func _suite_final_cleanup() -> void:
	MCPDebugBuffer.clear()
	await process_frame
	await process_frame
