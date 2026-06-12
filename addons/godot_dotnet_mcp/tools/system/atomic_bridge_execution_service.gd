@tool
extends RefCounted

## Internal execution facade for AtomicBridge calls.
## Owns support/runtime/dispatch composition while atomic_bridge.gd stays a thin compatibility facade.

const AtomicBridgeSupportScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_support.gd")
const AtomicBridgeRuntimeScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_runtime.gd")
const AtomicBridgeDispatchServiceScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_dispatch_service.gd")

var _support = AtomicBridgeSupportScript.new()
var _runtime = AtomicBridgeRuntimeScript.new()
var _dispatch_service = AtomicBridgeDispatchServiceScript.new()


func configure_default(runtime_context_provider: Callable = Callable()) -> void:
	_runtime.configure_default(runtime_context_provider)


func configure_runtime(context: Dictionary) -> void:
	_runtime.configure_runtime(context)


func call_atomic(full_name: String, args: Dictionary = {}) -> Dictionary:
	return _dispatch_service.call_atomic(full_name, args, _support, _runtime)


func call_atomic_async(full_name: String, args: Dictionary = {}) -> Dictionary:
	return await _dispatch_service.call_atomic_async(full_name, args, _support, _runtime)


func is_protected_path(path: String) -> bool:
	return _support.is_protected_path(path)


func is_write_action(args: Dictionary) -> bool:
	return _support.is_write_action(args)


func is_write_atomic_action(full_name: String, args: Dictionary) -> bool:
	return _support.is_write_atomic_action(full_name, args)


func is_write_action_name(action: String) -> bool:
	return _support.is_write_action_name(action)


func infer_write_action_from_atomic_name(full_name: String) -> String:
	return _support.infer_write_action_from_atomic_name(full_name)


func find_path_in_args(args: Dictionary) -> String:
	return _support.find_path_in_args(args)


func dispose_executor(executor) -> void:
	_runtime.dispose_executor(executor)


func invalidate() -> void:
	_runtime.invalidate()


func cache_executor_for_test(category: String, executor) -> void:
	_runtime.cache_executor_for_test(category, executor)


func get_cached_executor_count_for_test() -> int:
	return _runtime.get_cached_executor_count_for_test()
