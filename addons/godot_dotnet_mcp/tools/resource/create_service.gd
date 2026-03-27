@tool
extends "res://addons/godot_dotnet_mcp/tools/resource/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	return _create_resource(str(args.get("type", "")), _normalize_resource_path(str(args.get("path", ""))))


func _create_resource(type_name: String, path: String) -> Dictionary:
	if type_name.is_empty():
		return _error("Type is required")
	if path.is_empty():
		return _error("Path is required")

	var resource: Resource = null
	match type_name:
		"GDScript":
			resource = GDScript.new()
			resource.source_code = "extends Node\n\n\nfunc _ready() -> void:\n\tpass\n"
		"Resource":
			resource = Resource.new()
		"Environment":
			resource = Environment.new()
		"StandardMaterial3D":
			resource = StandardMaterial3D.new()
		"ShaderMaterial":
			resource = ShaderMaterial.new()
		"StyleBoxFlat":
			resource = StyleBoxFlat.new()
		"Gradient":
			resource = Gradient.new()
		"Curve":
			resource = Curve.new()
		_:
			if ClassDB.class_exists(type_name) and ClassDB.is_parent_class(type_name, "Resource"):
				resource = ClassDB.instantiate(type_name)
			else:
				return _error("Unknown resource type: %s" % type_name)

	if resource == null:
		return _error("Failed to create resource of type: %s" % type_name)

	_ensure_parent_directory(path)
	var error := ResourceSaver.save(resource, path)
	if error != OK:
		return _error("Failed to save resource: %s" % error_string(error))

	_refresh_filesystem()
	return _success({
		"path": path,
		"type": type_name
	}, "Resource created: %s" % path)
