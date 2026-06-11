extends RefCounted

# {"name": "system_atomic_bridge_dispatch_contracts"}

const AtomicBridgeDispatchServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_dispatch_service.gd")
const AtomicBridgeExecutionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_execution_service.gd")
const AtomicBridgeSupportScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_support.gd")


class FakeRuntime:
	extends RefCounted

	var categories := {"sync": true, "async": true, "script": true}
	var dispatch_calls: Array[Dictionary] = []
	var async_calls: Array[Dictionary] = []
	var invalidate_count := 0
	var next_success := true

	func has_category(category: String) -> bool:
		return categories.has(category)

	func dispatch(category: String, tool_name: String, args: Dictionary) -> Dictionary:
		dispatch_calls.append({"category": category, "tool_name": tool_name, "args": args.duplicate(true)})
		return {"success": next_success, "data": {"category": category, "tool_name": tool_name}}

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
	if service.extract_data({"data": {"ok": true}}).get("ok") != true:
		return _failure("Atomic bridge execution service should expose result extraction helpers for the facade.")
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
