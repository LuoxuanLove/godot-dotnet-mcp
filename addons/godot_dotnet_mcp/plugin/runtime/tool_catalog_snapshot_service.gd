@tool
extends RefCounted
class_name ToolCatalogSnapshotService

const ToolPresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")
const ToolTreePresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_tree_presentation_service.gd")
const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")


static func build_snapshot(loader, overrides: Dictionary = {}) -> Dictionary:
	if loader == null or not loader.has_method("get_exposed_tool_definitions"):
		return {"success": false, "error": "tool_loader_unavailable", "message": "Tool loader is unavailable"}

	var catalog_manifest := _build_catalog_manifest_snapshot()
	var tools_by_category_source = overrides.get("all_tools_by_category", _get_all_tools_by_category(loader))
	var all_tools_by_category := _filter_removed_tools_by_category(loader, tools_by_category_source if tools_by_category_source is Dictionary else {})
	var exposed_source = overrides.get("exposed_tools", loader.get_exposed_tool_definitions())
	var exposed_tools := _filter_removed_tools(loader, exposed_source if exposed_source is Array else [])
	if exposed_tools.is_empty() and not overrides.has("exposed_tools"):
		exposed_tools = _derive_exposed_tools_from_categories(loader, all_tools_by_category, catalog_manifest)
	var visible_tools := exposed_tools.duplicate(true)
	if overrides.has("visible_tools"):
		var visible_source = overrides.get("visible_tools", [])
		visible_tools = _filter_removed_tools(loader, visible_source if visible_source is Array else [])
	elif loader.has_method("get_tool_definitions"):
		visible_tools = _filter_removed_tools(loader, loader.get_tool_definitions())
	var category_state_source = overrides.get("category_states", _get_domain_states(loader))
	var category_states := _duplicate_dictionary_array(category_state_source if category_state_source is Array else [])
	var domain_states := _aggregate_domain_states(category_states, catalog_manifest.get("domain_defs", []))
	var disabled_source = overrides.get("disabled_tools", [])
	var presentation_views := _normalize_presentation_views(overrides.get("presentation_views", []))
	var build_all_views := presentation_views.is_empty()
	var needs_legacy := build_all_views or presentation_views.has("legacy")
	var needs_agent := build_all_views or presentation_views.has("agent_tools")
	var presentation := {}
	if needs_legacy:
		presentation = ToolPresentationServiceScript.build_tool_presentation(
			exposed_tools,
			all_tools_by_category,
			domain_states,
			disabled_source if disabled_source is Array else [],
			catalog_manifest.get("domain_defs", [])
		)
	var disabled_tools: Array = disabled_source if disabled_source is Array else []
	var agent_tool_presentation := ToolTreePresentationServiceScript.build_agent_tool_tree(exposed_tools, disabled_tools, all_tools_by_category) if needs_agent else {}

	return {
		"success": true,
		"catalog_manifest": catalog_manifest,
		"exposed_tools": exposed_tools,
		"visible_tools": visible_tools,
		"all_tools_by_category": all_tools_by_category,
		"category_states": category_states,
		"domain_states": domain_states,
		"presentation": presentation.duplicate(true),
		"agent_tool_presentation": agent_tool_presentation.duplicate(true),
		"tool_loader_status": _get_loader_status(loader)
	}


static func _normalize_presentation_views(raw_views) -> Array[String]:
	var views: Array[String] = []
	if not (raw_views is Array):
		return views
	for raw_view in raw_views:
		var view := str(raw_view).strip_edges()
		match view:
			"legacy", "agent_tools":
				if not views.has(view):
					views.append(view)
	return views


static func _filter_removed_tools(loader, tools: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for raw_tool in tools:
		if not (raw_tool is Dictionary):
			continue
		var tool := raw_tool as Dictionary
		var full_name := str(tool.get("name", tool.get("full_name", "")))
		if full_name.is_empty() or seen.has(full_name):
			continue
		if _is_public_removed_tool(loader, full_name):
			continue
		seen[full_name] = true
		out.append(tool.duplicate(true))
	return out


static func _filter_removed_tools_by_category(loader, tools_by_category: Dictionary) -> Dictionary:
	var out := {}
	var ordered_categories := _ordered_categories(tools_by_category)
	for raw_category in ordered_categories:
		var category := str(raw_category)
		var tools = tools_by_category.get(raw_category, [])
		var filtered: Array[Dictionary] = []
		if tools is Array:
			for raw_tool in tools:
				if not (raw_tool is Dictionary):
					continue
				var tool := raw_tool as Dictionary
				var full_name := _get_full_name(category, tool)
				if full_name.is_empty() or _is_public_removed_tool(loader, full_name):
					continue
				filtered.append(tool.duplicate(true))
		out[category] = filtered
	return out


static func _derive_exposed_tools_from_categories(loader, tools_by_category: Dictionary, catalog_manifest: Dictionary) -> Array[Dictionary]:
	var exposed: Array[Dictionary] = []
	var seen := {}
	var public_categories: Array = catalog_manifest.get("public_categories", [])
	for raw_category in _ordered_categories(tools_by_category):
		var category := str(raw_category)
		if not public_categories.has(category):
			continue
		var tools = tools_by_category.get(raw_category, [])
		if not (tools is Array):
			continue
		for raw_tool in tools:
			if not (raw_tool is Dictionary):
				continue
			var tool := raw_tool as Dictionary
			if bool(tool.get("compatibility_alias", false)):
				continue
			var full_name := _get_full_name(category, tool)
			if full_name.is_empty() or seen.has(full_name):
				continue
			if _is_public_removed_tool(loader, full_name):
				continue
			var exposed_tool := tool.duplicate(true)
			exposed_tool["name"] = full_name
			exposed_tool["full_name"] = full_name
			exposed_tool["category"] = category
			seen[full_name] = true
			exposed.append(exposed_tool)
	return exposed


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


static func _aggregate_domain_states(category_states: Array[Dictionary], domain_defs: Array) -> Array[Dictionary]:
	var domain_order := _domain_order(domain_defs)
	var by_domain := {}
	for domain_def in domain_defs:
		if not (domain_def is Dictionary):
			continue
		var domain_key := str((domain_def as Dictionary).get("key", ""))
		if domain_key.is_empty():
			domain_key = str((domain_def as Dictionary).get("domain_key", ""))
		if domain_key.is_empty():
			continue
		by_domain[domain_key] = {
			"domain": domain_key,
			"domain_key": domain_key,
			"categories": [],
			"category_count": 0,
			"loaded_category_count": 0,
			"loaded": false,
			"tool_count": 0,
			"enabled_tool_count": 0,
			"load_error_count": 0,
			"last_errors": []
		}
	for state in category_states:
		var category := str(state.get("category", state.get("domain", "")))
		var domain_key := str(state.get("domain_key", ""))
		if domain_key.is_empty():
			domain_key = ToolCatalogManifest.get_domain_key_for_category(category)
		if domain_key.is_empty():
			domain_key = str(state.get("domain", category))
		if domain_key.is_empty():
			continue
		if not by_domain.has(domain_key):
			by_domain[domain_key] = {
				"domain": domain_key,
				"domain_key": domain_key,
				"categories": [],
				"category_count": 0,
				"loaded_category_count": 0,
				"loaded": true,
				"tool_count": 0,
				"enabled_tool_count": 0,
				"load_error_count": 0,
				"last_errors": []
			}
		var aggregate: Dictionary = by_domain[domain_key]
		var categories: Array = aggregate.get("categories", [])
		if not category.is_empty() and not categories.has(category):
			categories.append(category)
			aggregate["categories"] = categories
		aggregate["category_count"] = int(aggregate.get("category_count", 0)) + 1
		if bool(state.get("loaded", false)):
			aggregate["loaded_category_count"] = int(aggregate.get("loaded_category_count", 0)) + 1
		else:
			aggregate["loaded"] = false
		aggregate["tool_count"] = int(aggregate.get("tool_count", 0)) + int(state.get("tool_count", 0))
		aggregate["enabled_tool_count"] = int(aggregate.get("enabled_tool_count", 0)) + int(state.get("enabled_tool_count", 0))
		var last_error = state.get("last_error", null)
		if last_error != null:
			aggregate["load_error_count"] = int(aggregate.get("load_error_count", 0)) + 1
			var last_errors: Array = aggregate.get("last_errors", [])
			last_errors.append(last_error)
			aggregate["last_errors"] = last_errors
	var out: Array[Dictionary] = []
	var keys := _ordered_keys(by_domain, domain_order)
	for key in keys:
		var aggregate: Dictionary = by_domain[key]
		var categories: Array = aggregate.get("categories", [])
		categories.sort()
		aggregate["categories"] = categories
		out.append(aggregate)
	return out


static func _get_loader_status(loader) -> Dictionary:
	if loader.has_method("get_tool_loader_status"):
		var status = loader.get_tool_loader_status()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {}


static func _duplicate_dictionary_array(values: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for value in values:
		if value is Dictionary:
			out.append((value as Dictionary).duplicate(true))
	return out


static func _get_full_name(category: String, tool: Dictionary) -> String:
	var tool_name := str(tool.get("name", ""))
	var full_name := str(tool.get("full_name", ""))
	if not full_name.is_empty():
		return full_name
	if tool_name.is_empty():
		return ""
	if tool_name.begins_with("%s_" % category):
		return tool_name
	return "%s_%s" % [category, tool_name]


static func _is_public_removed_tool(loader, full_name: String) -> bool:
	if ToolCatalogManifest.is_removed_public_tool(full_name):
		return true
	return loader.has_method("is_public_removed_tool") and bool(loader.is_public_removed_tool(full_name))


static func _build_catalog_manifest_snapshot() -> Dictionary:
	return {
		"domain_defs": ToolCatalogManifest.get_domain_defs(),
		"categories": ToolCatalogManifest.get_all_tool_categories(),
		"builtin_categories": ToolCatalogManifest.get_builtin_categories(),
		"public_categories": ToolCatalogManifest.get_public_mcp_tool_categories(),
		"removed_public_tools": ToolCatalogManifest.get_removed_public_tool_names()
	}


static func build_public_catalog_manifest(catalog_manifest: Dictionary) -> Dictionary:
	return {
		"domain_defs": catalog_manifest.get("domain_defs", []),
		"categories": catalog_manifest.get("categories", []),
		"builtin_categories": catalog_manifest.get("builtin_categories", []),
		"public_categories": catalog_manifest.get("public_categories", []),
		"removed_public_tool_count": (catalog_manifest.get("removed_public_tools", []) as Array).size()
	}


static func _ordered_categories(tools_by_category: Dictionary) -> Array[String]:
	var ordered: Array[String] = []
	var seen := {}
	for category in ToolCatalogManifest.get_builtin_categories():
		if tools_by_category.has(category):
			ordered.append(category)
			seen[category] = true
	var extras: Array[String] = []
	for raw_category in tools_by_category.keys():
		var category := str(raw_category)
		if not seen.has(category):
			extras.append(category)
	extras.sort()
	ordered.append_array(extras)
	return ordered


static func _domain_order(domain_defs: Array) -> Dictionary:
	var order := {}
	for index in range(domain_defs.size()):
		var domain_def = domain_defs[index]
		if domain_def is Dictionary:
			order[str((domain_def as Dictionary).get("key", ""))] = index
	return order


static func _ordered_keys(values: Dictionary, order: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in values.keys():
		keys.append(str(key))
	keys.sort_custom(func(a: String, b: String) -> bool:
		var left_order := int(order.get(a, 9999))
		var right_order := int(order.get(b, 9999))
		if left_order == right_order:
			return a < b
		return left_order < right_order
	)
	return keys
