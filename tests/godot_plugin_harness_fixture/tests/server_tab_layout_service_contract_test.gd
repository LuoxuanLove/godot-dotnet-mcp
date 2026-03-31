extends RefCounted

const ServerPanelScene = preload("res://addons/godot_dotnet_mcp/ui/server_panel.tscn")
const ServerTabLayoutNodes = preload("res://addons/godot_dotnet_mcp/ui/server_tab_layout_nodes.gd")
const ServerTabLayoutService = preload("res://addons/godot_dotnet_mcp/ui/server_tab_layout_service.gd")

var _instance: VBoxContainer = null


func run_case(tree: SceneTree) -> Dictionary:
	_instance = ServerPanelScene.instantiate() as VBoxContainer
	if _instance == null:
		return _failure("Server tab layout service test could not instantiate server panel scene.")
	tree.root.add_child(_instance)
	await tree.process_frame

	_instance.size = Vector2(640, 720)
	var service = ServerTabLayoutService.new()
	var layout_nodes = ServerTabLayoutNodes.new().populate_from(_instance)
	service.apply_editor_scale(layout_nodes, 1.0)
	var first_width = service.apply_responsive_layout(layout_nodes, 1.0, -1.0)
	var second_width = service.apply_responsive_layout(layout_nodes, 1.0, first_width)

	if first_width <= 0.0:
		return _failure("Server tab layout service should calculate a positive responsive width.")
	if not is_equal_approx(first_width, second_width):
		return _failure("Server tab layout service should keep layout width stable when width does not change.")
	if not layout_nodes.is_resolved():
		return _failure("Server tab layout service should resolve all layout nodes from the server panel scene.")

	var status_grid = layout_nodes.status_grid
	var overview_buttons = layout_nodes.overview_buttons
	if status_grid.columns <= 0:
		return _failure("Server tab layout service should keep status grid columns valid.")
	if overview_buttons.columns <= 0:
		return _failure("Server tab layout service should keep overview button columns valid.")

	return {
		"name": "server_tab_layout_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"layout_width": first_width,
			"status_columns": status_grid.columns,
			"overview_columns": overview_buttons.columns,
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	if _instance != null and is_instance_valid(_instance):
		_instance.queue_free()
	_instance = null
	await tree.process_frame
	await tree.process_frame


func _failure(message: String) -> Dictionary:
	return {
		"name": "server_tab_layout_service_contracts",
		"success": false,
		"error": message,
	}
