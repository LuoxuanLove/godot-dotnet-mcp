@tool
extends RefCounted
class_name ToolCatalogSearchService

const ToolCatalogSnapshotServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_snapshot_service.gd")

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

	var snapshot := ToolCatalogSnapshotServiceScript.build_snapshot(loader)
	if not bool(snapshot.get("success", false)):
		return {
			"success": false,
			"error": str(snapshot.get("error", "tool_loader_unavailable")),
			"message": str(snapshot.get("message", "Tool loader is unavailable"))
		}

	var catalog := _build_catalog(snapshot, visibility == "visible", include_schema)
	var catalog_filter_index := _build_filter_index(catalog)
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
	var diagnostics := _build_search_diagnostics(
		query,
		visibility,
		domain_filters,
		category_filters,
		catalog_filter_index,
		total_matched
	)

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
				},
				"available_filters": {
					"domain": catalog_filter_index.get("domain", []),
					"category": catalog_filter_index.get("category", [])
				},
				"filter_warnings": diagnostics.get("filter_warnings", []),
				"suggested_next_queries": diagnostics.get("suggested_next_queries", [])
			},
			"matches": matches,
			"tool_loader_status": snapshot.get("tool_loader_status", {})
		},
		"message": "Tool catalog search complete"
	}


static func _build_catalog(snapshot: Dictionary, include_internal: bool, include_schema: bool) -> Array[Dictionary]:
	var exposed_tools: Array = snapshot.get("exposed_tools", [])
	var presentation: Dictionary = snapshot.get("presentation", {})
	var metadata_by_name: Dictionary = presentation.get("toolMetadataByName", {})
	var source_tools: Array = exposed_tools
	if include_internal:
		source_tools = snapshot.get("visible_tools", exposed_tools)
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
		var output_schema := _get_tool_output_schema(tool)
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
			item["output_schema"] = output_schema
		out.append(item)
	return out


static func _extract_actions(input_schema: Dictionary) -> Array[String]:
	var properties: Dictionary = input_schema.get("properties", {})
	var action_schema = properties.get("action", {})
	var actions: Array[String] = []
	if action_schema is Dictionary:
		for value in (action_schema as Dictionary).get("enum", []):
			actions.append(str(value))
	actions.sort()
	return actions


static func _get_tool_output_schema(tool: Dictionary) -> Dictionary:
	var explicit_schema = tool.get("outputSchema", tool.get("output_schema", null))
	if explicit_schema is Dictionary:
		return (explicit_schema as Dictionary).duplicate(true)
	return _build_default_tool_output_schema()


static func _build_default_tool_output_schema() -> Dictionary:
	return {
		"type": "object",
		"additionalProperties": true,
		"required": ["success"],
		"properties": {
			"success": {"type": "boolean"},
			"data": {
				"type": ["object", "array", "string", "number", "boolean", "null"],
				"description": "Tool-specific structured payload.",
				"additionalProperties": true
			},
			"message": {"type": "string"},
			"error": {"type": "string"},
			"hints": {
				"type": "array",
				"items": {"type": "string"}
			},
			"activity": {
				"type": "object",
				"additionalProperties": true
			}
		}
	}


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


static func _build_filter_index(catalog: Array[Dictionary]) -> Dictionary:
	var domains := {}
	var categories := {}
	for tool in catalog:
		var domain := str(tool.get("domain_key", "")).strip_edges().to_lower()
		var category := str(tool.get("category", "")).strip_edges().to_lower()
		if not domain.is_empty():
			domains[domain] = true
		if not category.is_empty():
			categories[category] = true
	return {
		"domain": _sorted_keys(domains),
		"category": _sorted_keys(categories)
	}


static func _build_search_diagnostics(
	query: String,
	visibility: String,
	domain_filters: Dictionary,
	category_filters: Dictionary,
	filter_index: Dictionary,
	total_matched: int
) -> Dictionary:
	var warnings: Array[Dictionary] = []
	var suggestions: Array[Dictionary] = []
	var available_domains: Array = filter_index.get("domain", [])
	var available_categories: Array = filter_index.get("category", [])
	_append_filter_warnings(warnings, suggestions, "domain", domain_filters.keys(), category_filters.keys(), available_domains, available_categories, query, visibility)
	_append_filter_warnings(warnings, suggestions, "category", category_filters.keys(), domain_filters.keys(), available_categories, available_domains, query, visibility)
	if total_matched == 0 and warnings.is_empty() and (not domain_filters.is_empty() or not category_filters.is_empty()):
		suggestions.append({
			"query": query,
			"visibility": visibility,
			"domain": [],
			"category": [],
			"reason": "Remove filters to check whether the query matches another tool group."
		})
	if total_matched == 0 and suggestions.is_empty() and not query.is_empty():
		suggestions.append({
			"query": "",
			"visibility": visibility,
			"domain": domain_filters.keys(),
			"category": category_filters.keys(),
			"reason": "Clear the query to inspect tools available under the current filters."
		})
	return {
		"filter_warnings": warnings,
		"suggested_next_queries": suggestions
	}


static func _append_filter_warnings(
	warnings: Array[Dictionary],
	suggestions: Array[Dictionary],
	filter_name: String,
	requested_values: Array,
	paired_values: Array,
	available_values: Array,
	alternate_values: Array,
	query: String,
	visibility: String
) -> void:
	for raw_value in requested_values:
		var value := str(raw_value).strip_edges().to_lower()
		if value.is_empty() or available_values.has(value):
			continue
		var warning := {
			"filter": filter_name,
			"value": value,
			"available": available_values,
			"message": "%s filter '%s' is not available in %s tool catalog results." % [filter_name, value, visibility]
		}
		if alternate_values.has(value):
			warning["hint"] = "'%s' is available as the other filter type." % value
		warnings.append(warning)
		suggestions.append(_suggest_filter_removal(filter_name, value, requested_values, paired_values, query, visibility))
		if alternate_values.has(value):
			suggestions.append(_suggest_filter_transfer(filter_name, value, query, visibility))


static func _suggest_filter_removal(filter_name: String, value: String, requested_values: Array, paired_values: Array, query: String, visibility: String) -> Dictionary:
	var suggestion := {
		"query": query,
		"visibility": visibility,
		"reason": "Remove unavailable %s filter '%s'." % [filter_name, value]
	}
	var retained_values := _filter_values_except(requested_values, value)
	if filter_name == "domain":
		suggestion["domain"] = retained_values
		suggestion["category"] = paired_values
	else:
		suggestion["domain"] = paired_values
		suggestion["category"] = retained_values
	return suggestion


static func _filter_values_except(values: Array, excluded_value: String) -> Array[String]:
	var retained: Array[String] = []
	for raw_value in values:
		var value := str(raw_value).strip_edges().to_lower()
		if value.is_empty() or value == excluded_value:
			continue
		if not retained.has(value):
			retained.append(value)
	retained.sort()
	return retained


static func _suggest_filter_transfer(filter_name: String, value: String, query: String, visibility: String) -> Dictionary:
	if filter_name == "domain":
		return {
			"query": query,
			"visibility": visibility,
			"domain": [],
			"category": [value],
			"reason": "Use '%s' as a category filter instead of a domain filter." % value
		}
	return {
		"query": query,
		"visibility": visibility,
		"domain": [value],
		"category": [],
		"reason": "Use '%s' as a domain filter instead of a category filter." % value
	}


static func _sorted_keys(values: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in values.keys():
		out.append(str(key))
	out.sort()
	return out


static func _add_match_reason(reasons: Array[String], field: String, value: String, needle: String) -> void:
	if value.to_lower().find(needle) != -1 and not reasons.has(field):
		reasons.append(field)
