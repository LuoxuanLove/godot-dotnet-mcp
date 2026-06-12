extends RefCounted

const ContextServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_context_service.gd")
const StateStoreScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_state_store.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var store = StateStoreScript.new()
	var service = ContextServiceScript.new()
	service.configure(store)

	store.ordered_categories.append("system")
	store.entries_by_category["system"] = {"path": "res://system.gd"}
	store.runtime_by_category["system"] = {"loaded": true}
	store.tool_definitions_by_category["system"] = [{"name": "system_project_state"}]
	store.performance["startup_ms"] = 12.5
	store.set_force_reload_script_load(true)

	var catalog_context := service.build_catalog_projection_context({"marker": "catalog"})
	if catalog_context.get("entries_by_category", {}) != store.entries_by_category:
		return _failure("Context service should preserve catalog state references.")
	if str(catalog_context.get("marker", "")) != "catalog":
		return _failure("Context service should merge catalog callbacks.")

	var reload_context := service.build_reload_context({"marker": "reload"})
	if reload_context.get("performance", {}) != store.performance:
		return _failure("Context service should include reload performance state.")
	if not (reload_context.get("get_ordered_categories", Callable()) is Callable):
		return _failure("Context service should expose reload state accessors.")
	if str(reload_context.get("marker", "")) != "reload":
		return _failure("Context service should merge reload callbacks.")

	var user_reload_context := service.build_user_reload_context({"marker": "user"})
	if user_reload_context.get("performance", {}) != store.performance:
		return _failure("User reload context should reuse reload state projection.")
	if str(user_reload_context.get("marker", "")) != "user":
		return _failure("Context service should merge user reload callbacks.")

	var runtime_context := service.build_runtime_state_context({"marker": "runtime"})
	if not bool(runtime_context.get("force_reload_script_load", false)):
		return _failure("Context service should expose runtime force-reload state.")
	if not (runtime_context.get("get_force_reload_script_load", Callable()) is Callable):
		return _failure("Context service should expose runtime-state accessors.")
	if str(runtime_context.get("marker", "")) != "runtime":
		return _failure("Context service should merge runtime-state callbacks.")

	var lifecycle_context := service.build_lifecycle_context({"marker": "lifecycle"})
	if lifecycle_context.get("runtime_by_category", {}) != store.runtime_by_category:
		return _failure("Context service should preserve lifecycle runtime state references.")
	if not (lifecycle_context.get("set_force_reload_script_load", Callable()) is Callable):
		return _failure("Context service should expose lifecycle mutators.")
	if str(lifecycle_context.get("marker", "")) != "lifecycle":
		return _failure("Context service should merge lifecycle callbacks.")

	var fallback = ContextServiceScript.new()
	var fallback_context := fallback.build_reload_context({"marker": "fallback"})
	if str(fallback_context.get("marker", "")) != "fallback":
		return _failure("Context service should fail open to callback-only contexts when no store is configured.")

	return {
		"success": true,
		"name": "tool_loader_context_service_contracts",
		"contexts": 6
	}


func _failure(message: String, extra: Dictionary = {}) -> Dictionary:
	var data := extra.duplicate(true)
	data["message"] = message
	return {
		"success": false,
		"name": "tool_loader_context_service_contracts",
		"error": message,
		"data": data
	}
