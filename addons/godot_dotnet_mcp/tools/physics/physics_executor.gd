@tool
extends RefCounted

const PhysicsCatalog = preload("res://addons/godot_dotnet_mcp/tools/physics/catalog.gd")
const BodyService = preload("res://addons/godot_dotnet_mcp/tools/physics/body_service.gd")
const ShapeService = preload("res://addons/godot_dotnet_mcp/tools/physics/shape_service.gd")
const JointService = preload("res://addons/godot_dotnet_mcp/tools/physics/joint_service.gd")
const QueryService = preload("res://addons/godot_dotnet_mcp/tools/physics/query_service.gd")

var _catalog := PhysicsCatalog.new()
var _body_service := BodyService.new()
var _shape_service := ShapeService.new()
var _joint_service := JointService.new()
var _query_service := QueryService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_body_service, _shape_service, _joint_service, _query_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"physics_body":
			return _body_service.execute(tool_name, args)
		"collision_shape":
			return _shape_service.execute(tool_name, args)
		"physics_joint":
			return _joint_service.execute(tool_name, args)
		"physics_query":
			return _query_service.execute(tool_name, args)
		_:
			return _body_service._error("Unknown tool: %s" % tool_name)
