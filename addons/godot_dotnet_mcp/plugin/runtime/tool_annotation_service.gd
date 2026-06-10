@tool
extends RefCounted
class_name ToolAnnotationService

const READ_ONLY_ACTIONS := {
	"analyze": true,
	"capture": true,
	"check": true,
	"describe": true,
	"diagnose": true,
	"find": true,
	"get": true,
	"get_current": true,
	"get_dependencies": true,
	"get_info": true,
	"get_status": true,
	"inspect": true,
	"list": true,
	"query": true,
	"read": true,
	"recent": true,
	"search": true,
	"status": true,
	"validate": true
}

const IDEMPOTENT_MUTATION_ACTIONS := {
	"close": true,
	"disable": true,
	"enable": true,
	"open": true,
	"pause": true,
	"resume": true,
	"select": true,
	"set": true,
	"set_source": true,
	"show": true,
	"start": true,
	"stop": true
}

const DESTRUCTIVE_ACTIONS := {
	"clear": true,
	"delete": true,
	"full_reload_plugin": true,
	"import": true,
	"reload": true,
	"remove": true,
	"reset": true,
	"restart": true,
	"run": true,
	"save": true,
	"start_sync": true,
	"sync": true,
	"update": true,
	"write": true
}

const READ_ONLY_NAME_MARKERS := [
	"_state",
	"_status",
	"_query",
	"_inspect",
	"_evidence",
	"_catalog",
	"_activity",
	"_info",
	"_list",
	"_search"
]

const DESTRUCTIVE_NAME_MARKERS := [
	"_delete",
	"_remove",
	"_clear",
	"_reset",
	"_reload",
	"_update",
	"_import",
	"_save",
	"_write",
	"_run",
	"_build"
]


static func build_annotations(tool: Dictionary) -> Dictionary:
	var annotations: Dictionary = _get_explicit_annotations(tool)
	var tool_name := str(tool.get("name", tool.get("full_name", "")))
	var title := _get_tool_title(tool, tool_name, annotations)
	if not title.is_empty():
		annotations["title"] = title

	var behavior_hints := _infer_behavior_hints(tool, tool_name)
	for key in behavior_hints.keys():
		if not annotations.has(key):
			annotations[key] = behavior_hints[key]

	if not annotations.has("openWorldHint") and _infer_open_world_hint(tool_name):
		annotations["openWorldHint"] = _infer_open_world_hint(tool_name)

	return annotations


static func _get_explicit_annotations(tool: Dictionary) -> Dictionary:
	var explicit = tool.get("annotations", {})
	if explicit is Dictionary:
		return (explicit as Dictionary).duplicate(true)
	return {}


static func _get_tool_title(tool: Dictionary, tool_name: String, annotations: Dictionary) -> String:
	var explicit_title := str(tool.get("title", ""))
	if not explicit_title.is_empty():
		return explicit_title
	var annotation_title := str(annotations.get("title", ""))
	if not annotation_title.is_empty():
		return annotation_title
	return _humanize_tool_name(tool_name)


static func _infer_behavior_hints(tool: Dictionary, tool_name: String) -> Dictionary:
	var actions := _get_action_values(tool)
	if not actions.is_empty():
		return _infer_action_behavior_hints(actions)
	return _infer_name_behavior_hints(tool_name)


static func _infer_action_behavior_hints(actions: Array) -> Dictionary:
	var has_read_only := false
	var has_mutation := false
	var has_destructive := false
	var all_known_mutations_are_idempotent := true

	for action_value in actions:
		var action := str(action_value)
		if READ_ONLY_ACTIONS.has(action):
			has_read_only = true
			continue
		has_mutation = true
		if DESTRUCTIVE_ACTIONS.has(action):
			has_destructive = true
			all_known_mutations_are_idempotent = false
		elif not IDEMPOTENT_MUTATION_ACTIONS.has(action):
			all_known_mutations_are_idempotent = false

	if has_mutation:
		return {
			"readOnlyHint": false,
			"destructiveHint": has_destructive,
			"idempotentHint": all_known_mutations_are_idempotent
		}
	if has_read_only:
		return {
			"readOnlyHint": true,
			"destructiveHint": false,
			"idempotentHint": true
		}
	return {}


static func _infer_name_behavior_hints(tool_name: String) -> Dictionary:
	var lowered := tool_name.to_lower()
	for marker in DESTRUCTIVE_NAME_MARKERS:
		if lowered.contains(str(marker)):
			return {
				"readOnlyHint": false,
				"destructiveHint": true,
				"idempotentHint": false
			}
	for marker in READ_ONLY_NAME_MARKERS:
		if lowered.contains(str(marker)):
			return {
				"readOnlyHint": true,
				"destructiveHint": false,
				"idempotentHint": true
			}
	return {}


static func _infer_open_world_hint(tool_name: String) -> bool:
	var lowered := tool_name.to_lower()
	return lowered.contains("http") or lowered.contains("git") or lowered.contains("update") or lowered.contains("sync")


static func _get_action_values(tool: Dictionary) -> Array:
	var schema = tool.get("inputSchema", {})
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


static func _humanize_tool_name(tool_name: String) -> String:
	var parts := tool_name.replace("-", "_").replace(".", "_").split("_", false)
	var title_parts: Array[String] = []
	for part in parts:
		var value := str(part)
		if value.is_empty():
			continue
		title_parts.append(value.substr(0, 1).to_upper() + value.substr(1))
	return " ".join(title_parts)
