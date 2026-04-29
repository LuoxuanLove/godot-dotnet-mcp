extends RefCounted

const TilemapExecutorScript = preload("res://addons/godot_dotnet_mcp/tools/tilemap/executor.gd")

const TEMP_ROOT := "res://Tmp/godot_dotnet_mcp_tilemap_contracts"
const EMPTY_TILESET_PATH := "res://Tmp/godot_dotnet_mcp_tilemap_contracts/tilesets/empty_tileset.tres"
const ATLAS_TILESET_PATH := "res://Tmp/godot_dotnet_mcp_tilemap_contracts/tilesets/atlas_tileset.tres"

var _scene_root: Node2D = null


func run_case(tree: SceneTree) -> Dictionary:
	var executor = TilemapExecutorScript.new()
	_scene_root = _build_scene_fixture(tree)
	executor.configure_context({"scene_root": _scene_root})

	if ResourceLoader.exists("res://addons/godot_dotnet_mcp/tools/tilemap_tools.gd"):
		return _failure("tilemap_tools.gd should be removed once the split executor becomes the only stable entry.")

	_remove_tree(TEMP_ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))

	var tool_defs: Array[Dictionary] = executor.get_tools()
	if tool_defs.size() != 2:
		return _failure("Tilemap executor should expose 2 tool definitions after the split.")

	var expected_names := ["tileset", "tilemap"]
	var actual_names: Array[String] = []
	for tool_def in tool_defs:
		actual_names.append(str(tool_def.get("name", "")))
	for expected_name in expected_names:
		if not actual_names.has(expected_name):
			return _failure("Tilemap executor is missing tool definition '%s'." % expected_name)

	var create_empty_result: Dictionary = executor.execute("tileset", {
		"action": "create_empty",
		"save_path": EMPTY_TILESET_PATH
	})
	if not bool(create_empty_result.get("success", false)):
		return _failure("TileSet create_empty failed through the split tileset service.")

	if not _create_atlas_tileset_fixture(ATLAS_TILESET_PATH):
		return _failure("Failed to create atlas TileSet fixture for the split tilemap contracts.")

	var assign_result: Dictionary = executor.execute("tileset", {
		"action": "assign_to_tilemap",
		"path": "TileMapNode",
		"tileset_path": ATLAS_TILESET_PATH
	})
	if not bool(assign_result.get("success", false)):
		return _failure("TileSet assign_to_tilemap failed through the split tileset service.")

	var tileset_info_result: Dictionary = executor.execute("tileset", {
		"action": "get_info",
		"tileset_path": ATLAS_TILESET_PATH
	})
	if not bool(tileset_info_result.get("success", false)):
		return _failure("TileSet get_info failed through the split tileset service.")

	var list_sources_result: Dictionary = executor.execute("tileset", {
		"action": "list_sources",
		"tileset_path": ATLAS_TILESET_PATH
	})
	if not bool(list_sources_result.get("success", false)):
		return _failure("TileSet list_sources failed through the split tileset service.")

	var get_source_result: Dictionary = executor.execute("tileset", {
		"action": "get_source",
		"tileset_path": ATLAS_TILESET_PATH,
		"source_id": 0
	})
	if not bool(get_source_result.get("success", false)):
		return _failure("TileSet get_source failed through the split tileset service.")

	var list_tiles_result: Dictionary = executor.execute("tileset", {
		"action": "list_tiles",
		"tileset_path": ATLAS_TILESET_PATH,
		"source_id": 0
	})
	if not bool(list_tiles_result.get("success", false)):
		return _failure("TileSet list_tiles failed through the split tileset service.")

	var tile_data_result: Dictionary = executor.execute("tileset", {
		"action": "get_tile_data",
		"tileset_path": ATLAS_TILESET_PATH,
		"source_id": 0,
		"atlas_coords": {"x": 0, "y": 0}
	})
	if not bool(tile_data_result.get("success", false)):
		return _failure("TileSet get_tile_data failed through the split tileset service.")

	var tilemap_info_result: Dictionary = executor.execute("tilemap", {
		"action": "get_info",
		"path": "TileMapNode"
	})
	if not bool(tilemap_info_result.get("success", false)):
		return _failure("TileMap get_info failed through the split tilemap service.")

	var set_cell_result: Dictionary = executor.execute("tilemap", {
		"action": "set_cell",
		"path": "TileMapNode",
		"coords": {"x": 1, "y": 2},
		"source_id": 0,
		"atlas_coords": {"x": 0, "y": 0}
	})
	if not bool(set_cell_result.get("success", false)):
		return _failure("TileMap set_cell failed through the split tilemap service.")

	var get_cell_result: Dictionary = executor.execute("tilemap", {
		"action": "get_cell",
		"path": "TileMapNode",
		"coords": {"x": 1, "y": 2}
	})
	if not bool(get_cell_result.get("success", false)):
		return _failure("TileMap get_cell failed through the split tilemap service.")
	if bool(get_cell_result.get("data", {}).get("empty", true)):
		return _failure("TileMap get_cell should report a populated cell after set_cell.")

	var fill_rect_result: Dictionary = executor.execute("tilemap", {
		"action": "fill_rect",
		"path": "TileMapNode",
		"rect": {"x": 0, "y": 0, "width": 2, "height": 2},
		"source_id": 0,
		"atlas_coords": {"x": 0, "y": 0}
	})
	if not bool(fill_rect_result.get("success", false)):
		return _failure("TileMap fill_rect failed through the split tilemap service.")

	var used_cells_result: Dictionary = executor.execute("tilemap", {
		"action": "get_used_cells",
		"path": "TileMapNode"
	})
	if not bool(used_cells_result.get("success", false)):
		return _failure("TileMap get_used_cells failed through the split layer service.")

	var used_rect_result: Dictionary = executor.execute("tilemap", {
		"action": "get_used_rect",
		"path": "TileMapNode"
	})
	if not bool(used_rect_result.get("success", false)):
		return _failure("TileMap get_used_rect failed through the split layer service.")

	var erase_result: Dictionary = executor.execute("tilemap", {
		"action": "erase_cell",
		"path": "TileMapNode",
		"coords": {"x": 1, "y": 2}
	})
	if not bool(erase_result.get("success", false)):
		return _failure("TileMap erase_cell failed through the split layer service.")

	var clear_result: Dictionary = executor.execute("tilemap", {
		"action": "clear_layer",
		"path": "TileMapNode",
		"layer": 0
	})
	if not bool(clear_result.get("success", false)):
		return _failure("TileMap clear_layer failed through the split layer service.")

	var cleared_cells_result: Dictionary = executor.execute("tilemap", {
		"action": "get_used_cells",
		"path": "TileMapNode"
	})
	if not bool(cleared_cells_result.get("success", false)):
		return _failure("TileMap get_used_cells after clear failed through the split layer service.")
	if int(cleared_cells_result.get("data", {}).get("total_count", -1)) != 0:
		return _failure("TileMap clear_layer should remove all used cells.")

	return {
		"name": "tilemap_tool_executor_contracts",
		"success": true,
		"error": "",
		"details": {
			"tool_count": tool_defs.size(),
			"source_count": int(list_sources_result.get("data", {}).get("count", 0)),
			"tile_count": int(list_tiles_result.get("data", {}).get("count", 0)),
			"cells_after_fill": int(used_cells_result.get("data", {}).get("total_count", 0))
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	_remove_tree(TEMP_ROOT)
	if _scene_root != null:
		if _scene_root.get_parent() != null:
			_scene_root.get_parent().remove_child(_scene_root)
		_scene_root.queue_free()
		_scene_root = null
		await tree.process_frame


func _build_scene_fixture(tree: SceneTree) -> Node2D:
	var root := Node2D.new()
	root.name = "TilemapToolExecutorContracts"
	var tilemap := TileMap.new()
	tilemap.name = "TileMapNode"
	if tilemap.get_layers_count() == 0:
		tilemap.add_layer(0)
	root.add_child(tilemap)
	tree.root.add_child(root)
	return root


func _create_atlas_tileset_fixture(path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.4, 0.2, 1.0))
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		return false

	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(16, 16)
	atlas_source.create_tile(Vector2i.ZERO)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_source(atlas_source, 0)
	return ResourceSaver.save(tileset, path) == OK


func _remove_tree(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_tree_absolute(absolute_path)


func _remove_tree_absolute(absolute_path: String) -> void:
	var dir = DirAccess.open(absolute_path)
	if dir == null:
		DirAccess.remove_absolute(absolute_path)
		return

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child_path := absolute_path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree_absolute(child_path)
			else:
				DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "tilemap_tool_executor_contracts",
		"success": false,
		"error": message
	}
