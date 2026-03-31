@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var path = _normalize_res_path(str(args.get("path", "")))
	if path.is_empty():
		return _error("Path is required")
	if not path.ends_with(".cs"):
		return _error("script_edit_cs only supports .cs files")

	match action:
		"create":
			return _mutation_disabled_error(action)
		"write":
			return _mutation_disabled_error(action)
		"add_field":
			return _mutation_disabled_error(action)
		"add_method":
			return _mutation_disabled_error(action)
		"replace_method_body":
			return _mutation_disabled_error(action)
		"delete_member":
			return _mutation_disabled_error(action)
		"rename_member":
			return _mutation_disabled_error(action)
		_:
			return _error("Unknown action: %s. edit_cs is read-only in plugin; use host cs_file_patch for C# mutations." % action)


func _mutation_disabled_error(action: String) -> Dictionary:
	return _error("edit_cs action '%s' is disabled in plugin. Use host cs_file_patch for C# mutations." % action)
