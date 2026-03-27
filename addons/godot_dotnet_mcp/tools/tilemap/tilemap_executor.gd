@tool
extends RefCounted

const TilemapCatalog = preload("res://addons/godot_dotnet_mcp/tools/tilemap/catalog.gd")
const TilesetService = preload("res://addons/godot_dotnet_mcp/tools/tilemap/tileset_service.gd")
const TilemapService = preload("res://addons/godot_dotnet_mcp/tools/tilemap/tilemap_service.gd")
const LayerService = preload("res://addons/godot_dotnet_mcp/tools/tilemap/layer_service.gd")

var _catalog := TilemapCatalog.new()
var _tileset_service := TilesetService.new()
var _tilemap_service := TilemapService.new()
var _layer_service := LayerService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_tileset_service, _tilemap_service, _layer_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"tileset":
			return _tileset_service.execute(tool_name, args)
		"tilemap":
			return _execute_tilemap(args)
		_:
			return _tileset_service._error("Unknown tool: %s" % tool_name)


func _execute_tilemap(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"get_info", "get_cell", "set_cell", "fill_rect":
			return _tilemap_service.execute("tilemap", args)
		"erase_cell", "clear_layer", "get_used_cells", "get_used_rect":
			return _layer_service.execute("tilemap", args)
		_:
			return _tilemap_service._error("Unknown action: %s" % action)
