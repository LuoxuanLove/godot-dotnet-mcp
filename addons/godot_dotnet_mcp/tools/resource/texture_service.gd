@tool
extends "res://addons/godot_dotnet_mcp/tools/resource/service_base.gd"

const QueryService = preload("res://addons/godot_dotnet_mcp/tools/resource/query_service.gd")

var _query_service := QueryService.new()


func configure_context(context: Dictionary = {}) -> void:
	super.configure_context(context)
	_query_service.configure_context(context)


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"get_info":
			return _get_texture_info(_normalize_resource_path(str(args.get("path", ""))))
		"list_all":
			return _query_service.execute("query", {
				"action": "list",
				"path": "res://",
				"type": "Texture2D",
				"recursive": true
			})
		"assign_to_node":
			return _assign_texture_to_node(
				_normalize_resource_path(str(args.get("texture_path", ""))),
				str(args.get("node_path", "")),
				str(args.get("property", "texture"))
			)
		_:
			return _error("Unknown action: %s" % action)


func _get_texture_info(path: String) -> Dictionary:
	if path.is_empty():
		return _error("Path is required")

	var texture: Texture2D = null
	var image: Image = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	if texture == null:
		image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.is_empty():
			return _error("Texture not found: %s" % path)
		texture = ImageTexture.create_from_image(image)
	if texture == null:
		return _error("Not a valid texture: %s" % path)

	var format_info = "compressed"
	var has_alpha = false
	if image == null:
		image = texture.get_image() if texture.has_method("get_image") else null
	if image != null:
		format_info = image.get_format()
		has_alpha = format_info in [Image.FORMAT_RGBA8, Image.FORMAT_RGBA4444]

	return _success({
		"path": path,
		"width": texture.get_width(),
		"height": texture.get_height(),
		"format": format_info,
		"has_alpha": has_alpha
	})


func _assign_texture_to_node(texture_path: String, node_path: String, property: String) -> Dictionary:
	if texture_path.is_empty():
		return _error("Texture path is required")
	if node_path.is_empty():
		return _error("Node path is required")

	var texture: Texture2D = null
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path) as Texture2D
	if texture == null:
		var image = Image.load_from_file(ProjectSettings.globalize_path(texture_path))
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	if texture == null:
		return _error("Failed to load texture: %s" % texture_path)

	var node := _find_active_node(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)
	if not property in node:
		return _error("Property '%s' not found on node" % property)

	node.set(property, texture)
	return _success({
		"node": node_path,
		"property": property,
		"texture": texture_path
	}, "Texture assigned")
