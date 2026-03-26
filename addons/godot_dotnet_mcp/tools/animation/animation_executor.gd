@tool
extends RefCounted

const AnimationCatalog = preload("res://addons/godot_dotnet_mcp/tools/animation/catalog.gd")
const PlayerService = preload("res://addons/godot_dotnet_mcp/tools/animation/player_service.gd")
const AnimationService = preload("res://addons/godot_dotnet_mcp/tools/animation/animation_service.gd")
const TrackService = preload("res://addons/godot_dotnet_mcp/tools/animation/track_service.gd")
const TweenService = preload("res://addons/godot_dotnet_mcp/tools/animation/tween_service.gd")
const AnimationTreeService = preload("res://addons/godot_dotnet_mcp/tools/animation/animation_tree_service.gd")
const StateMachineService = preload("res://addons/godot_dotnet_mcp/tools/animation/state_machine_service.gd")
const BlendSpaceService = preload("res://addons/godot_dotnet_mcp/tools/animation/blend_space_service.gd")
const BlendTreeService = preload("res://addons/godot_dotnet_mcp/tools/animation/blend_tree_service.gd")

var _catalog := AnimationCatalog.new()
var _player_service := PlayerService.new()
var _animation_service := AnimationService.new()
var _track_service := TrackService.new()
var _tween_service := TweenService.new()
var _animation_tree_service := AnimationTreeService.new()
var _state_machine_service := StateMachineService.new()
var _blend_space_service := BlendSpaceService.new()
var _blend_tree_service := BlendTreeService.new()


func configure_context(context: Dictionary = {}) -> void:
	for service in [_player_service, _animation_service, _track_service, _tween_service, _animation_tree_service, _state_machine_service, _blend_space_service, _blend_tree_service]:
		service.configure_context(context)


func get_tools() -> Array[Dictionary]:
	return _catalog.get_tools()


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	match tool_name:
		"player":
			return _player_service.execute(tool_name, args)
		"animation":
			return _animation_service.execute(tool_name, args)
		"track":
			return _track_service.execute(tool_name, args)
		"tween":
			return _tween_service.execute(tool_name, args)
		"animation_tree":
			return _animation_tree_service.execute(tool_name, args)
		"state_machine":
			return _state_machine_service.execute(tool_name, args)
		"blend_space":
			return _blend_space_service.execute(tool_name, args)
		"blend_tree":
			return _blend_tree_service.execute(tool_name, args)
		_:
			return _player_service._error("Unknown tool: %s" % tool_name)
