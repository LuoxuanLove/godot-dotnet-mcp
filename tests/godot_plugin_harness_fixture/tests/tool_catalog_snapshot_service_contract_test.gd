extends RefCounted

# {"name": "tool_catalog_snapshot_service_contracts"}

const ToolCatalogSnapshotService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_snapshot_service.gd")


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

	func get_performance_summary() -> Dictionary:
		return {"startup_ms": 12.5, "tool_calls": []}

	func is_public_removed_tool(tool_name: String) -> bool:
		return tool_name == "system_tool_activity"


func run_case(_tree: SceneTree) -> Dictionary:
	var loader := FakeToolLoader.new()
	var snapshot: Dictionary = ToolCatalogSnapshotService.build_snapshot(loader)
	if not bool(snapshot.get("success", false)):
		return _failure("Snapshot build should succeed for a loader with exposed definitions.")

	for key in ["exposed_tools", "visible_tools", "all_tools_by_category", "category_states", "domain_states", "presentation", "tool_loader_status", "performance"]:
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
	var performance: Dictionary = snapshot.get("performance", {})
	if float(performance.get("startup_ms", 0.0)) != 12.5:
		return _failure("Snapshot should preserve loader performance.")
	status["status"] = "mutated"
	var second_snapshot: Dictionary = ToolCatalogSnapshotService.build_snapshot(loader)
	if str((second_snapshot.get("tool_loader_status", {}) as Dictionary).get("status", "")) != "ready":
		return _failure("Snapshot should return isolated status dictionaries.")

	var mcp_payload: Dictionary = ToolCatalogSnapshotService.build_mcp_tools_list_payload(snapshot)
	if _tool_names(mcp_payload.get("tools", [])) != ["system_project_state", "system_settings_dialog"]:
		return _failure("Snapshot MCP payload helper should build tools/list from filtered exposed tools.")
	if not (mcp_payload.get("toolTree", []) is Array) or (mcp_payload.get("toolTree", []) as Array).is_empty():
		return _failure("Snapshot MCP payload helper should preserve tool tree metadata.")
	if not (mcp_payload.get("toolGroups", []) is Array) or (mcp_payload.get("toolGroups", []) as Array).is_empty():
		return _failure("Snapshot MCP payload helper should preserve tool group metadata.")

	var presentation_payload: Dictionary = ToolCatalogSnapshotService.build_presentation_payload(snapshot)
	if _tool_names(presentation_payload.get("tools", [])) != ["system_project_state", "system_settings_dialog"]:
		return _failure("Snapshot presentation payload helper should enrich filtered exposed tools.")
	if int(presentation_payload.get("tool_count", 0)) != visible_tools.size():
		return _failure("Snapshot presentation payload helper should use filtered visible tool count.")
	if int(presentation_payload.get("exposed_tool_count", 0)) != exposed_tools.size():
		return _failure("Snapshot presentation payload helper should use filtered exposed tool count.")
	if float((presentation_payload.get("performance", {}) as Dictionary).get("startup_ms", 0.0)) != 12.5:
		return _failure("Snapshot presentation payload helper should preserve performance metadata.")

	var unavailable: Dictionary = ToolCatalogSnapshotService.build_snapshot(null)
	if bool(unavailable.get("success", true)) or str(unavailable.get("error", "")) != "tool_loader_unavailable":
		return _failure("Snapshot should fail clearly when the loader is unavailable.")
	var empty_mcp_payload: Dictionary = ToolCatalogSnapshotService.build_mcp_tools_list_payload(unavailable)
	if not (empty_mcp_payload.get("tools", []) is Array) or not (empty_mcp_payload.get("tools", []) as Array).is_empty():
		return _failure("Snapshot MCP payload helper should return an empty tools/list payload when unavailable.")

	return {
		"name": "tool_catalog_snapshot_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"exposed_tools": exposed_tools.size(),
			"visible_tools": visible_tools.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_catalog_snapshot_service_contracts",
		"success": false,
		"error": message
	}


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


func _find_domain_node(nodes: Array, domain_key: String) -> Dictionary:
	for node in nodes:
		if node is Dictionary and str((node as Dictionary).get("kind", "")) == "domain" and str((node as Dictionary).get("key", "")) == domain_key:
			return node as Dictionary
	return {}
