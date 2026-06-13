@tool
extends RefCounted

## Builds the Dock Resources presentation tree from protocol resource metadata.
## Classification is intentionally limited to projected metadata fields.

const GROUP_DEFS := [
	{"id": "guides", "label": "Guides", "label_key": "mcp_resource_group_guides", "kinds": ["guide"]},
	{"id": "project_state", "label": "Project State", "label_key": "mcp_resource_group_project_state", "kinds": ["state"]},
	{"id": "editor_state", "label": "Editor State", "label_key": "mcp_resource_group_editor_state", "kinds": ["state"]},
	{"id": "activity_logs", "label": "Activity & Logs", "label_key": "mcp_resource_group_activity_logs", "kinds": ["activity", "log"]},
	{"id": "tool_catalog", "label": "Tool Catalog", "label_key": "mcp_resource_group_tool_catalog", "kinds": ["catalog"]},
	{"id": "resource_templates", "label": "Resource Templates", "label_key": "mcp_resource_group_templates", "kinds": ["template"]},
	{"id": "advanced_resources", "label": "Advanced Resources", "label_key": "mcp_resource_group_advanced", "kinds": ["diagnostic", "resource"]}
]


func build_resource_catalog_tree(resources, templates) -> Dictionary:
	var groups: Array[Dictionary] = []
	var entries_by_id := {}
	var group_lookup := {}
	for group_def in GROUP_DEFS:
		var group := _make_group(group_def)
		groups.append(group)
		group_lookup[str(group.get("id", ""))] = group

	for raw_resource in _safe_array(resources):
		if not (raw_resource is Dictionary):
			continue
		var entry := _make_entry(raw_resource as Dictionary, false)
		_add_entry_to_group(entry, group_lookup, entries_by_id)
	for raw_template in _safe_array(templates):
		if not (raw_template is Dictionary):
			continue
		var entry := _make_entry(raw_template as Dictionary, true)
		_add_entry_to_group(entry, group_lookup, entries_by_id)

	var visible_groups: Array[Dictionary] = []
	for group in groups:
		if not (group.get("children", []) as Array).is_empty():
			group["count"] = (group.get("children", []) as Array).size()
			visible_groups.append(group)

	return {
		"presentationVersion": 1,
		"view": "resource_catalog",
		"resourceTree": visible_groups,
		"resourceGroups": visible_groups,
		"entriesById": entries_by_id,
		"counts": {
			"resources": _safe_array(resources).size(),
			"resource_templates": _safe_array(templates).size(),
			"groups": visible_groups.size()
		}
	}


func _make_group(group_def: Dictionary) -> Dictionary:
	return {
		"id": str(group_def.get("id", "")),
		"label": str(group_def.get("label", "")),
		"label_key": str(group_def.get("label_key", "")),
		"kind": "resource_group",
		"visibility": "public",
		"callability": "not_callable",
		"metadata": {
			"resource_kinds": (group_def.get("kinds", []) as Array).duplicate(true)
		},
		"children": [],
		"count": 0
	}


func _make_entry(entry: Dictionary, is_template: bool) -> Dictionary:
	var id := _entry_id(entry, is_template)
	var kind := "resource_template" if is_template else "resource_entry"
	var resource_kind := str(entry.get("resource_kind", "template" if is_template else "resource")).strip_edges()
	return {
		"id": id,
		"label": str(entry.get("title", entry.get("name", id))),
		"kind": kind,
		"resource_uri": id,
		"uriTemplate": str(entry.get("uriTemplate", "")),
		"resource_kind": resource_kind if not resource_kind.is_empty() else ("template" if is_template else "resource"),
		"resource_group": str(entry.get("resource_group", "")).strip_edges(),
		"visibility": "public",
		"callability": "not_callable",
		"source": "resources/templates/list" if is_template else "resources/list",
		"metadata": {
			"mimeType": str(entry.get("mimeType", "")),
			"description": str(entry.get("description", "")),
			"icons": _safe_array(entry.get("icons", [])).duplicate(true),
			"is_template": is_template
		},
		"entry": entry.duplicate(true),
		"children": []
	}


func _add_entry_to_group(entry: Dictionary, group_lookup: Dictionary, entries_by_id: Dictionary) -> void:
	var group_id := str(entry.get("resource_group", "")).strip_edges()
	if group_id.is_empty():
		group_id = _group_id_for_kind(str(entry.get("resource_kind", "")))
	var group: Dictionary = group_lookup.get(group_id, group_lookup.get("advanced_resources", {}))
	if group.is_empty():
		return
	(group["children"] as Array).append(entry)
	entries_by_id[str(entry.get("id", ""))] = entry


func _group_id_for_kind(resource_kind: String) -> String:
	match resource_kind:
		"project_state", "editor_state", "activity_logs", "tool_catalog", "resource_templates", "advanced_resources", "guides":
			return resource_kind
	match resource_kind:
		"guide":
			return "guides"
		"state":
			return "project_state"
		"activity", "log":
			return "activity_logs"
		"catalog":
			return "tool_catalog"
		"template":
			return "resource_templates"
		_:
			return "advanced_resources"


func _entry_id(entry: Dictionary, is_template: bool) -> String:
	if is_template:
		return str(entry.get("uriTemplate", entry.get("uri", "")))
	var uri_template := str(entry.get("uriTemplate", "")).strip_edges()
	if not uri_template.is_empty():
		return uri_template
	return str(entry.get("uri", ""))


func _safe_array(value) -> Array:
	if value is Array:
		return value as Array
	return []
