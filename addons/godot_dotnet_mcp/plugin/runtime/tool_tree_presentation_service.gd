@tool
extends RefCounted
class_name ToolTreePresentationService

const ToolAnnotationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_annotation_service.gd")
const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")
const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")

const PRESENTATION_VERSION := 1

const AGENT_TOOL_GROUPS: Array[Dictionary] = [
	{
		"key": "project_context",
		"labelKey": "agent_tools_group_project_context",
		"tools": [
			"system_project_state",
			"system_project_files",
			"system_project_configure",
			"system_project_lifecycle",
			"system_project_index_build",
			"system_project_symbol_search",
			"system_scene_dependency_graph"
		]
	},
	{
		"key": "editor_automation",
		"labelKey": "agent_tools_group_editor_automation",
		"tools": [
			"system_editor_state",
			"system_editor_control",
			"system_editor_evidence",
			"system_inspector",
			"system_settings_dialog"
		]
	},
	{
		"key": "scene_resource",
		"labelKey": "agent_tools_group_scene_resource",
		"tools": [
			"system_scene_tree",
			"system_scene_inspect",
			"system_scene_patch",
			"system_resource_reference_audit",
			"system_bindings_audit"
		]
	},
	{
		"key": "script_semantics",
		"labelKey": "agent_tools_group_script_csharp_semantics",
		"tools": [
			"system_script_analyze",
			"system_script_patch",
			"system_bindings_audit"
		]
	},
	{
		"key": "runtime_debugging",
		"labelKey": "agent_tools_group_runtime_debugging",
		"tools": [
			"system_runtime_control",
			"system_runtime_step",
			"system_runtime_diagnose",
			"system_dap_debugger"
		]
	},
	{
		"key": "plugin_maintenance",
		"labelKey": "agent_tools_group_plugin_maintenance",
		"tools": [
			"system_editor_plugin_control",
			"system_plugin_maintenance",
			"system_userdata_maintenance"
		]
	},
	{
		"key": "user_tools",
		"labelKey": "agent_tools_group_user_tools",
		"tools": []
	}
]


static func build_agent_tool_tree(exposed_tools: Array, disabled_tools: Array = []) -> Dictionary:
	var exposed_by_name := _build_exposed_public_lookup(exposed_tools)
	var disabled_lookup := _build_disabled_lookup(disabled_tools)
	var seen := {}
	var roots: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	var metadata_by_name := {}

	for group_def in AGENT_TOOL_GROUPS:
		var group_key := str(group_def.get("key", ""))
		var ordered_tools: Array = group_def.get("tools", [])
		var tool_nodes: Array[Dictionary] = []
		if group_key == "user_tools":
			var user_names := _collect_category_tool_names(exposed_by_name, "user")
			ordered_tools = user_names
		for tool_name_value in ordered_tools:
			var tool_name := str(tool_name_value)
			if seen.has(tool_name) or not exposed_by_name.has(tool_name):
				continue
			var tool: Dictionary = exposed_by_name.get(tool_name, {})
			var node := _build_public_tool_node(tool_name, tool, group_key, disabled_lookup)
			tool_nodes.append(node)
			metadata_by_name[tool_name] = _build_tool_metadata(node)
			seen[tool_name] = true
		if tool_nodes.is_empty():
			continue
		var counts := _count_enabled(tool_nodes)
		var group_node := {
			"kind": "tool_group",
			"id": "agent_group:%s" % group_key,
			"key": group_key,
			"label": str(group_def.get("label", group_key)),
			"labelKey": str(group_def.get("labelKey", "tool_group_%s" % group_key)),
			"visibility": "public",
			"callability": "not_callable",
			"enabledCount": int(counts.get("enabled", 0)),
			"totalCount": int(counts.get("total", 0)),
			"children": tool_nodes
		}
		roots.append(group_node)
		groups.append({
			"id": group_node.get("id", ""),
			"kind": "tool_group",
			"key": group_key,
			"labelKey": group_node.get("labelKey", ""),
			"toolIds": _node_keys(tool_nodes),
			"enabledCount": group_node.get("enabledCount", 0),
			"totalCount": group_node.get("totalCount", 0)
		})

	var uncategorized := _collect_uncategorized_public_tools(exposed_by_name, seen)
	if not uncategorized.is_empty():
		var tool_nodes: Array[Dictionary] = []
		for tool_name in uncategorized:
			var tool: Dictionary = exposed_by_name.get(tool_name, {})
			var node := _build_public_tool_node(tool_name, tool, "other_agent_tools", disabled_lookup)
			tool_nodes.append(node)
			metadata_by_name[tool_name] = _build_tool_metadata(node)
			seen[tool_name] = true
		var counts := _count_enabled(tool_nodes)
		var group_node := {
			"kind": "tool_group",
			"id": "agent_group:other_agent_tools",
			"key": "other_agent_tools",
			"label": "other_agent_tools",
			"labelKey": "agent_tools_group_other_agent_tools",
			"visibility": "public",
			"callability": "not_callable",
			"enabledCount": int(counts.get("enabled", 0)),
			"totalCount": int(counts.get("total", 0)),
			"children": tool_nodes
		}
		roots.append(group_node)
		groups.append({
			"id": group_node.get("id", ""),
			"kind": "tool_group",
			"key": group_node.get("key", ""),
			"labelKey": group_node.get("labelKey", ""),
			"toolIds": _node_keys(tool_nodes),
			"enabledCount": group_node.get("enabledCount", 0),
			"totalCount": group_node.get("totalCount", 0)
		})
	var presentation := {
		"presentationVersion": PRESENTATION_VERSION,
		"view": "agent_tools",
		"toolTree": roots,
		"toolGroups": groups,
		"toolMetadataByName": metadata_by_name
	}
	presentation["signature"] = ToolPresentationService.build_presentation_signature("agent_tools", roots, groups, metadata_by_name)
	return presentation


static func build_internal_executor_tree(
	all_tools_by_category: Dictionary,
	exposed_tools: Array,
	domain_states: Array = [],
	catalog_manifest: Dictionary = {}
) -> Dictionary:
	var exposed_lookup := _build_exposed_name_lookup(exposed_tools)
	var domain_defs: Array = catalog_manifest.get("domain_defs", ToolCatalogManifest.get_domain_defs())
	var category_states := _build_category_state_lookup(domain_states)
	var roots: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	for domain_def in domain_defs:
		if not (domain_def is Dictionary):
			continue
		var domain_dict := domain_def as Dictionary
		var domain_key := str(domain_dict.get("key", "other"))
		var category_nodes: Array[Dictionary] = []
		for category_value in domain_dict.get("categories", []):
			var category := str(category_value)
			if not all_tools_by_category.has(category):
				continue
			var tools = all_tools_by_category.get(category, [])
			if not (tools is Array):
				continue
			var tool_nodes: Array[Dictionary] = []
			var public_produced: Array[String] = []
			var internal_count := 0
			for raw_tool in tools:
				if not (raw_tool is Dictionary):
					continue
				var tool := raw_tool as Dictionary
				var full_name := _get_full_name(category, tool)
				if full_name.is_empty():
					continue
				var is_exposed := exposed_lookup.has(full_name)
				if is_exposed:
					public_produced.append(full_name)
				else:
					internal_count += 1
				tool_nodes.append(_build_executor_tool_node(category, domain_key, full_name, tool, is_exposed))
			if tool_nodes.is_empty():
				continue
			var state: Dictionary = category_states.get(category, {})
			var category_node := {
				"kind": "executor_category",
				"id": "executor:%s" % category,
				"key": category,
				"label": category,
				"category": category,
				"domain": domain_key,
				"labelKey": "cat_%s" % category,
				"visibility": "advanced",
				"callability": "not_callable",
				"loaded": bool(state.get("loaded", true)),
				"toolCount": tool_nodes.size(),
				"enabledToolCount": int(state.get("enabled_tool_count", tool_nodes.size())),
				"loadErrorCount": int(state.get("load_error_count", 0)),
				"lastError": state.get("last_error", null),
				"publicToolsProduced": public_produced,
				"internalToolCount": internal_count,
				"children": tool_nodes
			}
			category_nodes.append(category_node)
			groups.append({
				"id": category_node.get("id", ""),
				"kind": "executor_category",
				"key": category,
				"domain": domain_key,
				"toolIds": _node_keys(tool_nodes),
				"totalCount": tool_nodes.size()
			})
		if category_nodes.is_empty():
			continue
		roots.append({
			"kind": "executor_domain",
			"id": "executor_domain:%s" % domain_key,
			"key": domain_key,
			"label": str(domain_dict.get("label", domain_key)),
			"domain": domain_key,
			"labelKey": str(domain_dict.get("label", "domain_%s" % domain_key)),
			"visibility": "advanced",
			"callability": "not_callable",
			"totalCount": category_nodes.size(),
			"children": category_nodes
		})
	var presentation := {
		"presentationVersion": PRESENTATION_VERSION,
		"view": "internal_executors",
		"toolTree": roots,
		"toolGroups": groups
	}
	presentation["signature"] = ToolPresentationService.build_presentation_signature("internal_executors", roots, groups)
	return presentation


static func build_diagnostics_tree(exposed_tools: Array, all_tools_by_category: Dictionary, loader_status: Dictionary = {}) -> Dictionary:
	var exposed_lookup := _build_exposed_name_lookup(exposed_tools)
	var diagnostics: Array[Dictionary] = []
	var exposed_children: Array[Dictionary] = []
	for tool_name in _sorted_keys(exposed_lookup):
		var tool: Dictionary = exposed_lookup.get(tool_name, {})
		exposed_children.append({
			"kind": "diagnostic_node",
			"id": "diagnostic:tool:%s" % tool_name,
			"key": tool_name,
			"label": tool_name,
			"tool_name": tool_name,
			"category": str(tool.get("category", "")),
			"visibility": "public",
			"callability": "callable",
			"source": str(tool.get("source", "")),
			"schema": {
				"inputSchema": ToolPresentationService.build_tool_input_schema(tool),
				"outputSchema": ToolPresentationService.build_tool_output_schema(tool)
			},
			"children": []
		})
	if not exposed_children.is_empty():
		diagnostics.append({
			"kind": "diagnostic_node",
			"id": "diagnostic:public_tools",
			"key": "public_tools",
			"labelKey": "tool_diagnostics_public_tools",
			"visibility": "public",
			"callability": "not_callable",
			"children": exposed_children
		})

	var legacy_children: Array[Dictionary] = []
	for removed_tool in ToolCatalogManifest.get_removed_public_tool_names():
		legacy_children.append({
			"kind": "legacy_tool",
			"id": "diagnostic:legacy:%s" % removed_tool,
			"key": removed_tool,
			"label": removed_tool,
			"tool_name": removed_tool,
			"visibility": "removed",
			"callability": "compat_callable",
			"replacement": "godot-dotnet-mcp://guides/index",
			"reason": "context_moved_to_resources_prompts_or_canonical_tools",
			"children": []
		})
	if not legacy_children.is_empty():
		diagnostics.append({
			"kind": "diagnostic_node",
			"id": "diagnostic:legacy_tools",
			"key": "legacy_tools",
			"labelKey": "tool_diagnostics_legacy_tools",
			"visibility": "legacy",
			"callability": "not_callable",
			"children": legacy_children
		})

	var category_children: Array[Dictionary] = []
	for category in _sorted_dictionary_keys(all_tools_by_category):
		var tools = all_tools_by_category.get(category, [])
		category_children.append({
			"kind": "diagnostic_node",
			"id": "diagnostic:category:%s" % category,
			"key": category,
			"label": category,
			"category": category,
			"visibility": "internal" if not ToolCatalogManifest.is_public_category(category) else "public",
			"callability": "not_callable",
			"toolCount": (tools as Array).size() if tools is Array else 0,
			"children": []
		})
	diagnostics.append({
		"kind": "diagnostic_node",
		"id": "diagnostic:executor_categories",
		"key": "executor_categories",
		"labelKey": "tool_diagnostics_executor_categories",
		"visibility": "advanced",
		"callability": "not_callable",
		"status": loader_status.duplicate(true),
		"children": category_children
	})
	var presentation := {
		"presentationVersion": PRESENTATION_VERSION,
		"view": "tool_diagnostics",
		"toolTree": diagnostics
	}
	presentation["signature"] = ToolPresentationService.build_presentation_signature("tool_diagnostics", diagnostics)
	return presentation


static func _build_public_tool_node(tool_name: String, tool: Dictionary, group_key: String, disabled_lookup: Dictionary) -> Dictionary:
	var enabled := not disabled_lookup.has(tool_name) and bool(tool.get("enabled", true))
	var annotations := ToolAnnotationService.build_annotations(_tool_with_full_name(tool, tool_name))
	return {
		"kind": "public_tool",
		"id": "tool:%s" % tool_name,
		"key": tool_name,
		"label": str(annotations.get("title", tool_name)),
		"tool_name": tool_name,
		"fullName": tool_name,
		"category": str(tool.get("category", _category_from_name(tool_name))),
		"group": group_key,
		"visibility": "public",
		"callability": "callable" if enabled else "disabled",
		"enabled": enabled,
		"description": str(tool.get("description", "")),
		"title": str(annotations.get("title", "")),
		"icons": _duplicate_array(tool.get("icons", [])),
		"annotations": annotations,
		"inputSchema": ToolPresentationService.build_tool_input_schema(tool),
		"outputSchema": ToolPresentationService.build_tool_output_schema(tool),
		"source": str(tool.get("source", "")),
		"script_path": str(tool.get("script_path", tool.get("scriptPath", ""))),
		"metadata": {
			"resourceAlternatives": _duplicate_array(tool.get("resourceAlternatives", [])),
			"promptAlternatives": _duplicate_array(tool.get("promptAlternatives", []))
		},
		"children": []
	}


static func _build_executor_tool_node(category: String, domain_key: String, full_name: String, tool: Dictionary, is_exposed: bool) -> Dictionary:
	var visibility := "public" if is_exposed else "internal"
	return {
		"kind": "executor_tool",
		"id": "executor_tool:%s" % full_name,
		"key": full_name,
		"label": full_name,
		"tool_name": full_name,
		"fullName": full_name,
		"category": category,
		"domain": domain_key,
		"visibility": visibility,
		"callability": "callable" if is_exposed else "not_callable",
		"source": str(tool.get("source", "")),
		"loadState": str(tool.get("load_state", tool.get("loadState", ""))),
		"script_path": str(tool.get("script_path", tool.get("scriptPath", ""))),
		"children": []
	}


static func _build_tool_metadata(node: Dictionary) -> Dictionary:
	return {
		"id": str(node.get("id", "")),
		"kind": str(node.get("kind", "")),
		"key": str(node.get("key", "")),
		"label": str(node.get("label", "")),
		"toolName": str(node.get("tool_name", "")),
		"fullName": str(node.get("fullName", "")),
		"category": str(node.get("category", "")),
		"group": str(node.get("group", "")),
		"visibility": str(node.get("visibility", "")),
		"callability": str(node.get("callability", "")),
		"enabled": bool(node.get("enabled", true)),
		"description": str(node.get("description", "")),
		"title": str(node.get("title", "")),
		"icons": _duplicate_array(node.get("icons", [])),
		"annotations": _duplicate_dictionary(node.get("annotations", {})),
		"inputSchema": _duplicate_dictionary(node.get("inputSchema", {})),
		"outputSchema": _duplicate_dictionary(node.get("outputSchema", {})),
		"source": str(node.get("source", "")),
		"script_path": str(node.get("script_path", "")),
		"metadata": _duplicate_dictionary(node.get("metadata", {}))
	}


static func _build_exposed_public_lookup(exposed_tools: Array) -> Dictionary:
	var lookup := {}
	for raw_tool in exposed_tools:
		if not (raw_tool is Dictionary):
			continue
		var tool := raw_tool as Dictionary
		var full_name := str(tool.get("name", tool.get("full_name", "")))
		if full_name.is_empty() or ToolCatalogManifest.is_removed_public_tool(full_name):
			continue
		var category := str(tool.get("category", _category_from_name(full_name)))
		if not ToolCatalogManifest.is_public_category(category):
			continue
		var copy := tool.duplicate(true)
		copy["name"] = full_name
		copy["full_name"] = full_name
		copy["category"] = category
		lookup[full_name] = copy
	return lookup


static func _build_exposed_name_lookup(exposed_tools: Array) -> Dictionary:
	var lookup := {}
	for raw_tool in exposed_tools:
		if not (raw_tool is Dictionary):
			continue
		var tool := raw_tool as Dictionary
		var full_name := str(tool.get("name", tool.get("full_name", "")))
		if full_name.is_empty():
			continue
		var copy := tool.duplicate(true)
		copy["name"] = full_name
		copy["full_name"] = full_name
		if not copy.has("category"):
			copy["category"] = _category_from_name(full_name)
		lookup[full_name] = copy
	return lookup


static func _build_disabled_lookup(disabled_tools: Array) -> Dictionary:
	var lookup := {}
	for tool_name in disabled_tools:
		lookup[str(tool_name)] = true
	return lookup


static func _collect_category_tool_names(tools_by_name: Dictionary, category: String) -> Array[String]:
	var names: Array[String] = []
	for tool_name in tools_by_name.keys():
		var tool: Dictionary = tools_by_name.get(tool_name, {})
		if str(tool.get("category", "")) == category:
			names.append(str(tool_name))
	names.sort()
	return names


static func _collect_uncategorized_public_tools(tools_by_name: Dictionary, seen: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for tool_name in tools_by_name.keys():
		var name := str(tool_name)
		if seen.has(name):
			continue
		var category := str((tools_by_name.get(name, {}) as Dictionary).get("category", ""))
		if category == "user":
			continue
		names.append(name)
	names.sort()
	return names


static func _count_enabled(nodes: Array[Dictionary]) -> Dictionary:
	var total := 0
	var enabled := 0
	for node in nodes:
		total += 1
		if bool(node.get("enabled", true)):
			enabled += 1
	return {"total": total, "enabled": enabled}


static func _node_keys(nodes: Array[Dictionary]) -> Array[String]:
	var keys: Array[String] = []
	for node in nodes:
		keys.append(str(node.get("key", "")))
	return keys


static func _build_category_state_lookup(domain_states: Array) -> Dictionary:
	var lookup := {}
	for state in domain_states:
		if not (state is Dictionary):
			continue
		var state_dict := state as Dictionary
		var category := str(state_dict.get("category", ""))
		if not category.is_empty():
			lookup[category] = state_dict.duplicate(true)
	return lookup


static func _sorted_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in values.keys():
		keys.append(str(key))
	keys.sort()
	return keys


static func _sorted_dictionary_keys(values: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key in values.keys():
		keys.append(str(key))
	keys.sort()
	return keys


static func _get_full_name(category: String, tool: Dictionary) -> String:
	var full_name := str(tool.get("full_name", ""))
	if not full_name.is_empty():
		return full_name
	var name := str(tool.get("name", ""))
	if name.is_empty():
		return ""
	if name.begins_with("%s_" % category):
		return name
	return "%s_%s" % [category, name]


static func _category_from_name(tool_name: String) -> String:
	for category in ToolCatalogManifest.get_builtin_categories():
		if tool_name.begins_with("%s_" % category):
			return category
	return ""


static func _tool_with_full_name(tool: Dictionary, full_name: String) -> Dictionary:
	var copy := tool.duplicate(true)
	copy["name"] = full_name
	copy["full_name"] = full_name
	return copy


static func _duplicate_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _duplicate_array(value) -> Array:
	if value is Array:
		return (value as Array).duplicate(true)
	return []
