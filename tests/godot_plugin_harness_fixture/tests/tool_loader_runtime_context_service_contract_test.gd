extends RefCounted

const RuntimeContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_runtime_context_service.gd")


class FakeExecutor:
	extends RefCounted

	var configured_contexts: Array = []

	func configure_runtime(context: Dictionary) -> void:
		configured_contexts.append(context.duplicate(true))


func run_case(_tree: SceneTree) -> Dictionary:
	var service = RuntimeContextServiceScript.new()
	var loader = RefCounted.new()
	var server = RefCounted.new()
	var plugin_host = RefCounted.new()
	var activity_registry = RefCounted.new()

	var base_context: Dictionary = service.build_runtime_context(loader, server, plugin_host, activity_registry)
	if base_context.get("tool_loader", null) != loader:
		return _failure("Runtime context service should preserve the tool loader reference.")
	if base_context.get("server", null) != server or base_context.get("plugin_host", null) != plugin_host:
		return _failure("Runtime context service should preserve server and plugin host references.")
	if base_context.get("tool_activity_registry", null) != activity_registry:
		return _failure("Runtime context service should preserve the tool activity registry reference.")

	var entry := {"path": "res://system_executor.gd", "nested": {"value": "original"}}
	var executor_context: Dictionary = service.build_executor_runtime_context(
		loader,
		server,
		plugin_host,
		activity_registry,
		"system",
		entry,
		"preload"
	)
	if str(executor_context.get("category", "")) != "system" or str(executor_context.get("reason", "")) != "preload":
		return _failure("Runtime context service should preserve executor category and reason.")
	var context_entry = executor_context.get("entry", {})
	if not (context_entry is Dictionary):
		return _failure("Runtime context service should attach the executor entry dictionary.")
	entry["nested"]["value"] = "mutated"
	if str((((context_entry as Dictionary).get("nested", {}) as Dictionary).get("value", ""))) != "original":
		return _failure("Runtime context service should deep-copy executor entries.")

	var executor := FakeExecutor.new()
	var runtime_by_category := {
		"system": {"instance": executor},
		"missing": {"instance": null},
		"plain": {"instance": RefCounted.new()},
		"invalid": "not-a-runtime"
	}
	var configured_count: int = service.configure_loaded_runtimes(runtime_by_category, base_context)
	if configured_count != 1:
		return _failure("Runtime context service should configure only loaded executors with configure_runtime.")
	if executor.configured_contexts.size() != 1:
		return _failure("Runtime context service should call configure_runtime on loaded executors exactly once.")
	base_context["mutated"] = true
	if bool((executor.configured_contexts[0] as Dictionary).get("mutated", false)):
		return _failure("Runtime context service should pass an isolated context copy to loaded executors.")

	return {
		"name": "tool_loader_runtime_context_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"context_keys": base_context.keys().size(),
			"configured_count": configured_count,
			"executor_category": str(executor_context.get("category", ""))
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_runtime_context_service_contracts",
		"success": false,
		"error": message
	}
