@tool
extends RefCounted
class_name MCPToolsApiService

var _get_tool_loader := Callable()
var _get_tool_loader_status := Callable()


func configure(callbacks: Dictionary = {}) -> void:
	_get_tool_loader = callbacks.get("get_tool_loader", Callable())
	_get_tool_loader_status = callbacks.get("get_tool_loader_status", Callable())


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
	return {
		"tools": exposed_tools,
		"domain_states": loader.get_domain_states(),
		"tool_count": loader.get_tool_definitions().size(),
		"exposed_tool_count": exposed_tools.size(),
		"tool_loader_status": _get_loader_status_safe(),
		"performance": loader.get_performance_summary()
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
