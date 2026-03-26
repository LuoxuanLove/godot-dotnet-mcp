extends RefCounted

const ClientConfigSerializerScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_serializer.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var serializer = ClientConfigSerializerScript.new()

	if serializer.get_server_container_key("") != "mcpServers":
		return _failure("Serializer should use mcpServers for desktop-style config files.")
	if serializer.get_server_container_key("opencode") != "mcp":
		return _failure("Serializer should use mcp for opencode config files.")
	if not serializer.preflight_requires_confirmation("incompatible_mcp"):
		return _failure("Serializer should require confirmation for incompatible opencode MCP roots.")

	var desktop_prepare: Dictionary = serializer.prepare_new_config(JSON.stringify({
		"mcpServers": {
			"godot-mcp": {
				"url": "http://127.0.0.1:3000/mcp"
			}
		}
	}, "  "))
	if not bool(desktop_prepare.get("success", false)):
		return _failure("Serializer could not parse a valid desktop config payload.")

	var desktop_names: PackedStringArray = desktop_prepare.get("server_names", PackedStringArray())
	if not desktop_names.has("godot-mcp"):
		return _failure("Serializer did not collect the desktop server name.")

	var opencode_prepare: Dictionary = serializer.prepare_new_config(JSON.stringify({
		"mcp": {
			"godot-mcp": {
				"transport": "stdio",
				"command": ["godot-dotnet-mcp", "--stdio"]
			}
		}
	}, "  "), "opencode")
	if not bool(opencode_prepare.get("success", false)):
		return _failure("Serializer could not parse a valid opencode config payload.")

	return {
		"name": "client_config_serializer_contracts",
		"success": true,
		"error": "",
		"details": {
			"desktop_server_count": desktop_names.size(),
			"opencode_server_count": int((opencode_prepare.get("server_names", PackedStringArray()) as PackedStringArray).size()),
			"opencode_requires_confirmation": serializer.preflight_requires_confirmation("incompatible_mcp")
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_config_serializer_contracts",
		"success": false,
		"error": message
	}
