@tool
extends RefCounted
class_name MCPToolsApiService

const ToolCatalogSnapshotService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_snapshot_service.gd")

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
		return ToolCatalogSnapshotService.build_presentation_payload({
			"success": false,
			"tool_loader_status": _get_loader_status_safe()
		})

	var snapshot := ToolCatalogSnapshotService.build_snapshot(loader)
	snapshot["tool_loader_status"] = _get_loader_status_safe(snapshot.get("tool_loader_status", {}))
	return ToolCatalogSnapshotService.build_presentation_payload(snapshot)


func _get_loader():
	if _get_tool_loader.is_valid():
		return _get_tool_loader.call()
	return null


func _get_loader_status_safe(fallback: Dictionary = {}) -> Dictionary:
	if _get_tool_loader_status.is_valid():
		var status = _get_tool_loader_status.call()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return fallback.duplicate(true)
