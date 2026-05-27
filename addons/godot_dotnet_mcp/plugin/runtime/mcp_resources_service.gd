@tool
extends RefCounted
class_name MCPResourcesService

const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const MCPPathArgumentNormalizerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_path_argument_normalizer.gd")
const ToolPresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")
const MCPDebugBufferScript = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginSelfDiagnosticStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")

const PROJECT_INFO_URI := "godot-dotnet-mcp://project/info"
const DIAGNOSTICS_SUMMARY_URI := "godot-dotnet-mcp://diagnostics/summary"
const TOOL_CATALOG_URI := "godot-dotnet-mcp://tools/catalog"
const SCENE_TEMPLATE_URI := "godot-dotnet-mcp://scene/{path}"
const SCRIPT_TEMPLATE_URI := "godot-dotnet-mcp://script/{path}"
const RESOURCE_TEMPLATE_URI := "godot-dotnet-mcp://resource/{path}"
const REDACTED_VALUE := "[redacted]"
const SENSITIVE_KEY_PARTS := ["token", "password", "secret", "api_key", "apikey", "authorization", "credential", "private_key"]

var _get_tool_loader := Callable()
var _get_tool_loader_status := Callable()
var _sanitize_for_json := Callable()


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_get_tool_loader = context.get_tool_loader
	_get_tool_loader_status = context.get_tool_loader_status
	_sanitize_for_json = context.sanitize_for_json


func dispose() -> void:
	_get_tool_loader = Callable()
	_get_tool_loader_status = Callable()
	_sanitize_for_json = Callable()


func build_resources_list_result(_params: Dictionary = {}) -> Dictionary:
	return {
		"resources": [{
			"uri": PROJECT_INFO_URI,
			"name": "Project info",
			"description": "Current Godot project path, protocol facts, server info, and loader status.",
			"mimeType": "application/json"
		}, {
			"uri": DIAGNOSTICS_SUMMARY_URI,
			"name": "Diagnostics summary",
			"description": "Plugin self-diagnostics and recent MCP log records.",
			"mimeType": "application/json"
		}, {
			"uri": TOOL_CATALOG_URI,
			"name": "Tool catalog",
			"description": "Current MCP tool catalog with grouping metadata used by tools/list.",
			"mimeType": "application/json"
		}]
	}


func build_resource_templates_list_result(_params: Dictionary = {}) -> Dictionary:
	return {
		"resourceTemplates": [{
			"uriTemplate": SCENE_TEMPLATE_URI,
			"name": "Scene text",
			"description": "Read a .tscn scene file by project-relative path.",
			"mimeType": "text/plain"
		}, {
			"uriTemplate": SCRIPT_TEMPLATE_URI,
			"name": "Script text",
			"description": "Read a .gd or .cs script file by project-relative path.",
			"mimeType": "text/plain"
		}, {
			"uriTemplate": RESOURCE_TEMPLATE_URI,
			"name": "Resource text",
			"description": "Read a .tres or .res resource file by project-relative path.",
			"mimeType": "text/plain"
		}]
	}


func build_resources_read_result(params: Dictionary) -> Dictionary:
	var uri := str(params.get("uri", ""))
	match uri:
		PROJECT_INFO_URI:
			return _build_text_resource(uri, _build_project_info_payload(), "application/json")
		DIAGNOSTICS_SUMMARY_URI:
			return _build_text_resource(uri, _build_diagnostics_summary_payload(), "application/json")
		TOOL_CATALOG_URI:
			return _build_text_resource(uri, _build_tool_catalog_payload(), "application/json")
		_:
			return _read_template_resource(uri)


func build_server_capabilities() -> Dictionary:
	return {
		"tools": {"listChanged": false},
		"resources": {"subscribe": false, "listChanged": false},
		"prompts": {"listChanged": false}
	}


func _build_text_resource(uri: String, payload, mime_type: String) -> Dictionary:
	var text := JSON.stringify(_sanitize(payload)) if mime_type == "application/json" else str(payload)
	return {
		"contents": [{
			"uri": uri,
			"mimeType": mime_type,
			"text": text
		}]
	}


func _build_project_info_payload() -> Dictionary:
	return {
		"protocolVersion": MCPProtocolFacts.get_protocol_version(),
		"toolSchemaVersion": MCPProtocolFacts.get_tool_schema_version(),
		"serverInfo": MCPProtocolFacts.build_server_info(),
		"capabilities": build_server_capabilities(),
		"projectPath": ProjectSettings.globalize_path("res://"),
		"toolLoaderStatus": _get_loader_status_safe()
	}


func _build_diagnostics_summary_payload() -> Dictionary:
	return {
		"selfDiagnostics": PluginSelfDiagnosticStoreScript.get_health_snapshot({}, 3),
		"recentLogs": _redact_sensitive_value(MCPDebugBufferScript.get_recent(20)),
		"toolLoaderStatus": _get_loader_status_safe()
	}


func _build_tool_catalog_payload() -> Dictionary:
	var loader = _get_loader()
	if loader == null:
		return {"tools": [], "presentationVersion": 1, "toolTree": [], "toolGroups": [], "toolLoaderStatus": _get_loader_status_safe()}
	var exposed_tools = loader.get_exposed_tool_definitions()
	var all_tools_by_category := {}
	if loader.has_method("get_all_tools_by_category"):
		all_tools_by_category = loader.get_all_tools_by_category()
	elif loader.has_method("get_tools_by_category"):
		all_tools_by_category = loader.get_tools_by_category()
	var domain_states := []
	if loader.has_method("get_domain_states"):
		domain_states = loader.get_domain_states()
	var presentation = ToolPresentationServiceScript.build_tool_presentation(exposed_tools, all_tools_by_category, domain_states)
	return {
		"tools": ToolPresentationServiceScript.build_mcp_tool_list(exposed_tools, presentation),
		"presentationVersion": int(presentation.get("presentationVersion", 1)),
		"toolTree": presentation.get("toolTree", []),
		"toolGroups": presentation.get("toolGroups", []),
		"toolLoaderStatus": _get_loader_status_safe()
	}


func _read_template_resource(uri: String) -> Dictionary:
	var relative_path := ""
	var allowed_extensions: Array[String] = []
	if uri.begins_with("godot-dotnet-mcp://scene/"):
		relative_path = uri.substr("godot-dotnet-mcp://scene/".length())
		allowed_extensions = [".tscn", ".scn"]
	elif uri.begins_with("godot-dotnet-mcp://script/"):
		relative_path = uri.substr("godot-dotnet-mcp://script/".length())
		allowed_extensions = [".gd", ".cs"]
	elif uri.begins_with("godot-dotnet-mcp://resource/"):
		relative_path = uri.substr("godot-dotnet-mcp://resource/".length())
		allowed_extensions = [".tres", ".res"]
	else:
		return {"success": false, "error": "Unknown resource URI: %s" % uri}
	var res_path_result: Dictionary = MCPPathArgumentNormalizerScript.normalize_project_path(relative_path, allowed_extensions, "resource path")
	if not bool(res_path_result.get("success", false)):
		return {"success": false, "error": str(res_path_result.get("error", "Invalid resource path"))}
	var res_path := str(res_path_result.get("path", ""))
	if not FileAccess.file_exists(res_path):
		return {"success": false, "error": "Resource file not found: %s" % res_path}
	var text := FileAccess.get_file_as_string(res_path)
	return _build_text_resource(uri, text, _mime_type_for_path(res_path))
func _mime_type_for_path(path: String) -> String:
	var lower_path := path.to_lower()
	if lower_path.ends_with(".gd"):
		return "text/x-gdscript"
	if lower_path.ends_with(".cs"):
		return "text/x-csharp"
	if lower_path.ends_with(".tscn") or lower_path.ends_with(".scn"):
		return "text/x-godot-scene"
	if lower_path.ends_with(".tres") or lower_path.ends_with(".res"):
		return "text/x-godot-resource"
	return "text/plain"


func _redact_sensitive_value(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var redacted := {}
			for key in value:
				var key_text := str(key)
				if _is_sensitive_key(key_text):
					redacted[key_text] = REDACTED_VALUE
				else:
					redacted[key_text] = _redact_sensitive_value(value[key])
			return redacted
		TYPE_ARRAY:
			var redacted := []
			for item in value:
				redacted.append(_redact_sensitive_value(item))
			return redacted
		TYPE_STRING, TYPE_STRING_NAME:
			return _redact_sensitive_text(str(value))
		_:
			return value


func _is_sensitive_key(key: String) -> bool:
	var normalized := key.to_lower()
	for marker in SENSITIVE_KEY_PARTS:
		if normalized.find(str(marker)) != -1:
			return true
	return false


func _redact_sensitive_text(text: String) -> String:
	var redacted := text
	for marker in ["token=", "password=", "secret=", "api_key=", "apikey=", "authorization:", "authorization="]:
		redacted = _redact_after_marker(redacted, marker)
	return redacted


func _redact_after_marker(text: String, marker: String) -> String:
	var search_from := 0
	var result := text
	while true:
		var lower_result := result.to_lower()
		var marker_index := lower_result.find(marker, search_from)
		if marker_index == -1:
			return result
		var value_start := marker_index + marker.length()
		while value_start < result.length():
			var start_ch := result.substr(value_start, 1)
			if start_ch != " " and start_ch != "\t":
				break
			value_start += 1
		var value_end := value_start
		while value_end < result.length():
			var ch := result.substr(value_end, 1)
			if ch == "\n" or ch == "\r" or ch == ";" or ch == ",":
				break
			value_end += 1
		result = result.substr(0, value_start) + REDACTED_VALUE + result.substr(value_end)
		search_from = value_start + REDACTED_VALUE.length()
	return result

func _get_loader():
	if _get_tool_loader.is_valid():
		return _get_tool_loader.call()
	return null


func _get_loader_status_safe() -> Dictionary:
	if _get_tool_loader_status.is_valid():
		var status = _get_tool_loader_status.call()
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {}


func _sanitize(value):
	if _sanitize_for_json.is_valid():
		return _sanitize_for_json.call(value)
	return value
