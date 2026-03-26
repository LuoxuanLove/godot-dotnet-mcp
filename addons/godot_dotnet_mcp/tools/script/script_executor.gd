@tool
extends RefCounted

const ScriptCatalog = preload("res://addons/godot_dotnet_mcp/tools/script/catalog.gd")
const ScriptReadService = preload("res://addons/godot_dotnet_mcp/tools/script/read_service.gd")
const ScriptInspectService = preload("res://addons/godot_dotnet_mcp/tools/script/inspect_service.gd")
const ScriptReferenceService = preload("res://addons/godot_dotnet_mcp/tools/script/reference_service.gd")
const GDScriptEditService = preload("res://addons/godot_dotnet_mcp/tools/script/gdscript_edit_service.gd")
const CSharpEditService = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_service.gd")

var _catalog := ScriptCatalog.new()
var _read_service := ScriptReadService.new()
var _inspect_service := ScriptInspectService.new()
var _reference_service := ScriptReferenceService.new()
var _gdscript_edit_service := GDScriptEditService.new()
var _csharp_edit_service := CSharpEditService.new()


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"read", "open":
			return _read_service.execute(tool_name, args)
		"inspect", "symbols", "exports":
			return _inspect_service.execute(tool_name, args)
		"references":
			return _reference_service.execute(tool_name, args)
		"edit_gd":
			return _gdscript_edit_service.execute(tool_name, args)
		"edit_cs":
			return _csharp_edit_service.execute(tool_name, args)
		_:
			return _gdscript_edit_service._error("Unknown tool: %s" % tool_name)
