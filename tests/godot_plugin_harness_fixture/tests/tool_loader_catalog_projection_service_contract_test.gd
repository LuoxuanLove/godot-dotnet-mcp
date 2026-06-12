extends RefCounted

const ToolLoaderCatalogProjectionServiceScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader_catalog_projection_service.gd")

var _definitions_by_category: Dictionary = {}
var _visible_categories: Dictionary = {}
var _disabled_tools: Dictionary = {}
var _removed_full_names: Dictionary = {}
var _exposed_categories: Dictionary = {}


func run_case(_tree: SceneTree) -> Dictionary:
	_definitions_by_category = {
		"system": [
			{
				"name": "project_state",
				"description": "Project state",
				"parameters": {}
			},
			{
				"name": "help",
				"description": "Removed help",
				"parameters": {}
			}
		],
		"debug": [
			{
				"name": "log_write",
				"description": "Debug log write",
				"parameters": {},
				"script_path": "res://custom/debug_log_write.gd"
			}
		],
		"hidden": [
			{
				"name": "probe",
				"description": "Hidden probe",
				"parameters": {}
			}
		]
	}
	_visible_categories = {"system": true, "debug": true, "hidden": false}
	_disabled_tools = {"system_project_state": true}
	_removed_full_names = {"system_help": true}
	_exposed_categories = {"system": true, "user": true}

	var service = ToolLoaderCatalogProjectionServiceScript.new()
	var context := _build_context()
	var visible_groups: Dictionary = service.build_tools_by_category(context, true)
	if not visible_groups.has("system") or not visible_groups.has("debug"):
		return _failure("Catalog projection should include visible categories.")
	if visible_groups.has("hidden"):
		return _failure("Catalog projection should hide categories rejected by the visibility callback.")
	var system_defs: Array = visible_groups.get("system", [])
	if system_defs.size() != 1:
		return _failure("Catalog projection should remove public-removed tool definitions from visible groups.")
	var system_project_state: Dictionary = system_defs[0]
	if str(system_project_state.get("category", "")) != "system":
		return _failure("Catalog projection should decorate grouped tool category.")
	if str(system_project_state.get("full_name", "")) != "system_project_state":
		return _failure("Catalog projection should decorate grouped tool full_name.")
	if bool(system_project_state.get("enabled", true)):
		return _failure("Catalog projection should decorate disabled tool state.")
	if str(system_project_state.get("load_state", "")) != "loaded":
		return _failure("Catalog projection should decorate runtime load state.")
	if str(system_project_state.get("source", "")) != "builtin":
		return _failure("Catalog projection should decorate entry source.")
	if str(system_project_state.get("domain_script_path", "")) != "res://addons/system_executor.gd":
		return _failure("Catalog projection should decorate entry domain script path.")
	if str(system_project_state.get("script_path", "")) != "res://addons/system_executor.gd":
		return _failure("Catalog projection should default tool script_path to domain script path.")
	if str(system_project_state.get("domain_key", "")) != "system":
		return _failure("Catalog projection should decorate entry domain key.")

	var visible_definitions := service.build_tool_definitions(context, true)
	if _has_tool_name(visible_definitions, "hidden_probe"):
		return _failure("Visible flat definitions should respect category visibility.")
	if not _has_tool_name(visible_definitions, "system_help"):
		return _failure("Flat definitions should retain legacy removed definitions for replacement guidance.")
	var exposed_definitions := service.build_exposed_tool_definitions(context, visible_definitions)
	if _has_tool_name(exposed_definitions, "system_project_state"):
		return _failure("Exposed definitions should filter disabled tools.")
	if _has_tool_name(exposed_definitions, "debug_log_write"):
		return _failure("Exposed definitions should filter non-public categories.")
	if not _has_tool_name(exposed_definitions, "system_help"):
		return _failure("Exposed definitions should keep callable removed public tools for replacement routing when enabled.")

	var all_definitions := service.build_tool_definitions(context, false)
	if not _has_tool_name(all_definitions, "hidden_probe"):
		return _failure("All flat definitions should include hidden/internal categories.")

	var domain_states := service.build_domain_states(context, true)
	if domain_states.size() != 2:
		return _failure("Visible domain states should include only visible categories.")
	var system_state := _find_domain_state(domain_states, "system")
	if system_state.is_empty():
		return _failure("Domain states should include the system category.")
	if not bool(system_state.get("loaded", false)):
		return _failure("Domain states should report loaded runtime instances.")
	if str(system_state.get("load_state", "")) != "loaded":
		return _failure("Domain states should preserve runtime load_state.")
	if int(system_state.get("tool_count", 0)) != 2:
		return _failure("Domain states should count all category definitions.")
	if int(system_state.get("enabled_tool_count", -1)) != 1:
		return _failure("Domain states should count enabled tools through the callback.")
	if int(system_state.get("version", 0)) != 4 or int(system_state.get("load_count", 0)) != 6:
		return _failure("Domain states should project runtime version and load count.")
	var last_error: Dictionary = system_state.get("last_error", {})
	last_error["message"] = "mutated"
	var domain_states_after_mutation := service.build_domain_states(context, true)
	var system_state_after_mutation := _find_domain_state(domain_states_after_mutation, "system")
	if str((system_state_after_mutation.get("last_error", {}) as Dictionary).get("message", "")) != "original error":
		return _failure("Domain states should deep-copy last_error diagnostics.")

	return {
		"name": "tool_loader_catalog_projection_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"visible_groups": visible_groups.size(),
			"visible_definitions": visible_definitions.size(),
			"domain_states": domain_states.size()
		}
	}


func _build_context() -> Dictionary:
	return {
		"ordered_categories": ["system", "debug", "hidden"],
		"entries_by_category": {
			"system": {
				"source": "builtin",
				"path": "res://addons/system_executor.gd",
				"domain_key": "system",
				"hot_reloadable": true
			},
			"debug": {
				"source": "builtin",
				"path": "res://addons/debug_executor.gd",
				"domain_key": "core",
				"hot_reloadable": false
			},
			"hidden": {
				"source": "user",
				"path": "res://addons/hidden_executor.gd",
				"domain_key": "user"
			}
		},
		"runtime_by_category": {
			"system": {
				"instance": RefCounted.new(),
				"state": "loaded",
				"version": 4,
				"load_count": 6,
				"last_loaded_at_unix": 1234,
				"last_error": {
					"message": "original error"
				}
			},
			"debug": {
				"state": "definitions_only",
				"version": 1
			}
		},
		"tool_definitions_by_category": _definitions_by_category,
		"ensure_tool_definitions": Callable(self, "_ensure_tool_definitions"),
		"is_category_visible": Callable(self, "_is_category_visible"),
		"is_tool_enabled": Callable(self, "_is_tool_enabled"),
		"is_exposed_tool_definition": Callable(self, "_is_exposed_tool_definition"),
		"is_public_removed_tool_definition": Callable(self, "_is_public_removed_tool_definition")
	}


func _ensure_tool_definitions(category: String) -> Array:
	return (_definitions_by_category.get(category, []) as Array).duplicate(true)


func _is_category_visible(category: String) -> bool:
	return bool(_visible_categories.get(category, false))


func _is_tool_enabled(full_name: String) -> bool:
	return not bool(_disabled_tools.get(full_name, false))


func _is_exposed_tool_definition(tool_def: Dictionary) -> bool:
	return bool(_exposed_categories.get(str(tool_def.get("category", "")), false))


func _is_public_removed_tool_definition(tool_def: Dictionary) -> bool:
	return bool(_removed_full_names.get(str(tool_def.get("full_name", "")), false))


func _has_tool_name(definitions: Array, name: String) -> bool:
	for tool_def in definitions:
		if tool_def is Dictionary and str((tool_def as Dictionary).get("name", "")) == name:
			return true
	return false


func _find_domain_state(states: Array, category: String) -> Dictionary:
	for state in states:
		if state is Dictionary and str((state as Dictionary).get("category", "")) == category:
			return (state as Dictionary).duplicate(true)
	return {}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_loader_catalog_projection_service_contracts",
		"success": false,
		"error": message
	}
