@tool
extends RefCounted

const ProjectCatalog = preload("res://addons/godot_dotnet_mcp/tools/system/project/catalog.gd")
const StateService = preload("res://addons/godot_dotnet_mcp/tools/system/project/state_service.gd")
const AdviseService = preload("res://addons/godot_dotnet_mcp/tools/system/project/advise_service.gd")
const ConfigureService = preload("res://addons/godot_dotnet_mcp/tools/system/project/configure_service.gd")
const RuntimeService = preload("res://addons/godot_dotnet_mcp/tools/system/project/runtime_service.gd")

var bridge
var _catalog := ProjectCatalog.new()
var _state_service := StateService.new()
var _advise_service := AdviseService.new()
var _configure_service := ConfigureService.new()
var _runtime_service := RuntimeService.new()


func configure_runtime(context: Dictionary) -> void:
	for service in [_state_service, _advise_service, _configure_service, _runtime_service]:
		service.bridge = bridge


func handles(tool_name: String) -> bool:
	return tool_name in [
		"project_state",
		"project_advise",
		"project_configure",
		"project_run",
		"project_stop",
		"runtime_diagnose"
	]


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"project_state":
			return _state_service.execute(tool_name, args)
		"project_advise":
			return _advise_service.execute(tool_name, args)
		"project_configure":
			return _configure_service.execute(tool_name, args)
		"project_run", "project_stop", "runtime_diagnose":
			return _runtime_service.execute(tool_name, args)
		_:
			return bridge.error("Unknown tool: %s" % tool_name)
