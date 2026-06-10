extends RefCounted

# {"name": "tool_catalog_snapshot_service_contracts"}

const ToolCatalogSnapshotService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_snapshot_service.gd")
const ToolCatalogSearchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_search_service.gd")
const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")
const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")

var _real_loaders: Array = []


class FakeServerContext extends RefCounted:
	var _tool_access_provider
	var _runtime_control_service

	func _init(tool_access_provider, runtime_control_service = null) -> void:
		_tool_access_provider = tool_access_provider
		_runtime_control_service = runtime_control_service

	func get_tool_access_provider():
		return _tool_access_provider

	func get_runtime_control_service():
		return _runtime_control_service


class FakeToolAccessProvider extends RefCounted:
	var hidden_categories := {}

	func _init(categories_to_hide: Array = []) -> void:
		for category in categories_to_hide:
			hidden_categories[str(category)] = true

	func is_tool_category_visible(category: String) -> bool:
		return not hidden_categories.has(category)

	func is_tool_category_executable(category: String) -> bool:
		return not hidden_categories.has(category)

	func get_tool_access_denied_message(_category: String) -> String:
		return "Tool category disabled"


class FakeRuntimeControlService extends RefCounted:
	func get_status() -> Dictionary:
		return {
			"available": true,
			"armed": false,
			"message": "Runtime control is disabled for the current session."
		}


class FakeToolLoader:
	extends RefCounted

	var exposed_tools := [{
		"name": "system_project_state",
		"description": "Inspect project state and runtime health",
		"category": "system",
		"domain_key": "core",
		"enabled": true,
		"inputSchema": {
			"type": "object",
			"properties": {
				"sections": {"type": "array", "description": "Select summary, runtime, or health sections."}
			}
		}
	}, {
		"name": "system_settings_dialog",
		"description": "Settings dialog workflow",
		"category": "system",
		"domain_key": "core",
		"enabled": true,
		"inputSchema": {
			"type": "object",
			"properties": {
				"action": {"type": "string", "enum": ["open", "run_task"], "description": "Settings action"}
			}
		}
	}]

	var removed_tool := {
		"name": "system_tool_activity",
		"description": "Removed public activity diagnostics entry",
		"category": "system",
		"domain_key": "core",
		"enabled": true,
		"inputSchema": {"type": "object", "properties": {}}
	}

	func get_exposed_tool_definitions() -> Array:
		var tools := exposed_tools.duplicate(true)
		tools.append(removed_tool.duplicate(true))
		return tools

	func get_tool_definitions() -> Array:
		var tools := get_exposed_tool_definitions()
		tools.append({
			"name": "project_input",
			"description": "Manage input action mappings",
			"category": "project",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["list_actions", "get_action"], "description": "Input map action"}
				}
			}
		})
		return tools

	func get_all_tools_by_category() -> Dictionary:
		return {
			"system": [{
				"name": "project_state",
				"full_name": "system_project_state",
				"category": "system",
				"domain_key": "core",
				"enabled": true,
				"inputSchema": {
					"type": "object",
					"properties": {
						"sections": {"type": "array", "description": "Select summary, runtime, or health sections."}
					}
				}
			}, {
				"name": "settings_dialog",
				"full_name": "system_settings_dialog",
				"category": "system",
				"domain_key": "core",
				"enabled": true,
				"inputSchema": {
					"type": "object",
					"properties": {
						"action": {"type": "string", "enum": ["open", "run_task"], "description": "Settings action"}
					}
				}
			}, {
				"name": "tool_activity",
				"full_name": "system_tool_activity",
				"category": "system",
				"domain_key": "core",
				"enabled": true,
				"inputSchema": {"type": "object", "properties": {}}
			}],
			"project": [{
				"name": "input",
				"full_name": "project_input",
				"category": "project",
				"domain_key": "core",
				"enabled": true,
				"inputSchema": {
					"type": "object",
					"properties": {
						"action": {"type": "string", "enum": ["list_actions", "get_action"], "description": "Input map action"}
					}
				}
			}],
			"material": [{
				"name": "create_material",
				"full_name": "material_create_material",
				"category": "material",
				"domain_key": "visual",
				"enabled": true,
				"inputSchema": {
					"type": "object",
					"properties": {
						"action": {"type": "string", "enum": ["create"], "description": "Material action"}
					}
				}
			}]
		}

	func get_domain_states() -> Array:
		return [
			{"domain": "system", "category": "system", "domain_key": "core", "loaded": true, "tool_count": 2, "enabled_tool_count": 2},
			{"domain": "project", "category": "project", "domain_key": "core", "loaded": true, "tool_count": 1, "enabled_tool_count": 1},
			{"domain": "material", "category": "material", "domain_key": "visual", "loaded": true, "tool_count": 1, "enabled_tool_count": 1},
			{"domain": "user", "domain_key": "user", "loaded": true}
		]

	func get_tool_loader_status() -> Dictionary:
		return {"healthy": true, "status": "ready", "tool_count": 4, "exposed_tool_count": 3}

	func is_public_removed_tool(tool_name: String) -> bool:
		return tool_name == "system_tool_activity"


func run_case(_tree: SceneTree) -> Dictionary:
	var loader := FakeToolLoader.new()
	var snapshot: Dictionary = ToolCatalogSnapshotService.build_snapshot(loader)
	if not bool(snapshot.get("success", false)):
		return _failure("Snapshot build should succeed for a loader with exposed definitions.")

	for key in ["exposed_tools", "visible_tools", "all_tools_by_category", "category_states", "domain_states", "presentation", "tool_loader_status"]:
		if not snapshot.has(key):
			return _failure("Snapshot should include %s." % key)

	var exposed_tools: Array = snapshot.get("exposed_tools", [])
	var visible_tools: Array = snapshot.get("visible_tools", [])
	if _tool_names(exposed_tools) != ["system_project_state", "system_settings_dialog"]:
		return _failure("Snapshot should include only non-removed exposed tools.")
	if _tool_names(visible_tools) != ["project_input", "system_project_state", "system_settings_dialog"]:
		return _failure("Snapshot should include non-removed visible tools, including internal tools.")

	var tools_by_category: Dictionary = snapshot.get("all_tools_by_category", {})
	var system_tools: Array = tools_by_category.get("system", [])
	for removed_system_tool in ["system_plugin_reload", "system_plugin_update", "system_tool_activity"]:
		if _category_full_names("system", system_tools).has(removed_system_tool):
			return _failure("Snapshot category catalog should filter removed public tool %s." % removed_system_tool)
	if _category_full_names("system", system_tools).has("system_tool_activity"):
		return _failure("Snapshot category catalog should filter removed public tools.")
	if not _category_full_names("project", tools_by_category.get("project", [])).has("project_input"):
		return _failure("Snapshot category catalog should preserve non-removed internal visible tools.")

	var category_states: Array = snapshot.get("category_states", [])
	if category_states.size() < 4:
		return _failure("Snapshot should preserve category-grained loader states.")
	var domain_states: Array = snapshot.get("domain_states", [])
	var core_state := _find_state(domain_states, "core")
	if core_state.is_empty():
		return _failure("Snapshot should aggregate core category states into one domain state.")
	if (core_state.get("categories", []) as Array) != ["project", "system"]:
		return _failure("Core domain state should retain sorted source categories.")
	if int(core_state.get("tool_count", 0)) != 3 or int(core_state.get("enabled_tool_count", 0)) != 3:
		return _failure("Core domain state should aggregate category tool counts.")
	var visual_state := _find_state(domain_states, "visual")
	if visual_state.is_empty() or (visual_state.get("categories", []) as Array) != ["material"]:
		return _failure("Snapshot should preserve non-core manifest domains as aggregate states.")

	var presentation: Dictionary = snapshot.get("presentation", {})
	var metadata_by_name: Dictionary = presentation.get("toolMetadataByName", {})
	if not metadata_by_name.has("system_project_state") or metadata_by_name.has("system_tool_activity"):
		return _failure("Snapshot presentation metadata should mirror the filtered catalog.")
	var tree: Array = presentation.get("toolTree", [])
	var core_node := _find_domain_node(tree, "core")
	var core_node_state: Dictionary = core_node.get("domainState", {})
	if core_node.is_empty() or (core_node_state.get("categories", []) as Array) != ["project", "system"]:
		return _failure("Snapshot presentation should receive aggregate domain state instead of overwriting category states.")

	var status: Dictionary = snapshot.get("tool_loader_status", {})
	if str(status.get("status", "")) != "ready":
		return _failure("Snapshot should preserve loader status.")
	status["status"] = "mutated"
	var second_snapshot: Dictionary = ToolCatalogSnapshotService.build_snapshot(loader)
	if str((second_snapshot.get("tool_loader_status", {}) as Dictionary).get("status", "")) != "ready":
		return _failure("Snapshot should return isolated status dictionaries.")

	var unavailable: Dictionary = ToolCatalogSnapshotService.build_snapshot(null)
	if bool(unavailable.get("success", true)) or str(unavailable.get("error", "")) != "tool_loader_unavailable":
		return _failure("Snapshot should fail clearly when the loader is unavailable.")

	var real_loader_result := _build_real_loader()
	if not bool(real_loader_result.get("success", false)):
		return _failure(str(real_loader_result.get("error", "Failed to initialize real tool loader.")))
	var real_loader = real_loader_result.get("loader")
	var real_result := _assert_real_loader_snapshot_and_search(real_loader)
	if not bool(real_result.get("success", false)):
		return _failure(str(real_result.get("error", "Real loader snapshot/search contract failed.")))

	real_loader.set_disabled_tools(["system_project_state"])
	var disabled_snapshot := ToolCatalogSnapshotService.build_snapshot(real_loader)
	if not bool(disabled_snapshot.get("success", false)):
		return _failure("Snapshot should still build when a public tool is disabled.")
	if _tool_names(disabled_snapshot.get("exposed_tools", [])).has("system_project_state"):
		return _failure("Real loader snapshot should remove disabled public tools from exposed tools.")
	var disabled_visible_project_state := _find_match(disabled_snapshot.get("visible_tools", []), "system_project_state")
	if disabled_visible_project_state.is_empty() or bool(disabled_visible_project_state.get("enabled", true)):
		return _failure("Real loader snapshot should keep disabled tools visible only as enabled=false metadata.")
	var disabled_search: Dictionary = ToolCatalogSearchService.search(real_loader, {
		"query": "system_project_state",
		"visibility": "visible",
		"limit": 10
	})
	if not bool(disabled_search.get("success", false)):
		return _failure("Search should still succeed when a public tool is disabled.")
	var disabled_match := _find_match((disabled_search.get("data", {}) as Dictionary).get("matches", []), "system_project_state")
	if disabled_match.is_empty() or bool(disabled_match.get("enabled", true)) or bool(disabled_match.get("exposed", true)):
		return _failure("Search should report disabled public tools as visible but not enabled or exposed.")

	var hidden_loader_result := _build_real_loader(["material"])
	if not bool(hidden_loader_result.get("success", false)):
		return _failure(str(hidden_loader_result.get("error", "Failed to initialize hidden-category real tool loader.")))
	var hidden_loader = hidden_loader_result.get("loader")
	var hidden_snapshot := ToolCatalogSnapshotService.build_snapshot(hidden_loader)
	if not bool(hidden_snapshot.get("success", false)):
		return _failure("Snapshot should still build when a category is hidden by access policy.")
	if _tool_names(hidden_snapshot.get("visible_tools", [])).has("material_material"):
		return _failure("Real loader snapshot should not leak hidden categories into visible tools.")
	if not _find_category_state(hidden_snapshot.get("category_states", []), "material").is_empty():
		return _failure("Real loader snapshot should not leak hidden categories into visible category states.")
	var hidden_search: Dictionary = ToolCatalogSearchService.search(hidden_loader, {
		"query": "material",
		"visibility": "visible",
		"domain": "visual",
		"category": "material",
		"limit": 10
	})
	if not bool(hidden_search.get("success", false)):
		return _failure("Search should still succeed when a category is hidden by access policy.")
	if not ((hidden_search.get("data", {}) as Dictionary).get("matches", []) as Array).is_empty():
		return _failure("Search should not return hidden category tools through the real loader snapshot.")

	return {
		"name": "tool_catalog_snapshot_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"exposed_tools": exposed_tools.size(),
			"visible_tools": visible_tools.size(),
			"real_exposed_tools": (real_result.get("details", {}) as Dictionary).get("exposed_tools", 0),
			"real_domain_states": (real_result.get("details", {}) as Dictionary).get("domain_states", 0)
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	for loader in _real_loaders:
		if loader != null and loader.has_method("shutdown"):
			loader.shutdown()
	_real_loaders.clear()


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_catalog_snapshot_service_contracts",
		"success": false,
		"error": message
	}


func _build_real_loader(hidden_categories: Array = []) -> Dictionary:
	var loader = ToolLoaderScript.new()
	_real_loaders.append(loader)
	loader.configure(FakeServerContext.new(FakeToolAccessProvider.new(hidden_categories), FakeRuntimeControlService.new()))
	loader.set_tool_activity_registry(ToolActivityRegistryScript.new())
	var summary: Dictionary = loader.initialize([])
	if int(summary.get("category_count", 0)) <= 0:
		return {"success": false, "error": "Real tool loader did not initialize any categories."}
	if int(summary.get("tool_count", 0)) <= 0:
		return {"success": false, "error": "Real tool loader did not expose visible tool definitions."}
	if int(summary.get("exposed_tool_count", 0)) <= 0:
		return {"success": false, "error": "Real tool loader did not expose any public tools."}
	return {"success": true, "loader": loader, "summary": summary}


func _assert_real_loader_snapshot_and_search(loader) -> Dictionary:
	var snapshot: Dictionary = ToolCatalogSnapshotService.build_snapshot(loader)
	if not bool(snapshot.get("success", false)):
		return _assertion_failure("Real loader snapshot should build successfully.")
	var status: Dictionary = snapshot.get("tool_loader_status", {})
	if str(status.get("status", "")) != "ready" or not bool(status.get("healthy", false)):
		return _assertion_failure("Real loader snapshot should preserve a healthy ready loader status.")

	var exposed_names := _tool_names(snapshot.get("exposed_tools", []))
	if not exposed_names.has("system_project_state") or not exposed_names.has("system_settings_dialog"):
		return _assertion_failure("Real loader snapshot should include public system tools from the registry path.")
	for removed_name in ["system_help", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze"]:
		if exposed_names.has(removed_name):
			return _assertion_failure("Real loader snapshot should filter removed public tool %s from exposed tools." % removed_name)

	var visible_names := _tool_names(snapshot.get("visible_tools", []))
	for internal_name in ["material_material", "project_info", "filesystem_directory"]:
		if not visible_names.has(internal_name):
			return _assertion_failure("Real loader snapshot should preserve visible internal tool %s." % internal_name)

	var tools_by_category: Dictionary = snapshot.get("all_tools_by_category", {})
	for category in ["system", "project", "material"]:
		if not tools_by_category.has(category) or (tools_by_category.get(category, []) as Array).is_empty():
			return _assertion_failure("Real loader snapshot should include category %s from the registry path." % category)
	var material_full_names := _category_full_names("material", tools_by_category.get("material", []))
	if not material_full_names.has("material_material"):
		return _assertion_failure("Real loader snapshot should decorate material tools with full names.")

	var category_states: Array = snapshot.get("category_states", [])
	for required_category in ["system", "project", "material"]:
		var state := _find_category_state(category_states, required_category)
		if state.is_empty():
			return _assertion_failure("Real loader snapshot should preserve category state for %s." % required_category)
		if str(state.get("source", "")) != "builtin":
			return _assertion_failure("Real loader category state should preserve builtin source for %s." % required_category)
		if str(state.get("script_path", "")).is_empty():
			return _assertion_failure("Real loader category state should preserve script_path for %s." % required_category)
		if str(state.get("load_state", "")).is_empty():
			return _assertion_failure("Real loader category state should preserve load_state for %s." % required_category)
		if int(state.get("tool_count", 0)) <= 0:
			return _assertion_failure("Real loader category state should preserve tool counts for %s." % required_category)

	var domain_states: Array = snapshot.get("domain_states", [])
	for domain_key in ["core", "visual", "plugin"]:
		var domain_state := _find_state(domain_states, domain_key)
		if domain_state.is_empty():
			return _assertion_failure("Real loader snapshot should aggregate domain state for %s." % domain_key)
		if int(domain_state.get("category_count", 0)) <= 0:
			return _assertion_failure("Real loader domain state should preserve category counts for %s." % domain_key)
	var visual_state := _find_state(domain_states, "visual")
	if not ((visual_state.get("categories", []) as Array).has("material")):
		return _assertion_failure("Real loader visual domain state should include the material category.")

	var presentation: Dictionary = snapshot.get("presentation", {})
	if int(presentation.get("presentationVersion", 0)) <= 0:
		return _assertion_failure("Real loader snapshot should include a presentation version.")
	var metadata_by_name: Dictionary = presentation.get("toolMetadataByName", {})
	for tool_name in ["system_project_state", "system_settings_dialog"]:
		var metadata: Dictionary = metadata_by_name.get(tool_name, {})
		if metadata.is_empty():
			return _assertion_failure("Real loader presentation should include metadata for %s." % tool_name)
		if str(metadata.get("source", "")) != "builtin":
			return _assertion_failure("Real loader presentation metadata should preserve builtin source for %s." % tool_name)
		if str(metadata.get("loadState", "")).is_empty():
			return _assertion_failure("Real loader presentation metadata should preserve loadState for %s." % tool_name)
		if (metadata.get("groupPath", []) as Array).is_empty():
			return _assertion_failure("Real loader presentation metadata should include groupPath for %s." % tool_name)
	if metadata_by_name.has("system_tool_catalog") or metadata_by_name.has("system_tool_activity"):
		return _assertion_failure("Real loader presentation metadata should not include removed public catalog/activity tools.")

	var core_node := _find_domain_node(presentation.get("toolTree", []), "core")
	if core_node.is_empty() or (core_node.get("domainState", {}) as Dictionary).is_empty():
		return _assertion_failure("Real loader presentation should attach aggregate core domain state.")

	var search_result: Dictionary = ToolCatalogSearchService.search(loader, {
		"query": "create",
		"visibility": "visible",
		"domain": "visual",
		"category": "material",
		"include_schema": true,
		"limit": 20
	})
	if not bool(search_result.get("success", false)):
		return _assertion_failure("Real loader catalog search should succeed.")
	var matches: Array = (search_result.get("data", {}) as Dictionary).get("matches", [])
	var material_match := _find_match(matches, "material_material")
	if material_match.is_empty():
		return _assertion_failure("Real loader catalog search should find material_material.")
	if bool(material_match.get("exposed", true)):
		return _assertion_failure("Real loader catalog search should mark internal material tools as not exposed.")
	if str(material_match.get("domain_key", "")) != "visual" or str(material_match.get("category", "")) != "material":
		return _assertion_failure("Real loader catalog search should preserve registry domain/category metadata.")
	if str(material_match.get("source", "")) != "builtin" or str(material_match.get("load_state", "")).is_empty():
		return _assertion_failure("Real loader catalog search should preserve loader decoration metadata.")
	var material_input_schema: Dictionary = material_match.get("input_schema", {})
	if material_input_schema.is_empty():
		return _assertion_failure("Real loader catalog search should include input_schema when requested.")
	var material_output_schema: Dictionary = material_match.get("output_schema", {})
	if not ((material_output_schema.get("required", []) as Array).has("success")):
		return _assertion_failure("Real loader catalog search should synthesize the default output schema.")
	if JSON.stringify(material_input_schema) == JSON.stringify(material_output_schema):
		return _assertion_failure("Real loader catalog search should not mirror inputSchema as output_schema.")

	var system_search: Dictionary = ToolCatalogSearchService.search(loader, {
		"query": "runtime health",
		"visibility": "exposed",
		"include_schema": true,
		"limit": 20
	})
	if not bool(system_search.get("success", false)):
		return _assertion_failure("Real loader exposed catalog search should succeed.")
	var system_match := _find_match((system_search.get("data", {}) as Dictionary).get("matches", []), "system_project_state")
	if system_match.is_empty():
		return _assertion_failure("Real loader exposed catalog search should find system_project_state.")
	if not bool(system_match.get("exposed", false)):
		return _assertion_failure("Real loader exposed catalog search should mark system_project_state as exposed.")
	if str(system_match.get("domain_key", "")) != "core" or str(system_match.get("category", "")) != "system":
		return _assertion_failure("Real loader exposed catalog search should preserve system domain/category metadata.")
	if (system_match.get("group_path", []) as Array).is_empty():
		return _assertion_failure("Real loader exposed catalog search should preserve presentation groupPath metadata.")

	return {
		"success": true,
		"details": {
			"exposed_tools": exposed_names.size(),
			"visible_tools": visible_names.size(),
			"domain_states": domain_states.size()
		}
	}


func _assertion_failure(message: String) -> Dictionary:
	return {"success": false, "error": message}


func _tool_names(tools: Array) -> Array[String]:
	var names: Array[String] = []
	for tool in tools:
		if tool is Dictionary:
			names.append(str((tool as Dictionary).get("name", "")))
	names.sort()
	return names


func _category_full_names(category: String, tools: Array) -> Array[String]:
	var names: Array[String] = []
	for tool in tools:
		if not (tool is Dictionary):
			continue
		var tool_dict := tool as Dictionary
		var full_name := str(tool_dict.get("full_name", ""))
		if full_name.is_empty():
			full_name = "%s_%s" % [category, str(tool_dict.get("name", ""))]
		names.append(full_name)
	names.sort()
	return names


func _find_state(states: Array, domain_key: String) -> Dictionary:
	for state in states:
		if state is Dictionary and str((state as Dictionary).get("domain_key", "")) == domain_key:
			return state as Dictionary
	return {}


func _find_category_state(states: Array, category: String) -> Dictionary:
	for state in states:
		if state is Dictionary and str((state as Dictionary).get("category", "")) == category:
			return state as Dictionary
	return {}


func _find_domain_node(nodes: Array, domain_key: String) -> Dictionary:
	for node in nodes:
		if node is Dictionary and str((node as Dictionary).get("kind", "")) == "domain" and str((node as Dictionary).get("key", "")) == domain_key:
			return node as Dictionary
	return {}


func _find_match(matches: Array, tool_name: String) -> Dictionary:
	for match in matches:
		if match is Dictionary and str((match as Dictionary).get("name", "")) == tool_name:
			return match as Dictionary
	return {}
