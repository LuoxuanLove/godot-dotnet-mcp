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


static func build_agent_tool_tree(exposed_tools: Array, disabled_tools: Array = [], all_tools_by_category: Dictionary = {}) -> Dictionary:
	var exposed_by_name := _build_exposed_public_lookup(exposed_tools)
	var all_tools_by_name := _build_all_tool_lookup(all_tools_by_category)
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
			var node := _build_public_tool_node(tool_name, tool, group_key, disabled_lookup, all_tools_by_name)
			tool_nodes.append(node)
			_index_tool_metadata_recursive(node, metadata_by_name)
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
			var node := _build_public_tool_node(tool_name, tool, "other_agent_tools", disabled_lookup, all_tools_by_name)
			tool_nodes.append(node)
			_index_tool_metadata_recursive(node, metadata_by_name)
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


static func _build_public_tool_node(tool_name: String, tool: Dictionary, group_key: String, disabled_lookup: Dictionary, all_tools_by_name: Dictionary) -> Dictionary:
	var enabled := not disabled_lookup.has(tool_name) and bool(tool.get("enabled", true))
	var annotations := ToolAnnotationService.build_annotations(_tool_with_full_name(tool, tool_name))
	var children := _build_architecture_children(tool_name, tool, all_tools_by_name, disabled_lookup, ["tool:%s" % tool_name], {})
	var child_ids: Array[String] = []
	for child in children:
		child_ids.append(str(child.get("id", "")))
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
		"groupPath": ["tool:%s" % tool_name],
		"treeChildren": child_ids,
		"children": children
	}


static func _build_architecture_children(parent_full_name: String, tool: Dictionary, all_tools_by_name: Dictionary, disabled_lookup: Dictionary, parent_path: Array, visited: Dictionary) -> Array[Dictionary]:
	var children: Array[Dictionary] = []
	var action_nodes: Array[Dictionary] = []
	for action in _extract_action_values(tool):
		action_nodes.append(_build_action_node(parent_full_name, str(action), parent_path))
	if not action_nodes.is_empty():
		children.append(_build_architecture_group_node(parent_full_name, "actions", "tool_architecture_actions", action_nodes, parent_path))
	var next_visited := visited.duplicate()
	next_visited[parent_full_name] = true
	var atomic_nodes := _build_atomic_nodes(parent_full_name, all_tools_by_name, disabled_lookup, parent_path, next_visited)
	if not atomic_nodes.is_empty():
		children.append(_build_architecture_group_node(parent_full_name, "implemented_by", "tool_architecture_implemented_by", atomic_nodes, parent_path))
	return children


static func _build_architecture_group_node(parent_full_name: String, group_key: String, label_key: String, children: Array[Dictionary], parent_path: Array) -> Dictionary:
	var group_path := parent_path.duplicate()
	group_path.append("architecture:%s.%s" % [parent_full_name, group_key])
	var child_ids: Array[String] = []
	for child in children:
		child_ids.append(str(child.get("id", "")))
	return {
		"kind": "architecture_group",
		"id": "architecture:%s:%s" % [parent_full_name, group_key],
		"key": "%s:%s" % [parent_full_name, group_key],
		"labelKey": label_key,
		"parentTool": parent_full_name,
		"parent_tool": parent_full_name,
		"visibility": "internal",
		"callability": "not_callable",
		"totalCount": children.size(),
		"groupPath": group_path,
		"treeChildren": child_ids,
		"children": children
	}


static func _build_atomic_nodes(parent_full_name: String, all_tools_by_name: Dictionary, disabled_lookup: Dictionary, parent_path: Array, visited: Dictionary) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for entry in ToolPresentationService.get_atomic_child_specs(parent_full_name):
		var atomic_full_name := ""
		var actions: Array = []
		if entry is Dictionary:
			atomic_full_name = str((entry as Dictionary).get("tool", ""))
			actions = (entry as Dictionary).get("actions", [])
		else:
			atomic_full_name = str(entry)
		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		var atomic_tool: Dictionary = all_tools_by_name.get(atomic_full_name, {})
		if atomic_tool.is_empty():
			continue
		var next_path := parent_path.duplicate()
		next_path.append("atomic:%s" % atomic_full_name)
		var next_visited := visited.duplicate()
		next_visited[atomic_full_name] = true
		var nested_children: Array[Dictionary] = []
		var action_nodes: Array[Dictionary] = []
		for action in actions:
			action_nodes.append(_build_action_node(atomic_full_name, str(action), next_path))
		if not action_nodes.is_empty():
			nested_children.append(_build_architecture_group_node(atomic_full_name, "actions", "tool_architecture_actions", action_nodes, next_path))
		var deeper_atomic := _build_atomic_nodes(atomic_full_name, all_tools_by_name, disabled_lookup, next_path, next_visited)
		if not deeper_atomic.is_empty():
			nested_children.append(_build_architecture_group_node(atomic_full_name, "implemented_by", "tool_architecture_implemented_by", deeper_atomic, next_path))
		nodes.append(_build_atomic_tool_node(atomic_full_name, atomic_tool, disabled_lookup, next_path, nested_children))
	return nodes


static func _build_atomic_tool_node(full_name: String, tool: Dictionary, disabled_lookup: Dictionary, group_path: Array, children: Array[Dictionary]) -> Dictionary:
	var category := str(tool.get("category", _category_from_name(full_name)))
	var tool_name := str(tool.get("name", full_name.trim_prefix("%s_" % category)))
	var annotations := ToolAnnotationService.build_annotations(_tool_with_full_name(tool, full_name))
	var child_ids: Array[String] = []
	for child in children:
		child_ids.append(str(child.get("id", "")))
	return {
		"kind": "atomic",
		"id": "atomic:%s" % full_name,
		"key": full_name,
		"label": str(annotations.get("title", full_name)),
		"tool_name": tool_name,
		"toolName": tool_name,
		"fullName": full_name,
		"category": category,
		"visibility": "internal",
		"callability": "not_callable",
		"enabled": not disabled_lookup.has(full_name) and bool(tool.get("enabled", true)),
		"description": str(tool.get("description", "")),
		"title": str(annotations.get("title", "")),
		"icons": _duplicate_array(tool.get("icons", [])),
		"annotations": annotations,
		"inputSchema": ToolPresentationService.build_tool_input_schema(tool),
		"outputSchema": ToolPresentationService.build_tool_output_schema(tool),
		"source": str(tool.get("source", "")),
		"loadState": str(tool.get("load_state", tool.get("loadState", ""))),
		"script_path": str(tool.get("script_path", tool.get("scriptPath", ""))),
		"scriptPath": str(tool.get("script_path", tool.get("scriptPath", ""))),
		"domain_script_path": str(tool.get("domain_script_path", tool.get("domainScriptPath", ""))),
		"domainScriptPath": str(tool.get("domain_script_path", tool.get("domainScriptPath", ""))),
		"groupPath": group_path,
		"treeChildren": child_ids,
		"children": children
	}


static func _build_action_node(parent_full_name: String, action_name: String, parent_path: Array) -> Dictionary:
	var group_path := parent_path.duplicate()
	group_path.append("action:%s.%s" % [parent_full_name, action_name])
	return {
		"kind": "action",
		"id": "action:%s.%s" % [parent_full_name, action_name],
		"key": "%s.%s" % [parent_full_name, action_name],
		"actionName": action_name,
		"action": action_name,
		"parentTool": parent_full_name,
		"parent_tool": parent_full_name,
		"labelKey": ToolPresentationService.get_action_name_key(parent_full_name, action_name),
		"descriptionKey": ToolPresentationService.get_action_desc_key(parent_full_name, action_name),
		"groupPath": group_path,
		"visibility": "internal",
		"callability": "not_callable",
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
		"loadState": str(node.get("loadState", "")),
		"script_path": str(node.get("script_path", "")),
		"scriptPath": str(node.get("scriptPath", node.get("script_path", ""))),
		"domain_script_path": str(node.get("domain_script_path", "")),
		"domainScriptPath": str(node.get("domainScriptPath", node.get("domain_script_path", ""))),
		"groupPath": _duplicate_array(node.get("groupPath", [])),
		"treeChildren": _collect_direct_atomic_child_ids(node),
		"metadata": _duplicate_dictionary(node.get("metadata", {}))
	}


static func _collect_direct_atomic_child_ids(node: Dictionary) -> Array[String]:
	var child_ids: Array[String] = []
	for child in node.get("children", []):
		if not (child is Dictionary):
			continue
		var child_dict := child as Dictionary
		if str(child_dict.get("kind", "")) == "atomic":
			child_ids.append(str(child_dict.get("id", "")))
			continue
		if str(child_dict.get("kind", "")) != "architecture_group":
			continue
		for nested in child_dict.get("children", []):
			if not (nested is Dictionary):
				continue
			var nested_dict := nested as Dictionary
			if str(nested_dict.get("kind", "")) == "atomic":
				child_ids.append(str(nested_dict.get("id", "")))
	return child_ids


static func _index_tool_metadata_recursive(node: Dictionary, metadata_by_name: Dictionary) -> void:
	var kind := str(node.get("kind", ""))
	if kind == "public_tool" or kind == "atomic":
		var full_name := str(node.get("fullName", node.get("key", "")))
		if not full_name.is_empty():
			metadata_by_name[full_name] = _build_tool_metadata(node)
	for child in node.get("children", []):
		if child is Dictionary:
			_index_tool_metadata_recursive(child as Dictionary, metadata_by_name)


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


static func _build_all_tool_lookup(all_tools_by_category: Dictionary) -> Dictionary:
	var lookup := {}
	for raw_category in all_tools_by_category.keys():
		var category := str(raw_category)
		var tools = all_tools_by_category.get(raw_category, [])
		if not (tools is Array):
			continue
		for raw_tool in tools:
			if not (raw_tool is Dictionary):
				continue
			var tool := (raw_tool as Dictionary).duplicate(true)
			var full_name := _get_full_name(category, tool)
			if full_name.is_empty():
				continue
			tool["name"] = str(tool.get("name", full_name.trim_prefix("%s_" % category)))
			tool["full_name"] = full_name
			tool["category"] = category
			lookup[full_name] = tool
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


static func _extract_action_values(tool_def: Dictionary) -> Array[String]:
	var actions: Array[String] = []
	var input_schema = tool_def.get("inputSchema", {})
	if not (input_schema is Dictionary):
		return actions
	var properties = (input_schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return actions
	var action_schema = (properties as Dictionary).get("action", {})
	if not (action_schema is Dictionary):
		return actions
	var enum_values = (action_schema as Dictionary).get("enum", [])
	if not (enum_values is Array):
		return actions
	for value in enum_values:
		var action := str(value)
		if not action.is_empty():
			actions.append(action)
	return actions


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
