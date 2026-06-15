@tool
extends RefCounted
class_name ToolPresentationService

const SystemTreeCatalog = preload("res://addons/godot_dotnet_mcp/plugin/runtime/system_tree_catalog.gd")
const ToolAnnotationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_annotation_service.gd")
const ToolCatalogManifest = preload("res://addons/godot_dotnet_mcp/tools/tool_catalog_manifest.gd")

const PRESENTATION_VERSION := 1
const JSON_SCHEMA_2020_12_URI := "https://json-schema.org/draft/2020-12/schema"


static func build_tool_presentation(
	exposed_tools: Array,
	all_tools_by_category: Dictionary,
	domain_states: Array = [],
	disabled_tools: Array = [],
	domain_defs: Array = []
) -> Dictionary:
	if domain_defs.is_empty():
		domain_defs = ToolCatalogManifest.get_domain_defs()
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

	var presentation := {
		"presentationVersion": PRESENTATION_VERSION,
		"toolTree": roots,
		"toolGroups": groups,
		"toolMetadataByName": metadata_by_name
	}
	presentation["signature"] = build_presentation_signature("domain_catalog", roots, groups, metadata_by_name)
	return presentation


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
		tool["inputSchema"] = build_tool_input_schema(tool)
		tool["outputSchema"] = build_tool_output_schema(tool)
		enriched.append(tool)
	return enriched


static func build_mcp_tool_list(tools: Array, _presentation: Dictionary = {}) -> Array[Dictionary]:
	var tools_list: Array[Dictionary] = []
	for tool_def in tools:
		if not (tool_def is Dictionary):
			continue
		var tool := tool_def as Dictionary
		var item := {
			"name": tool.get("name", ""),
			"description": tool.get("description", ""),
			"inputSchema": build_tool_input_schema(tool),
			"outputSchema": build_tool_output_schema(tool),
			"annotations": ToolAnnotationService.build_annotations(tool)
		}
		tools_list.append(item)
	return tools_list


static func get_json_schema_dialect() -> String:
	return JSON_SCHEMA_2020_12_URI


static func build_presentation_signature(view: String, roots: Array, groups: Array = [], metadata_by_name: Dictionary = {}) -> String:
	var entries: Array[String] = [
		"presentation_version=%d" % PRESENTATION_VERSION,
		"view=%s" % view
	]
	_append_node_signature_entries(entries, roots)
	_append_group_signature_entries(entries, groups)
	_append_metadata_signature_entries(entries, metadata_by_name)
	return "\n".join(entries)


static func _append_node_signature_entries(entries: Array[String], nodes: Array) -> void:
	entries.append("nodes=%d" % nodes.size())
	for node_value in nodes:
		if not (node_value is Dictionary):
			entries.append("node|invalid")
			continue
		var node := node_value as Dictionary
		entries.append("node|%s" % JSON.stringify([
			str(node.get("kind", "")),
			str(node.get("id", "")),
			str(node.get("key", "")),
			str(node.get("label", "")),
			str(node.get("labelKey", "")),
			str(node.get("category", "")),
			str(node.get("domain", "")),
			str(node.get("fullName", node.get("full_name", ""))),
			str(node.get("tool_name", node.get("toolName", ""))),
			str(node.get("actionName", node.get("action", ""))),
			str(node.get("parentTool", node.get("parent_tool", ""))),
			str(node.get("visibility", "")),
			str(node.get("callability", "")),
			str(node.get("source", "")),
			str(node.get("script_path", node.get("scriptPath", ""))),
			str(node.get("domain_script_path", node.get("domainScriptPath", ""))),
			str(node.get("loadState", node.get("load_state", ""))),
			str(node.get("title", "")),
			str(node.get("description", "")),
			str(node.get("replacement", "")),
			str(node.get("reason", "")),
			bool(node.get("enabled", true)),
			int(node.get("enabledCount", node.get("enabledToolCount", 0))),
			int(node.get("totalCount", node.get("toolCount", 0))),
			int(node.get("loadErrorCount", 0)),
			node.get("icons", []),
			node.get("annotations", {}),
			node.get("inputSchema", {}),
			node.get("outputSchema", {}),
			node.get("metadata", {}),
			node.get("treeChildren", [])
		]))
		var children = node.get("children", [])
		if children is Array:
			_append_node_signature_entries(entries, children as Array)


static func _append_group_signature_entries(entries: Array[String], groups: Array) -> void:
	entries.append("groups=%d" % groups.size())
	for group_value in groups:
		if group_value is Dictionary:
			entries.append("group|%s" % JSON.stringify(group_value))
		else:
			entries.append("group|invalid")


static func _append_metadata_signature_entries(entries: Array[String], metadata_by_name: Dictionary) -> void:
	var names: Array = metadata_by_name.keys()
	names.sort()
	entries.append("metadata=%d" % names.size())
	for name_value in names:
		var name := str(name_value)
		var metadata = metadata_by_name.get(name_value, {})
		if metadata is Dictionary:
			entries.append("metadata|%s|%s" % [name, JSON.stringify(metadata)])
		else:
			entries.append("metadata|%s|invalid" % name)


static func get_atomic_child_specs(parent_full_name: String) -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	for entry in SystemTreeCatalog.SYSTEM_TOOL_ATOMIC_CHILDREN.get(parent_full_name, []):
		var atomic_full_name := ""
		var actions: Array = []
		if entry is Dictionary:
			atomic_full_name = str((entry as Dictionary).get("tool", ""))
			actions = (entry as Dictionary).get("actions", [])
		else:
			atomic_full_name = str(entry)
		if atomic_full_name.is_empty():
			continue
		specs.append({
			"tool": atomic_full_name,
			"actions": _duplicate_array(actions)
		})
	return specs


static func has_atomic_children(parent_full_name: String) -> bool:
	return not get_atomic_child_specs(parent_full_name).is_empty()


static func get_action_name_key(parent_full_name: String, action_name: String) -> String:
	return SystemTreeCatalog.get_action_name_key(parent_full_name, action_name)


static func get_generic_action_name_key(action_name: String) -> String:
	return SystemTreeCatalog.get_generic_action_name_key(action_name)


static func get_action_desc_key(parent_full_name: String, action_name: String) -> String:
	return SystemTreeCatalog.get_action_desc_key(parent_full_name, action_name)


static func get_generic_action_desc_key(action_name: String) -> String:
	return SystemTreeCatalog.get_generic_action_desc_key(action_name)


static func normalize_json_schema(schema, fallback: Dictionary = {}) -> Dictionary:
	var schema_dict: Dictionary = {}
	if schema is Dictionary:
		schema_dict = (schema as Dictionary).duplicate(true)
	elif not fallback.is_empty():
		schema_dict = fallback.duplicate(true)
	else:
		schema_dict = {"type": "object", "properties": {}}
	if not schema_dict.has("$schema"):
		schema_dict["$schema"] = JSON_SCHEMA_2020_12_URI
	return schema_dict


static func build_tool_input_schema(tool: Dictionary) -> Dictionary:
	return normalize_json_schema(tool.get("inputSchema", null), {"type": "object", "properties": {}})


static func build_tool_output_schema(tool: Dictionary) -> Dictionary:
	var explicit_schema = tool.get("outputSchema", tool.get("output_schema", null))
	if explicit_schema is Dictionary:
		return normalize_json_schema(explicit_schema)
	return normalize_json_schema(_build_default_tool_output_schema())


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
	var annotations := ToolAnnotationService.build_annotations(_tool_with_full_name(tool, full_name))
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
		"description": str(tool.get("description", "")),
		"title": str(annotations.get("title", "")),
		"icons": _duplicate_array(tool.get("icons", [])),
		"annotations": annotations,
		"inputSchema": build_tool_input_schema(tool),
		"outputSchema": build_tool_output_schema(tool),
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
		var annotations := ToolAnnotationService.build_annotations(_tool_with_full_name(atomic_tool, atomic_full_name))
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
			"description": str(atomic_tool.get("description", "")),
			"title": str(annotations.get("title", "")),
			"icons": _duplicate_array(atomic_tool.get("icons", [])),
			"annotations": annotations,
			"inputSchema": build_tool_input_schema(atomic_tool),
			"outputSchema": build_tool_output_schema(atomic_tool),
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
		"description": str(node.get("description", "")),
		"title": str(node.get("title", "")),
		"icons": _duplicate_array(node.get("icons", [])),
		"annotations": _duplicate_dictionary(node.get("annotations", {})),
		"inputSchema": _duplicate_dictionary(node.get("inputSchema", {})),
		"outputSchema": _duplicate_dictionary(node.get("outputSchema", {})),
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
