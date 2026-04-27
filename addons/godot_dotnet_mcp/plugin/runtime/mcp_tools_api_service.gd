@tool
extends RefCounted
class_name MCPToolsApiService

const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")

var _get_tool_loader := Callable()
var _get_tool_loader_status := Callable()


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_get_tool_loader = context.get_tool_loader
	_get_tool_loader_status = context.get_tool_loader_status


func dispose() -> void:
	_get_tool_loader = Callable()
	_get_tool_loader_status = Callable()


func build_tools_list_response() -> Dictionary:
	var loader = _get_loader()
	if loader == null:
		return {
			"tools": [],
			"domain_states": [],
			"tool_count": 0,
			"exposed_tool_count": 0,
			"tool_loader_status": _get_loader_status_safe(),
			"performance": {}
		}

	var exposed_tools = loader.get_exposed_tool_definitions()
	var domain_states = loader.get_domain_states()
	var all_tools_by_category := {}
	if loader.has_method("get_all_tools_by_category"):
		all_tools_by_category = loader.get_all_tools_by_category()
	elif loader.has_method("get_tools_by_category"):
		all_tools_by_category = loader.get_tools_by_category()
	var presentation = ToolPresentationService.build_tool_presentation(
		exposed_tools,
		all_tools_by_category,
		domain_states
	)
	return {
		"tools": ToolPresentationService.enrich_tools_for_presentation(exposed_tools, presentation),
		"domain_states": domain_states,
		"tool_count": loader.get_tool_definitions().size(),
		"exposed_tool_count": exposed_tools.size(),
		"tool_loader_status": _get_loader_status_safe(),
		"performance": loader.get_performance_summary(),
		"presentationVersion": int(presentation.get("presentationVersion", 1)),
		"toolTree": presentation.get("toolTree", []),
		"toolGroups": presentation.get("toolGroups", [])
	}


func _get_loader():
	if _get_tool_loader.is_valid():
		return _get_tool_loader.call()
	return null


func _get_loader_status_safe() -> Dictionary:
	if _get_tool_loader_status.is_valid():
		var status = _get_tool_loader_status.call()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {}
