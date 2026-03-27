@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

var _scene_root_override: Node = null


func configure_context(context: Dictionary = {}) -> void:
	_scene_root_override = context.get("scene_root", null)


func _get_active_root() -> Node:
	if _scene_root_override != null and is_instance_valid(_scene_root_override):
		return _scene_root_override
	return _get_edited_scene_root()


func _find_active_node(path: String) -> Node:
	var root := _get_active_root()
	if root == null:
		return null
	if _scene_root_override == null:
		return _find_node_by_path(path)
	var normalized := _normalize_active_path(path, root)
	if normalized.is_empty() or normalized == ".":
		return root
	if normalized.begins_with("/"):
		var absolute_node = root.get_node_or_null(NodePath(normalized))
		if absolute_node != null:
			return absolute_node
	return root.get_node_or_null(NodePath(normalized))


func _normalize_active_path(path: String, root: Node = null) -> String:
	if root == null:
		root = _get_active_root()
	if root == null:
		return path.strip_edges()

	var normalized = path.strip_edges()
	if normalized.is_empty() or normalized == "/" or normalized == ".":
		return "."

	var root_name = str(root.name)
	var root_path = str(root.get_path())
	var absolute_tree_prefix = "/root/"

	if normalized == "/root":
		return "."
	if normalized.begins_with(absolute_tree_prefix):
		normalized = normalized.substr(absolute_tree_prefix.length())
		if normalized == root_name:
			return "."
		if normalized.begins_with(root_name + "/"):
			return normalized.substr(root_name.length() + 1)
		if normalized.is_empty():
			return "."

	if normalized == root_name or normalized == "/" + root_name:
		return "."
	if normalized == root_path:
		return "."
	if normalized.begins_with(root_path + "/"):
		return normalized.substr(root_path.length() + 1)
	if normalized.begins_with(root_name + "/"):
		return normalized.substr(root_name.length() + 1)
	if normalized.begins_with("/" + root_name + "/"):
		return normalized.substr(root_name.length() + 2)
	if normalized.begins_with("./"):
		return normalized.substr(2)
	if normalized.begins_with("/"):
		return normalized.trim_prefix("/")
	return normalized


func _get_tilemap(path: String) -> TileMap:
	if path.is_empty():
		return null
	var node = _find_active_node(path)
	if node != null and node is TileMap:
		return node
	return null


func _get_tileset_from_args(args: Dictionary) -> TileSet:
	var tilemap_path := str(args.get("path", ""))
	if not tilemap_path.is_empty():
		var tilemap := _get_tilemap(tilemap_path)
		if tilemap != null and tilemap.tile_set != null:
			return tilemap.tile_set

	var tileset_path := _normalize_res_path(str(args.get("tileset_path", "")))
	if tileset_path.is_empty():
		return null
	if ResourceLoader.exists(tileset_path) or FileAccess.file_exists(tileset_path):
		return ResourceLoader.load(tileset_path, "", ResourceLoader.CACHE_MODE_REPLACE) as TileSet
	return null


func _ensure_res_directory(path: String) -> void:
	if path.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		DirAccess.make_dir_recursive_absolute(absolute_path)
