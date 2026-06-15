@tool
extends RefCounted
class_name MCPToolsApiService

const ToolPresentationService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")
const ToolCatalogSnapshotService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_snapshot_service.gd")

var _get_tool_loader := Callable()
var _get_tool_loader_status := Callable()
var _ensure_initialized := Callable()


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_get_tool_loader = context.get_tool_loader
	_get_tool_loader_status = context.get_tool_loader_status
	_ensure_initialized = context.ensure_initialized


func dispose() -> void:
	_get_tool_loader = Callable()
	_get_tool_loader_status = Callable()
	_ensure_initialized = Callable()


func build_tools_list_response() -> Dictionary:
	_ensure_tool_runtime_initialized()
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

	var snapshot: Dictionary = ToolCatalogSnapshotService.build_snapshot(loader)
	if not bool(snapshot.get("success", false)):
		return {
			"tools": [],
			"domain_states": [],
			"tool_count": 0,
			"exposed_tool_count": 0,
			"tool_loader_status": _get_loader_status_safe(),
			"performance": {}
		}
	var exposed_tools: Array = snapshot.get("exposed_tools", [])
	var visible_tools: Array = snapshot.get("visible_tools", exposed_tools)
	var category_states: Array = snapshot.get("category_states", [])
	var presentation: Dictionary = snapshot.get("presentation", {})
	var loader_status: Dictionary = snapshot.get("tool_loader_status", {})
	if loader_status.is_empty():
		loader_status = _get_loader_status_safe()
	return {
		"tools": ToolPresentationService.enrich_tools_for_presentation(exposed_tools, presentation),
		"domain_states": category_states,
		"tool_count": visible_tools.size(),
		"exposed_tool_count": exposed_tools.size(),
		"tool_loader_status": loader_status,
		"performance": loader.get_performance_summary() if loader.has_method("get_performance_summary") else {},
		"presentationVersion": int(presentation.get("presentationVersion", 1)),
		"toolTree": presentation.get("toolTree", []),
		"toolGroups": presentation.get("toolGroups", []),
		"catalogManifest": ToolCatalogSnapshotService.build_public_catalog_manifest(snapshot.get("catalog_manifest", {}))
	}


func _get_loader():
	if _get_tool_loader.is_valid():
		return _get_tool_loader.call()
	return null


func _ensure_tool_runtime_initialized() -> void:
	if _ensure_initialized.is_valid():
		_ensure_initialized.call()


func _get_loader_status_safe() -> Dictionary:
	if _get_tool_loader_status.is_valid():
		var status = _get_tool_loader_status.call()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {}
