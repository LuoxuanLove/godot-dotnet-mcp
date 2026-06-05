@tool
extends RefCounted
class_name ToolCatalogSearchService

const ToolPresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")

const DEFAULT_LIMIT := 25
const MAX_LIMIT := 100


static func search(loader, args: Dictionary) -> Dictionary:
	if loader == null or not loader.has_method("get_exposed_tool_definitions"):
		return {"success": false, "error": "tool_loader_unavailable", "message": "Tool loader is unavailable"}

	var visibility := str(args.get("visibility", "exposed")).strip_edges().to_lower()
	if visibility.is_empty():
		visibility = "exposed"
	if visibility not in ["exposed", "visible"]:
		return {"success": false, "error": "invalid_argument", "message": "visibility must be exposed or visible"}

	var limit := clampi(int(args.get("limit", DEFAULT_LIMIT)), 1, MAX_LIMIT)
	var query := str(args.get("query", "")).strip_edges()
	var domain_filters := _string_filter_set(args.get("domain", args.get("domain_key", "")))
	var category_filters := _string_filter_set(args.get("category", ""))
	var include_schema := bool(args.get("include_schema", false))

	var catalog := _build_catalog(loader, visibility == "visible", include_schema)
	var matches: Array[Dictionary] = []
	var total_matched := 0
	for tool in catalog:
		var tool_dict := tool as Dictionary
		if not category_filters.is_empty() and not category_filters.has(str(tool_dict.get("category", "")).to_lower()):
			continue
		if not domain_filters.is_empty() and not domain_filters.has(str(tool_dict.get("domain_key", "")).to_lower()):
			continue
		var match_reasons := _match_reasons(tool_dict, query)
		if not query.is_empty() and match_reasons.is_empty():
			continue
		total_matched += 1
		if matches.size() < limit:
			var item := tool_dict.duplicate(true)
			item["match_reasons"] = match_reasons
			matches.append(item)

	return {
		"success": true,
		"data": {
			"summary": {
				"query": query,
				"visibility": visibility,
				"limit": limit,
				"include_schema": include_schema,
				"total_scanned": catalog.size(),
				"total_matched": total_matched,
				"result_count": matches.size(),
				"truncated": total_matched > matches.size(),
				"filters": {
					"domain": domain_filters.keys(),
					"category": category_filters.keys()
				}
			},
			"matches": matches,
			"tool_loader_status": _get_loader_status(loader)
		},
		"message": "Tool catalog search complete"
	}


static func _build_catalog(loader, include_internal: bool, include_schema: bool) -> Array[Dictionary]:
	var exposed_tools: Array = loader.get_exposed_tool_definitions()
	var all_tools_by_category := _get_all_tools_by_category(loader)
	var domain_states := _get_domain_states(loader)
	var presentation := ToolPresentationServiceScript.build_tool_presentation(exposed_tools, all_tools_by_category, domain_states)
	var metadata_by_name: Dictionary = presentation.get("toolMetadataByName", {})
	var source_tools: Array = exposed_tools
	if include_internal:
		if loader.has_method("get_tool_definitions"):
			source_tools = loader.get_tool_definitions()
	var exposed_lookup := {}
	for exposed in exposed_tools:
		if exposed is Dictionary:
			exposed_lookup[str((exposed as Dictionary).get("name", ""))] = true

	var out: Array[Dictionary] = []
	var seen := {}
	for raw_tool in source_tools:
		if not (raw_tool is Dictionary):
			continue
		var tool := raw_tool as Dictionary
		var full_name := str(tool.get("name", tool.get("full_name", "")))
		if full_name.is_empty() or seen.has(full_name):
			continue
		seen[full_name] = true
		var metadata: Dictionary = metadata_by_name.get(full_name, {})
		var input_schema: Dictionary = tool.get("inputSchema", {"type": "object", "properties": {}})
		var item := {
			"name": full_name,
			"kind": "tool",
			"description": str(tool.get("description", "")),
			"category": str(tool.get("category", metadata.get("category", ""))),
			"domain_key": str(tool.get("domain_key", tool.get("domainKey", metadata.get("domainKey", "other")))),
			"enabled": bool(metadata.get("enabled", tool.get("enabled", true))),
			"exposed": exposed_lookup.has(full_name),
			"source": str(tool.get("source", "builtin")),
			"load_state": str(tool.get("load_state", tool.get("loadState", "definitions_only"))),
			"group_path": metadata.get("groupPath", tool.get("groupPath", [])),
			"actions": _extract_actions(input_schema),
			"params": _extract_params(input_schema)
		}
		if include_schema:
			item["input_schema"] = input_schema.duplicate(true)
		out.append(item)
	return out


static func _get_all_tools_by_category(loader) -> Dictionary:
	if loader.has_method("get_all_tools_by_category"):
		return loader.get_all_tools_by_category()
	if loader.has_method("get_tools_by_category"):
		return loader.get_tools_by_category()
	return {}


static func _get_domain_states(loader) -> Array:
	if loader.has_method("get_domain_states"):
		return loader.get_domain_states()
	return []


static func _get_loader_status(loader) -> Dictionary:
	if loader.has_method("get_tool_loader_status"):
		return loader.get_tool_loader_status()
	return {}


static func _extract_actions(input_schema: Dictionary) -> Array[String]:
	var properties: Dictionary = input_schema.get("properties", {})
	var action_schema = properties.get("action", {})
	var actions: Array[String] = []
	if action_schema is Dictionary:
		for value in (action_schema as Dictionary).get("enum", []):
			actions.append(str(value))
	actions.sort()
	return actions


static func _extract_params(input_schema: Dictionary) -> Array[Dictionary]:
	var properties: Dictionary = input_schema.get("properties", {})
	var required_lookup := {}
	for value in input_schema.get("required", []):
		required_lookup[str(value)] = true
	var params: Array[Dictionary] = []
	for key in properties.keys():
		var name := str(key)
		var schema = properties.get(key, {})
		var entry := {
			"name": name,
			"required": required_lookup.has(name),
			"type": "",
			"description": "",
			"enum": []
		}
		if schema is Dictionary:
			var schema_dict := schema as Dictionary
			entry["type"] = str(schema_dict.get("type", ""))
			entry["description"] = str(schema_dict.get("description", ""))
			var enum_values: Array = schema_dict.get("enum", [])
			if not enum_values.is_empty():
				var enum_text: Array[String] = []
				for value in enum_values:
					enum_text.append(str(value))
				entry["enum"] = enum_text
		params.append(entry)
	params.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return params


static func _string_filter_set(value) -> Dictionary:
	var out := {}
	if value is Array:
		for item in value:
			var key := str(item).strip_edges().to_lower()
			if not key.is_empty():
				out[key] = true
		return out
	var key := str(value).strip_edges().to_lower()
	if not key.is_empty():
		out[key] = true
	return out


static func _match_reasons(tool: Dictionary, query: String) -> Array[String]:
	if query.is_empty():
		return ["no_query"]
	var needle := query.to_lower()
	var reasons: Array[String] = []
	_add_match_reason(reasons, "name", str(tool.get("name", "")), needle)
	_add_match_reason(reasons, "description", str(tool.get("description", "")), needle)
	_add_match_reason(reasons, "category", str(tool.get("category", "")), needle)
	_add_match_reason(reasons, "domain", str(tool.get("domain_key", "")), needle)
	for action in tool.get("actions", []):
		_add_match_reason(reasons, "action", str(action), needle)
	for parameter in tool.get("params", []):
		if not (parameter is Dictionary):
			continue
		var param := parameter as Dictionary
		_add_match_reason(reasons, "param", str(param.get("name", "")), needle)
		_add_match_reason(reasons, "param_description", str(param.get("description", "")), needle)
		for enum_value in param.get("enum", []):
			_add_match_reason(reasons, "param_enum", str(enum_value), needle)
	return reasons


static func _add_match_reason(reasons: Array[String], field: String, value: String, needle: String) -> void:
	if value.to_lower().find(needle) != -1 and not reasons.has(field):
		reasons.append(field)
