extends SceneTree

const HttpServerContractTest = preload("res://tests/http_server_contract_test.gd")
const RuntimeControlContractTest = preload("res://tests/runtime_control_contract_test.gd")
const RuntimeBridgeContractTest = preload("res://tests/runtime_bridge_contract_test.gd")
const SystemIndexImplContractTest = preload("res://tests/system_index_impl_contract_test.gd")
const SystemRuntimeImplContractTest = preload("res://tests/system_runtime_impl_contract_test.gd")
const ToolLoaderContractTest = preload("res://tests/tool_loader_contract_test.gd")


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	var results: Array[Dictionary] = []
	var success := true
	var cases := [
		{
			"name": "runtime_bridge_invalid_action_fallback",
			"instance": RuntimeBridgeContractTest.new()
		},
		{
			"name": "runtime_control_contracts",
			"instance": RuntimeControlContractTest.new()
		},
		{
			"name": "http_server_contracts",
			"instance": HttpServerContractTest.new()
		},
		{
			"name": "system_runtime_impl_contracts",
			"instance": SystemRuntimeImplContractTest.new()
		},
		{
			"name": "system_index_impl_contracts",
			"instance": SystemIndexImplContractTest.new()
		},
		{
			"name": "tool_loader_contracts",
			"instance": ToolLoaderContractTest.new()
		}
	]
	var only_case := OS.get_environment("GODOT_PLUGIN_HARNESS_ONLY_CASE").strip_edges()
	for case_info in cases:
		if only_case != "" and str(case_info.get("name", "")) != only_case:
			continue
		var case_instance = case_info.get("instance", null)
		if case_instance == null:
			continue
		var case_name := str(case_info.get("name", "unknown_case"))
		print("HARNESS_CASE_START:%s" % case_name)
		var result: Dictionary = await case_instance.run_case(self)
		results.append(result)
		if not bool(result.get("success", false)):
			success = false
		print("HARNESS_CASE_DONE:%s:%s" % [case_name, str(bool(result.get("success", false)))])

	print(JSON.stringify({
		"success": success,
		"results": results
	}))
	quit(0 if success else 1)
