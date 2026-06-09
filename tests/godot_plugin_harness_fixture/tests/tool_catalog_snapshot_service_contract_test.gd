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
			}]
		}

	func get_domain_states() -> Array:
		return [
			{"domain": "system", "domain_key": "core", "loaded": true},
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

	for key in ["exposed_tools", "visible_tools", "all_tools_by_category", "domain_states", "presentation", "tool_loader_status"]:
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
	if _category_full_names("system", system_tools).has("system_tool_activity"):
		return _failure("Snapshot category catalog should filter removed public tools.")
	if not _category_full_names("project", tools_by_category.get("project", [])).has("project_input"):
		return _failure("Snapshot category catalog should preserve non-removed internal visible tools.")

	var presentation: Dictionary = snapshot.get("presentation", {})
	var metadata_by_name: Dictionary = presentation.get("toolMetadataByName", {})
	if not metadata_by_name.has("system_project_state") or metadata_by_name.has("system_tool_activity"):
		return _failure("Snapshot presentation metadata should mirror the filtered catalog.")

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
