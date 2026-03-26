extends SceneTree

const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const HttpServerContractTest = preload("res://tests/http_server_contract_test.gd")
const HttpRequestRouterContractTest = preload("res://tests/http_request_router_contract_test.gd")
const HttpResponseServiceContractTest = preload("res://tests/http_response_service_contract_test.gd")
const JsonRpcRouterContractTest = preload("res://tests/json_rpc_router_contract_test.gd")
const EditorLifecycleActionServiceContractTest = preload("res://tests/editor_lifecycle_action_service_contract_test.gd")
const RuntimeControlContractTest = preload("res://tests/runtime_control_contract_test.gd")
const RuntimeControlRequestCoordinatorContractTest = preload("res://tests/runtime_control_request_coordinator_contract_test.gd")
const RuntimeControlReplyResolverContractTest = preload("res://tests/runtime_control_reply_resolver_contract_test.gd")
const RuntimeBridgeContractTest = preload("res://tests/runtime_bridge_contract_test.gd")
const RuntimeFallbackStoreContractTest = preload("res://tests/runtime_fallback_store_contract_test.gd")
const RuntimeReplyServiceContractTest = preload("res://tests/runtime_reply_service_contract_test.gd")
const ClientConfigSerializerContractTest = preload("res://tests/client_config_serializer_contract_test.gd")
const ClientConfigInspectionServiceContractTest = preload("res://tests/client_config_inspection_service_contract_test.gd")
const ClientConfigFileTransactionContractTest = preload("res://tests/client_config_file_transaction_contract_test.gd")
const ClientConfigLauncherAdapterContractTest = preload("res://tests/client_config_launcher_adapter_contract_test.gd")
const EditorLifecycleStateBuilderContractTest = preload("res://tests/editor_lifecycle_state_builder_contract_test.gd")
const SystemIndexImplContractTest = preload("res://tests/system_index_impl_contract_test.gd")
const SystemRuntimeImplContractTest = preload("res://tests/system_runtime_impl_contract_test.gd")
const ToolLoaderContractTest = preload("res://tests/tool_loader_contract_test.gd")
const ToolsTabInteractionSupportContractTest = preload("res://tests/tools_tab_interaction_support_contract_test.gd")
const ToolsTabSearchServiceContractTest = preload("res://tests/tools_tab_search_service_contract_test.gd")
const ToolsTabPreviewBuilderContractTest = preload("res://tests/tools_tab_preview_builder_contract_test.gd")


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
		var case_script = case_info.get("script", null)
		if case_script == null:
			continue
		var case_name := str(case_info.get("name", "unknown_case"))
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
