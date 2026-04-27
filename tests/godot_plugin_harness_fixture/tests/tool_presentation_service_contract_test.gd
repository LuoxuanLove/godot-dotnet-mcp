extends RefCounted

# {"name": "tool_presentation_service_contracts"}

const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var exposed_tools := [{
		"name": "system_project_state",
		"description": "Inspect project state",
		"category": "system",
		"domain_key": "core",
		"enabled": true,
		"inputSchema": {"type": "object", "properties": {}}
	}, {
		"name": "system_runtime_control",
		"description": "Control runtime session",
		"category": "system",
		"domain_key": "core",
		"enabled": true,
		"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["status", "enable", "disable"]}}}
	}, {
		"name": "system_project_index_build",
		"description": "Build project index",
		"category": "system",
		"domain_key": "core",
		"enabled": true,
		"inputSchema": {"type": "object", "properties": {}}
	}]
	var all_tools_by_category := {
		"system": [{
			"name": "project_state",
			"full_name": "system_project_state",
			"category": "system",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}, {
			"name": "runtime_control",
			"full_name": "system_runtime_control",
			"category": "system",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["status", "enable", "disable"]}}}
		}, {
			"name": "project_index_build",
			"full_name": "system_project_index_build",
			"category": "system",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}],
		"project": [{
			"name": "info",
			"full_name": "project_info",
			"category": "project",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}],
		"filesystem": [{
			"name": "directory",
			"full_name": "filesystem_directory",
			"category": "filesystem",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}],
		"runtime": [{
			"name": "control",
			"full_name": "runtime_control",
			"category": "runtime",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["status", "enable", "disable"]}}}
		}],
		"script": [{
			"name": "inspect",
			"full_name": "script_inspect",
			"category": "script",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}],
		"resource": [{
			"name": "query",
			"full_name": "resource_query",
			"category": "resource",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {}}
		}]
	}
	var presentation := ToolPresentationService.build_tool_presentation(exposed_tools, all_tools_by_category)
	if int(presentation.get("presentationVersion", 0)) != 1:
		return _failure("Presentation service should expose a stable presentation version.")
	var tool_tree: Array = presentation.get("toolTree", [])
	var core_domain := _find_node(tool_tree, "domain", "core")
	if core_domain.is_empty():
		return _failure("Presentation service should build a core domain node.")
	var system_category := _find_node(core_domain.get("children", []), "category", "system")
	if system_category.is_empty():
		return _failure("Presentation service should build a system category node.")
	var project_state := _find_node(system_category.get("children", []), "tool", "system_project_state")
	if project_state.is_empty():
		return _failure("Presentation service should build the high-level system tool node.")
	if _find_node(project_state.get("children", []), "atomic", "project_info").is_empty():
		return _failure("Presentation service should attach atomic children from SystemTreeCatalog.")
	var runtime_control := _find_node(system_category.get("children", []), "tool", "system_runtime_control")
	if runtime_control.is_empty() or _find_node(runtime_control.get("children", []), "atomic", "runtime_control").is_empty():
		return _failure("Presentation service should expose runtime high-level tools through real runtime atomic children.")
	var project_index_build := _find_node(system_category.get("children", []), "tool", "system_project_index_build")
	if project_index_build.is_empty() or _find_node(project_index_build.get("children", []), "atomic", "script_inspect").is_empty():
		return _failure("Presentation service should expose project index build through its real filesystem/script/resource atomic chain.")
	var disabled_presentation := ToolPresentationService.build_tool_presentation(exposed_tools, all_tools_by_category, [], ["system_project_state", "system_runtime_control", "system_project_index_build"])
	var disabled_project_state := _find_node((_find_node((_find_node(disabled_presentation.get("toolTree", []), "domain", "core")).get("children", []), "category", "system")).get("children", []), "tool", "system_project_state")
	if disabled_project_state.is_empty() or bool(disabled_project_state.get("enabled", true)):
		return _failure("Presentation service should let disabled_tools override tool enabled metadata.")
	if int((_find_node((_find_node(disabled_presentation.get("toolTree", []), "domain", "core")).get("children", []), "category", "system")).get("enabledCount", -1)) != 0:
		return _failure("Presentation service should compute group enabled counts from disabled_tools.")
	var metadata: Dictionary = presentation.get("toolMetadataByName", {})
	if not metadata.has("system_project_state"):
		return _failure("Presentation service should index metadata by full tool name.")
	var enriched := ToolPresentationService.enrich_tools_for_presentation(exposed_tools, presentation)
	if enriched.is_empty() or not (enriched[0] as Dictionary).has("groupPath"):
		return _failure("Presentation service should add non-breaking groupPath metadata to flat tools.")

	return {
		"name": "tool_presentation_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"domain_count": tool_tree.size(),
			"project_state_children": (project_state.get("children", []) as Array).size()
		}
	}


func _find_node(nodes: Array, kind: String, key: String) -> Dictionary:
	for node in nodes:
		if not (node is Dictionary):
			continue
		var node_dict := node as Dictionary
		if str(node_dict.get("kind", "")) == kind and str(node_dict.get("key", "")) == key:
			return node_dict
	return {}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_presentation_service_contracts",
		"success": false,
		"error": message
	}
