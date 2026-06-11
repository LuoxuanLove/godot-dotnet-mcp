extends RefCounted

const JsonRpcMethodServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_method_service.gd")
const JsonRpcMethodContextScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_method_context.gd")
const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")


class FakeResponseService:
	extends RefCounted

	func build_json_rpc_response(result, id) -> Dictionary:
		return {
			"jsonrpc": "2.0",
			"result": result,
			"id": id
		}


func run_case(_tree: SceneTree) -> Dictionary:
	if MCPProtocolFacts.get_protocol_version() != "2025-11-25":
		return _failure("MCP protocol facts should default to the 2025-11-25 release target.")
	if MCPProtocolFacts.get_server_description().is_empty():
		return _failure("MCP server facts should include a human-readable implementation description.")

	var server_info := MCPProtocolFacts.build_server_info()
	if str(server_info.get("name", "")) != MCPProtocolFacts.get_server_name():
		return _failure("MCP serverInfo should preserve the configured server name.")
	if str(server_info.get("version", "")) != MCPProtocolFacts.get_server_version():
		return _failure("MCP serverInfo should preserve the configured server version.")
	if str(server_info.get("description", "")) != MCPProtocolFacts.get_server_description():
		return _failure("MCP serverInfo should expose the configured implementation description.")

	var server_facts := MCPProtocolFacts.build_server_facts()
	if str(server_facts.get("protocol_version", "")) != "2025-11-25":
		return _failure("MCP server facts should expose the 2025-11-25 default protocol version.")
	if str(server_facts.get("server_description", "")) != MCPProtocolFacts.get_server_description():
		return _failure("MCP server facts should expose the server description for diagnostics and resources.")

	var service = JsonRpcMethodServiceScript.new()
	var context = JsonRpcMethodContextScript.new()
	context.response_service = FakeResponseService.new()
	service.configure(context)
	var initialize_response: Dictionary = service.handle_initialize({}, 1)
	var initialize_result = initialize_response.get("result", {})
	if not (initialize_result is Dictionary):
		return _failure("initialize should return a result object.")
	if str((initialize_result as Dictionary).get("protocolVersion", "")) != "2025-11-25":
		return _failure("initialize should advertise protocolVersion 2025-11-25.")
	var initialize_server_info = (initialize_result as Dictionary).get("serverInfo", {})
	if not (initialize_server_info is Dictionary):
		return _failure("initialize should return serverInfo.")
	if str((initialize_server_info as Dictionary).get("description", "")) != MCPProtocolFacts.get_server_description():
		return _failure("initialize serverInfo should include the implementation description.")

	return {
		"name": "mcp_2025_baseline_contracts",
		"success": true,
		"error": "",
		"details": {
			"protocol_version": MCPProtocolFacts.get_protocol_version(),
			"server_description": MCPProtocolFacts.get_server_description()
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "mcp_2025_baseline_contracts",
		"success": false,
		"error": message
	}
