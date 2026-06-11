extends RefCounted

# {"name": "system_atomic_bridge_runtime_contracts"}

const AtomicBridgeRuntimeScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_runtime.gd")
const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_atomic_bridge_runtime_contracts"
const EXECUTOR_PATH := TEMP_ROOT + "/atomic_contract_executor.gd"
const ASYNC_EXECUTOR_PATH := TEMP_ROOT + "/atomic_async_contract_executor.gd"
const INVALID_EXECUTOR_PATH := TEMP_ROOT + "/atomic_invalid_executor.gd"
const MISSING_EXECUTOR_PATH := TEMP_ROOT + "/missing_executor.gd"

var _provided_contexts: Array[Dictionary] = []


func run_case(_tree: SceneTree) -> Dictionary:
	var setup := _write_fixture_scripts()
	if not bool(setup.get("success", false)):
		return setup

	var runtime = AtomicBridgeRuntimeScript.new()
	runtime.configure({
		"sync": EXECUTOR_PATH,
		"async": ASYNC_EXECUTOR_PATH,
		"invalid": INVALID_EXECUTOR_PATH,
		"missing": MISSING_EXECUTOR_PATH
	}, {}, Callable(self, "_build_context"))
	runtime.configure_runtime({
		"tool_loader": "loader-a",
		"server": "server-a"
	})

	if runtime.has_category("ghost"):
		return _failure("Atomic bridge runtime should reject unknown categories.")
	var unknown_result: Dictionary = runtime.get_executor("ghost")
	if bool(unknown_result.get("success", true)) or str(unknown_result.get("error", "")) != "Unknown atomic category: ghost":
		return _failure("Atomic bridge runtime should report stable unknown-category errors.")

	var missing_result: Dictionary = runtime.get_executor("missing")
	if bool(missing_result.get("success", true)) or not str(missing_result.get("error", "")).begins_with("Failed to load atomic executor:"):
		return _failure("Atomic bridge runtime should report missing executor scripts.")

	var invalid_result: Dictionary = runtime.get_executor("invalid")
	if bool(invalid_result.get("success", true)) or str(invalid_result.get("error", "")) != "Atomic executor not available: invalid":
		return _failure("Atomic bridge runtime should reject scripts without execute/execute_async.")

	var first_result: Dictionary = runtime.dispatch("sync", "probe", {"value": 7})
	if not bool(first_result.get("success", false)):
		return _failure("Atomic bridge runtime should call sync executors.", first_result)
	if int(first_result.get("data", {}).get("call_count", 0)) != 1:
		return _failure("Atomic bridge runtime should expose first executor call count.")
	var second_result: Dictionary = runtime.dispatch("sync", "probe", {"value": 8})
	if int(second_result.get("data", {}).get("call_count", 0)) != 2:
		return _failure("Atomic bridge runtime should cache executor instances between calls.")
	var context: Dictionary = second_result.get("data", {}).get("context", {})
	if str(context.get("category", "")) != "sync" or str(context.get("tool_loader", "")) != "loader-a":
		return _failure("Atomic bridge runtime should inject configured context into executors.")
	if _provided_contexts.size() != 1:
		return _failure("Atomic bridge runtime should not rebuild context while the executor stays cached.")

	runtime.invalidate()
	var after_invalidate: Dictionary = runtime.dispatch("sync", "probe", {})
	if int(after_invalidate.get("data", {}).get("call_count", 0)) != 1:
		return _failure("Atomic bridge runtime should recreate executors after invalidation.")
	if _provided_contexts.size() != 2:
		return _failure("Atomic bridge runtime should rebuild context after invalidation.")

	var async_result: Dictionary = await runtime.dispatch_async("async", "probe_async", {"value": 9})
	if not bool(async_result.get("success", false)) or str(async_result.get("data", {}).get("mode", "")) != "async":
		return _failure("Atomic bridge runtime should prefer execute_async when available.", async_result)

	var fallback_result: Dictionary = await runtime.dispatch_async("sync", "probe_fallback", {})
	if not bool(fallback_result.get("success", false)) or str(fallback_result.get("data", {}).get("tool_name", "")) != "probe_fallback":
		return _failure("Atomic bridge runtime should fall back to sync execute from async dispatch.", fallback_result)

	runtime.configure_runtime({"tool_loader": "loader-b"})
	var reconfigured_result: Dictionary = runtime.dispatch("sync", "probe", {})
	if str(reconfigured_result.get("data", {}).get("context", {}).get("tool_loader", "")) != "loader-b":
		return _failure("Atomic bridge runtime should invalidate cached executors when runtime context changes.")

	return {
		"name": "system_atomic_bridge_runtime_contracts",
		"success": true,
		"context_count": _provided_contexts.size()
	}


func _build_context(category: String, runtime_context: Dictionary) -> Dictionary:
	var context := runtime_context.duplicate(true)
	context["category"] = category
	_provided_contexts.append(context.duplicate(true))
	return context


func _write_fixture_scripts() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	var executor_source := "extends RefCounted\n\nvar _context := {}\nvar _call_count := 0\nvar _disposed := false\n\nfunc configure_runtime(context: Dictionary) -> void:\n\t_context = context.duplicate(true)\n\nfunc execute(tool_name: String, args: Dictionary) -> Dictionary:\n\t_call_count += 1\n\treturn {\"success\": true, \"data\": {\"tool_name\": tool_name, \"args\": args.duplicate(true), \"call_count\": _call_count, \"context\": _context.duplicate(true), \"disposed\": _disposed}}\n\nfunc dispose() -> void:\n\t_disposed = true\n\nfunc shutdown() -> void:\n\t_disposed = true\n"
	var async_executor_source := "extends RefCounted\n\nvar _context := {}\n\nfunc configure_context(context: Dictionary) -> void:\n\t_context = context.duplicate(true)\n\nfunc execute_async(tool_name: String, args: Dictionary) -> Dictionary:\n\tawait Engine.get_main_loop().process_frame\n\treturn {\"success\": true, \"data\": {\"mode\": \"async\", \"tool_name\": tool_name, \"args\": args.duplicate(true), \"context\": _context.duplicate(true)}}\n"
	var invalid_source := "extends RefCounted\n\nfunc no_execute() -> void:\n\tpass\n"
	var write_executor := _write_text(EXECUTOR_PATH, executor_source)
	if not bool(write_executor.get("success", false)):
		return write_executor
	var write_async := _write_text(ASYNC_EXECUTOR_PATH, async_executor_source)
	if not bool(write_async.get("success", false)):
		return write_async
	return _write_text(INVALID_EXECUTOR_PATH, invalid_source)


func _write_text(path: String, content: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("Failed to open fixture script for writing: %s" % path)
	file.store_string(content)
	file.close()
	return {"success": true}


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"name": "system_atomic_bridge_runtime_contracts",
		"success": false,
		"error": message,
		"data": data
	}
