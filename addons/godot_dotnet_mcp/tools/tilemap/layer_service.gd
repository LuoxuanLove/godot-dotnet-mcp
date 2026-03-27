@tool
extends "res://addons/godot_dotnet_mcp/tools/tilemap/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	var tilemap := _get_tilemap(str(args.get("path", "")))
	if tilemap == null:
		return _error("Node is not a TileMap: %s" % str(args.get("path", "")))

	match action:
		"erase_cell":
			return _erase_tilemap_cell(tilemap, args)
		"clear_layer":
			return _clear_tilemap_layer(tilemap, args)
		"get_used_cells":
			return _get_used_cells(tilemap, args)
		"get_used_rect":
			return _get_used_rect(tilemap, args)
		_:
			return _error("Unknown action: %s" % action)


func _erase_tilemap_cell(tilemap: TileMap, args: Dictionary) -> Dictionary:
	var layer_result := _validate_layer(tilemap, args)
	if not bool(layer_result.get("success", false)):
		return layer_result

	var layer := int(layer_result.get("layer", 0))
	var coords := _parse_coords(args.get("coords", {"x": 0, "y": 0}))
	tilemap.erase_cell(layer, coords)
	return _success({
		"coords": _serialize_value(coords),
		"layer": layer
	}, "Cell erased")


func _clear_tilemap_layer(tilemap: TileMap, args: Dictionary) -> Dictionary:
	var layer_result := _validate_layer(tilemap, args)
	if not bool(layer_result.get("success", false)):
		return layer_result

	var layer := int(layer_result.get("layer", 0))
	tilemap.clear_layer(layer)
	return _success({
		"layer": layer
	}, "Layer %d cleared" % layer)


func _get_used_cells(tilemap: TileMap, args: Dictionary) -> Dictionary:
	var layer_result := _validate_layer(tilemap, args)
	if not bool(layer_result.get("success", false)):
		return layer_result

	var layer := int(layer_result.get("layer", 0))
	var cells = tilemap.get_used_cells(layer)
	var cells_array: Array[Dictionary] = []
	var limit := mini(cells.size(), 1000)
	for i in range(limit):
		cells_array.append(_serialize_value(cells[i]))

	return _success({
		"layer": layer,
		"total_count": cells.size(),
		"returned_count": cells_array.size(),
		"cells": cells_array,
		"truncated": cells.size() > 1000
	})


func _get_used_rect(tilemap: TileMap, _args: Dictionary) -> Dictionary:
	var rect = tilemap.get_used_rect()
	return _success({
		"rect": {
			"position": _serialize_value(rect.position),
			"size": _serialize_value(rect.size),
			"end": _serialize_value(rect.end)
		}
	})


func _validate_layer(tilemap: TileMap, args: Dictionary) -> Dictionary:
	var layer := int(args.get("layer", 0))
	if layer < 0 or layer >= tilemap.get_layers_count():
		return _error("Invalid layer: %d" % layer)
	return {"success": true, "layer": layer}


func _parse_coords(value: Dictionary) -> Vector2i:
	return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
