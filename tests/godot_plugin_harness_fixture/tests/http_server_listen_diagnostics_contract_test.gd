extends RefCounted

const MCPHttpServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var server = MCPHttpServerScript.new()
	server.initialize(3000, "127.0.0.1", false)

	var address_in_use: Dictionary = server._build_listen_failure_context(1, "Already in use")
	if str(address_in_use.get("failure_reason", "")) != "address_in_use":
		return _failure("Listen diagnostics should classify already-in-use errors as address_in_use.")
	if bool(address_in_use.get("requires_client_config_update", true)):
		return _failure("address_in_use diagnostics should not require a client config update by default.")
	var address_hint: String = server._build_listen_failure_suggested_action(address_in_use)
	if address_hint.find("stale plugin instance") == -1:
		return _failure("address_in_use diagnostics should mention stale plugin instances or occupied ports.")

	var access_denied: Dictionary = server._build_listen_failure_context(1, "AccessDenied 10013")
	var access_reason := str(access_denied.get("failure_reason", ""))
	if access_reason != "access_denied":
		return _failure("AccessDenied 10013 should classify as access_denied unless excluded or reserved port evidence is present.")
	if bool(access_denied.get("requires_client_config_update", true)):
		return _failure("access_denied diagnostics should not require a client config update by default.")
	if OS.get_name().to_lower().find("windows") != -1:
		var access_commands = access_denied.get("diagnostic_commands", [])
		if not (access_commands is Array) or (access_commands as Array).is_empty():
			return _failure("Windows access_denied diagnostics should include netsh commands as an investigation hint.")

	var reserved: Dictionary = server._build_listen_failure_context(1, "AccessDenied 10013 excluded port range")
	var reserved_reason := str(reserved.get("failure_reason", ""))
	if OS.get_name().to_lower().find("windows") != -1:
		if reserved_reason != "port_excluded_or_reserved":
			return _failure("Windows excluded port evidence should classify as port_excluded_or_reserved.")
		var reserved_commands = reserved.get("diagnostic_commands", [])
		if not (reserved_commands is Array) or (reserved_commands as Array).is_empty():
			return _failure("Reserved port diagnostics should include netsh diagnostic commands.")
		if str((reserved_commands as Array)[0]).find("excludedportrange") == -1:
			return _failure("Reserved port diagnostics should point at netsh excludedportrange.")
		if not bool(reserved.get("requires_client_config_update", false)):
			return _failure("Reserved port diagnostics should require a client config update after changing ports.")
	else:
		if reserved_reason != "access_denied":
			return _failure("Non-Windows AccessDenied should classify as access_denied.")

	var reserved_hint: String = server._build_listen_failure_suggested_action(reserved)
	if reserved_reason == "port_excluded_or_reserved" and reserved_hint.find("netsh") == -1:
		return _failure("Reserved port suggested action should mention netsh.")

	server.free()
	return {
		"name": "http_server_listen_diagnostics_contracts",
		"success": true,
		"error": "",
		"details": {
			"address_in_use_reason": str(address_in_use.get("failure_reason", "")),
			"access_denied_reason": access_reason,
			"reserved_reason": reserved_reason
		}
	}


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_server_listen_diagnostics_contracts",
		"success": false,
		"error": message
	}
