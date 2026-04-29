@tool
extends RefCounted
class_name ToolPresentationService

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const MCPToolManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_manifest.gd")

const PRESENTATION_VERSION := 1


static func build_tool_presentation(
	exposed_tools: Array,
	all_tools_by_category: Dictionary,
	domain_states: Array = [],
	disabled_tools: Array = [],
	domain_defs: Array = MCPToolManifest.TOOL_DOMAIN_DEFS
) -> Dictionary:
	var tool_index := _build_tool_index(all_tools_by_category)
	var exposed_lookup := _build_exposed_lookup(exposed_tools)
	var disabled_lookup := _build_disabled_lookup(disabled_tools)
	var domain_state_lookup := _build_domain_state_lookup(domain_states)
	var metadata_by_name := {}
	var roots: Array[Dictionary] = []
	var groups: Array[Dictionary] = []

	for domain_def in domain_defs:
		if not (domain_def is Dictionary):
			continue
		var domain_dict := domain_def as Dictionary
		var domain_key := str(domain_dict.get("key", "other"))
		var domain_label_key := str(domain_dict.get("label", "domain_other"))
		var category_nodes: Array[Dictionary] = []
		var domain_tool_ids: Array[String] = []
		var domain_enabled := 0
		var domain_total := 0

		for category_value in domain_dict.get("categories", []):
			var category := str(category_value)
			var category_path := ["domain:%s" % domain_key, "category:%s" % category]
			var tool_nodes := _build_category_tool_nodes(category, category_path, all_tools_by_category, tool_index, exposed_lookup, disabled_lookup, metadata_by_name)
			if tool_nodes.is_empty():
				continue
			var category_tool_ids: Array[String] = []
			var category_enabled := 0
			for tool_node in tool_nodes:
				var full_name := str(tool_node.get("fullName", tool_node.get("key", "")))
				category_tool_ids.append(full_name)
				domain_tool_ids.append(full_name)
				if bool(tool_node.get("enabled", true)):
					category_enabled += 1
			var category_total := tool_nodes.size()
			domain_enabled += category_enabled
			domain_total += category_total
			var category_label_key := _get_category_label_key(category)
			var category_node := {
				"kind": "category",
				"id": "category:%s" % category,
				"key": category,
				"category": category,
				"labelKey": category_label_key,
				"groupPath": category_path,
				"enabledCount": category_enabled,
				"totalCount": category_total,
				"children": tool_nodes
			}
			category_nodes.append(category_node)
			groups.append({
				"id": "category:%s" % category,
				"kind": "category",
				"key": category,
				"labelKey": category_label_key,
				"groupPath": category_path,
				"toolIds": category_tool_ids,
				"enabledCount": category_enabled,
				"totalCount": category_total
			})

		if category_nodes.is_empty():
			continue
		var domain_node := {
			"kind": "domain",
			"id": "domain:%s" % domain_key,
			"key": domain_key,
			"labelKey": domain_label_key,
			"enabledCount": domain_enabled,
			"totalCount": domain_total,
			"domainState": domain_state_lookup.get(domain_key, {}),
			"children": category_nodes
		}
		roots.append(domain_node)
		groups.append({
			"id": "domain:%s" % domain_key,
			"kind": "domain",
			"key": domain_key,
			"labelKey": domain_label_key,
			"groupPath": ["domain:%s" % domain_key],
			"toolIds": domain_tool_ids,
			"enabledCount": domain_enabled,
			"totalCount": domain_total
		})

	return {
		"presentationVersion": PRESENTATION_VERSION,
		"toolTree": roots,
		"toolGroups": groups,
		"toolMetadataByName": metadata_by_name
	}


static func enrich_tools_for_presentation(tools: Array, presentation: Dictionary) -> Array[Dictionary]:
	var metadata_by_name: Dictionary = presentation.get("toolMetadataByName", {})
	var enriched: Array[Dictionary] = []
	for raw_tool in tools:
		if not (raw_tool is Dictionary):
			continue
		var tool := (raw_tool as Dictionary).duplicate(true)
		var full_name := str(tool.get("name", tool.get("full_name", "")))
		var metadata: Dictionary = metadata_by_name.get(full_name, {})
		if not metadata.is_empty():
			tool["groupPath"] = metadata.get("groupPath", [])
			tool["treeChildren"] = metadata.get("treeChildren", [])
			tool["enabled"] = bool(metadata.get("enabled", tool.get("enabled", true)))
		enriched.append(tool)
	return enriched


static func build_mcp_tool_list(tools: Array, presentation: Dictionary = {}) -> Array[Dictionary]:
	var source_tools := tools
	if not presentation.is_empty():
		source_tools = enrich_tools_for_presentation(tools, presentation)
	var tools_list: Array[Dictionary] = []
	for tool_def in source_tools:
		if not (tool_def is Dictionary):
			continue
		var tool := tool_def as Dictionary
		var item := {
			"name": tool.get("name", ""),
			"description": tool.get("description", ""),
			"category": tool.get("category", ""),
			"domainKey": tool.get("domain_key", tool.get("domainKey", "other")),
			"loadState": tool.get("load_state", tool.get("loadState", "definitions_only")),
			"source": tool.get("source", "builtin"),
			"enabled": bool(tool.get("enabled", true)),
			"inputSchema": tool.get("inputSchema", {"type": "object", "properties": {}})
		}
		if tool.has("groupPath"):
			item["groupPath"] = tool.get("groupPath", [])
		if tool.has("treeChildren"):
			item["treeChildren"] = tool.get("treeChildren", [])
		tools_list.append(item)
	return tools_list


static func _build_category_tool_nodes(
	category: String,
	category_path: Array,
	all_tools_by_category: Dictionary,
	tool_index: Dictionary,
	exposed_lookup: Dictionary,
	disabled_lookup: Dictionary,
	metadata_by_name: Dictionary
) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for tool_def in all_tools_by_category.get(category, []):
		if not (tool_def is Dictionary):
			continue
		var tool := tool_def as Dictionary
		if bool(tool.get("compatibility_alias", false)):
			continue
		var full_name := _get_full_name(category, tool)
		if not _is_top_level_tool(category, full_name, exposed_lookup):
			continue
		nodes.append(_build_tool_node(category, category_path, tool, full_name, tool_index, exposed_lookup, disabled_lookup, metadata_by_name))
	return nodes


static func _build_tool_node(
	category: String,
	category_path: Array,
	tool: Dictionary,
	full_name: String,
	tool_index: Dictionary,
	exposed_lookup: Dictionary,
	disabled_lookup: Dictionary,
	metadata_by_name: Dictionary
) -> Dictionary:
	var tool_name := str(tool.get("name", full_name.trim_prefix("%s_" % category)))
	var children: Array[Dictionary] = []
	var group_path := category_path.duplicate()
	group_path.append("tool:%s" % full_name)
	for action in _extract_action_values(tool):
		children.append(_build_action_node(full_name, str(action), group_path))
	children.append_array(_build_atomic_children(full_name, tool_index, exposed_lookup, disabled_lookup, metadata_by_name, group_path, {}))
	var child_ids: Array[String] = []
	for child in children:
		child_ids.append(str(child.get("id", "")))
	var enabled := _is_tool_enabled(tool, full_name, disabled_lookup)
	var node := {
		"kind": "tool",
		"id": "tool:%s" % full_name,
		"key": full_name,
		"category": category,
		"toolName": tool_name,
		"tool_name": tool_name,
		"fullName": full_name,
		"labelKey": "tool_%s_name" % full_name,
		"descriptionKey": "tool_%s_desc" % full_name,
		"enabled": enabled,
		"exposed": exposed_lookup.has(full_name),
		"source": str(tool.get("source", "builtin")),
		"loadState": str(tool.get("load_state", tool.get("loadState", "definitions_only"))),
		"scriptPath": str(tool.get("script_path", tool.get("scriptPath", ""))),
		"script_path": str(tool.get("script_path", tool.get("scriptPath", ""))),
		"domainScriptPath": str(tool.get("domain_script_path", tool.get("domainScriptPath", ""))),
		"domain_script_path": str(tool.get("domain_script_path", tool.get("domainScriptPath", ""))),
		"inputSchema": tool.get("inputSchema", {"type": "object", "properties": {}}),
		"groupPath": group_path,
		"treeChildren": child_ids,
		"children": children
	}
	metadata_by_name[full_name] = _build_tool_metadata(node)
	return node


static func _build_atomic_children(
	parent_full_name: String,
	tool_index: Dictionary,
	exposed_lookup: Dictionary,
	disabled_lookup: Dictionary,
	metadata_by_name: Dictionary,
	parent_path: Array,
	visited: Dictionary
) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for entry in SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.get(parent_full_name, []):
		var atomic_full_name := ""
		var actions: Array = []
		if entry is Dictionary:
			atomic_full_name = str((entry as Dictionary).get("tool", ""))
			actions = (entry as Dictionary).get("actions", [])
		else:
			atomic_full_name = str(entry)
		if atomic_full_name.is_empty() or visited.has(atomic_full_name):
			continue
		var atomic_tool: Dictionary = tool_index.get(atomic_full_name, {})
		if atomic_tool.is_empty():
			continue
		var category := str(atomic_tool.get("category", ""))
		var tool_name := str(atomic_tool.get("name", ""))
		if category.is_empty() or tool_name.is_empty():
			continue
		var next_path := parent_path.duplicate()
		next_path.append("atomic:%s" % atomic_full_name)
		var next_visited := visited.duplicate()
		next_visited[atomic_full_name] = true
		var children: Array[Dictionary] = _build_atomic_children(atomic_full_name, tool_index, exposed_lookup, disabled_lookup, metadata_by_name, next_path, next_visited)
		for action in actions:
			children.append(_build_action_node(atomic_full_name, str(action), next_path))
		var child_ids: Array[String] = []
		for child in children:
			child_ids.append(str(child.get("id", "")))
		var enabled := _is_tool_enabled(atomic_tool, atomic_full_name, disabled_lookup)
		var node := {
			"kind": "atomic",
			"id": "atomic:%s" % atomic_full_name,
			"key": atomic_full_name,
			"category": category,
			"toolName": tool_name,
			"tool_name": tool_name,
			"fullName": atomic_full_name,
			"labelKey": "tool_%s_name" % atomic_full_name,
			"descriptionKey": "tool_%s_desc" % atomic_full_name,
			"enabled": enabled,
			"exposed": exposed_lookup.has(atomic_full_name),
			"source": str(atomic_tool.get("source", "builtin")),
			"loadState": str(atomic_tool.get("load_state", atomic_tool.get("loadState", "definitions_only"))),
			"scriptPath": str(atomic_tool.get("script_path", atomic_tool.get("scriptPath", ""))),
			"script_path": str(atomic_tool.get("script_path", atomic_tool.get("scriptPath", ""))),
			"domainScriptPath": str(atomic_tool.get("domain_script_path", atomic_tool.get("domainScriptPath", ""))),
			"domain_script_path": str(atomic_tool.get("domain_script_path", atomic_tool.get("domainScriptPath", ""))),
			"inputSchema": atomic_tool.get("inputSchema", {"type": "object", "properties": {}}),
			"groupPath": next_path,
			"treeChildren": child_ids,
			"children": children
		}
		metadata_by_name[atomic_full_name] = _build_tool_metadata(node)
		nodes.append(node)
	return nodes


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
		"labelKey": SystemTreeCatalog.get_action_name_key(parent_full_name, action_name),
		"descriptionKey": SystemTreeCatalog.get_action_desc_key(parent_full_name, action_name),
		"groupPath": group_path,
		"children": []
	}


static func _build_tool_metadata(node: Dictionary) -> Dictionary:
	return {
		"id": str(node.get("id", "")),
		"kind": str(node.get("kind", "")),
		"key": str(node.get("key", "")),
		"category": str(node.get("category", "")),
		"toolName": str(node.get("toolName", "")),
		"fullName": str(node.get("fullName", "")),
		"labelKey": str(node.get("labelKey", "")),
		"enabled": bool(node.get("enabled", true)),
		"source": str(node.get("source", "")),
		"loadState": str(node.get("loadState", "")),
		"scriptPath": str(node.get("scriptPath", "")),
		"script_path": str(node.get("script_path", "")),
		"domainScriptPath": str(node.get("domainScriptPath", "")),
		"domain_script_path": str(node.get("domain_script_path", "")),
		"groupPath": node.get("groupPath", []),
		"treeChildren": node.get("treeChildren", [])
	}


static func _build_tool_index(all_tools_by_category: Dictionary) -> Dictionary:
	var index := {}
	for category in all_tools_by_category.keys():
		for tool_def in all_tools_by_category.get(category, []):
			if not (tool_def is Dictionary):
				continue
			var tool := (tool_def as Dictionary).duplicate(true)
			var category_name := str(category)
			var full_name := _get_full_name(category_name, tool)
			tool["category"] = category_name
			tool["full_name"] = full_name
			index[full_name] = tool
	return index


static func _build_exposed_lookup(exposed_tools: Array) -> Dictionary:
	var lookup := {}
	for tool_def in exposed_tools:
		if not (tool_def is Dictionary):
			continue
		var tool := tool_def as Dictionary
		var full_name := str(tool.get("name", tool.get("full_name", "")))
		if not full_name.is_empty():
			lookup[full_name] = true
	return lookup


static func _build_disabled_lookup(disabled_tools: Array) -> Dictionary:
	var lookup := {}
	for tool_name in disabled_tools:
		lookup[str(tool_name)] = true
	return lookup


static func _is_tool_enabled(tool: Dictionary, full_name: String, disabled_lookup: Dictionary) -> bool:
	if disabled_lookup.has(full_name):
		return false
	return bool(tool.get("enabled", true))


static func _build_domain_state_lookup(domain_states: Array) -> Dictionary:
	var lookup := {}
	for state in domain_states:
		if not (state is Dictionary):
			continue
		var state_dict := state as Dictionary
		var domain_key := str(state_dict.get("domain_key", state_dict.get("domain", state_dict.get("category", ""))))
		if not domain_key.is_empty():
			lookup[domain_key] = state_dict.duplicate(true)
	return lookup


static func _get_full_name(category: String, tool: Dictionary) -> String:
	var full_name := str(tool.get("full_name", ""))
	if not full_name.is_empty():
		return full_name
	return "%s_%s" % [category, str(tool.get("name", ""))]


static func _is_top_level_tool(category: String, full_name: String, exposed_lookup: Dictionary) -> bool:
	if category == "user":
		return true
	if category == "system" and SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.has(full_name):
		return true
	return exposed_lookup.has(full_name)


static func _extract_action_values(tool_def: Dictionary) -> Array:
	var schema = tool_def.get("inputSchema", {})
	if not (schema is Dictionary):
		return []
	var properties = (schema as Dictionary).get("properties", {})
	if not (properties is Dictionary):
		return []
	var action_schema = (properties as Dictionary).get("action", {})
	if not (action_schema is Dictionary):
		return []
	var enum_values = (action_schema as Dictionary).get("enum", [])
	return enum_values if enum_values is Array else []


static func _get_category_label_key(category: String) -> String:
	return "cat_%s" % category
