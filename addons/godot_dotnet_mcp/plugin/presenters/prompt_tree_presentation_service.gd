@tool
extends RefCounted

## Builds the Dock Prompts presentation tree from protocol prompt metadata.
## Prompt grouping consumes projected prompt_kind values instead of prompt names.

const GROUP_DEFS := [
	{"id": "project_understanding", "label": "Project Understanding", "label_key": "mcp_prompt_group_project_understanding", "kinds": ["orientation"]},
	{"id": "editor_workflow", "label": "Editor Workflow", "label_key": "mcp_prompt_group_editor_workflow", "kinds": ["editor_ui", "authoring"]},
	{"id": "runtime_validation", "label": "Runtime Validation", "label_key": "mcp_prompt_group_runtime_validation", "kinds": ["runtime", "debug"]},
	{"id": "script_csharp_workflow", "label": "Script & C# Workflow", "label_key": "mcp_prompt_group_script_csharp", "kinds": ["integrity"]},
	{"id": "plugin_maintenance", "label": "Plugin Maintenance", "label_key": "mcp_prompt_group_plugin_maintenance", "kinds": ["plugin"]},
	{"id": "advanced_prompts", "label": "Advanced Prompts", "label_key": "mcp_prompt_group_advanced", "kinds": ["prompt"]}
]


func build_prompt_catalog_tree(prompts) -> Dictionary:
	var groups: Array[Dictionary] = []
	var entries_by_id := {}
	var group_lookup := {}
	for group_def in GROUP_DEFS:
		var group := _make_group(group_def)
		groups.append(group)
		group_lookup[str(group.get("id", ""))] = group

	for raw_prompt in _safe_array(prompts):
		if not (raw_prompt is Dictionary):
			continue
		var entry := _make_entry(raw_prompt as Dictionary)
		_add_entry_to_group(entry, group_lookup, entries_by_id)

	var visible_groups: Array[Dictionary] = []
	for group in groups:
		if not (group.get("children", []) as Array).is_empty():
			group["count"] = (group.get("children", []) as Array).size()
			visible_groups.append(group)

	return {
		"presentationVersion": 1,
		"view": "prompt_catalog",
		"promptTree": visible_groups,
		"promptGroups": visible_groups,
		"entriesById": entries_by_id,
		"counts": {
			"prompts": _safe_array(prompts).size(),
			"groups": visible_groups.size()
		}
	}


func _make_group(group_def: Dictionary) -> Dictionary:
	return {
		"id": str(group_def.get("id", "")),
		"label": str(group_def.get("label", "")),
		"label_key": str(group_def.get("label_key", "")),
		"kind": "prompt_group",
		"visibility": "public",
		"callability": "not_callable",
		"metadata": {
			"prompt_kinds": (group_def.get("kinds", []) as Array).duplicate(true)
		},
		"children": [],
		"count": 0
	}


func _make_entry(prompt: Dictionary) -> Dictionary:
	var name := str(prompt.get("name", "")).strip_edges()
	var argument_nodes: Array[Dictionary] = []
	for raw_argument in _safe_array(prompt.get("arguments", [])):
		if not (raw_argument is Dictionary):
			continue
		var argument := raw_argument as Dictionary
		var argument_name := str(argument.get("name", "")).strip_edges()
		if argument_name.is_empty():
			continue
		argument_nodes.append({
			"id": "%s/%s" % [name, argument_name],
			"label": argument_name,
			"kind": "prompt_argument",
			"prompt_name": name,
			"visibility": "public",
			"callability": "not_callable",
			"metadata": argument.duplicate(true),
			"children": []
		})
	var prompt_kind := str(prompt.get("prompt_kind", "prompt")).strip_edges()
	return {
		"id": name,
		"label": str(prompt.get("title", name)),
		"kind": "prompt_entry",
		"prompt_name": name,
		"prompt_kind": prompt_kind if not prompt_kind.is_empty() else "prompt",
		"visibility": "public",
		"callability": "not_callable",
		"source": "prompts/list",
		"metadata": {
			"description": str(prompt.get("description", "")),
			"icons": _safe_array(prompt.get("icons", [])).duplicate(true),
			"argument_count": argument_nodes.size()
		},
		"entry": prompt.duplicate(true),
		"children": argument_nodes
	}


func _add_entry_to_group(entry: Dictionary, group_lookup: Dictionary, entries_by_id: Dictionary) -> void:
	var group_id := _group_id_for_kind(str(entry.get("prompt_kind", "")))
	var group: Dictionary = group_lookup.get(group_id, group_lookup.get("advanced_prompts", {}))
	if group.is_empty():
		return
	(group["children"] as Array).append(entry)
	entries_by_id[str(entry.get("id", ""))] = entry


func _group_id_for_kind(prompt_kind: String) -> String:
	match prompt_kind:
		"orientation":
			return "project_understanding"
		"editor_ui", "authoring":
			return "editor_workflow"
		"runtime", "debug":
			return "runtime_validation"
		"integrity":
			return "script_csharp_workflow"
		"plugin":
			return "plugin_maintenance"
		_:
			return "advanced_prompts"


func _safe_array(value) -> Array:
	if value is Array:
		return value as Array
	return []
