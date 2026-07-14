@tool
extends RefCounted

## Projects MCP Resources, Resource Templates, and Prompts into Dock model data.
## The protocol services remain the source of truth; this layer only adds UI grouping hints.

const MCPResourcesServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service.gd")
const MCPPromptsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service.gd")
const ResourceTreePresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/resource_tree_presentation_service.gd")
const PromptTreePresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/presenters/prompt_tree_presentation_service.gd")

var _resources_service = MCPResourcesServiceScript.new()
var _prompts_service = MCPPromptsServiceScript.new()
var _resource_tree_presentation_service = ResourceTreePresentationServiceScript.new()
var _prompt_tree_presentation_service = PromptTreePresentationServiceScript.new()
var _sanitize_for_json := Callable()


func configure(context = null) -> void:
	_sanitize_for_json = _context_callable(context, "sanitize_for_json")
	var list_context := _build_loaderless_list_context()
	_resources_service.configure(list_context)
	_prompts_service.configure(list_context)


func dispose() -> void:
	_resources_service.dispose()
	_prompts_service.dispose()
	_resource_tree_presentation_service = ResourceTreePresentationServiceScript.new()
	_prompt_tree_presentation_service = PromptTreePresentationServiceScript.new()
	_sanitize_for_json = Callable()


func build_projection() -> Dictionary:
	var resources := _project_resources(_resources_service.build_resources_list_result().get("resources", []), false)
	var resource_templates := _project_resources(_resources_service.build_resource_templates_list_result().get("resourceTemplates", []), true)
	var prompts := _project_prompts(_prompts_service.build_prompts_list_result().get("prompts", []))
	var resource_presentation := _resource_tree_presentation_service.build_resource_catalog_tree(resources, resource_templates)
	var prompt_presentation := _prompt_tree_presentation_service.build_prompt_catalog_tree(prompts)
	return {
		"mcp_resources": resources,
		"mcp_resource_templates": resource_templates,
		"mcp_prompts": prompts,
		"mcp_resource_presentation": resource_presentation,
		"mcp_prompt_presentation": prompt_presentation,
		"mcp_catalog_counts": {
			"resources": resources.size(),
			"resource_templates": resource_templates.size(),
			"prompts": prompts.size()
		}
	}


func _project_resources(entries, is_template: bool) -> Array[Dictionary]:
	var projected: Array[Dictionary] = []
	if not (entries is Array):
		return projected
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var source := (entry as Dictionary).duplicate(true)
		var uri := str(source.get("uriTemplate", source.get("uri", "")))
		var projected_entry := {
			"uri": uri,
			"uriTemplate": str(source.get("uriTemplate", "")),
			"title": str(source.get("title", source.get("name", uri))),
			"name": str(source.get("name", "")),
			"description": str(source.get("description", "")),
			"mimeType": str(source.get("mimeType", "")),
			"icons": _duplicate_array(source.get("icons", [])),
			"resource_kind": _resource_kind_for_entry(source, is_template),
			"resource_group": _resource_group_for_entry(source, is_template),
			"is_template": is_template
		}
		projected.append(projected_entry)
	return projected


func _project_prompts(entries) -> Array[Dictionary]:
	var projected: Array[Dictionary] = []
	if not (entries is Array):
		return projected
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var source := (entry as Dictionary).duplicate(true)
		var name := str(source.get("name", ""))
		projected.append({
			"name": name,
			"title": str(source.get("title", name)),
			"description": str(source.get("description", "")),
			"arguments": _duplicate_array(source.get("arguments", [])),
			"icons": _duplicate_array(source.get("icons", [])),
			"prompt_kind": _prompt_kind_for_entry(source)
		})
	return projected


func _resource_kind_for_entry(entry: Dictionary, is_template: bool) -> String:
	var meta = entry.get("_meta", {})
	var protocol_kind := ""
	if meta is Dictionary:
		protocol_kind = str((meta as Dictionary).get("resourceKind", "")).strip_edges()
	if protocol_kind.is_empty():
		protocol_kind = str(entry.get("resource_kind", "")).strip_edges()
	if not protocol_kind.is_empty():
		return protocol_kind
	if is_template:
		return "template"
	return "resource"


func _resource_group_for_entry(entry: Dictionary, is_template: bool) -> String:
	var meta = entry.get("_meta", {})
	var protocol_group := ""
	if meta is Dictionary:
		protocol_group = str((meta as Dictionary).get("resourceGroup", "")).strip_edges()
	if not protocol_group.is_empty():
		return protocol_group
	if is_template:
		return "resource_templates"
	return ""


func _prompt_kind_for_entry(entry: Dictionary) -> String:
	var meta = entry.get("_meta", {})
	var protocol_kind := ""
	if meta is Dictionary:
		protocol_kind = str((meta as Dictionary).get("promptKind", "")).strip_edges()
	if protocol_kind.is_empty():
		protocol_kind = str(entry.get("prompt_kind", "")).strip_edges()
	return protocol_kind if not protocol_kind.is_empty() else "prompt"


func _duplicate_array(values) -> Array:
	if values is Array:
		return (values as Array).duplicate(true)
	return []


func _build_loaderless_list_context() -> Dictionary:
	return {
		"get_tool_loader": Callable(self, "_null_tool_loader"),
		"get_tool_loader_status": Callable(self, "_empty_tool_loader_status"),
		"get_tool_activity_registry": Callable(self, "_null_tool_activity_registry"),
		"sanitize_for_json": Callable(self, "_sanitize_projection_value")
	}


func _null_tool_loader():
	return null


func _empty_tool_loader_status() -> Dictionary:
	return {}


func _null_tool_activity_registry():
	return null


func _sanitize_projection_value(value):
	if _sanitize_for_json.is_valid():
		return _sanitize_for_json.call(value)
	return value


func _context_callable(context, key: String) -> Callable:
	if context == null:
		return Callable()
	if context is Dictionary:
		var value = (context as Dictionary).get(key, Callable())
		return value if value is Callable else Callable()
	if context.has_method("get"):
		var value = context.get(key)
		return value if value is Callable else Callable()
	return Callable()
