@tool
extends RefCounted
class_name ClientConfigFileTransaction

const ClientConfigServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd")

var _service := ClientConfigServiceScript.new()
var _serializer: Variant = null


func configure(serializer: Variant) -> void:
	_serializer = serializer


func preflight_write_config(config_type: String, filepath: String, new_config: String) -> Dictionary:
	return _service.preflight_write_config(config_type, filepath, new_config)


func write_config_file(config_type: String, filepath: String, new_config: String, options: Dictionary = {}) -> Dictionary:
	return _service.write_config_file(config_type, filepath, new_config, options)


func remove_config_entry(config_type: String, filepath: String, server_name: String = "godot-mcp") -> Dictionary:
	return _service.remove_config_entry(config_type, filepath, {}, server_name)
