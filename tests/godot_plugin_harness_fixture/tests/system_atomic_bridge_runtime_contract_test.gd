extends RefCounted

# {"name": "system_atomic_bridge_runtime_contracts"}

const AtomicBridgeRuntimeScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_runtime.gd")
const AtomicBridgeContextResolverScript = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_context_resolver.gd")
const AtomicBridgeExecutorManifest = preload("res://addons/godot_dotnet_mcp/tools/system/atomic_bridge_executor_manifest.gd")
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
	var context_resolver_result := _verify_context_resolver()
	if not bool(context_resolver_result.get("success", false)):
		return context_resolver_result
	var default_result := _verify_default_manifest_configuration()
	if not bool(default_result.get("success", false)):
		return default_result

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


func _verify_context_resolver() -> Dictionary:
	var loader := FakeLoader.new()
	var resolver = AtomicBridgeContextResolverScript.new()
	if resolver.get_tool_loader({"tool_loader": loader}) != loader:
		return _failure("Atomic bridge context resolver should expose the runtime-context tool loader when no runtime singleton is available.")
	if resolver.get_gdscript_lsp_diagnostics_service({"tool_loader": loader}) != loader.service:
		return _failure("Atomic bridge context resolver should prefer the loader diagnostics service from runtime context.")
	var fallback_service = resolver.get_gdscript_lsp_diagnostics_service({})
	if fallback_service == null:
		return _failure("Atomic bridge context resolver should fall back to the singleton diagnostics service.")
	var direct_plugin := FakePluginHost.new()
	var source_context := {"plugin_host": direct_plugin, "tool_loader": loader}
	var direct_context: Dictionary = resolver.build_atomic_runtime_context("scene", source_context)
	if str(direct_context.get("category", "")) != "scene" or direct_context.get("plugin_host") != direct_plugin:
		return _failure("Atomic bridge context resolver should inject category and preserve direct plugin hosts.")
	if direct_context.get("tool_loader") != loader:
		return _failure("Atomic bridge context resolver should preserve runtime context values.")
	if direct_context.get("editor_interface") != direct_plugin.editor_interface:
		return _failure("Atomic bridge context resolver should derive editor_interface from direct plugin hosts.")
	direct_context["tool_loader"] = "mutated"
	if source_context.get("tool_loader") != loader:
		return _failure("Atomic bridge context resolver should return a duplicate context.")
	var explicit_editor := RefCounted.new()
	var explicit_context: Dictionary = resolver.build_atomic_runtime_context("script", {
		"plugin_host": direct_plugin,
		"editor_interface": explicit_editor
	})
	if explicit_context.get("editor_interface") != explicit_editor:
		return _failure("Atomic bridge context resolver should not replace an explicit editor_interface.")
	var getter_plugin := FakePluginHost.new()
	var getter_context: Dictionary = resolver.build_atomic_runtime_context("resource", {
		"get_plugin_host": Callable(FakePluginHostProvider.new(getter_plugin), "get_plugin_host")
	})
	if getter_context.get("plugin_host") != getter_plugin:
		return _failure("Atomic bridge context resolver should resolve plugin hosts from runtime getter callables.")
	var server_plugin := FakePluginHost.new()
	var server_context: Dictionary = resolver.build_atomic_runtime_context("project", {
		"server": FakeServerHost.new(server_plugin)
	})
	if server_context.get("plugin_host") != server_plugin:
		return _failure("Atomic bridge context resolver should resolve plugin hosts from server parents.")
	var fallback_plugin := FakePluginHost.new()
	var fallback_context: Dictionary = resolver.build_atomic_runtime_context("debug", {
		"get_plugin_host": Callable(FakePluginHostProvider.new(null), "get_plugin_host"),
		"server": FakeServerHost.new(fallback_plugin)
	})
	if fallback_context.get("plugin_host") != fallback_plugin:
		return _failure("Atomic bridge context resolver should fall back to server parents when getter callables return null.")
	var empty_context: Dictionary = resolver.build_atomic_runtime_context("runtime", {})
	if empty_context.has("plugin_host") or str(empty_context.get("category", "")) != "runtime":
		return _failure("Atomic bridge context resolver should omit plugin_host when no plugin source is available.")
	return {"success": true}


func _verify_default_manifest_configuration() -> Dictionary:
	var expected_categories := [
		"dap",
		"debug",
		"editor",
		"filesystem",
		"node",
		"project",
		"resource",
		"runtime",
		"scene",
		"script"
	]
	if AtomicBridgeExecutorManifest.get_categories() != expected_categories:
		return _failure("Atomic bridge executor manifest should expose the canonical category set.")
	var dependency_paths := AtomicBridgeExecutorManifest.get_executor_dependency_paths()
	if not dependency_paths.has("editor"):
		return _failure("Atomic bridge executor manifest should preserve editor executor dependencies.")
	var editor_dependencies: Array = dependency_paths.get("editor", [])
	if not editor_dependencies.has("res://addons/godot_dotnet_mcp/tools/editor_tools.gd"):
		return _failure("Atomic bridge executor manifest should keep the editor_tools compatibility dependency.")
	editor_dependencies.clear()
	var fresh_dependencies := AtomicBridgeExecutorManifest.get_executor_dependency_paths()
	if fresh_dependencies.get("editor", []).is_empty():
		return _failure("Atomic bridge executor manifest should not leak mutable dependency arrays.")

	var default_runtime = AtomicBridgeRuntimeScript.new()
	default_runtime.configure_default()
	for category in expected_categories:
		if not default_runtime.has_category(category):
			return _failure("Atomic bridge runtime default configuration should include category: %s" % category)
	if default_runtime.has_category("ghost"):
		return _failure("Atomic bridge runtime default configuration should not include unknown categories.")
	return {"success": true}


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


class FakeLoader extends RefCounted:
	var service := RefCounted.new()

	func get_gdscript_lsp_diagnostics_service():
		return service


class FakePluginHost extends RefCounted:
	var editor_interface := RefCounted.new()

	func get_editor_interface():
		return editor_interface


class FakePluginHostProvider extends RefCounted:
	var plugin_host = null

	func _init(host) -> void:
		plugin_host = host

	func get_plugin_host():
		return plugin_host


class FakeServerHost extends RefCounted:
	var plugin_host = null

	func _init(host) -> void:
		plugin_host = host

	func get_parent():
		return plugin_host


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
