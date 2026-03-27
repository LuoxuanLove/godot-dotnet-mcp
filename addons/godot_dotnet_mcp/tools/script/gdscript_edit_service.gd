@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

const GDScriptSemanticProvider = preload("res://addons/godot_dotnet_mcp/tools/script/gdscript_semantic_provider.gd")
const GDScriptEditActionService = preload("res://addons/godot_dotnet_mcp/tools/script/gdscript_edit_action_service.gd")

var _semantic_provider := GDScriptSemanticProvider.new()
var _action_service := GDScriptEditActionService.new()


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var path = _normalize_res_path(args.get("path", ""))
	if path.is_empty():
		return _error("Path is required")
	if not path.ends_with(".gd"):
		return _error("script_edit_gd only supports .gd files")

	match action:
		"create":
			return _action_service.create_script(path, args.get("extends", "Node"), args.get("class_name", ""))
		"write":
			return _action_service.write_script(path, args.get("content", ""))
		"delete":
			return _action_service.delete_script(path)
		"add_function":
			return _action_service.add_function(path, args)
		"remove_function":
			return _action_service.remove_function(path, args.get("name", ""))
		"add_variable":
			return _action_service.add_variable(path, args)
		"add_signal":
			return _action_service.add_signal(path, args.get("name", ""), args.get("params", []))
		"add_export":
			return _action_service.add_export(path, args)
		"get_functions":
			return _semantic_provider.get_functions(path)
		"get_variables":
			return _semantic_provider.get_variables(path)
		"replace_function_body":
			return _action_service.replace_function_body(path, str(args.get("name", "")), str(args.get("body", "")))
		"remove_member":
			return _action_service.remove_member(path, str(args.get("name", "")), str(args.get("member_type", "auto")))
		"rename_member":
			return _action_service.rename_member(path, str(args.get("name", "")), str(args.get("new_name", "")))
		_:
			return _error("Unknown action: %s" % action)
