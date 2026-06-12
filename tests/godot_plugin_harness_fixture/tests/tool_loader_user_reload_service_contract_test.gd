extends RefCounted

const UserReloadServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_user_reload_service.gd")


class FakeExecutor:
	extends RefCounted

	var requested: Array = []
	var snapshot: Array = [{"path": "res://addons/user_tool.gd", "state": "loaded"}]

	func request_reload_by_script(script_path: String, reason: String) -> void:
		requested.append({
			"script_path": script_path,
			"reason": reason
		})

	func get_runtime_state_snapshot() -> Array:
		return snapshot.duplicate(true)


class FakeUserReloadContext:
	extends RefCounted

	var entries_by_category: Dictionary = {}
	var runtime_by_category: Dictionary = {}
	var definitions_by_category: Dictionary = {}
	var category_enabled := true
	var ensure_calls: Array = []
	var tick_calls: Array = []
	var applied_tick_results: Array = []
	var refresh_count := 0
	var ensure_executor: FakeExecutor = null

	func build() -> Dictionary:
		return {
			"entries_by_category": entries_by_category,
			"runtime_by_category": runtime_by_category,
			"tool_definitions_by_category": definitions_by_category,
			"get_entries_by_category": Callable(self, "get_entries_by_category"),
			"get_runtime_by_category": Callable(self, "get_runtime_by_category"),
			"get_tool_definitions_by_category": Callable(self, "get_tool_definitions_by_category"),
			"category_has_enabled_tools": Callable(self, "category_has_enabled_tools"),
			"ensure_runtime_loaded": Callable(self, "ensure_runtime_loaded"),
			"tick_loaded_runtimes": Callable(self, "tick_loaded_runtimes"),
			"apply_tick_result": Callable(self, "apply_tick_result"),
			"refresh_runtime_context": Callable(self, "refresh_runtime_context")
		}

	func get_entries_by_category() -> Dictionary:
		return entries_by_category

	func get_runtime_by_category() -> Dictionary:
		return runtime_by_category

	func get_tool_definitions_by_category() -> Dictionary:
		return definitions_by_category

	func category_has_enabled_tools(category: String) -> bool:
		return category == "user" and category_enabled

	func ensure_runtime_loaded(category: String, reason: String) -> Dictionary:
		ensure_calls.append({"category": category, "reason": reason})
		if ensure_executor != null:
			runtime_by_category["user"] = {"instance": ensure_executor, "state": "loaded"}
		return {"success": ensure_executor != null, "runtime": runtime_by_category.get("user", {})}

	func tick_loaded_runtimes(runtime_subset: Dictionary, definitions: Dictionary, delta: float) -> Dictionary:
		tick_calls.append({
			"runtime_keys": runtime_subset.keys(),
			"definition_count": definitions.size(),
			"delta": delta
		})
		return {
			"user_definitions_changed": true,
			"user_definitions": [{"name": "user_reloaded_probe"}]
		}

	func apply_tick_result(result: Dictionary) -> void:
		applied_tick_results.append(result.duplicate(true))
		if bool(result.get("user_definitions_changed", false)):
			definitions_by_category["user"] = (result.get("user_definitions", []) as Array).duplicate(true)

	func refresh_runtime_context() -> void:
		refresh_count += 1


func run_case(_tree: SceneTree) -> Dictionary:
	var service = UserReloadServiceScript.new()

	var missing_path := FakeUserReloadContext.new()
	var missing_path_status: Dictionary = service.request_reload_by_script("   ", "manual", missing_path.build())
	if bool(missing_path_status.get("success", true)) or str(missing_path_status.get("error", "")) != "Missing script path":
		return _failure("User reload service should reject blank script paths.")

	var missing_user := FakeUserReloadContext.new()
	var missing_user_status: Dictionary = service.request_reload_by_script("res://addons/tool.gd", "manual", missing_user.build())
	if bool(missing_user_status.get("success", true)) or str(missing_user_status.get("error", "")) != "User domain is not registered":
		return _failure("User reload service should fail when the user domain is absent.")

	var unavailable := FakeUserReloadContext.new()
	unavailable.entries_by_category = {"user": {"path": "res://addons/user/executor.gd"}}
	unavailable.category_enabled = false
	var unavailable_status: Dictionary = service.request_reload_by_script("res://addons/tool.gd", "manual", unavailable.build())
	if bool(unavailable_status.get("success", true)) or str(unavailable_status.get("error", "")) != "User runtime is unavailable":
		return _failure("User reload service should fail when runtime loading cannot provide a user executor.")
	if unavailable.ensure_calls.is_empty():
		return _failure("User reload service should attempt to load the disabled user runtime before failing.")

	var executor := FakeExecutor.new()
	var success := FakeUserReloadContext.new()
	success.entries_by_category = {"user": {"path": "res://addons/user/executor.gd"}}
	success.runtime_by_category = {"user": {"instance": executor, "state": "loaded"}}
	success.definitions_by_category = {"user": [{"name": "old_user_tool"}]}
	var success_status: Dictionary = service.request_reload_by_script(" res://addons/tool.gd ", "watcher_file_changed", success.build())
	if not bool(success_status.get("success", false)):
		return _failure("User reload service should report successful script reload requests.")
	if str(success_status.get("script_path", "")) != "res://addons/tool.gd":
		return _failure("User reload service should normalize script paths.")
	if executor.requested.size() != 1 or str((executor.requested[0] as Dictionary).get("reason", "")) != "watcher_file_changed":
		return _failure("User reload service should pass normalized script reload requests to the executor.")
	if success.tick_calls.size() != 1 or success.applied_tick_results.size() != 1 or success.refresh_count != 1:
		return _failure("User reload service should tick the user runtime and refresh runtime context after successful requests.")
	if str(((success.definitions_by_category.get("user", []) as Array)[0] as Dictionary).get("name", "")) != "user_reloaded_probe":
		return _failure("User reload service should apply user definition updates from the tick result.")

	var loaded_by_service_executor := FakeExecutor.new()
	var loaded_by_service := FakeUserReloadContext.new()
	loaded_by_service.entries_by_category = {"user": {"path": "res://addons/user/executor.gd"}}
	loaded_by_service.category_enabled = false
	loaded_by_service.ensure_executor = loaded_by_service_executor
	var loaded_status: Dictionary = service.request_reload_by_script("res://addons/new_tool.gd", "manual", loaded_by_service.build())
	if not bool(loaded_status.get("success", false)) or loaded_by_service.ensure_calls.is_empty():
		return _failure("User reload service should use newly ensured user runtimes.")

	var snapshot := service.get_user_tool_runtime_snapshot(success.build())
	if snapshot.is_empty():
		return _failure("User reload service should expose user runtime snapshots.")
	(snapshot[0] as Dictionary)["state"] = "mutated"
	var snapshot_again := service.get_user_tool_runtime_snapshot(success.build())
	if str((snapshot_again[0] as Dictionary).get("state", "")) != "loaded":
		return _failure("User reload service should return isolated runtime snapshot copies.")

	return {
		"name": "tool_loader_user_reload_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"tick_calls": success.tick_calls.size(),
			"ensure_calls": loaded_by_service.ensure_calls.size(),
			"snapshot_count": snapshot_again.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_user_reload_service_contracts",
		"success": false,
		"error": message
	}
