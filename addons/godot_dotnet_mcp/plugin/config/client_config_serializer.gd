@tool
extends RefCounted
class_name ClientConfigSerializer


func get_server_container_key(config_type: String) -> String:
	return _get_server_container_key(config_type)


func preflight_requires_confirmation(status: String) -> bool:
	return _preflight_requires_confirmation(status)


func prepare_new_config(new_config: String, config_type: String = "") -> Dictionary:
	var json = JSON.new()
	if json.parse(new_config) != OK:
		return {"success": false, "error": "parse_error"}

	var new_config_data = json.get_data()
	if not (new_config_data is Dictionary):
		return {"success": false, "error": "parse_error"}

	var new_servers = new_config_data.get(_get_server_container_key(config_type), {})
	if not (new_servers is Dictionary):
		return {"success": false, "error": "parse_error"}

	var server_names := PackedStringArray()
	for server_name in new_servers.keys():
		server_names.append(str(server_name))

	return {
		"success": true,
		"config_data": new_config_data,
		"new_servers": new_servers,
		"server_names": server_names
	}


func _preflight_requires_confirmation(status: String) -> bool:
	return status == "invalid_json" or status == "incompatible_root" or status == "incompatible_mcp_servers" or status == "incompatible_mcp"


func _get_server_container_key(config_type: String) -> String:
	return "mcp" if config_type == "opencode" else "mcpServers"
