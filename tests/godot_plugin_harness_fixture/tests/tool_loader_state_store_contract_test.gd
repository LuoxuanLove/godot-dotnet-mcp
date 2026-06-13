extends RefCounted

const StateStoreScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_state_store.gd")


class FakeRegistry:
	extends RefCounted

	var entries: Array = []

	func collect_entries() -> Array:
		return entries.duplicate(true)


class FakeEntryService:
	extends RefCounted

	var next_index: Dictionary = {}

	func build_index(_entries: Array) -> Dictionary:
		return next_index.duplicate(true)


class FakeDiagnostics:
	extends RefCounted

	var cleared := false
	var replaced_errors: Array = []
	var recorded_errors: Array = []

	func clear_load_errors() -> void:
		cleared = true

	func replace_load_errors(errors: Array) -> void:
		replaced_errors = errors.duplicate(true)

	func record_load_error(category: String, path: String, message: String) -> Dictionary:
		var info := {
			"category": category,
			"path": path,
			"message": message
		}
		recorded_errors.append(info.duplicate(true))
		return info


class FakeSync:
	extends RefCounted

	var phases: Array = []

	func sync(phase: String) -> void:
		phases.append(phase)


func run_case(_tree: SceneTree) -> Dictionary:
	var store = StateStoreScript.new()
	var diagnostics := FakeDiagnostics.new()
	var registry := FakeRegistry.new()
	var entry_service := FakeEntryService.new()
	var sync := FakeSync.new()

	store.entries_by_category["stale"] = {"path": "res://stale.gd"}
	store.ordered_categories.append("stale")
	store.runtime_by_category["stale"] = {"instance": RefCounted.new()}
	store.tool_definitions_by_category["stale"] = [{"name": "stale_probe"}]
	store.performance["reload_count"] = 7
	store.set_force_reload_script_load(true)
	store.reset(diagnostics)
	if not diagnostics.cleared:
		return _failure("State store reset should clear diagnostics.")
	if not store.entries_by_category.is_empty() or not store.ordered_categories.is_empty() or not store.runtime_by_category.is_empty() or not store.tool_definitions_by_category.is_empty():
		return _failure("State store reset should clear indexed state while preserving the performance map.")
	if int(store.performance.get("reload_count", 0)) != 7 or not store.get_force_reload_script_load():
		return _failure("State store reset should not silently rewrite performance or force-reload flags.")

	store.runtime_by_category = {
		"system": {"version": 2},
		"removed": {"version": 1}
	}
	store.tool_definitions_by_category = {
		"system": [{"name": "old_system"}],
		"removed": [{"name": "old_removed"}]
	}
	store.entries_by_category = {}
	store.ordered_categories.clear()
	var entries_ref: Dictionary = store.entries_by_category
	var order_ref: Array[String] = store.ordered_categories
	entry_service.next_index = {
		"entries_by_category": {
			"system": {"path": "res://system.gd"},
			"user": {"path": "res://user.gd"}
		},
		"ordered_categories": ["system", "user"],
		"load_errors": [{"category": "broken"}]
	}
	store.refresh_entries(registry, entry_service, diagnostics, Callable(sync, "sync"))
	if entries_ref != store.entries_by_category or order_ref != store.ordered_categories:
		return _failure("State store refresh should preserve entries/order reference identity.")
	if not store.entries_by_category.has("user") or store.ordered_categories.size() != 2:
		return _failure("State store refresh should publish the new registry index.")
	if store.runtime_by_category.has("removed") or store.tool_definitions_by_category.has("removed"):
		return _failure("State store refresh should prune runtime and definition state for removed categories.")
	if diagnostics.replaced_errors.size() != 1 or not sync.phases.has("refresh_entries"):
		return _failure("State store refresh should replace load errors and sync diagnostics incidents.")

	store.record_load_error("system", "res://system.gd", "compile failed", diagnostics)
	var runtime: Dictionary = store.runtime_by_category.get("system", {})
	var last_error = runtime.get("last_error", {})
	if not (last_error is Dictionary) or str((last_error as Dictionary).get("message", "")) != "compile failed":
		return _failure("State store should write recorded load errors into category runtime state.")

	var reload_context: Dictionary = store.build_reload_context({"marker": "reload"})
	var runtime_from_context: Dictionary = reload_context.get("runtime_by_category", {})
	runtime_from_context["system"] = {"version": 99}
	if int((store.runtime_by_category.get("system", {}) as Dictionary).get("version", 0)) != 99:
		return _failure("State store contexts should expose shared mutable runtime references.")
	var callback_runtime: Dictionary = (reload_context.get("get_runtime_by_category") as Callable).call()
	if callback_runtime != store.runtime_by_category:
		return _failure("State store reload callbacks should return the canonical runtime reference.")

	var lifecycle_context: Dictionary = store.build_lifecycle_context({})
	(lifecycle_context.get("set_force_reload_script_load") as Callable).call(false)
	if store.get_force_reload_script_load():
		return _failure("State store lifecycle context should own force-reload state writes.")

	return {
		"name": "tool_loader_state_store_contracts",
		"success": true,
		"error": "",
		"details": {
			"categories": store.ordered_categories.duplicate(),
			"load_error_count": diagnostics.recorded_errors.size(),
			"sync_phases": sync.phases.duplicate()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_state_store_contracts",
		"success": false,
		"error": message
	}
