@tool
extends RefCounted

const NodeCatalog = preload("res://addons/godot_dotnet_mcp/tools/node/catalog.gd")
const QueryService = preload("res://addons/godot_dotnet_mcp/tools/node/query_service.gd")
const LifecycleService = preload("res://addons/godot_dotnet_mcp/tools/node/lifecycle_service.gd")
const TransformService = preload("res://addons/godot_dotnet_mcp/tools/node/transform_service.gd")
const PropertyService = preload("res://addons/godot_dotnet_mcp/tools/node/property_service.gd")
const HierarchyService = preload("res://addons/godot_dotnet_mcp/tools/node/hierarchy_service.gd")
const ProcessService = preload("res://addons/godot_dotnet_mcp/tools/node/process_service.gd")
const MetadataService = preload("res://addons/godot_dotnet_mcp/tools/node/metadata_service.gd")
const CallService = preload("res://addons/godot_dotnet_mcp/tools/node/call_service.gd")
const VisibilityService = preload("res://addons/godot_dotnet_mcp/tools/node/visibility_service.gd")

var _catalog := NodeCatalog.new()
var _query_service := QueryService.new()
var _lifecycle_service := LifecycleService.new()
var _transform_service := TransformService.new()
var _property_service := PropertyService.new()
var _hierarchy_service := HierarchyService.new()
var _process_service := ProcessService.new()
var _metadata_service := MetadataService.new()
var _call_service := CallService.new()
var _visibility_service := VisibilityService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [
		_query_service,
		_lifecycle_service,
		_transform_service,
		_property_service,
		_hierarchy_service,
		_process_service,
		_metadata_service,
		_call_service,
		_visibility_service,
	]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"query":
			return _query_service.execute(tool_name, args)
		"lifecycle":
			return _lifecycle_service.execute(tool_name, args)
		"transform":
			return _transform_service.execute(tool_name, args)
		"property":
			return _property_service.execute(tool_name, args)
		"hierarchy":
			return _hierarchy_service.execute(tool_name, args)
		"process":
			return _process_service.execute(tool_name, args)
		"metadata":
			return _metadata_service.execute(tool_name, args)
		"call":
			return _call_service.execute(tool_name, args)
		"visibility":
			return _visibility_service.execute(tool_name, args)
		_:
			return _query_service._error("Unknown tool: %s" % tool_name)
