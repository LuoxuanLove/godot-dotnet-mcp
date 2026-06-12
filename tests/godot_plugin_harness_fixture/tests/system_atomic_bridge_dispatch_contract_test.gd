extends RefCounted

# {"name": "system_atomic_bridge_dispatch_contracts"}

const AtomicBridgeDispatchServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_dispatch_service.gd")
const AtomicBridgeExecutionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_execution_service.gd")
const AtomicBridgeHelperServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_helper_service.gd")
const AtomicBridgeSupportScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_support.gd")
const AtomicBridgeScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge.gd")


class FakeRuntime:
	extends RefCounted

	var categories := {"sync": true, "async": true, "script": true, "filesystem": true}
	var dispatch_calls: Array[Dictionary] = []
	var async_calls: Array[Dictionary] = []
	var invalidate_count := 0
	var next_success := true
	var next_data_by_tool := {}

	func has_category(category: String) -> bool:
		return categories.has(category)

	func dispatch(category: String, tool_name: String, args: Dictionary) -> Dictionary:
		dispatch_calls.append({"category": category, "tool_name": tool_name, "args": args.duplicate(true)})
		var data: Dictionary = next_data_by_tool.get(tool_name, {})
		if data.is_empty():
			data = {"category": category, "tool_name": tool_name}
		return {"success": next_success, "data": data.duplicate(true)}

	func call_atomic_for_helper(full_name: String, args: Dictionary) -> Dictionary:
		var parts := full_name.split("_", true, 1)
		if parts.size() != 2:
			return {"success": false, "error": "Invalid atomic tool name: %s" % full_name}
		return dispatch(str(parts[0]), str(parts[1]), args)

	func dispatch_async(category: String, tool_name: String, args: Dictionary) -> Dictionary:
		async_calls.append({"category": category, "tool_name": tool_name, "args": args.duplicate(true)})
		await Engine.get_main_loop().process_frame
		return {"success": next_success, "data": {"category": category, "tool_name": tool_name, "mode": "async"}}

	func invalidate() -> void:
		invalidate_count += 1


func run_case(_tree: SceneTree) -> Dictionary:
	var service = AtomicBridgeDispatchServiceScript.new()
	var support = AtomicBridgeSupportScript.new()
	var runtime = FakeRuntime.new()

	var sync_result: Dictionary = service.call_atomic("sync_probe", {"action": "get"}, support, runtime)
	if not bool(sync_result.get("success", false)):
		return _failure("Atomic bridge dispatch service should route sync calls.", sync_result)
	if runtime.dispatch_calls.size() != 1:
		return _failure("Atomic bridge dispatch service should call runtime.dispatch exactly once for sync calls.")
	var sync_call: Dictionary = runtime.dispatch_calls[0]
	if str(sync_call.get("category", "")) != "sync" or str(sync_call.get("tool_name", "")) != "probe":
		return _failure("Atomic bridge dispatch service should split category and tool name before sync dispatch.")

	var async_result: Dictionary = await service.call_atomic_async("async_probe", {"action": "get"}, support, runtime)
	if not bool(async_result.get("success", false)) or str(async_result.get("data", {}).get("mode", "")) != "async":
		return _failure("Atomic bridge dispatch service should route async calls.", async_result)
	if runtime.async_calls.size() != 1:
		return _failure("Atomic bridge dispatch service should call runtime.dispatch_async exactly once for async calls.")

	var invalid_name_result: Dictionary = service.call_atomic("invalid", {}, support, runtime)
	if bool(invalid_name_result.get("success", true)) or str(invalid_name_result.get("error", "")) != "Invalid atomic tool name: invalid":
		return _failure("Atomic bridge dispatch service should keep stable invalid-name errors.")

	var unknown_result: Dictionary = service.call_atomic("ghost_probe", {}, support, runtime)
	if bool(unknown_result.get("success", true)) or str(unknown_result.get("error", "")) != "Unknown atomic category: ghost (from ghost_probe)":
		return _failure("Atomic bridge dispatch service should keep stable unknown-category errors.")

	var protected_result: Dictionary = service.call_atomic("script_edit_gd", {
		"path": "res://addons/godot_dotnet_mcp/plugin/plugin.gd"
	}, support, runtime)
	if bool(protected_result.get("success", true)) or not str(protected_result.get("error", "")).begins_with("Protected path:"):
		return _failure("Atomic bridge dispatch service should reject protected plugin writes.")
	if runtime.dispatch_calls.size() != 1:
		return _failure("Protected plugin writes should not reach runtime.dispatch.")

	var allowed_write_result: Dictionary = service.call_atomic("script_edit_gd", {
		"path": "res://addons/godot_dotnet_mcp/plugin/plugin.gd",
		"allow_plugin_write": true
	}, support, runtime)
	if not bool(allowed_write_result.get("success", false)):
		return _failure("Atomic bridge dispatch service should allow explicitly authorized plugin writes.", allowed_write_result)
	if runtime.invalidate_count != 1:
		return _failure("Successful write atomic calls should invalidate cached atomic executors.")

	runtime.next_success = false
	var failed_write_result: Dictionary = service.call_atomic("script_edit_gd", {
		"path": "res://game/Player.gd"
	}, support, runtime)
	if bool(failed_write_result.get("success", true)):
		return _failure("Atomic bridge dispatch service should preserve failed runtime write results.")
	if runtime.invalidate_count != 1:
		return _failure("Failed write atomic calls should not invalidate cached atomic executors.")

	var execution_service_result := await _verify_execution_service_facade()
	if not bool(execution_service_result.get("success", false)):
		return execution_service_result
	var bridge_facade_result := _verify_atomic_bridge_facade_is_thin()
	if not bool(bridge_facade_result.get("success", false)):
		return bridge_facade_result

	return {"name": "system_atomic_bridge_dispatch_contracts", "success": true, "error": ""}


func _verify_execution_service_facade() -> Dictionary:
	var service = AtomicBridgeExecutionServiceScript.new()
	var runtime = FakeRuntime.new()
	service._runtime = runtime

	var sync_result: Dictionary = service.call_atomic("sync_probe", {"action": "get"})
	if not bool(sync_result.get("success", false)):
		return _failure("Atomic bridge execution service should route sync calls.", sync_result)
	if runtime.dispatch_calls.size() != 1:
		return _failure("Atomic bridge execution service should call its runtime for sync calls.")

	var async_result: Dictionary = await service.call_atomic_async("async_probe", {"action": "get"})
	if not bool(async_result.get("success", false)) or str(async_result.get("data", {}).get("mode", "")) != "async":
		return _failure("Atomic bridge execution service should route async calls.", async_result)
	if runtime.async_calls.size() != 1:
		return _failure("Atomic bridge execution service should call its runtime for async calls.")

	if not service.is_write_atomic_action("script_edit_gd", {}):
		return _failure("Atomic bridge execution service should expose write-action helpers for the facade.")
	var execution_source_guard := _verify_execution_service_source_guard()
	if not bool(execution_source_guard.get("success", false)):
		return execution_source_guard
	var helper_result := _verify_helper_service_collection_helpers(runtime)
	if not bool(helper_result.get("success", false)):
		return helper_result
	return {"success": true}


func _verify_helper_service_collection_helpers(runtime: FakeRuntime) -> Dictionary:
	var service = AtomicBridgeHelperServiceScript.new()
	runtime.next_success = true
	runtime.dispatch_calls.clear()
	runtime.next_data_by_tool = {
		"directory": {
			"files": ["res://A.gd"],
			"count": 7,
			"counts_by_filter": {"*.gd": 2, "*.cs": 5}
		}
	}
	var caller := Callable(runtime, "call_atomic_for_helper")
	var files: Array = service.collect_files("*.gd", caller)
	if files != ["res://A.gd"]:
		return _failure("Atomic bridge helper service should collect file lists through filesystem_directory.", {"files": files})
	var file_count: int = service.collect_file_count("*.gd", caller)
	if file_count != 7:
		return _failure("Atomic bridge helper service should collect file counts through filesystem_directory.", {"count": file_count})
	var counts: Dictionary = service.collect_file_counts(["*.gd", "*.cs"], caller)
	if int(counts.get("*.gd", 0)) != 2 or int(counts.get("*.cs", 0)) != 5:
		return _failure("Atomic bridge helper service should collect batched counts through filesystem_directory.", counts)
	counts["*.gd"] = 99
	if int(service.collect_file_counts(["*.gd"], caller).get("*.gd", 0)) != 2:
		return _failure("Atomic bridge helper service should return a copy of batched count dictionaries.")
	if runtime.dispatch_calls.size() != 4:
		return _failure("Atomic bridge helper service collection helpers should dispatch once per call.")
	var list_call: Dictionary = runtime.dispatch_calls[0]
	if str(list_call.get("category", "")) != "filesystem" or str(list_call.get("tool_name", "")) != "directory":
		return _failure("Atomic bridge helper service should route collection helpers to filesystem_directory.")
	var list_args: Dictionary = list_call.get("args", {})
	if str(list_args.get("path", "")) != "res://" or str(list_args.get("filter", "")) != "*.gd" or not bool(list_args.get("recursive", false)):
		return _failure("Atomic bridge helper service collect_files should preserve filesystem_directory arguments.", list_args)
	var count_args: Dictionary = runtime.dispatch_calls[1].get("args", {})
	if not bool(count_args.get("count_only", false)):
		return _failure("Atomic bridge helper service collect_file_count should request count_only enumeration.", count_args)
	var counts_args: Dictionary = runtime.dispatch_calls[2].get("args", {})
	if not bool(counts_args.get("count_only", false)) or not (counts_args.get("filters", []) is Array):
		return _failure("Atomic bridge helper service collect_file_counts should request filters with count_only.", counts_args)
	if service.extract_data({"data": {"ok": true}}).get("ok") != true:
		return _failure("Atomic bridge helper service should expose result extraction helpers.")
	return {"success": true}


func _verify_execution_service_source_guard() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_execution_service.gd")
	if source.is_empty():
		return _failure("AtomicBridgeExecutionService source should be readable for helper demotion guards.")
	for forbidden in [
		"func extract_data",
		"func extract_array",
		"func collect_files",
		"func collect_file_count",
		"func collect_file_counts",
		"func build_issue",
		"func append_unique_issue",
		"func has_severity",
		"func normalize_dependency_path",
		"func normalize_resource_path",
		"func parse_dependency_reference",
		"func resource_path_exists"
	]:
		if source.find(forbidden) != -1:
			return _failure("AtomicBridgeExecutionService should stay execution-only and not regain helper methods: %s" % forbidden)
	return {"success": true}


func _verify_atomic_bridge_facade_is_thin() -> Dictionary:
	var bridge = AtomicBridgeScript.new()
	var allowed_methods := [
		"success",
		"error",
		"configure_runtime",
		"get_tool_loader",
		"get_gdscript_lsp_diagnostics_service",
		"call_atomic",
		"call_atomic_async"
	]
	for method_name in allowed_methods:
		if not bridge.has_method(method_name):
			return _failure("AtomicBridge facade should keep required execution method: %s" % method_name)
	var removed_helper_methods := [
		"extract_data",
		"extract_array",
		"collect_files",
		"collect_file_count",
		"collect_file_counts",
		"build_issue",
		"append_unique_issue",
		"has_severity",
		"normalize_dependency_path",
		"parse_dependency_reference",
		"_is_write_action",
		"_is_write_atomic_action",
		"_find_path_in_args",
		"_cache_atomic_executor_for_test",
		"_invalidate_atomic_executors",
		"_get_cached_atomic_executor_count_for_test"
	]
	for method_name in removed_helper_methods:
		if bridge.has_method(method_name):
			return _failure("AtomicBridge facade should not expose helper method after demotion: %s" % method_name)
	var source_guard := _verify_atomic_bridge_source_guard()
	if not bool(source_guard.get("success", false)):
		return source_guard
	return {"success": true}


func _verify_atomic_bridge_source_guard() -> Dictionary:
	var source := FileAccess.get_file_as_string("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge.gd")
	if source.is_empty():
		return _failure("AtomicBridge source should be readable for facade guard coverage.")
	for forbidden in [
		"func extract_data",
		"func extract_array",
		"func collect_files",
		"func collect_file_count",
		"func collect_file_counts",
		"func build_issue",
		"func append_unique_issue",
		"func has_severity",
		"func normalize_dependency_path",
		"func parse_dependency_reference",
		"AtomicBridgeSupportScript",
		"AtomicBridgeRuntimeScript",
		"AtomicBridgeDispatchServiceScript"
	]:
		if source.find(forbidden) != -1:
			return _failure("AtomicBridge facade source should not regain helper/runtime implementation wiring: %s" % forbidden)
	for required in [
		"AtomicBridgeExecutionServiceScript",
		"_execution_service.call_atomic(full_name, args)",
		"_execution_service.call_atomic_async(full_name, args)"
	]:
		if source.find(required) == -1:
			return _failure("AtomicBridge facade source should delegate execution through AtomicBridgeExecutionService: %s" % required)
	return {"success": true}


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"name": "system_atomic_bridge_dispatch_contracts",
		"success": false,
		"error": message,
		"data": data
	}
