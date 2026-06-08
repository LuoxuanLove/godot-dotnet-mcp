extends RefCounted

# {"name": "tool_catalog_search_service_contracts"}

const ToolCatalogSearchService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_search_service.gd")


class FakeToolLoader:
	extends RefCounted

	func get_exposed_tool_definitions() -> Array:
		return [{
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
			"description": "Settings dialog workflow with trusted task orchestration",
			"category": "system",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["open", "resolve_row", "run_task"], "description": "Settings dialog workflow action"},
					"capture_policy": {"type": "string", "description": "Capture policy for run_task"}
				}
			}
		}, {
			"name": "system_runtime_step",
			"description": "Apply runtime input and capture a frame",
			"category": "system",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["step", "capture", "input"], "description": "Runtime automation mode"},
					"capture_label": {"type": "string", "description": "Optional capture label"}
				}
			}
		}, {
			"name": "system_inspector",
			"description": "Inspector property workflow with trusted task orchestration",
			"category": "system",
			"domain_key": "core",
			"enabled": true,
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "enum": ["list_properties", "resolve_property", "run_task"], "description": "Inspector workflow action"},
					"property_path": {"type": "string", "description": "Inspector property path or fragment"}
				}
			}
		}]

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
					"action": {"type": "string", "enum": ["list_actions", "get_action"], "description": "Input map action"},
					"name": {"type": "string", "description": "Input action name"}
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
						"action": {"type": "string", "enum": ["open", "resolve_row", "run_task"], "description": "Settings dialog workflow action"},
						"capture_policy": {"type": "string", "description": "Capture policy for run_task"}
					}
				}
			}, {
				"name": "runtime_step",
				"full_name": "system_runtime_step",
				"category": "system",
				"domain_key": "core",
				"enabled": true,
				"inputSchema": {
					"type": "object",
					"properties": {
						"action": {"type": "string", "enum": ["step", "capture", "input"], "description": "Runtime automation mode"},
						"capture_label": {"type": "string", "description": "Optional capture label"}
					}
				}
			}, {
				"name": "inspector",
				"full_name": "system_inspector",
				"category": "system",
				"domain_key": "core",
				"enabled": true,
				"inputSchema": {
					"type": "object",
					"properties": {
						"action": {"type": "string", "enum": ["list_properties", "resolve_property", "run_task"], "description": "Inspector workflow action"},
						"property_path": {"type": "string", "description": "Inspector property path or fragment"}
					}
				}
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
						"action": {"type": "string", "enum": ["list_actions", "get_action"], "description": "Input map action"},
						"name": {"type": "string", "description": "Input action name"}
					}
				}
			}]
		}

	func get_domain_states() -> Array:
		return [
			{"domain": "system", "domain_key": "core", "loaded": true},
			{"domain": "plugin_runtime", "domain_key": "plugin", "loaded": true},
			{"domain": "user", "domain_key": "user", "loaded": true}
		]

	func get_tool_loader_status() -> Dictionary:
		return {"healthy": true, "status": "ready", "tool_count": 5, "exposed_tool_count": 4}


func run_case(_tree: SceneTree) -> Dictionary:
	var loader := FakeToolLoader.new()
	var exposed_search: Dictionary = ToolCatalogSearchService.search(loader, {"query": "input", "limit": 10})
	if not bool(exposed_search.get("success", false)):
		return _failure("Exposed catalog search should succeed.")
	var exposed_data: Dictionary = exposed_search.get("data", {})
	var exposed_matches: Array = exposed_data.get("matches", [])
	if exposed_matches.size() != 1 or str((exposed_matches[0] as Dictionary).get("name", "")) != "system_runtime_step":
		return _failure("Default search should match exposed tools by action/description.")
	if (exposed_matches[0] as Dictionary).has("input_schema"):
		return _failure("Catalog search should omit full schemas unless include_schema=true.")
	if not ((exposed_matches[0] as Dictionary).get("match_reasons", []) as Array).has("action"):
		return _failure("Catalog search should report action match reasons.")

	var settings_task_search: Dictionary = ToolCatalogSearchService.search(loader, {"query": "capture_policy", "limit": 10})
	var settings_task_matches: Array = (settings_task_search.get("data", {}) as Dictionary).get("matches", [])
	if settings_task_matches.size() != 1 or str((settings_task_matches[0] as Dictionary).get("name", "")) != "system_settings_dialog":
		return _failure("Catalog search should expose system_settings_dialog task capture policy discovery.")
	if not ((settings_task_matches[0] as Dictionary).get("match_reasons", []) as Array).has("param"):
		return _failure("Catalog search should report capture_policy as a parameter match.")

	var inspector_search: Dictionary = ToolCatalogSearchService.search(loader, {"query": "property_path", "limit": 10})
	var inspector_matches: Array = (inspector_search.get("data", {}) as Dictionary).get("matches", [])
	if inspector_matches.size() != 1 or str((inspector_matches[0] as Dictionary).get("name", "")) != "system_inspector":
		return _failure("Catalog search should expose system_inspector property workflow discovery.")
	if not ((inspector_matches[0] as Dictionary).get("match_reasons", []) as Array).has("param"):
		return _failure("Catalog search should report property_path as a parameter match.")

	var visible_search: Dictionary = ToolCatalogSearchService.search(loader, {
		"query": "get_action",
		"visibility": "visible",
		"category": "project",
		"include_schema": true
	})
	var visible_matches: Array = (visible_search.get("data", {}) as Dictionary).get("matches", [])
	if visible_matches.size() != 1 or str((visible_matches[0] as Dictionary).get("name", "")) != "project_input":
		return _failure("Visible catalog search should include internal project tools.")
	if bool((visible_matches[0] as Dictionary).get("exposed", true)):
		return _failure("Internal project_input should be reported as not exposed.")
	if not (visible_matches[0] as Dictionary).has("input_schema"):
		return _failure("include_schema=true should preserve the full input schema.")
	if not ((visible_matches[0] as Dictionary).get("match_reasons", []) as Array).has("param_enum"):
		return _failure("Catalog search should match enum values and report param_enum.")

	var domain_search: Dictionary = ToolCatalogSearchService.search(loader, {"domain": "core", "query": "label"})
	var domain_matches: Array = (domain_search.get("data", {}) as Dictionary).get("matches", [])
	if domain_matches.size() != 1 or not ((domain_matches[0] as Dictionary).get("match_reasons", []) as Array).has("param"):
		return _failure("Domain-key-filtered search should match parameter names.")
	var alternate_domain_search: Dictionary = ToolCatalogSearchService.search(loader, {"domain": "plugin", "query": "label"})
	var alternate_domain_matches: Array = (alternate_domain_search.get("data", {}) as Dictionary).get("matches", [])
	if not alternate_domain_matches.is_empty():
		return _failure("Domain-key-filtered search should exclude matches from other domains.")

	var invalid_visibility: Dictionary = ToolCatalogSearchService.search(loader, {"visibility": "all"})
	if bool(invalid_visibility.get("success", true)):
		return _failure("Invalid visibility should fail with invalid_argument.")

	return {
		"name": "tool_catalog_search_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"exposed_matches": exposed_matches.size(),
			"visible_matches": visible_matches.size()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_catalog_search_service_contracts",
		"success": false,
		"error": message
	}
