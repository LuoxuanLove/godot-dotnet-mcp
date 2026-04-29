@tool
extends RefCounted
class_name ClientConfigInspectionService

const ClientConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")

var _service := ClientConfigServiceScript.new()
var _serializer: Variant = null
var _support: Variant = null


func configure(serializer: Variant, support: Variant) -> void:
	_serializer = serializer
	_support = support


func inspect_config_entry(config_type: String, filepath: String) -> Dictionary:
	return _service.inspect_config_entry(config_type, filepath)


func preflight_write_config(config_type: String, filepath: String, new_config: String) -> Dictionary:
	return _service.preflight_write_config(config_type, filepath, new_config)
