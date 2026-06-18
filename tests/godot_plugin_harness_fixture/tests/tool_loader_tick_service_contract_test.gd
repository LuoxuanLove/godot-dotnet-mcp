extends RefCounted

const TickServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_tick_service.gd")


class FakeExecutor:
	extends RefCounted

	var ticked_delta := 0.0
	var tools: Array = [{"name": "runtime_probe", "description": "Runtime probe", "parameters": {}}]
	var should_unload := false
	var definitions_revision := 0

	func tick(delta: float) -> void:
		ticked_delta = delta

	func get_tools() -> Array:
		return tools.duplicate(true)

	func should_unload_runtime() -> bool:
		return should_unload

	func get_definitions_revision() -> int:
		return definitions_revision


var _extract_call_count := 0


func run_case(_tree: SceneTree) -> Dictionary:
	var service = TickServiceScript.new()
	_extract_call_count = 0

	var system_executor := FakeExecutor.new()
	var user_executor := FakeExecutor.new()
	user_executor.tools = [{"name": "user_probe", "description": "User probe", "parameters": {}}]
	var runtime_by_category := {
		"system": {"instance": system_executor},
		"user": {"instance": user_executor},
		"plain": {"instance": RefCounted.new()},
		"invalid": "not-a-runtime"
	}
	var tool_definitions_by_category := {
		"user": [{"name": "old_user_probe", "description": "Old user probe", "parameters": {}}]
	}

	var result: Dictionary = service.tick_loaded_runtimes(
		runtime_by_category,
		tool_definitions_by_category,
		0.25,
		Callable(self, "_extract_definitions")
	)
	if not ((result.get("ticked_categories", []) as Array).has("system")):
		return _failure("Tick service should tick loaded system executors.")
	if not ((result.get("ticked_categories", []) as Array).has("user")):
		return _failure("Tick service should tick loaded user executors.")
	if not is_equal_approx(system_executor.ticked_delta, 0.25) or not is_equal_approx(user_executor.ticked_delta, 0.25):
		return _failure("Tick service should pass the frame delta to executor tick methods.")
	if not bool(result.get("user_definitions_changed", false)):
		return _failure("Tick service should report changed user tool definitions.")
	if _extract_call_count != 1:
		return _failure("Tick service should extract user definitions exactly once when the revision changes.")
	var user_defs: Array = result.get("user_definitions", [])
	if user_defs.size() != 1 or str((user_defs[0] as Dictionary).get("name", "")) != "user_probe":
		return _failure("Tick service should return the refreshed user definitions.")
	user_defs[0]["name"] = "mutated"
	if str(user_executor.tools[0].get("name", "")) != "user_probe":
		return _failure("Tick service should isolate returned user definition snapshots.")
	if bool(result.get("user_should_unload", true)):
		return _failure("Tick service should not unload active user runtimes unless requested.")

	user_executor.tools = [{"name": "user_probe", "description": "User probe", "parameters": {}}]
	user_executor.should_unload = true
	_extract_call_count = 0
	var idle_result: Dictionary = service.tick_loaded_runtimes(
		{"user": {"instance": user_executor}},
		{"user": [{"name": "user_probe", "description": "User probe", "parameters": {}}]},
		0.5,
		Callable(self, "_extract_definitions")
	)
	if bool(idle_result.get("user_definitions_changed", true)):
		return _failure("Tick service should not report unchanged user definitions.")
	if _extract_call_count != 0:
		return _failure("Tick service should skip user definition extraction when the revision is unchanged.")
	if not bool(idle_result.get("user_should_unload", false)):
		return _failure("Tick service should report user runtime unload requests.")

	service.invalidate_user_definitions()
	_extract_call_count = 0
	var invalidated_result: Dictionary = service.tick_loaded_runtimes(
		{"user": {"instance": user_executor}},
		{"user": [{"name": "user_probe", "description": "User probe", "parameters": {}}]},
		0.5,
		Callable(self, "_extract_definitions")
	)
	if _extract_call_count != 1:
		return _failure("Tick service should re-extract user definitions after explicit invalidation.")
	if bool(invalidated_result.get("user_definitions_changed", true)):
		return _failure("Tick service should treat equivalent invalidated definitions as unchanged.")

	user_executor.definitions_revision += 1
	_extract_call_count = 0
	var revised_result: Dictionary = service.tick_loaded_runtimes(
		{"user": {"instance": user_executor}},
		{"user": [{"name": "user_probe", "description": "User probe", "parameters": {}}]},
		0.5,
		Callable(self, "_extract_definitions")
	)
	if _extract_call_count != 1:
		return _failure("Tick service should re-extract user definitions after the revision changes.")
	if bool(revised_result.get("user_definitions_changed", true)):
		return _failure("Tick service should treat equivalent refreshed definitions as unchanged after a revision bump.")

	var replacement_executor := FakeExecutor.new()
	replacement_executor.tools = [{"name": "replacement_probe", "description": "Replacement probe", "parameters": {}}]
	replacement_executor.definitions_revision = user_executor.definitions_revision
	_extract_call_count = 0
	var replacement_result: Dictionary = service.tick_loaded_runtimes(
		{"user": {"instance": replacement_executor}},
		{"user": [{"name": "user_probe", "description": "User probe", "parameters": {}}]},
		0.5,
		Callable(self, "_extract_definitions")
	)
	if _extract_call_count != 1:
		return _failure("Tick service should refresh user definitions when the executor instance changes.")
	var replacement_defs: Array = replacement_result.get("user_definitions", [])
	if replacement_defs.size() != 1 or str((replacement_defs[0] as Dictionary).get("name", "")) != "replacement_probe":
		return _failure("Tick service should surface refreshed definitions from a replacement executor instance.")

	var missing_executor_result: Dictionary = service.tick_loaded_runtimes(
		{"user": {"instance": null}},
		{"user": []},
		0.1,
		Callable(self, "_extract_definitions")
	)
	if not bool(missing_executor_result.get("user_should_unload", false)):
		return _failure("Tick service should unload empty user runtime shells with no executor.")

	return {
		"name": "tool_loader_tick_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"ticked_categories": result.get("ticked_categories", []),
			"user_definitions_changed": bool(result.get("user_definitions_changed", false)),
			"user_should_unload": bool(idle_result.get("user_should_unload", false))
		}
	}


func _extract_definitions(_category: String, executor) -> Array:
	_extract_call_count += 1
	if executor != null and executor.has_method("get_tools"):
		return executor.get_tools()
	return []


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_tick_service_contracts",
		"success": false,
		"error": message
	}
