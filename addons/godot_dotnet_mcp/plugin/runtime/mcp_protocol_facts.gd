@tool
extends RefCounted
class_name MCPProtocolFacts

const FACTS_PATH := "res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.json"

static var _cached_facts: Dictionary = {}


static func get_all() -> Dictionary:
	if _cached_facts.is_empty():
		_cached_facts = _load_facts()
	return _cached_facts.duplicate(true)


static func get_protocol_version() -> String:
	return str(get_all().get("protocol_version", ""))


static func get_tool_schema_version() -> String:
	return str(get_all().get("tool_schema_version", ""))


static func get_server_name() -> String:
	return str(get_all().get("server_name", ""))


static func get_server_version() -> String:
	return str(get_all().get("server_version", ""))


static func get_error_codes() -> Dictionary:
	var error_codes = get_all().get("error_codes", {})
	if error_codes is Dictionary:
		return (error_codes as Dictionary).duplicate(true)
	return {}


static func get_error_code(key: String) -> String:
	var error_codes = get_error_codes()
	return str(error_codes.get(key, key))


static func build_server_info() -> Dictionary:
	return {
		"name": get_server_name(),
		"version": get_server_version()
	}


static func build_server_facts() -> Dictionary:
	return {
		"server_name": get_server_name(),
		"server_version": get_server_version(),
		"protocol_version": get_protocol_version(),
		"tool_schema_version": get_tool_schema_version()
	}


static func _load_facts() -> Dictionary:
	if not FileAccess.file_exists(FACTS_PATH):
		push_error("[MCP] Protocol facts file is missing: %s" % FACTS_PATH)
		return _default_facts()

	var raw_text := FileAccess.get_file_as_string(FACTS_PATH)
	if raw_text.is_empty():
		push_error("[MCP] Protocol facts file is empty: %s" % FACTS_PATH)
		return _default_facts()

	var json := JSON.new()
	if json.parse(raw_text) != OK:
		push_error("[MCP] Failed to parse protocol facts: %s" % json.get_error_message())
		return _default_facts()

	var data = json.get_data()
	if not (data is Dictionary):
		push_error("[MCP] Protocol facts file must contain a dictionary payload.")
		return _default_facts()

	var facts: Dictionary = data
	var error_codes := {}
	var raw_error_codes = facts.get("error_codes", {})
	if raw_error_codes is Dictionary:
		error_codes = (raw_error_codes as Dictionary).duplicate(true)

	return {
		"protocol_version": str(facts.get("protocol_version", "")),
		"tool_schema_version": str(facts.get("tool_schema_version", "")),
		"server_name": str(facts.get("server_name", "")),
		"server_version": str(facts.get("server_version", "")),
		"error_codes": error_codes
	}


static func _default_facts() -> Dictionary:
	return {
		"protocol_version": "2025-06-18",
		"tool_schema_version": "2026-03-27",
		"server_name": "godot-dotnet-mcp",
		"server_version": "0.6.0-dev",
		"error_codes": {
			"bridge_version_mismatch": "bridge_version_mismatch"
		}
	}
