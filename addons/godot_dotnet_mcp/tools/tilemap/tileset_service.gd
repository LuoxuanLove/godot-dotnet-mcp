@tool
extends "res://addons/godot_dotnet_mcp/tools/tilemap/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	match action:
		"create_empty":
			return _create_empty_tileset(args)
		"assign_to_tilemap":
			return _assign_tileset_to_tilemap(args)
		"get_info":
			return _get_tileset_info(args)
		"list_sources":
			return _list_tileset_sources(args)
		"get_source":
			return _get_tileset_source(args)
		"list_tiles":
			return _list_tiles(args)
		"get_tile_data":
			return _get_tile_data(args)
		_:
			return _error("Unknown action: %s" % action)


func _create_empty_tileset(args: Dictionary) -> Dictionary:
	var tileset := TileSet.new()
	var save_path := _normalize_res_path(str(args.get("save_path", "")))

	if save_path.is_empty():
		return _success({
			"tile_size": _serialize_value(tileset.tile_size),
			"note": "TileSet created in memory. Provide save_path to persist it."
		}, "TileSet created")

	if not save_path.ends_with(".tres") and not save_path.ends_with(".res"):
		save_path += ".tres"

	_ensure_res_directory(save_path.get_base_dir())
	var error := ResourceSaver.save(tileset, save_path)
	if error != OK:
		return _error("Failed to save TileSet: %s" % error_string(error))

	var filesystem := _get_filesystem()
	if filesystem != null:
		filesystem.scan()

	return _success({
		"path": save_path,
		"tile_size": _serialize_value(tileset.tile_size)
	}, "TileSet created and saved")


func _assign_tileset_to_tilemap(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if path.is_empty():
		return _error("TileMap path is required")

	var tilemap := _get_tilemap(path)
	if tilemap == null:
		return _error("Node is not a TileMap: %s" % path)

	var tileset := _get_tileset_from_args(args)
	if tileset == null:
		return _error("TileSet not found")

	tilemap.tile_set = tileset
	return _success({
		"path": _get_scene_path(tilemap),
		"tileset_path": str(tileset.resource_path)
	}, "TileSet assigned to TileMap")


func _get_tileset_info(args: Dictionary) -> Dictionary:
	var tileset := _get_tileset_from_args(args)
	if tileset == null:
		return _error("TileSet not found. Provide 'path' (TileMap node) or 'tileset_path' (resource)")

	var info := {
		"tile_size": _serialize_value(tileset.tile_size),
		"source_count": tileset.get_source_count(),
		"physics_layers_count": tileset.get_physics_layers_count(),
		"terrain_sets_count": tileset.get_terrain_sets_count(),
		"navigation_layers_count": tileset.get_navigation_layers_count(),
		"custom_data_layers_count": tileset.get_custom_data_layers_count()
	}
	var custom_layers: Array[String] = []
	for i in range(tileset.get_custom_data_layers_count()):
		custom_layers.append(tileset.get_custom_data_layer_name(i))
	info["custom_data_layers"] = custom_layers
	return _success(info)


func _list_tileset_sources(args: Dictionary) -> Dictionary:
	var tileset := _get_tileset_from_args(args)
	if tileset == null:
		return _error("TileSet not found")

	var sources: Array[Dictionary] = []
	for i in range(tileset.get_source_count()):
		var source_id = tileset.get_source_id(i)
		var source = tileset.get_source(source_id)
		var source_info: Dictionary = {
			"id": source_id,
			"type": str(source.get_class())
		}
		if source is TileSetAtlasSource:
			source_info["texture"] = str(source.texture.resource_path) if source.texture != null else null
			source_info["texture_region_size"] = _serialize_value(source.texture_region_size)
			source_info["tile_count"] = source.get_tiles_count()
		elif source is TileSetScenesCollectionSource:
			source_info["scene_count"] = source.get_scene_tiles_count()
		sources.append(source_info)

	return _success({
		"count": sources.size(),
		"sources": sources
	})


func _get_tileset_source(args: Dictionary) -> Dictionary:
	var tileset := _get_tileset_from_args(args)
	if tileset == null:
		return _error("TileSet not found")

	var source_id := int(args.get("source_id", 0))
	if not tileset.has_source(source_id):
		return _error("Source not found: %d" % source_id)

	var source = tileset.get_source(source_id)
	var info: Dictionary = {
		"id": source_id,
		"type": str(source.get_class())
	}

	if source is TileSetAtlasSource:
		info["texture"] = str(source.texture.resource_path) if source.texture != null else null
		info["texture_region_size"] = _serialize_value(source.texture_region_size)
		info["separation"] = _serialize_value(source.separation)
		info["margins"] = _serialize_value(source.margins)
		info["tile_count"] = source.get_tiles_count()

		var tiles: Array[Dictionary] = []
		for j in range(source.get_tiles_count()):
			var coords = source.get_tile_id(j)
			tiles.append({
				"atlas_coords": _serialize_value(coords),
				"size_in_atlas": _serialize_value(source.get_tile_size_in_atlas(coords)),
				"alternative_count": source.get_alternative_tiles_count(coords)
			})
		info["tiles"] = tiles
	elif source is TileSetScenesCollectionSource:
		var scenes: Array[Dictionary] = []
		for j in range(source.get_scene_tiles_count()):
			var scene_id = source.get_scene_tile_id(j)
			var scene = source.get_scene_tile_scene(scene_id)
			scenes.append({
				"id": scene_id,
				"scene": str(scene.resource_path) if scene != null else null
			})
		info["scenes"] = scenes

	return _success(info)


func _list_tiles(args: Dictionary) -> Dictionary:
	var tileset := _get_tileset_from_args(args)
	if tileset == null:
		return _error("TileSet not found")

	var source_id := int(args.get("source_id", 0))
	if not tileset.has_source(source_id):
		return _error("Source not found: %d" % source_id)

	var source = tileset.get_source(source_id)
	var tiles: Array[Dictionary] = []
	if source is TileSetAtlasSource:
		for i in range(source.get_tiles_count()):
			var coords = source.get_tile_id(i)
			var tile_info: Dictionary = {
				"atlas_coords": _serialize_value(coords),
				"size_in_atlas": _serialize_value(source.get_tile_size_in_atlas(coords))
			}
			var alternatives: Array[int] = []
			for alt_idx in range(source.get_alternative_tiles_count(coords)):
				alternatives.append(source.get_alternative_tile_id(coords, alt_idx))
			tile_info["alternatives"] = alternatives
			tiles.append(tile_info)
	elif source is TileSetScenesCollectionSource:
		for i in range(source.get_scene_tiles_count()):
			var scene_id = source.get_scene_tile_id(i)
			var scene = source.get_scene_tile_scene(scene_id)
			tiles.append({
				"scene_id": scene_id,
				"scene_path": str(scene.resource_path) if scene != null else null
			})

	return _success({
		"source_id": source_id,
		"count": tiles.size(),
		"tiles": tiles
	})


func _get_tile_data(args: Dictionary) -> Dictionary:
	var tileset := _get_tileset_from_args(args)
	if tileset == null:
		return _error("TileSet not found")

	var source_id := int(args.get("source_id", 0))
	if not tileset.has_source(source_id):
		return _error("Source not found: %d" % source_id)

	var source = tileset.get_source(source_id)
	if not (source is TileSetAtlasSource):
		return _error("Source is not an atlas source")

	var atlas_coords_dict: Dictionary = args.get("atlas_coords", {"x": 0, "y": 0})
	var atlas_coords := Vector2i(int(atlas_coords_dict.get("x", 0)), int(atlas_coords_dict.get("y", 0)))
	var alternative_id := int(args.get("alternative_id", 0))
	if not source.has_tile(atlas_coords):
		return _error("Tile not found at coords: %s" % str(atlas_coords))

	var tile_data = source.get_tile_data(atlas_coords, alternative_id)
	if tile_data == null:
		return _error("Tile data not found")

	var info: Dictionary = {
		"atlas_coords": _serialize_value(atlas_coords),
		"alternative_id": alternative_id,
		"texture_origin": _serialize_value(tile_data.texture_origin),
		"modulate": _serialize_value(tile_data.modulate),
		"z_index": tile_data.z_index,
		"y_sort_origin": tile_data.y_sort_origin,
		"probability": tile_data.probability
	}
	var custom_data := {}
	for i in range(tileset.get_custom_data_layers_count()):
		var layer_name = tileset.get_custom_data_layer_name(i)
		custom_data[layer_name] = tile_data.get_custom_data(layer_name)
	info["custom_data"] = custom_data

	return _success(info)
