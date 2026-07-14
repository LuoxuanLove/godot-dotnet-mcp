extends RefCounted

# {"name": "tool_presentation_service_contracts"}

const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")

const JSON_SCHEMA_2020_12_URI := "https://json-schema.org/draft/2020-12/schema"


func run_case(_tree: SceneTree) -> Dictionary:
	var source_guard := _assert_presentation_signatures_are_lightweight()
	if not source_guard.is_empty():
		return _failure(source_guard)
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
		"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["status", "enable", "disable"]}}},
		"outputSchema": {"type": "object", "required": ["success"], "properties": {"success": {"type": "boolean"}, "data": {"type": "object"}}}
	}, {
		"name": "system_editor_evidence",
		"description": "Capture editor evidence",
		"category": "system",
		"domain_key": "core",
		"enabled": true,
		"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["capture"]}}}
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
		"description": "Control runtime sessions",
		"title": "Runtime Control",
		"icons": [{"src": "codicon:play", "mimeType": "image/svg+xml"}],
		"category": "system",
		"enabled": true,
		"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["status", "enable", "disable"]}}},
		"outputSchema": {"type": "object", "required": ["success"], "properties": {"success": {"type": "boolean"}, "data": {"type": "object"}}}
		}, {
			"name": "editor_evidence",
			"full_name": "system_editor_evidence",
			"category": "system",
			"enabled": true,
			"inputSchema": {"type": "object", "properties": {"action": {"type": "string", "enum": ["capture"]}}}
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
	var presentation_signature := str(presentation.get("signature", ""))
	if presentation_signature.is_empty():
		return _failure("Presentation service should expose a reusable presentation signature for UI refresh checks.")
	var presentation_with_reordered_metadata := ToolPresentationService.build_presentation_signature(
		"agent_tools",
		[{"kind": "tool", "key": "system_runtime_control", "inputSchema": {"properties": {"action": {"enum": ["status", "enable"]}}}}],
		[{"rank": 1, "key": "core"}],
		{"system_runtime_control": {"presentation": {"rank": 1, "group": "Runtime"}, "icons": [{"src": "codicon:play"}]}}
	)
	var presentation_with_equivalent_metadata := ToolPresentationService.build_presentation_signature(
		"agent_tools",
		[{"inputSchema": {"properties": {"action": {"enum": ["status", "enable"]}}}, "key": "system_runtime_control", "kind": "tool"}],
		[{"key": "core", "rank": 1}],
		{"system_runtime_control": {"icons": [{"src": "codicon:play"}], "presentation": {"group": "Runtime", "rank": 1}}}
	)
	if presentation_with_reordered_metadata != presentation_with_equivalent_metadata:
		return _failure("Presentation signature should stay stable when dictionary keys are reordered.")
	var presentation_with_nested_change := ToolPresentationService.build_presentation_signature(
		"agent_tools",
		[{"kind": "tool", "key": "system_runtime_control", "inputSchema": {"properties": {"action": {"enum": ["status", "disable"]}}}}],
		[{"rank": 1, "key": "core"}],
		{"system_runtime_control": {"presentation": {"rank": 1, "group": "Runtime"}, "icons": [{"src": "codicon:play"}]}}
	)
	if presentation_with_reordered_metadata == presentation_with_nested_change:
		return _failure("Presentation signature should detect nested schema and metadata changes without JSON serialization.")
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
	var disabled_presentation := ToolPresentationService.build_tool_presentation(exposed_tools, all_tools_by_category, [], ["system_project_state", "system_runtime_control", "system_editor_evidence", "system_project_index_build"])
	if str(disabled_presentation.get("signature", "")) == presentation_signature:
		return _failure("Presentation signature should change when disabled tool state changes.")
	var disabled_project_state := _find_node((_find_node((_find_node(disabled_presentation.get("toolTree", []), "domain", "core")).get("children", []), "category", "system")).get("children", []), "tool", "system_project_state")
	if disabled_project_state.is_empty() or bool(disabled_project_state.get("enabled", true)):
		return _failure("Presentation service should let disabled_tools override tool enabled metadata.")
	if int((_find_node((_find_node(disabled_presentation.get("toolTree", []), "domain", "core")).get("children", []), "category", "system")).get("enabledCount", -1)) != 0:
		return _failure("Presentation service should compute group enabled counts from disabled_tools.")
	var metadata: Dictionary = presentation.get("toolMetadataByName", {})
	if not metadata.has("system_project_state"):
		return _failure("Presentation service should index metadata by full tool name.")
	var runtime_metadata: Dictionary = metadata.get("system_runtime_control", {})
	if runtime_metadata.is_empty():
		return _failure("Presentation service should index runtime control metadata by full tool name.")
	if str(runtime_metadata.get("description", "")) != "Control runtime sessions":
		return _failure("Presentation metadata should preserve tool descriptions for UI consumers.")
	if str(runtime_metadata.get("title", "")) != "Runtime Control":
		return _failure("Presentation metadata should preserve tool titles for UI consumers.")
	var metadata_icons = runtime_metadata.get("icons", [])
	if not (metadata_icons is Array) or (metadata_icons as Array).is_empty():
		return _failure("Presentation metadata should preserve tool icons for UI consumers.")
	var runtime_metadata_annotations = runtime_metadata.get("annotations", {})
	if not (runtime_metadata_annotations is Dictionary) or str((runtime_metadata_annotations as Dictionary).get("title", "")) != "Runtime Control":
		return _failure("Presentation metadata should preserve MCP annotations for UI consumers.")
	if bool((runtime_metadata_annotations as Dictionary).get("readOnlyHint", true)):
		return _failure("Presentation metadata should preserve behavior annotation hints.")
	var runtime_metadata_input_schema = runtime_metadata.get("inputSchema", {})
	if not (runtime_metadata_input_schema is Dictionary) or str((runtime_metadata_input_schema as Dictionary).get("$schema", "")) != JSON_SCHEMA_2020_12_URI:
		return _failure("Presentation metadata should preserve normalized input schemas.")
	var runtime_metadata_output_schema = runtime_metadata.get("outputSchema", {})
	if not (runtime_metadata_output_schema is Dictionary) or str((runtime_metadata_output_schema as Dictionary).get("$schema", "")) != JSON_SCHEMA_2020_12_URI:
		return _failure("Presentation metadata should preserve normalized output schemas.")
	var enriched := ToolPresentationService.enrich_tools_for_presentation(exposed_tools, presentation)
	if enriched.is_empty() or not (enriched[0] as Dictionary).has("groupPath"):
		return _failure("Presentation service should add non-breaking groupPath metadata to flat tools.")
	var mcp_tools := ToolPresentationService.build_mcp_tool_list(exposed_tools, presentation)
	var mcp_project_state := _find_mcp_tool(mcp_tools, "system_project_state")
	if mcp_project_state.is_empty():
		return _failure("Presentation service should include project state in MCP tools/list output.")
	if mcp_project_state.has("groupPath") or mcp_project_state.has("treeChildren"):
		return _failure("Presentation service should keep MCP tools/list entries free of presentation metadata.")
	for internal_key in ["category", "domainKey", "loadState", "source", "enabled"]:
		if mcp_project_state.has(internal_key):
			return _failure("Presentation service should keep MCP tools/list entries free of internal metadata key: %s" % internal_key)
	var project_state_annotations = mcp_project_state.get("annotations", {})
	if not (project_state_annotations is Dictionary):
		return _failure("Presentation service should attach MCP annotations to tools/list entries.")
	if str((project_state_annotations as Dictionary).get("title", "")) != "System Project State":
		return _failure("Presentation service should attach a display title annotation to tools/list entries.")
	if bool((project_state_annotations as Dictionary).get("readOnlyHint", false)) != true:
		return _failure("Presentation service should mark clear state/query tools as read-only.")
	if bool((project_state_annotations as Dictionary).get("destructiveHint", true)) != false:
		return _failure("Presentation service should not mark read-only state tools as destructive.")
	if bool((project_state_annotations as Dictionary).get("openWorldHint", true)) != false:
		return _failure("Presentation service should explicitly mark local project-state tools as closed-world.")
	var default_output_schema = mcp_project_state.get("outputSchema", {})
	if not (default_output_schema is Dictionary):
		return _failure("Presentation service should attach default outputSchema to MCP tools/list entries.")
	var default_input_schema = mcp_project_state.get("inputSchema", {})
	if not (default_input_schema is Dictionary) or str((default_input_schema as Dictionary).get("$schema", "")) != JSON_SCHEMA_2020_12_URI:
		return _failure("Presentation service should advertise JSON Schema 2020-12 on MCP inputSchema.")
	if str((default_output_schema as Dictionary).get("$schema", "")) != JSON_SCHEMA_2020_12_URI:
		return _failure("Presentation service should advertise JSON Schema 2020-12 on default MCP outputSchema.")
	if not ((default_output_schema as Dictionary).get("properties", {}) is Dictionary) or not (((default_output_schema as Dictionary).get("properties", {}) as Dictionary).has("success")):
		return _failure("Default outputSchema should document the normalized success envelope.")
	if not ((default_output_schema as Dictionary).get("required", []) is Array) or not (((default_output_schema as Dictionary).get("required", []) as Array).has("success")):
		return _failure("Default outputSchema should require the normalized success flag.")
	var default_data_schema = ((default_output_schema as Dictionary).get("properties", {}) as Dictionary).get("data", {})
	if not (default_data_schema is Dictionary) or not (((default_data_schema as Dictionary).get("type", []) is Array)) or not (((default_data_schema as Dictionary).get("type", []) as Array).has("array")) or not (((default_data_schema as Dictionary).get("type", []) as Array).has("null")):
		return _failure("Default outputSchema data should allow existing object, array, scalar, and null tool payloads.")
	var mcp_runtime_control := _find_mcp_tool(mcp_tools, "system_runtime_control")
	if mcp_runtime_control.is_empty():
		return _failure("Presentation service should include runtime control in MCP tools/list output.")
	var runtime_annotations = mcp_runtime_control.get("annotations", {})
	if not (runtime_annotations is Dictionary) or bool((runtime_annotations as Dictionary).get("readOnlyHint", true)):
		return _failure("Presentation service should not mark mixed runtime control actions as read-only.")
	if (runtime_annotations as Dictionary).has("idempotentHint"):
		return _failure("Presentation service should not claim mixed runtime control actions are idempotent.")
	var mcp_editor_evidence := _find_mcp_tool(mcp_tools, "system_editor_evidence")
	if mcp_editor_evidence.is_empty():
		return _failure("Presentation service should include editor evidence in MCP tools/list output.")
	var evidence_annotations = mcp_editor_evidence.get("annotations", {})
	if not (evidence_annotations is Dictionary) or bool((evidence_annotations as Dictionary).get("readOnlyHint", true)):
		return _failure("Presentation service should not mark capture actions as read-only because they can write evidence files.")
	if (evidence_annotations as Dictionary).has("destructiveHint") and bool((evidence_annotations as Dictionary).get("destructiveHint", false)) == false:
		return _failure("Presentation service should not claim capture actions are non-destructive.")
	var explicit_output_schema = mcp_runtime_control.get("outputSchema", {})
	if not (explicit_output_schema is Dictionary) or not (((explicit_output_schema as Dictionary).get("properties", {}) as Dictionary).has("data")):
		return _failure("Presentation service should preserve explicit tool outputSchema definitions.")
	if str((mcp_runtime_control.get("inputSchema", {}) as Dictionary).get("$schema", "")) != JSON_SCHEMA_2020_12_URI:
		return _failure("Presentation service should advertise JSON Schema 2020-12 on explicit MCP inputSchema.")
	if str((explicit_output_schema as Dictionary).get("$schema", "")) != JSON_SCHEMA_2020_12_URI:
		return _failure("Presentation service should advertise JSON Schema 2020-12 on explicit MCP outputSchema.")
	if JSON.stringify(mcp_runtime_control.get("inputSchema", {})) == JSON.stringify(explicit_output_schema):
		return _failure("Presentation service should not mirror inputSchema into outputSchema.")

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


func _find_mcp_tool(tools: Array, name: String) -> Dictionary:
	for tool in tools:
		if not (tool is Dictionary):
			continue
		var tool_dict := tool as Dictionary
		if str(tool_dict.get("name", "")) == name:
			return tool_dict
	return {}


func _failure(message: String) -> Dictionary:
	return {
		"name": "tool_presentation_service_contracts",
		"success": false,
		"error": message
	}


func _assert_presentation_signatures_are_lightweight() -> String:
	var source_path := "res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd"
	if not FileAccess.file_exists(source_path):
		return "Tool presentation service source should exist for signature guard."
	var source := FileAccess.get_file_as_string(source_path)
	if source.find("node|%s\" % JSON.stringify") != -1 or source.find("group|%s\" % JSON.stringify") != -1 or source.find("JSON.stringify(metadata)") != -1:
		return "Presentation signatures should not JSON-serialize nodes, groups, or metadata maps."
	if source.find("static func _signature_value") == -1 or source.find("static func _signature_scalar") == -1:
		return "Presentation signatures should use lightweight deterministic value signatures."
	return ""
