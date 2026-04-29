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


func clear() -> void:
	if _read_service != null and _read_service.has_method("clear"):
		_read_service.clear()
	if _inspect_service != null and _inspect_service.has_method("clear"):
		_inspect_service.clear()
	if _reference_service != null and _reference_service.has_method("clear"):
		_reference_service.clear()
	if _gdscript_edit_service != null and _gdscript_edit_service.has_method("clear"):
		_gdscript_edit_service.clear()
	if _csharp_edit_service != null and _csharp_edit_service.has_method("clear"):
		_csharp_edit_service.clear()
	_catalog = null
	_read_service = null
	_inspect_service = null
	_reference_service = null
	_gdscript_edit_service = null
	_csharp_edit_service = null
