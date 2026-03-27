@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "theme",
			"description": """THEME OPERATIONS: Create and manage UI themes.

ACTIONS:
- create: Create a new Theme resource
- get_info: Get theme information
- set_color: Set a color in the theme
- get_color: Get a color from the theme
- set_constant: Set a constant (integer) value
- get_constant: Get a constant value
- set_font: Set a font
- set_font_size: Set font size
- set_stylebox: Create and set a StyleBox
- clear_item: Clear a theme item
- copy_default: Copy items from default theme
- assign_to_node: Assign theme to a Control node

THEME ITEM TYPES:
- colors: Color values
- constants: Integer values (margins, spacing, etc.)
- fonts: Font resources
- font_sizes: Integer font sizes
- icons: Texture2D resources
- styleboxes: StyleBox resources

EXAMPLES:
- Create theme: {"action": "create", "save_path": "res://themes/custom.tres"}
- Set color: {"action": "set_color", "path": "res://themes/custom.tres", "name": "font_color", "type": "Button", "color": {"r": 1, "g": 1, "b": 1, "a": 1}}
- Set constant: {"action": "set_constant", "path": "res://themes/custom.tres", "name": "margin_left", "type": "Button", "value": 10}
- Assign to node: {"action": "assign_to_node", "theme_path": "res://themes/custom.tres", "node_path": "/root/UI"}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["create", "get_info", "set_color", "get_color", "set_constant", "get_constant", "set_font", "set_font_size", "set_stylebox", "clear_item", "copy_default", "assign_to_node"],
						"description": "Theme action"
					},
					"path": {
						"type": "string",
						"description": "Theme resource path"
					},
					"theme_path": {
						"type": "string",
						"description": "Theme to assign"
					},
					"node_path": {
						"type": "string",
						"description": "Control node path"
					},
					"save_path": {
						"type": "string",
						"description": "Path to save theme"
					},
					"name": {
						"type": "string",
						"description": "Theme item name"
					},
					"type": {
						"type": "string",
						"description": "Control type (Button, Label, etc.)"
					},
					"color": {
						"type": "object",
						"description": "Color value {r, g, b, a}"
					},
					"value": {
						"description": "Value for constants/font_sizes"
					},
					"font_path": {
						"type": "string",
						"description": "Font resource path"
					},
					"stylebox_type": {
						"type": "string",
						"enum": ["flat", "line", "texture", "empty"],
						"description": "StyleBox type to create"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "control",
			"description": """CONTROL LAYOUT: Manage Control node layout and properties.

ACTIONS:
- get_layout: Get Control layout information
- set_anchor: Set anchor values
- set_anchor_preset: Set anchor preset
- set_margins: Set margin values (now called offsets)
- set_size_flags: Set size flags
- set_min_size: Set minimum size
- set_focus_mode: Set focus mode
- set_mouse_filter: Set mouse filter
- arrange: Arrange child controls

ANCHOR PRESETS:
- top_left, top_right, bottom_left, bottom_right
- center_left, center_right, center_top, center_bottom
- center, full_rect
- top_wide, bottom_wide, left_wide, right_wide
- hcenter_wide, vcenter_wide

SIZE FLAGS:
- fill: Control fills available space
- expand: Control expands to fill
- shrink_center: Center when smaller
- shrink_end: Align to end when smaller

EXAMPLES:
- Get layout: {"action": "get_layout", "path": "/root/UI/Button"}
- Set anchor preset: {"action": "set_anchor_preset", "path": "/root/UI/Panel", "preset": "full_rect"}
- Set margins: {"action": "set_margins", "path": "/root/UI/Panel", "left": 10, "top": 10, "right": -10, "bottom": -10}
- Set size flags: {"action": "set_size_flags", "path": "/root/UI/Button", "horizontal": ["fill", "expand"]}""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["get_layout", "set_anchor", "set_anchor_preset", "set_margins", "set_size_flags", "set_min_size", "set_focus_mode", "set_mouse_filter", "arrange"],
						"description": "Control action"
					},
					"path": {
						"type": "string",
						"description": "Control node path"
					},
					"preset": {
						"type": "string",
						"description": "Anchor preset name"
					},
					"left": {"type": "number", "description": "Left anchor/margin"},
					"top": {"type": "number", "description": "Top anchor/margin"},
					"right": {"type": "number", "description": "Right anchor/margin"},
					"bottom": {"type": "number", "description": "Bottom anchor/margin"},
					"horizontal": {
						"type": "array",
						"items": {"type": "string"},
						"description": "Horizontal size flags"
					},
					"vertical": {
						"type": "array",
						"items": {"type": "string"},
						"description": "Vertical size flags"
					},
					"width": {"type": "number", "description": "Minimum width"},
					"height": {"type": "number", "description": "Minimum height"},
					"mode": {
						"type": "string",
						"enum": ["none", "click", "all"],
						"description": "Focus mode"
					},
					"filter": {
						"type": "string",
						"enum": ["stop", "pass", "ignore"],
						"description": "Mouse filter"
					}
				},
				"required": ["action", "path"]
			}
		}
	]
