@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const CSharpEditHelper = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_helper.gd")
const CSharpEditActionService = preload("res://addons/godot_dotnet_mcp/tools/script/csharp_edit_action_service.gd")

var _edit_helper := CSharpEditHelper.new()
var _action_service := CSharpEditActionService.new()


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var path = _normalize_res_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Path is required")
	if not path.ends_with(".cs"):
		return _error("script_edit_cs only supports .cs files")

	match action:
		"create":
			return _action_service.create_script(path, args)
		"write":
			return _action_service.write_script(path, str(args.get("content", "")))
		"add_field":
			return _action_service.add_field(path, args)
		"add_method":
			return _action_service.add_method(path, args)
		"replace_method_body":
			return _action_service.replace_method_body(path, str(args.get("name", "")), str(args.get("body", "")))
		"delete_member":
			return _action_service.remove_member(path, str(args.get("name", "")), str(args.get("member_type", "auto")))
		"rename_member":
			return _action_service.rename_member(path, str(args.get("name", "")), str(args.get("new_name", "")))
		_:
			return _error("Unknown action: %s" % action)
