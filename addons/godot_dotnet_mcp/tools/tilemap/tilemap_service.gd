@tool
extends "res://addons/godot_dotnet_mcp/tools/tilemap/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	var tilemap := _get_tilemap(str(args.get("path", "")))
	if tilemap == null:
		return _error("Node is not a TileMap: %s" % str(args.get("path", "")))

	match action:
		"get_info":
			return _get_tilemap_info(tilemap)
		"get_cell":
			return _get_tilemap_cell(tilemap, args)
		"set_cell":
			return _set_tilemap_cell(tilemap, args)
		"fill_rect":
			return _fill_tilemap_rect(tilemap, args)
		_:
			return _error("Unknown action: %s" % action)


func _get_tilemap_info(tilemap: TileMap) -> Dictionary:
	var info: Dictionary = {
		"path": _get_scene_path(tilemap),
		"layers_count": tilemap.get_layers_count(),
		"has_tileset": tilemap.tile_set != null
	}
	if tilemap.tile_set != null:
		info["tile_size"] = _serialize_value(tilemap.tile_set.tile_size)

	var layers: Array[Dictionary] = []
	for i in range(tilemap.get_layers_count()):
		layers.append({
			"index": i,
			"name": tilemap.get_layer_name(i),
			"enabled": tilemap.is_layer_enabled(i),
			"modulate": _serialize_value(tilemap.get_layer_modulate(i)),
			"y_sort_enabled": tilemap.is_layer_y_sort_enabled(i),
			"z_index": tilemap.get_layer_z_index(i)
		})
	info["layers"] = layers
	return _success(info)


func _get_tilemap_cell(tilemap: TileMap, args: Dictionary) -> Dictionary:
	var layer_result := _validate_layer(tilemap, args)
	if not bool(layer_result.get("success", false)):
		return layer_result

	var layer := int(layer_result.get("layer", 0))
	var coords := _parse_coords(args.get("coords", {"x": 0, "y": 0}))
	var source_id = tilemap.get_cell_source_id(layer, coords)
	var atlas_coords = tilemap.get_cell_atlas_coords(layer, coords)
	var alternative_id = tilemap.get_cell_alternative_tile(layer, coords)

	if source_id == -1:
		return _success({
			"coords": _serialize_value(coords),
			"layer": layer,
			"empty": true
		})

	return _success({
		"coords": _serialize_value(coords),
		"layer": layer,
		"source_id": source_id,
		"atlas_coords": _serialize_value(atlas_coords),
		"alternative_id": alternative_id,
		"empty": false
	})


func _set_tilemap_cell(tilemap: TileMap, args: Dictionary) -> Dictionary:
	var layer_result := _validate_layer(tilemap, args)
	if not bool(layer_result.get("success", false)):
		return layer_result

	var layer := int(layer_result.get("layer", 0))
	var coords := _parse_coords(args.get("coords", {"x": 0, "y": 0}))
	var source_id := int(args.get("source_id", 0))
	var atlas_coords := _parse_coords(args.get("atlas_coords", {"x": 0, "y": 0}))
	var alternative_id := int(args.get("alternative_id", 0))
	tilemap.set_cell(layer, coords, source_id, atlas_coords, alternative_id)

	return _success({
		"coords": _serialize_value(coords),
		"layer": layer,
		"source_id": source_id,
		"atlas_coords": _serialize_value(atlas_coords),
		"alternative_id": alternative_id
	}, "Cell set")


func _fill_tilemap_rect(tilemap: TileMap, args: Dictionary) -> Dictionary:
	var layer_result := _validate_layer(tilemap, args)
	if not bool(layer_result.get("success", false)):
		return layer_result

	var layer := int(layer_result.get("layer", 0))
	var rect_dict: Dictionary = args.get("rect", {"x": 0, "y": 0, "width": 1, "height": 1})
	var source_id := int(args.get("source_id", 0))
	var atlas_coords := _parse_coords(args.get("atlas_coords", {"x": 0, "y": 0}))
	var alternative_id := int(args.get("alternative_id", 0))

	var start_x := int(rect_dict.get("x", 0))
	var start_y := int(rect_dict.get("y", 0))
	var width := int(rect_dict.get("width", 1))
	var height := int(rect_dict.get("height", 1))

	var cells_set := 0
	for x in range(start_x, start_x + width):
		for y in range(start_y, start_y + height):
			tilemap.set_cell(layer, Vector2i(x, y), source_id, atlas_coords, alternative_id)
			cells_set += 1

	return _success({
		"layer": layer,
		"rect": rect_dict,
		"cells_set": cells_set,
		"source_id": source_id,
		"atlas_coords": _serialize_value(atlas_coords)
	}, "Rectangle filled with %d cells" % cells_set)


func _validate_layer(tilemap: TileMap, args: Dictionary) -> Dictionary:
	var layer := int(args.get("layer", 0))
	if layer < 0 or layer >= tilemap.get_layers_count():
		return _error("Invalid layer: %d" % layer)
	return {"success": true, "layer": layer}


func _parse_coords(value: Dictionary) -> Vector2i:
	return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
