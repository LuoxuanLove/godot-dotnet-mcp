@tool
extends "res://addons/godot_dotnet_mcp/tools/scene/service_base.gd"

const BindingsService = preload("res://addons/godot_dotnet_mcp/tools/scene/bindings_service.gd")

var _bindings_service := BindingsService.new()


func configure_context(context: Dictionary = {}) -> void:
	super.configure_context(context)
	_bindings_service.configure_context(context)


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var analysis = {}

	match action:
		"current":
			analysis = _bindings_service.analyze_scene_bindings("")
		"from_path":
			analysis = _bindings_service.analyze_scene_bindings(str(args.get("path", "")))
		_:
			return _error("Unknown action: %s" % action)

	if not bool(analysis.get("success", false)):
		return analysis

	var data: Dictionary = analysis.get("data", {})
	return _success({
		"scene_path": data.get("scene_path", ""),
		"issue_count": data.get("issues", []).size(),
		"issues": data.get("issues", [])
	})
