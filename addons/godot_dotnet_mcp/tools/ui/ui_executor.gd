@tool
extends RefCounted

const UICatalog = preload("res://addons/godot_dotnet_mcp/tools/ui/catalog.gd")
const ThemeService = preload("res://addons/godot_dotnet_mcp/tools/ui/theme_service.gd")
const LayoutService = preload("res://addons/godot_dotnet_mcp/tools/ui/layout_service.gd")
const FocusService = preload("res://addons/godot_dotnet_mcp/tools/ui/focus_service.gd")
const ControlService = preload("res://addons/godot_dotnet_mcp/tools/ui/control_service.gd")

var _catalog := UICatalog.new()
var _theme_service := ThemeService.new()
var _layout_service := LayoutService.new()
var _focus_service := FocusService.new()
var _control_service := ControlService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_theme_service, _layout_service, _focus_service, _control_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"theme":
			return _theme_service.execute(tool_name, args)
		"control":
			return _execute_control(args)
		_:
			return _theme_service._error("Unknown tool: %s" % tool_name)


func _execute_control(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if path.is_empty():
		return _control_service._error("Path is required")

	var node = _control_service._find_active_node(path)
	if not node:
		return _control_service._error("Node not found: %s" % path)
	if not (node is Control):
		return _control_service._error("Node is not a Control: %s" % path)

	var action := str(args.get("action", ""))
	match action:
		"get_layout", "arrange":
			return _control_service.handle_control(node, args)
		"set_anchor", "set_anchor_preset", "set_margins", "set_size_flags", "set_min_size":
			return _layout_service.handle_control(node, args)
		"set_focus_mode", "set_mouse_filter":
			return _focus_service.handle_control(node, args)
		_:
			return _control_service._error("Unknown action: %s" % action)
