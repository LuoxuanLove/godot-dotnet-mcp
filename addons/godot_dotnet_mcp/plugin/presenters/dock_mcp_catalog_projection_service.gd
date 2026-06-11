@tool
extends RefCounted

## Projects MCP Resources, Resource Templates, and Prompts into Dock model data.
## The protocol services remain the source of truth; this layer only adds UI grouping hints.

const MCPResourcesServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_resources_service.gd")
const MCPPromptsServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_prompts_service.gd")

var _resources_service = MCPResourcesServiceScript.new()
var _prompts_service = MCPPromptsServiceScript.new()


func configure(context = null) -> void:
	if context == null or not _has_runtime_context_methods(context):
		dispose()
		return
	_resources_service.configure(context)
	_prompts_service.configure(context)


func dispose() -> void:
	_resources_service.dispose()
	_prompts_service.dispose()


func build_projection() -> Dictionary:
	var resources := _project_resources(_resources_service.build_resources_list_result().get("resources", []), false)
	var resource_templates := _project_resources(_resources_service.build_resource_templates_list_result().get("resourceTemplates", []), true)
	var prompts := _project_prompts(_prompts_service.build_prompts_list_result().get("prompts", []))
	return {
		"mcp_resources": resources,
		"mcp_resource_templates": resource_templates,
		"mcp_prompts": prompts,
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
			"resource_kind": _resource_kind_for_uri(uri, is_template),
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
			"prompt_kind": _prompt_kind_for_name(name)
		})
	return projected


func _resource_kind_for_uri(uri: String, is_template: bool) -> String:
	if is_template:
		return "template"
	if uri.begins_with("godot-dotnet-mcp://guides/"):
		return "guide"
	if uri.begins_with("godot-dotnet-mcp://state/") or uri == "godot-dotnet-mcp://project/info":
		return "state"
	if uri.begins_with("godot-dotnet-mcp://activity/"):
		return "activity"
	if uri.begins_with("godot-dotnet-mcp://tools/catalog") or uri == "godot-dotnet-mcp://tools/catalog":
		return "catalog"
	if uri.begins_with("godot-dotnet-mcp://logs/"):
		return "log"
	if uri.begins_with("godot-dotnet-mcp://diagnostics/"):
		return "diagnostic"
	return "resource"


func _prompt_kind_for_name(name: String) -> String:
	if name.find("debug") != -1:
		return "debug"
	if name.find("runtime") != -1:
		return "runtime"
	if name.find("ui") != -1:
		return "editor_ui"
	if name.find("authoring") != -1:
		return "authoring"
	if name.find("reference") != -1:
		return "integrity"
	return "orientation"


func _duplicate_array(values) -> Array:
	if values is Array:
		return (values as Array).duplicate(true)
	return []


func _has_runtime_context_methods(context) -> bool:
	return context != null \
		and context.get("get_tool_loader") is Callable \
		and context.get("get_tool_loader_status") is Callable \
		and context.get("get_tool_activity_registry") is Callable \
		and context.get("sanitize_for_json") is Callable
