@tool
extends RefCounted
class_name ToolCatalogSnapshotService

const ToolPresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")


static func build_snapshot(loader) -> Dictionary:
	if loader == null or not loader.has_method("get_exposed_tool_definitions"):
		return {"success": false, "error": "tool_loader_unavailable", "message": "Tool loader is unavailable"}

	var exposed_tools := _filter_removed_tools(loader, loader.get_exposed_tool_definitions())
	var visible_tools := exposed_tools.duplicate(true)
	if loader.has_method("get_tool_definitions"):
		visible_tools = _filter_removed_tools(loader, loader.get_tool_definitions())
	var all_tools_by_category := _filter_removed_tools_by_category(loader, _get_all_tools_by_category(loader))
	var category_states := _duplicate_dictionary_array(_get_domain_states(loader))
	var domain_states := _aggregate_domain_states(category_states)
	var presentation := ToolPresentationServiceScript.build_tool_presentation(
		exposed_tools,
		all_tools_by_category,
		domain_states
	)

	return {
		"success": true,
		"exposed_tools": exposed_tools,
		"visible_tools": visible_tools,
		"all_tools_by_category": all_tools_by_category,
		"category_states": category_states,
		"domain_states": domain_states,
		"presentation": presentation.duplicate(true),
		"tool_loader_status": _get_loader_status(loader),
		"performance": _get_performance_summary(loader)
	}


static func build_mcp_tools_list_payload(snapshot: Dictionary) -> Dictionary:
	if not bool(snapshot.get("success", false)):
		return {"tools": [], "presentationVersion": 1, "toolTree": [], "toolGroups": []}
	var exposed_tools: Array = snapshot.get("exposed_tools", [])
	var presentation: Dictionary = snapshot.get("presentation", {})
	return {
		"tools": ToolPresentationServiceScript.build_mcp_tool_list(exposed_tools, presentation),
		"presentationVersion": int(presentation.get("presentationVersion", 1)),
		"toolTree": presentation.get("toolTree", []),
		"toolGroups": presentation.get("toolGroups", [])
	}


static func build_presentation_payload(snapshot: Dictionary) -> Dictionary:
	if not bool(snapshot.get("success", false)):
		return {
			"tools": [],
			"domain_states": [],
			"tool_count": 0,
			"exposed_tool_count": 0,
			"tool_loader_status": snapshot.get("tool_loader_status", {}),
			"performance": {},
			"presentationVersion": 1,
			"toolTree": [],
			"toolGroups": []
		}
	var exposed_tools: Array = snapshot.get("exposed_tools", [])
	var visible_tools: Array = snapshot.get("visible_tools", [])
	var domain_states: Array = snapshot.get("domain_states", [])
	var presentation: Dictionary = snapshot.get("presentation", {})
	return {
		"tools": ToolPresentationServiceScript.enrich_tools_for_presentation(exposed_tools, presentation),
		"domain_states": domain_states,
		"tool_count": visible_tools.size(),
		"exposed_tool_count": exposed_tools.size(),
		"tool_loader_status": snapshot.get("tool_loader_status", {}),
		"performance": snapshot.get("performance", {}),
		"presentationVersion": int(presentation.get("presentationVersion", 1)),
		"toolTree": presentation.get("toolTree", []),
		"toolGroups": presentation.get("toolGroups", [])
	}


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
	for raw_category in tools_by_category.keys():
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


static func _aggregate_domain_states(category_states: Array[Dictionary]) -> Array[Dictionary]:
	var by_domain := {}
	for state in category_states:
		var domain_key := str(state.get("domain_key", state.get("domain", state.get("category", ""))))
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
		var category := str(state.get("category", state.get("domain", "")))
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
	var keys := by_domain.keys()
	keys.sort()
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


static func _get_performance_summary(loader) -> Dictionary:
	if loader.has_method("get_performance_summary"):
		var performance = loader.get_performance_summary()
		if performance is Dictionary:
			return (performance as Dictionary).duplicate(true)
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
	return loader.has_method("is_public_removed_tool") and bool(loader.is_public_removed_tool(full_name))
