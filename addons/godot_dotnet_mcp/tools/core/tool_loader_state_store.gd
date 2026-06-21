@tool
extends RefCounted
class_name ToolLoaderStateStore

var entries_by_category: Dictionary = {}
var ordered_categories: Array[String] = []
var runtime_by_category: Dictionary = {}
var tool_definitions_by_category: Dictionary = {}
var force_reload_script_load := false
var performance: Dictionary = {
	"startup_ms": 0.0,
	"definition_scan_ms": 0.0,
	"preload_ms": 0.0,
	"reload_total_ms": 0.0,
	"reload_count": 0
}


func reset(diagnostics_service) -> void:
	entries_by_category.clear()
	ordered_categories.clear()
	runtime_by_category.clear()
	tool_definitions_by_category.clear()
	if diagnostics_service != null and diagnostics_service.has_method("clear_load_errors"):
		diagnostics_service.clear_load_errors()


func refresh_entries(registry, entry_service, diagnostics_service, sync_load_error_incidents: Callable) -> void:
	if registry == null or entry_service == null or not registry.has_method("collect_entries") or not entry_service.has_method("build_index"):
		return
	var index: Dictionary = entry_service.build_index(registry.collect_entries())
	var new_entries: Dictionary = _dictionary(index.get("entries_by_category", {}))
	var new_order: Array = _array(index.get("ordered_categories", []))
	if diagnostics_service != null and diagnostics_service.has_method("replace_load_errors"):
		diagnostics_service.replace_load_errors(index.get("load_errors", []))

	for existing_category in runtime_by_category.keys():
		if not new_entries.has(existing_category):
			runtime_by_category.erase(existing_category)
			tool_definitions_by_category.erase(existing_category)

	_replace_dictionary_ref(entries_by_category, new_entries)
	_replace_string_array_ref(ordered_categories, new_order)
	if sync_load_error_incidents.is_valid():
		sync_load_error_incidents.call("refresh_entries")


func record_load_error(category: String, path: String, message: String, diagnostics_service) -> void:
	if diagnostics_service == null or not diagnostics_service.has_method("record_load_error"):
		return
	var error_info: Dictionary = diagnostics_service.record_load_error(category, path, message)
	var runtime: Dictionary = _dictionary(runtime_by_category.get(category, {}))
	runtime["last_error"] = error_info.duplicate(true)
	runtime_by_category[category] = runtime


func entry_for(category: String) -> Dictionary:
	return _dictionary(entries_by_category.get(category, {}))


func get_ordered_categories() -> Array:
	return ordered_categories


func get_entries_by_category() -> Dictionary:
	return entries_by_category


func get_runtime_by_category() -> Dictionary:
	return runtime_by_category


func get_tool_definitions_by_category() -> Dictionary:
	return tool_definitions_by_category


func get_performance() -> Dictionary:
	return performance


func set_force_reload_script_load(enabled: bool) -> void:
	force_reload_script_load = enabled


func get_force_reload_script_load() -> bool:
	return force_reload_script_load


func build_catalog_projection_context(callbacks: Dictionary) -> Dictionary:
	var context := _state_context()
	context.merge(callbacks, true)
	return context


func build_reload_context(callbacks: Dictionary) -> Dictionary:
	var context := _state_context()
	context["performance"] = performance
	context["get_ordered_categories"] = Callable(self, "get_ordered_categories")
	context["get_entries_by_category"] = Callable(self, "get_entries_by_category")
	context["get_runtime_by_category"] = Callable(self, "get_runtime_by_category")
	context["get_tool_definitions_by_category"] = Callable(self, "get_tool_definitions_by_category")
	context["get_performance"] = Callable(self, "get_performance")
	context.merge(callbacks, true)
	return context


func build_runtime_state_context(callbacks: Dictionary) -> Dictionary:
	var context := _state_context()
	context["force_reload_script_load"] = force_reload_script_load
	context["get_entries_by_category"] = Callable(self, "get_entries_by_category")
	context["get_runtime_by_category"] = Callable(self, "get_runtime_by_category")
	context["get_tool_definitions_by_category"] = Callable(self, "get_tool_definitions_by_category")
	context["get_force_reload_script_load"] = Callable(self, "get_force_reload_script_load")
	context.merge(callbacks, true)
	return context


func build_lifecycle_context(callbacks: Dictionary) -> Dictionary:
	var context := {
		"ordered_categories": ordered_categories,
		"entries_by_category": entries_by_category,
		"runtime_by_category": runtime_by_category,
		"tool_definitions_by_category": tool_definitions_by_category,
		"performance": performance,
		"set_force_reload_script_load": Callable(self, "set_force_reload_script_load"),
		"get_entries_by_category": Callable(self, "get_entries_by_category"),
		"get_runtime_by_category": Callable(self, "get_runtime_by_category"),
		"get_tool_definitions_by_category": Callable(self, "get_tool_definitions_by_category"),
		"get_ordered_categories": Callable(self, "get_ordered_categories")
	}
	context.merge(callbacks, true)
	return context


func _state_context() -> Dictionary:
	return {
		"ordered_categories": ordered_categories,
		"entries_by_category": entries_by_category,
		"runtime_by_category": runtime_by_category,
		"tool_definitions_by_category": tool_definitions_by_category
	}


func _replace_dictionary_ref(target: Dictionary, source: Dictionary) -> void:
	target.clear()
	for key in source.keys():
		target[key] = source[key]


func _replace_string_array_ref(target: Array[String], source: Array) -> void:
	target.clear()
	for value in source:
		target.append(str(value))


func _dictionary(value) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _array(value) -> Array:
	if value is Array:
		return value
	return []
