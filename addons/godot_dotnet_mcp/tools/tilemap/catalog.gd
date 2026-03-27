@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "tileset",
			"description": """TILESET MANAGEMENT: Manage TileSet resources.

ACTIONS:
- create_empty: Create an empty TileSet resource
- assign_to_tilemap: Assign a TileSet resource to a TileMap
- get_info: Get TileSet information
- list_sources: List all sources (atlases/scenes) in TileSet
- get_source: Get details of a specific source
- list_tiles: List all tiles in a source
- get_tile_data: Get custom data for a tile

TILESET SOURCES:
- Atlas Source: Image-based tiles (TileSetAtlasSource)
- Scene Source: Scene-based tiles (TileSetScenesCollectionSource)
""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create_empty", "assign_to_tilemap", "get_info", "list_sources", "get_source", "list_tiles", "get_tile_data"],
						"description": "TileSet action"
					},
					"path": {
						"type": "string",
						"description": "TileMap node path"
					},
					"tileset_path": {
						"type": "string",
						"description": "TileSet resource path (res://...)"
					},
					"save_path": {
						"type": "string",
						"description": "Path to save the created TileSet resource"
					},
					"source_id": {
						"type": "integer",
						"description": "Source ID in the TileSet"
					},
					"atlas_coords": {
						"type": "object",
						"description": "Atlas coordinates {x, y}"
					},
					"alternative_id": {
						"type": "integer",
						"description": "Alternative tile ID (default: 0)"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "tilemap",
			"description": """TILEMAP OPERATIONS: Manipulate TileMap cells.

ACTIONS:
- get_info: Get TileMap layer information
- get_cell: Get cell data at coordinates
- set_cell: Set a cell to a specific tile
- erase_cell: Erase a cell (remove tile)
- fill_rect: Fill a rectangular area with tiles
- clear_layer: Clear all cells in a layer
- get_used_cells: Get all used cell coordinates
- get_used_rect: Get bounding rectangle of used cells
""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_info", "get_cell", "set_cell", "erase_cell", "fill_rect", "clear_layer", "get_used_cells", "get_used_rect"],
						"description": "TileMap action"
					},
					"path": {
						"type": "string",
						"description": "TileMap node path"
					},
					"layer": {
						"type": "integer",
						"description": "Layer index (default: 0)"
					},
					"coords": {
						"type": "object",
						"description": "Cell coordinates {x, y}"
					},
					"rect": {
						"type": "object",
						"description": "Rectangle {x, y, width, height}"
					},
					"source_id": {
						"type": "integer",
						"description": "TileSet source ID"
					},
					"atlas_coords": {
						"type": "object",
						"description": "Atlas coordinates {x, y}"
					},
					"alternative_id": {
						"type": "integer",
						"description": "Alternative tile ID"
					}
				},
				"required": ["action", "path"]
			}
		}
	]
