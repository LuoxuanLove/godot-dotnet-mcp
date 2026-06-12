extends RefCounted

const ReloadServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_reload_service.gd")


class FakeExecutor:
	extends RefCounted

	var definitions: Array = []

	func _init(new_definitions: Array = []) -> void:
		definitions = new_definitions.duplicate(true)


class FakeReloadContext:
	extends RefCounted

	var ordered_categories: Array = []
	var entries_by_category: Dictionary = {}
	var runtime_by_category: Dictionary = {}
	var definitions_by_category: Dictionary = {}
	var performance: Dictionary = {
		"reload_total_ms": 0.0,
		"reload_count": 0
	}
	var disabled_tools: Array = []
	var set_disabled_snapshots: Array = []
	var incidents: Array = []
	var reload_statuses: Array = []
	var instantiate_failures: Dictionary = {}
	var instantiate_definitions: Dictionary = {}
	var empty_enabled_categories: Dictionary = {}
	var unloaded: Array = []
	var refresh_count := 0
	var runtime_refresh_count := 0
	var lsp_reset_count := 0
	var sync_actions: Array = []
	var refresh_replacement := {}

	func build() -> Dictionary:
		return {
			"ordered_categories": ordered_categories,
			"entries_by_category": entries_by_category,
			"runtime_by_category": runtime_by_category,
			"tool_definitions_by_category": definitions_by_category,
			"performance": performance,
			"get_ordered_categories": Callable(self, "get_ordered_categories"),
			"get_entries_by_category": Callable(self, "get_entries_by_category"),
			"get_runtime_by_category": Callable(self, "get_runtime_by_category"),
			"get_tool_definitions_by_category": Callable(self, "get_tool_definitions_by_category"),
			"get_performance": Callable(self, "get_performance"),
			"refresh_entries": Callable(self, "refresh_entries"),
			"instantiate_executor": Callable(self, "instantiate_executor"),
			"extract_tool_definitions": Callable(self, "extract_tool_definitions"),
			"record_reload_incident": Callable(self, "record_reload_incident"),
			"sync_load_error_incidents": Callable(self, "sync_load_error_incidents"),
			"refresh_runtime_context": Callable(self, "refresh_runtime_context"),
			"reset_gdscript_lsp_diagnostics_service": Callable(self, "reset_gdscript_lsp_diagnostics_service"),
			"category_has_enabled_tools": Callable(self, "category_has_enabled_tools"),
			"unload_runtime": Callable(self, "unload_runtime"),
			"make_reload_status": Callable(self, "make_reload_status"),
			"update_reload_status": Callable(self, "update_reload_status"),
			"get_disabled_tools": Callable(self, "get_disabled_tools"),
			"set_disabled_tools": Callable(self, "set_disabled_tools")
		}

	func get_ordered_categories() -> Array:
		return ordered_categories

	func get_entries_by_category() -> Dictionary:
		return entries_by_category

	func get_runtime_by_category() -> Dictionary:
		return runtime_by_category

	func get_tool_definitions_by_category() -> Dictionary:
		return definitions_by_category

	func get_performance() -> Dictionary:
		return performance

	func refresh_entries() -> void:
		refresh_count += 1
		if refresh_replacement is Dictionary and not (refresh_replacement as Dictionary).is_empty():
			entries_by_category = (refresh_replacement as Dictionary).get("entries", {}).duplicate(true)
			ordered_categories = (refresh_replacement as Dictionary).get("categories", []).duplicate()

	func instantiate_executor(category: String, _force_reload: bool, _reason: String) -> Dictionary:
		if instantiate_failures.has(category):
			return {
				"success": false,
				"error": str(instantiate_failures.get(category, "instantiate failed"))
			}
		var definitions: Array = instantiate_definitions.get(category, [{"name": "%s_probe" % category}]).duplicate(true)
		return {
			"success": true,
			"executor": FakeExecutor.new(definitions)
		}

	func extract_tool_definitions(_category: String, executor) -> Array:
		if executor is FakeExecutor:
			return (executor as FakeExecutor).definitions.duplicate(true)
		return []

	func record_reload_incident(category: String, error: String, action: String) -> void:
		incidents.append({
			"domain": category,
			"error": error,
			"action": action
		})

	func sync_load_error_incidents(action: String) -> void:
		sync_actions.append(action)

	func refresh_runtime_context() -> void:
		runtime_refresh_count += 1

	func reset_gdscript_lsp_diagnostics_service() -> void:
		lsp_reset_count += 1

	func category_has_enabled_tools(category: String) -> bool:
		return not bool(empty_enabled_categories.get(category, false))

	func unload_runtime(category: String, reason: String) -> void:
		unloaded.append({
			"domain": category,
			"reason": reason
		})

	func make_reload_status(action: String, reloaded_domains: Array, skipped_domains: Array, failed_domains: Array, elapsed_ms: float) -> Dictionary:
		return {
			"action": action,
			"reloaded_domains": reloaded_domains.duplicate(),
			"skipped_domains": skipped_domains.duplicate(),
			"failed_domains": failed_domains.duplicate(true),
			"elapsed_ms": elapsed_ms,
			"performance": performance.duplicate(true)
		}

	func update_reload_status(status: Dictionary) -> Dictionary:
		reload_statuses.append(status.duplicate(true))
		return status.duplicate(true)

	func get_disabled_tools() -> Array:
		return disabled_tools.duplicate()

	func set_disabled_tools(tools: Array) -> void:
		disabled_tools = tools.duplicate()
		set_disabled_snapshots.append(disabled_tools.duplicate())


func run_case(_tree: SceneTree) -> Dictionary:
	var service = ReloadServiceScript.new()

	var missing := FakeReloadContext.new()
	var missing_status: Dictionary = service.reload_domain("missing", missing.build())
	if not _failed_domains(missing_status).has("missing"):
		return _failure("Reload service should fail unknown domains.")

	var missing_user := FakeReloadContext.new()
	var user_status: Dictionary = service.reload_domain("user", missing_user.build())
	if not _skipped_domains(user_status).has("user") or missing_user.refresh_count != 1:
		return _failure("Reload service should refresh and skip missing user domains.")

	var skipped := FakeReloadContext.new()
	skipped.entries_by_category = {"system": {"hot_reloadable": false}}
	var skipped_status: Dictionary = service.reload_domain("system", skipped.build())
	if not _skipped_domains(skipped_status).has("system"):
		return _failure("Reload service should skip non-hot-reloadable domains.")

	var success := FakeReloadContext.new()
	success.entries_by_category = {"system": {"hot_reloadable": true}}
	success.runtime_by_category = {"system": {"version": 2, "load_count": 3}}
	success.definitions_by_category = {"system": [{"name": "old"}]}
	success.instantiate_definitions = {"system": [{"name": "new_probe"}]}
	var success_status: Dictionary = service.reload_domain("system", success.build())
	if not _reloaded_domains(success_status).has("system"):
		return _failure("Reload service should report successful domain reloads.")
	if int((success.runtime_by_category.get("system", {}) as Dictionary).get("version", 0)) != 3:
		return _failure("Reload service should increment runtime versions from previous state.")
	if str(((success.definitions_by_category.get("system", []) as Array)[0] as Dictionary).get("name", "")) != "new_probe":
		return _failure("Reload service should replace tool definitions after successful reloads.")
	if int(success.performance.get("reload_count", 0)) != 1 or success.runtime_refresh_count != 1 or success.lsp_reset_count != 1:
		return _failure("Reload service should update reload performance and dependent runtime state.")

	var instantiate_failure := FakeReloadContext.new()
	instantiate_failure.entries_by_category = {"debug": {"hot_reloadable": true}}
	instantiate_failure.runtime_by_category = {"debug": {"version": 7, "load_count": 11, "marker": "old"}}
	instantiate_failure.definitions_by_category = {"debug": [{"name": "old_debug"}]}
	instantiate_failure.instantiate_failures = {"debug": "compile failed"}
	var failure_status: Dictionary = service.reload_domain("debug", instantiate_failure.build())
	if not _failed_domains(failure_status).has("debug") or instantiate_failure.incidents.is_empty():
		return _failure("Reload service should report and record instantiate failures.")
	if str((instantiate_failure.runtime_by_category.get("debug", {}) as Dictionary).get("marker", "")) != "old":
		return _failure("Reload service should preserve previous runtime state after instantiate failures.")

	var allowed_empty := FakeReloadContext.new()
	allowed_empty.entries_by_category = {"empty": {"hot_reloadable": true, "allow_empty_definitions": true}}
	allowed_empty.instantiate_definitions = {"empty": []}
	allowed_empty.empty_enabled_categories = {"empty": true}
	var allowed_status: Dictionary = service.reload_domain("empty", allowed_empty.build())
	if not _reloaded_domains(allowed_status).has("empty") or not (allowed_empty.definitions_by_category.get("empty", ["marker"]) as Array).is_empty():
		return _failure("Reload service should allow explicitly empty definition reloads.")
	if allowed_empty.unloaded.is_empty():
		return _failure("Reload service should unload reloaded domains that have no enabled tools.")

	var rejected_empty := FakeReloadContext.new()
	rejected_empty.entries_by_category = {"empty": {"hot_reloadable": true}}
	rejected_empty.runtime_by_category = {"empty": {"version": 4, "marker": "old"}}
	rejected_empty.definitions_by_category = {"empty": [{"name": "old_empty"}]}
	rejected_empty.instantiate_definitions = {"empty": []}
	var rejected_status: Dictionary = service.reload_domain("empty", rejected_empty.build())
	if not _failed_domains(rejected_status).has("empty"):
		return _failure("Reload service should reject empty definitions unless the manifest allows them.")
	if str((rejected_empty.runtime_by_category.get("empty", {}) as Dictionary).get("marker", "")) != "old":
		return _failure("Reload service should roll back runtime state after rejected empty definitions.")

	var all := FakeReloadContext.new()
	all.ordered_categories = ["stale"]
	all.entries_by_category = {"stale": {"hot_reloadable": true}}
	all.disabled_tools = ["system_project_state"]
	all.refresh_replacement = {
		"categories": ["system", "skip", "fail"],
		"entries": {
			"system": {"hot_reloadable": true},
			"skip": {"hot_reloadable": false},
			"fail": {"hot_reloadable": true}
		}
	}
	all.instantiate_failures = {"fail": "boom"}
	var all_status: Dictionary = service.reload_all_domains(all.build())
	if not _reloaded_domains(all_status).has("system"):
		return _failure("Reload all should use refreshed category state instead of stale context snapshots.")
	if not _skipped_domains(all_status).has("skip") or not _failed_domains(all_status).has("fail"):
		return _failure("Reload all should aggregate skipped and failed domain results.")
	if all.disabled_tools != ["system_project_state"] or all.set_disabled_snapshots.is_empty():
		return _failure("Reload all should preserve disabled tools across entry refreshes.")

	return {
		"name": "tool_loader_reload_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"reload_count": int(success.performance.get("reload_count", 0)),
			"aggregate_reloaded": _reloaded_domains(all_status),
			"aggregate_failed": _failed_domains(all_status)
		}
	}


func _reloaded_domains(status: Dictionary) -> Array:
	return (status.get("reloaded_domains", []) as Array)


func _skipped_domains(status: Dictionary) -> Array:
	return (status.get("skipped_domains", []) as Array)


func _failed_domains(status: Dictionary) -> Array:
	var names: Array = []
	for failure in (status.get("failed_domains", []) as Array):
		if failure is Dictionary:
			names.append(str((failure as Dictionary).get("domain", "")))
	return names


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_reload_service_contracts",
		"success": false,
		"error": message
	}
