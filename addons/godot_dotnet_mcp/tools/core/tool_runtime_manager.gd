@tool
extends RefCounted
class_name ToolRuntimeManager

var _runtime_context_provider := Callable()


func configure(runtime_context_provider: Callable = Callable()) -> void:
	_runtime_context_provider = runtime_context_provider


func instantiate_executor(category: String, entry: Dictionary, force_reload: bool, reason: String) -> Dictionary:
	if entry.is_empty():
		return {"success": false, "error": "Tool domain is not registered"}

	var path = str(entry.get("path", ""))
	if path.is_empty():
		return {"success": false, "error": "Tool domain path is empty"}

	var script_resource = load_script_resource(path, force_reload)
	if script_resource == null:
		return {"success": false, "error": "Failed to load tool script"}
	if script_resource is Script and not script_resource.can_instantiate():
		# Stale cache recovery: reload from disk and refresh external script dependencies.
		script_resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if script_resource == null:
			return {"success": false, "error": "Failed to load tool script"}
		if script_resource is Script and not script_resource.can_instantiate():
			return {"success": false, "error": "Tool script could not be instantiated [replace_reload_failed]"}
	if not script_resource.has_method("new"):
		return {"success": false, "error": "Loaded tool resource is not instantiable"}

	var executor = script_resource.new()
	if executor == null:
		return {"success": false, "error": "Tool executor instance creation returned null"}
	if not executor.has_method("get_tools") or (not executor.has_method("execute") and not executor.has_method("execute_async")):
		return {"success": false, "error": "Tool executor does not expose get_tools/execute or get_tools/execute_async"}
	if executor.has_method("configure_runtime"):
		executor.configure_runtime(_build_runtime_context(category, entry, reason))

	return {
		"success": true,
		"executor": executor
	}


func extract_tool_definitions(executor) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	if executor == null or not executor.has_method("get_tools"):
		return definitions
	for tool_def in executor.get_tools():
		if not (tool_def is Dictionary):
			continue
		definitions.append((tool_def as Dictionary).duplicate(true))
	return definitions


func dispose_executor(executor) -> void:
	if executor == null:
		return
	if executor.has_method("dispose"):
		executor.dispose()
	if executor.has_method("shutdown"):
		executor.shutdown()
	if executor.has_method("clear"):
		executor.clear()


func load_script_resource(path: String, force_reload: bool) -> Resource:
	var cache_mode = ResourceLoader.CACHE_MODE_REUSE
	if force_reload:
		cache_mode = ResourceLoader.CACHE_MODE_IGNORE_DEEP
	return ResourceLoader.load(path, "", cache_mode)


func _build_runtime_context(category: String, entry: Dictionary, reason: String) -> Dictionary:
	if _runtime_context_provider.is_valid():
		var provided = _runtime_context_provider.call(category, entry, reason)
		if provided is Dictionary:
			return (provided as Dictionary).duplicate(true)
	return {
		"category": category,
		"reason": reason,
		"entry": entry.duplicate(true)
	}
