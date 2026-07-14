extends RefCounted

const LifecycleServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_lifecycle_service.gd")


class FakeLifecycleContext:
	extends RefCounted

	var ordered_categories: Array = []
	var runtime_by_category: Dictionary = {}
	var performance: Dictionary = {
		"startup_ms": 0.0,
		"definition_scan_ms": 0.0,
		"preload_ms": 0.0
	}
	var disabled_tools: Array = []
	var force_reload_script_load := false
	var reset_count := 0
	var lsp_reset_count := 0
	var lsp_dispose_count := 0
	var refresh_entries_count := 0
	var runtime_refresh_count := 0
	var tool_definition_query_count := 0
	var exposed_definition_query_count := 0
	var sync_actions: Array = []
	var ensured_definitions: Array = []
	var ensured_runtimes: Array = []
	var unloaded_runtimes: Array = []
	var reload_statuses: Array = []
	var tool_definitions: Array = []
	var exposed_definitions: Array = []
	var definitions_by_category: Dictionary = {}
	var entries_by_category: Dictionary = {}
	var tool_load_error_count := 0
	var disabled_categories: Dictionary = {}
	var hidden_categories: Dictionary = {}
	var disabled_tool_names: Dictionary = {}
	var exposed_tool_names: Dictionary = {}
	var forced_values: Array = []
	var tick_result: Dictionary = {}
	var tick_deltas: Array = []
	var lsp_tick_deltas: Array = []
	var preload_runtimes := false
	var disabled_tools_changed := true

	func build() -> Dictionary:
		return {
			"ordered_categories": ordered_categories,
			"entries_by_category": entries_by_category,
			"runtime_by_category": runtime_by_category,
			"tool_definitions_by_category": definitions_by_category,
			"performance": performance,
			"set_force_reload_script_load": Callable(self, "set_force_reload_script_load"),
			"get_runtime_by_category": Callable(self, "get_runtime_by_category"),
			"get_tool_definitions_by_category": Callable(self, "get_tool_definitions_by_category"),
			"get_entries_by_category": Callable(self, "get_entries_by_category"),
			"get_ordered_categories": Callable(self, "get_ordered_categories"),
			"reset_state": Callable(self, "reset_state"),
			"set_disabled_tools": Callable(self, "set_disabled_tools"),
			"reset_gdscript_lsp_diagnostics_service": Callable(self, "reset_gdscript_lsp_diagnostics_service"),
			"dispose_gdscript_lsp_diagnostics_adapter": Callable(self, "dispose_gdscript_lsp_diagnostics_adapter"),
			"tick_gdscript_lsp_diagnostics": Callable(self, "tick_gdscript_lsp_diagnostics"),
			"refresh_entries": Callable(self, "refresh_entries"),
			"ensure_tool_definitions": Callable(self, "ensure_tool_definitions"),
			"category_has_enabled_tools": Callable(self, "category_has_enabled_tools"),
			"should_preload_runtimes": Callable(self, "should_preload_runtimes"),
			"ensure_runtime_loaded": Callable(self, "ensure_runtime_loaded"),
			"unload_runtime": Callable(self, "unload_runtime"),
			"tick_loaded_runtimes": Callable(self, "tick_loaded_runtimes"),
			"make_reload_status": Callable(self, "make_reload_status"),
			"update_reload_status": Callable(self, "update_reload_status"),
			"sync_load_error_incidents": Callable(self, "sync_load_error_incidents"),
			"refresh_runtime_context": Callable(self, "refresh_runtime_context"),
			"get_tool_definitions": Callable(self, "get_tool_definitions"),
			"get_exposed_tool_definitions": Callable(self, "get_exposed_tool_definitions"),
			"is_category_visible": Callable(self, "is_category_visible"),
			"is_tool_enabled": Callable(self, "is_tool_enabled"),
			"is_exposed_tool_definition": Callable(self, "is_exposed_tool_definition"),
			"get_tool_load_error_count": Callable(self, "get_tool_load_error_count")
		}

	func set_force_reload_script_load(enabled: bool) -> void:
		force_reload_script_load = enabled
		forced_values.append(enabled)

	func get_runtime_by_category() -> Dictionary:
		return runtime_by_category

	func get_tool_definitions_by_category() -> Dictionary:
		return definitions_by_category

	func get_entries_by_category() -> Dictionary:
		return entries_by_category

	func get_ordered_categories() -> Array:
		return ordered_categories

	func reset_state() -> void:
		reset_count += 1

	func set_disabled_tools(new_disabled_tools: Array) -> bool:
		if not disabled_tools_changed:
			return false
		disabled_tools = new_disabled_tools.duplicate()
		return true

	func reset_gdscript_lsp_diagnostics_service() -> void:
		lsp_reset_count += 1

	func dispose_gdscript_lsp_diagnostics_adapter() -> void:
		lsp_dispose_count += 1

	func tick_gdscript_lsp_diagnostics(delta: float) -> void:
		lsp_tick_deltas.append(delta)

	func refresh_entries() -> void:
		refresh_entries_count += 1

	func ensure_tool_definitions(category: String) -> Array:
		ensured_definitions.append(category)
		var defs: Array = definitions_by_category.get(category, [])
		if defs.is_empty():
			defs = [{"name": "%s_probe" % category}]
			definitions_by_category[category] = defs
		return defs

	func category_has_enabled_tools(category: String) -> bool:
		return not bool(disabled_categories.get(category, false))

	func should_preload_runtimes() -> bool:
		return preload_runtimes

	func ensure_runtime_loaded(category: String, reason: String) -> Dictionary:
		ensured_runtimes.append({
			"category": category,
			"reason": reason
		})
		runtime_by_category[category] = {
			"instance": RefCounted.new(),
			"state": "loaded",
			"reason": reason
		}
		return {
			"success": true,
			"runtime": runtime_by_category.get(category, {})
		}

	func unload_runtime(category: String, reason: String) -> void:
		unloaded_runtimes.append({
			"category": category,
			"reason": reason
		})
		runtime_by_category.erase(category)

	func tick_loaded_runtimes(delta: float) -> Dictionary:
		tick_deltas.append(delta)
		return tick_result.duplicate(true)

	func make_reload_status(action: String) -> Dictionary:
		return {
			"action": action,
			"performance": performance.duplicate(true)
		}

	func update_reload_status(status: Dictionary) -> Dictionary:
		reload_statuses.append(status.duplicate(true))
		return status.duplicate(true)

	func sync_load_error_incidents(action: String) -> void:
		sync_actions.append(action)

	func refresh_runtime_context() -> void:
		runtime_refresh_count += 1

	func get_tool_definitions() -> Array:
		tool_definition_query_count += 1
		return tool_definitions.duplicate(true)

	func get_exposed_tool_definitions() -> Array:
		exposed_definition_query_count += 1
		return exposed_definitions.duplicate(true)

	func is_category_visible(category: String) -> bool:
		return not bool(hidden_categories.get(category, false))

	func is_tool_enabled(tool_name: String) -> bool:
		return not bool(disabled_tool_names.get(tool_name, false))

	func is_exposed_tool_definition(tool_def: Dictionary) -> bool:
		return bool(exposed_tool_names.get(str(tool_def.get("name", "")), false))

	func get_tool_load_error_count() -> int:
		return tool_load_error_count


func run_case(_tree: SceneTree) -> Dictionary:
	var service = LifecycleServiceScript.new()

	var init_context := FakeLifecycleContext.new()
	init_context.ordered_categories = ["system", "project", "debug"]
	init_context.definitions_by_category = {
		"system": [
			{"name": "visible_probe"},
			{"name": "disabled_probe"},
			{"name": "legacy_removed"}
		],
		"project": [{"name": "hidden_probe"}],
		"debug": [{"name": "internal_probe"}]
	}
	init_context.entries_by_category = {
		"system": {"domain_key": "core", "path": "res://system.gd", "source": "builtin"},
		"project": {"domain_key": "core", "path": "res://project.gd", "source": "builtin"},
		"debug": {"domain_key": "core", "path": "res://debug.gd", "source": "builtin"}
	}
	init_context.disabled_categories = {"debug": true}
	init_context.hidden_categories = {"project": true}
	init_context.disabled_tool_names = {"system_disabled_probe": true}
	init_context.exposed_tool_names = {
		"system_visible_probe": true,
		"system_disabled_probe": true
	}
	init_context.tool_load_error_count = 2
	var init_summary: Dictionary = service.initialize(["debug_probe"], true, init_context.build())
	if init_context.forced_values.size() != 2 or init_context.forced_values[0] != true or init_context.forced_values[1] != false:
		return _failure("Lifecycle service should bracket initialization with force reload enabled and then reset it.")
	if init_context.disabled_tools != ["debug_probe"]:
		return _failure("Lifecycle service should configure disabled tools before refreshing entries.")
	if init_context.reset_count != 1 or init_context.lsp_reset_count != 1 or init_context.refresh_entries_count != 1:
		return _failure("Lifecycle service should reset state, LSP diagnostics, and entries during initialize.")
	if init_context.ensured_definitions != ["system", "project", "debug"]:
		return _failure("Lifecycle service should scan definitions for all ordered categories.")
	if not init_context.ensured_runtimes.is_empty():
		return _failure("Lifecycle service should skip runtime preload by default.")
	if float(init_context.performance.get("preload_ms", 1.0)) != 0.0 or not bool(init_context.performance.get("preload_skipped", false)):
		return _failure("Lifecycle service should report skipped preload without recording startup preload time.")
	if init_context.reload_statuses.is_empty() or str((init_context.reload_statuses[0] as Dictionary).get("action", "")) != "initialize":
		return _failure("Lifecycle service should publish initialize reload status.")
	if init_context.sync_actions != ["initialize"] or init_context.runtime_refresh_count != 1:
		return _failure("Lifecycle service should sync load incidents and refresh runtime context after initialize.")
	if int(init_summary.get("tool_count", 0)) != 4 or int(init_summary.get("exposed_tool_count", 0)) != 1 or int(init_summary.get("category_count", 0)) != 3 or int(init_summary.get("tool_load_error_count", 0)) != 2:
		return _failure("Lifecycle service should return initialization summary counts from scanned definitions.")
	if init_context.tool_definition_query_count != 0 or init_context.exposed_definition_query_count != 0:
		return _failure("Lifecycle service initialize summary should not call heavy public definition query callbacks.")
	if float(init_context.performance.get("startup_ms", 0.0)) <= 0.0:
		return _failure("Lifecycle service should update startup performance metrics.")

	var preload_context := FakeLifecycleContext.new()
	preload_context.preload_runtimes = true
	preload_context.ordered_categories = ["system", "project", "debug"]
	preload_context.disabled_categories = {"debug": true}
	service.initialize([], false, preload_context.build())
	if preload_context.ensured_runtimes.size() != 2:
		return _failure("Lifecycle service should preload only enabled categories when explicit preload is requested.")
	if str((preload_context.ensured_runtimes[0] as Dictionary).get("reason", "")) != "preload":
		return _failure("Lifecycle service should preserve preload runtime reasons when preloading is enabled.")
	if bool(preload_context.performance.get("preload_skipped", true)):
		return _failure("Lifecycle service should mark preload_skipped=false when explicit preload runs.")

	var disabled_context := FakeLifecycleContext.new()
	disabled_context.ordered_categories = ["system", "debug"]
	disabled_context.runtime_by_category = {"debug": {"instance": RefCounted.new()}}
	disabled_context.disabled_categories = {"debug": true}
	service.set_disabled_tools(["debug_probe"], disabled_context.build())
	if disabled_context.disabled_tools != ["debug_probe"]:
		return _failure("Lifecycle service should apply disabled tool lists.")
	if disabled_context.ensured_runtimes.size() != 1 or str((disabled_context.ensured_runtimes[0] as Dictionary).get("category", "")) != "system":
		return _failure("Lifecycle service should load enabled categories after disabled-tool changes.")
	if disabled_context.unloaded_runtimes.size() != 1 or str((disabled_context.unloaded_runtimes[0] as Dictionary).get("reason", "")) != "disabled_tools_changed":
		return _failure("Lifecycle service should unload disabled categories with disabled_tools_changed reason.")
	if disabled_context.runtime_refresh_count != 1:
		return _failure("Lifecycle service should refresh runtime context after disabled-tool changes.")
	disabled_context.disabled_tools_changed = false
	service.set_disabled_tools(["debug_probe"], disabled_context.build())
	if disabled_context.ensured_runtimes.size() != 1 or disabled_context.unloaded_runtimes.size() != 1 or disabled_context.runtime_refresh_count != 1:
		return _failure("Lifecycle service should skip runtime rewiring when disabled tools are unchanged.")

	var shutdown_context := FakeLifecycleContext.new()
	shutdown_context.runtime_by_category = {
		"system": {"instance": RefCounted.new()},
		"user": {"instance": RefCounted.new()}
	}
	service.shutdown(shutdown_context.build())
	if shutdown_context.unloaded_runtimes.size() != 2:
		return _failure("Lifecycle service should unload all loaded runtimes on shutdown.")
	for unload_record in shutdown_context.unloaded_runtimes:
		if str((unload_record as Dictionary).get("reason", "")) != "shutdown":
			return _failure("Lifecycle service should tag shutdown unload reasons.")
	if shutdown_context.lsp_dispose_count != 1 or shutdown_context.reset_count != 1:
		return _failure("Lifecycle service should dispose LSP diagnostics and reset state on shutdown.")
	if shutdown_context.forced_values != [false]:
		return _failure("Lifecycle service should clear force reload during shutdown.")

	var tick_context := FakeLifecycleContext.new()
	tick_context.runtime_by_category = {"user": {"instance": RefCounted.new()}}
	tick_context.definitions_by_category = {"user": [{"name": "old_user_probe"}]}
	tick_context.tick_result = {
		"user_definitions_changed": true,
		"user_definitions": [{"name": "new_user_probe"}],
		"user_should_unload": false
	}
	service.tick(0.25, tick_context.build())
	if tick_context.tick_deltas != [0.25] or tick_context.lsp_tick_deltas != [0.25]:
		return _failure("Lifecycle service should forward tick deltas to runtime and LSP maintenance.")
	if str(((tick_context.definitions_by_category.get("user", []) as Array)[0] as Dictionary).get("name", "")) != "new_user_probe":
		return _failure("Lifecycle service should apply user definition changes from tick results.")
	if tick_context.runtime_refresh_count != 1:
		return _failure("Lifecycle service should refresh runtime context when tick results change definitions.")

	var unload_tick_context := FakeLifecycleContext.new()
	unload_tick_context.runtime_by_category = {"user": {"instance": RefCounted.new()}}
	unload_tick_context.definitions_by_category = {"user": [{"name": "user_probe"}]}
	unload_tick_context.tick_result = {"user_should_unload": true}
	service.tick(0.5, unload_tick_context.build())
	if unload_tick_context.runtime_by_category.has("user") or unload_tick_context.definitions_by_category.has("user"):
		return _failure("Lifecycle service should remove user runtime and definitions when tick requests unload.")
	if unload_tick_context.runtime_refresh_count != 1:
		return _failure("Lifecycle service should refresh runtime context when tick unloads user runtime.")

	return {
		"name": "tool_loader_lifecycle_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"initialized_categories": init_context.ensured_definitions.size(),
			"disabled_unloads": disabled_context.unloaded_runtimes.size(),
			"shutdown_unloads": shutdown_context.unloaded_runtimes.size(),
			"tick_refreshes": tick_context.runtime_refresh_count + unload_tick_context.runtime_refresh_count
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_lifecycle_service_contracts",
		"success": false,
		"error": message
	}
