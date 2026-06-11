extends RefCounted

const ToolRuntimeManagerScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_runtime_manager.gd")
const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_tool_runtime_manager_contracts"
const EXECUTOR_PATH := TEMP_ROOT + "/contract_executor.gd"
const INVALID_EXECUTOR_PATH := TEMP_ROOT + "/invalid_executor.gd"

var _provided_contexts: Array[Dictionary] = []


func run_case(_tree: SceneTree) -> Dictionary:
	var setup := _write_fixture_scripts()
	if not bool(setup.get("success", false)):
		return setup

	var manager = ToolRuntimeManagerScript.new()
	manager.configure(Callable(self, "_build_context"))

	var missing_result: Dictionary = manager.instantiate_executor("missing", {}, false, "definitions")
	if bool(missing_result.get("success", true)) or str(missing_result.get("error", "")) != "Tool domain is not registered":
		return _failure("Runtime manager should reject empty domain entries.")

	var empty_path_result: Dictionary = manager.instantiate_executor("empty_path", {"path": ""}, false, "definitions")
	if bool(empty_path_result.get("success", true)) or str(empty_path_result.get("error", "")) != "Tool domain path is empty":
		return _failure("Runtime manager should reject empty script paths.")

	var invalid_result: Dictionary = manager.instantiate_executor("invalid", {"path": INVALID_EXECUTOR_PATH}, false, "definitions")
	if bool(invalid_result.get("success", true)) or str(invalid_result.get("error", "")) != "Tool executor does not expose get_tools/execute or get_tools/execute_async":
		return _failure("Runtime manager should reject scripts without the executor API.")

	var entry := {
		"path": EXECUTOR_PATH,
		"source": "contract",
		"hot_reloadable": true
	}
	var instantiate_result: Dictionary = manager.instantiate_executor("contract", entry, true, "tool_call")
	if not bool(instantiate_result.get("success", false)):
		return _failure("Runtime manager should instantiate valid executor scripts.", instantiate_result)
	var executor = instantiate_result.get("executor", null)
	if executor == null:
		return _failure("Runtime manager should return the executor instance.")

	var context = executor.get_context()
	if not (context is Dictionary):
		return _failure("Runtime manager should pass dictionary runtime context into executors.")
	if str((context as Dictionary).get("category", "")) != "contract":
		return _failure("Runtime manager should preserve context category.")
	if str((context as Dictionary).get("reason", "")) != "tool_call":
		return _failure("Runtime manager should preserve context reason.")
	if str(((context as Dictionary).get("entry", {}) as Dictionary).get("path", "")) != EXECUTOR_PATH:
		return _failure("Runtime manager should duplicate the executor entry into context.")
	if _provided_contexts.size() != 1 or str(_provided_contexts[0].get("category", "")) != "contract":
		return _failure("Runtime manager should call the configured context provider.")

	var definitions := manager.extract_tool_definitions(executor)
	if definitions.size() != 1:
		return _failure("Runtime manager should copy only dictionary tool definitions.")
	if str(definitions[0].get("name", "")) != "runtime_probe":
		return _failure("Runtime manager should preserve tool definition fields.")
	definitions[0]["name"] = "mutated"
	var fresh_definitions := manager.extract_tool_definitions(executor)
	if str(fresh_definitions[0].get("name", "")) != "runtime_probe":
		return _failure("Runtime manager should return duplicated tool definitions.")

	var execute_result: Dictionary = executor.execute("runtime_probe", {})
	if not bool(execute_result.get("success", false)):
		return _failure("Runtime manager should keep valid executor instances executable.")

	manager.dispose_executor(executor)
	if executor.get_dispose_events() != ["dispose", "shutdown", "clear"]:
		return _failure("Runtime manager should dispose executors in the legacy order.")

	return {
		"success": true,
		"name": "tool_runtime_manager_contracts",
		"context_count": _provided_contexts.size(),
		"definition_count": fresh_definitions.size()
	}


func _build_context(category: String, entry: Dictionary, reason: String) -> Dictionary:
	var context := {
		"tool_loader": "contract_loader",
		"server": "contract_server",
		"plugin_host": "contract_plugin_host",
		"tool_activity_registry": "contract_activity_registry",
		"category": category,
		"reason": reason,
		"entry": entry.duplicate(true)
	}
	_provided_contexts.append(context.duplicate(true))
	return context


func _write_fixture_scripts() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	var executor_source := "extends RefCounted\n\nvar _context := {}\nvar _dispose_events := []\n\nfunc configure_runtime(context: Dictionary) -> void:\n\t_context = context.duplicate(true)\n\nfunc get_context() -> Dictionary:\n\treturn _context.duplicate(true)\n\nfunc get_tools() -> Array:\n\treturn [\n\t\t{\"name\": \"runtime_probe\", \"description\": \"Runtime probe\", \"parameters\": {}},\n\t\t\"ignored\"\n\t]\n\nfunc execute(tool_name: String, _args: Dictionary) -> Dictionary:\n\treturn {\"success\": tool_name == \"runtime_probe\", \"data\": {\"tool_name\": tool_name}}\n\nfunc dispose() -> void:\n\t_dispose_events.append(\"dispose\")\n\nfunc shutdown() -> void:\n\t_dispose_events.append(\"shutdown\")\n\nfunc clear() -> void:\n\t_dispose_events.append(\"clear\")\n\nfunc get_dispose_events() -> Array:\n\treturn _dispose_events.duplicate()\n"
	var invalid_source := "extends RefCounted\n\nfunc get_tools() -> Array:\n\treturn []\n"
	var write_executor := _write_text(EXECUTOR_PATH, executor_source)
	if not bool(write_executor.get("success", false)):
		return write_executor
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
		"success": false,
		"name": "tool_runtime_manager_contracts",
		"error": message,
		"data": data
	}
