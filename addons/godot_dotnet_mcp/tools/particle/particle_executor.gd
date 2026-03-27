@tool
extends RefCounted

const ParticleCatalog = preload("res://addons/godot_dotnet_mcp/tools/particle/catalog.gd")
const EmitterService = preload("res://addons/godot_dotnet_mcp/tools/particle/emitter_service.gd")
const ProcessMaterialService = preload("res://addons/godot_dotnet_mcp/tools/particle/process_material_service.gd")

var _catalog := ParticleCatalog.new()
var _emitter_service := EmitterService.new()
var _process_material_service := ProcessMaterialService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_emitter_service, _process_material_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"particles":
			return _emitter_service.execute(tool_name, args)
		"particle_material":
			return _process_material_service.execute(tool_name, args)
		_:
			return _emitter_service._error("Unknown tool: %s" % tool_name)
