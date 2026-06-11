@tool
extends RefCounted
class_name MCPResourcesService

const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const MCPPathArgumentNormalizerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_path_argument_normalizer.gd")
const ToolPresentationServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_presentation_service.gd")
const ToolCatalogSnapshotServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/tool_catalog_snapshot_service.gd")
const MCPDebugBufferScript = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const PluginSelfDiagnosticStoreScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_self_diagnostic_store.gd")
const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")

const PROJECT_INFO_URI := "godot-dotnet-mcp://project/info"
const DIAGNOSTICS_SUMMARY_URI := "godot-dotnet-mcp://diagnostics/summary"
const TOOL_CATALOG_URI := "godot-dotnet-mcp://tools/catalog"
const GUIDES_INDEX_URI := "godot-dotnet-mcp://guides/index"
const GUIDES_CAPABILITIES_URI := "godot-dotnet-mcp://guides/capabilities"
const GUIDES_UI_AUTOMATION_URI := "godot-dotnet-mcp://guides/ui-automation"
const STATE_PROJECT_SUMMARY_URI := "godot-dotnet-mcp://state/project/summary"
const STATE_EDITOR_URI := "godot-dotnet-mcp://state/editor"
const EDITOR_LOG_OUTPUT_URI := "godot-dotnet-mcp://logs/editor/output"
const EDITOR_LOG_ERRORS_URI := "godot-dotnet-mcp://logs/editor/errors"
const ACTIVITY_STATUS_URI := "godot-dotnet-mcp://activity/status"
const ACTIVITY_RECENT_URI := "godot-dotnet-mcp://activity/recent"
const ACTIVITY_CALL_TEMPLATE_URI := "godot-dotnet-mcp://activity/call/{id}"
const ACTIVITY_CALL_URI_PREFIX := "godot-dotnet-mcp://activity/call/"
const TOOLS_CATALOG_EXPOSED_URI := "godot-dotnet-mcp://tools/catalog/exposed"
const TOOLS_CATALOG_VISIBLE_URI := "godot-dotnet-mcp://tools/catalog/visible"
const SCENE_TEMPLATE_URI := "godot-dotnet-mcp://scene/{path}"
const SCRIPT_TEMPLATE_URI := "godot-dotnet-mcp://script/{path}"
const RESOURCE_TEMPLATE_URI := "godot-dotnet-mcp://resource/{path}"
const REDACTED_VALUE := "[redacted]"
const SENSITIVE_KEY_PARTS := ["token", "password", "secret", "api_key", "apikey", "authorization", "credential", "private_key", "privatekey"]
const SENSITIVE_TEXT_KEYS := [
	"token", "password", "secret",
	"api_key", "apikey", "api-key", "apiKey", "x-api-key", "x.api.key", "xApiKey",
	"authorization", "credential",
	"private_key", "private-key", "privateKey",
	"access_token", "access-token", "accessToken",
	"refresh_token", "refresh-token", "refreshToken",
	"client_secret", "client-secret", "clientSecret"
]
const URL_SCHEME_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-."
const URL_SCHEME_FIRST_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
const MAX_RESOURCE_TEXT_BYTES := 524288
const MAX_BUILTIN_JSON_RESOURCE_TEXT_BYTES := 2097152

var _get_tool_loader := Callable()
var _get_tool_loader_status := Callable()
var _get_tool_activity_registry := Callable()
var _sanitize_for_json := Callable()


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_get_tool_loader = context.get_tool_loader
	_get_tool_loader_status = context.get_tool_loader_status
	_get_tool_activity_registry = context.get_tool_activity_registry
	_sanitize_for_json = context.sanitize_for_json


func dispose() -> void:
	_get_tool_loader = Callable()
	_get_tool_loader_status = Callable()
	_get_tool_activity_registry = Callable()
	_sanitize_for_json = Callable()


func build_resources_list_result(_params: Dictionary = {}) -> Dictionary:
	var result := {
		"resources": [{
			"uri": GUIDES_INDEX_URI,
			"name": _text("mcp_resource_guides_index_name", "Guide index"),
			"description": _text("mcp_resource_guides_index_desc", "Canonical MCP entry map for guides, state, activity, and tool catalog resources."),
			"mimeType": "application/json"
		}, {
			"uri": GUIDES_CAPABILITIES_URI,
			"name": _text("mcp_resource_guides_capabilities_name", "Capability guide"),
			"description": _text("mcp_resource_guides_capabilities_desc", "Protocol facts, MCP capabilities, loader status, and recommended discovery flow."),
			"mimeType": "application/json"
		}, {
			"uri": GUIDES_UI_AUTOMATION_URI,
			"name": _text("mcp_resource_guides_ui_automation_name", "UI automation guide"),
			"description": _text("mcp_resource_guides_ui_automation_desc", "Resource-first guidance for semantic editor UI automation and evidence capture."),
			"mimeType": "application/json"
		}, {
			"uri": STATE_PROJECT_SUMMARY_URI,
			"name": _text("mcp_resource_state_project_summary_name", "Project state summary"),
			"description": _text("mcp_resource_state_project_summary_desc", "Canonical project summary resource replacing project/info for new clients."),
			"mimeType": "application/json"
		}, {
			"uri": STATE_EDITOR_URI,
			"name": _text("mcp_resource_state_editor_name", "Editor state"),
			"description": _text("mcp_resource_state_editor_desc", "Editor-facing readiness, protocol facts, and tool loader state snapshot."),
			"mimeType": "application/json"
		}, {
			"uri": EDITOR_LOG_OUTPUT_URI,
			"name": _text("mcp_resource_editor_log_output_name", "Editor log output"),
			"description": _text("mcp_resource_editor_log_output_desc", "Read recent Godot editor Output panel lines without using a public tool."),
			"mimeType": "application/json"
		}, {
			"uri": EDITOR_LOG_ERRORS_URI,
			"name": _text("mcp_resource_editor_log_errors_name", "Editor log warnings and errors"),
			"description": _text("mcp_resource_editor_log_errors_desc", "Read warning and error entries from the Godot editor Output panel."),
			"mimeType": "application/json"
		}, {
			"uri": ACTIVITY_STATUS_URI,
			"name": _text("mcp_resource_activity_status_name", "Activity status"),
			"description": _text("mcp_resource_activity_status_desc", "Current running tool activity, execution order, and recent failure summaries."),
			"mimeType": "application/json"
		}, {
			"uri": ACTIVITY_RECENT_URI,
			"name": _text("mcp_resource_activity_recent_name", "Recent activity"),
			"description": _text("mcp_resource_activity_recent_desc", "Recent tool activity records for workflow audit and diagnostics."),
			"mimeType": "application/json"
		}, {
			"uri": TOOLS_CATALOG_EXPOSED_URI,
			"name": _text("mcp_resource_tools_catalog_exposed_name", "Exposed tool catalog"),
			"description": _text("mcp_resource_tools_catalog_exposed_desc", "Canonical list of public MCP tools exposed to clients."),
			"mimeType": "application/json"
		}, {
			"uri": TOOLS_CATALOG_VISIBLE_URI,
			"name": _text("mcp_resource_tools_catalog_visible_name", "Visible tool catalog"),
			"description": _text("mcp_resource_tools_catalog_visible_desc", "Canonical visible tool tree, groups, domain states, and loader status."),
			"mimeType": "application/json"
		}, {
			"uri": PROJECT_INFO_URI,
			"name": _text("mcp_resource_project_info_name", "Project info"),
			"description": _text("mcp_resource_project_info_desc", "Current Godot project path, protocol facts, server info, and loader status."),
			"mimeType": "application/json"
		}, {
			"uri": DIAGNOSTICS_SUMMARY_URI,
			"name": _text("mcp_resource_diagnostics_summary_name", "Diagnostics summary"),
			"description": _text("mcp_resource_diagnostics_summary_desc", "Plugin self-diagnostics and recent MCP log records."),
			"mimeType": "application/json"
		}, {
			"uri": TOOL_CATALOG_URI,
			"name": _text("mcp_resource_tool_catalog_name", "Tool catalog"),
			"description": _text("mcp_resource_tool_catalog_desc", "Current MCP tool catalog with grouping metadata served through resources."),
			"mimeType": "application/json"
		}]
	}
	for index in range((result.get("resources", []) as Array).size()):
		var resource := (result["resources"] as Array)[index] as Dictionary
		(result["resources"] as Array)[index] = _with_catalog_metadata(resource, _resource_icon_for_uri(str(resource.get("uri", ""))))
	return result


func build_resource_templates_list_result(_params: Dictionary = {}) -> Dictionary:
	var result := {
		"resourceTemplates": [{
			"uriTemplate": ACTIVITY_CALL_TEMPLATE_URI,
			"name": _text("mcp_resource_template_activity_call_name", "Activity call"),
			"description": _text("mcp_resource_template_activity_call_desc", "Read one running or recent tool activity record by call id."),
			"mimeType": "application/json"
		}, {
			"uriTemplate": SCENE_TEMPLATE_URI,
			"name": _text("mcp_resource_template_scene_name", "Scene text"),
			"description": _text("mcp_resource_template_scene_desc", "Read a .tscn scene file by project-relative path."),
			"mimeType": "text/plain"
		}, {
			"uriTemplate": SCRIPT_TEMPLATE_URI,
			"name": _text("mcp_resource_template_script_name", "Script text"),
			"description": _text("mcp_resource_template_script_desc", "Read a .gd or .cs script file by project-relative path."),
			"mimeType": "text/plain"
		}, {
			"uriTemplate": RESOURCE_TEMPLATE_URI,
			"name": _text("mcp_resource_template_resource_name", "Resource text"),
			"description": _text("mcp_resource_template_resource_desc", "Read a .tres resource file by project-relative path."),
			"mimeType": "text/plain"
		}]
	}
	for index in range((result.get("resourceTemplates", []) as Array).size()):
		var template := (result["resourceTemplates"] as Array)[index] as Dictionary
		(result["resourceTemplates"] as Array)[index] = _with_catalog_metadata(template, _resource_template_icon_for_uri(str(template.get("uriTemplate", ""))))
	return result


func build_resources_read_result(params: Dictionary) -> Dictionary:
	var uri := str(params.get("uri", ""))
	match uri:
		GUIDES_INDEX_URI:
			return _build_text_resource(uri, _build_guides_index_payload(), "application/json")
		GUIDES_CAPABILITIES_URI:
			return _build_text_resource(uri, _build_capabilities_guide_payload(), "application/json")
		GUIDES_UI_AUTOMATION_URI:
			return _build_text_resource(uri, _build_ui_automation_guide_payload(), "application/json")
		STATE_PROJECT_SUMMARY_URI:
			return _build_text_resource(uri, _build_project_info_payload(), "application/json")
		STATE_EDITOR_URI:
			return _build_text_resource(uri, _build_editor_state_payload(), "application/json")
		EDITOR_LOG_OUTPUT_URI:
			return _build_text_resource(uri, _build_editor_log_payload(EDITOR_LOG_OUTPUT_URI, "get_output", {"limit": 200}), "application/json")
		EDITOR_LOG_ERRORS_URI:
			return _build_text_resource(uri, _build_editor_log_payload(EDITOR_LOG_ERRORS_URI, "get_errors", {"limit": 200, "include_warnings": true}), "application/json")
		ACTIVITY_STATUS_URI:
			return _build_text_resource(uri, _build_activity_status_payload(), "application/json")
		ACTIVITY_RECENT_URI:
			return _build_text_resource(uri, _build_activity_recent_payload(), "application/json")
		TOOLS_CATALOG_EXPOSED_URI:
			return _build_text_resource(uri, _build_exposed_tool_catalog_payload(), "application/json")
		TOOLS_CATALOG_VISIBLE_URI:
			return _build_text_resource(uri, _build_tool_catalog_payload(), "application/json")
		PROJECT_INFO_URI:
			return _build_text_resource(uri, _build_project_info_payload(), "application/json")
		DIAGNOSTICS_SUMMARY_URI:
			return _build_text_resource(uri, _build_diagnostics_summary_payload(), "application/json")
		TOOL_CATALOG_URI:
			return _build_text_resource(uri, _build_exposed_tool_catalog_payload(), "application/json")
		_:
			if uri.begins_with(ACTIVITY_CALL_URI_PREFIX):
				return _build_text_resource(uri, _build_activity_call_payload(uri.substr(ACTIVITY_CALL_URI_PREFIX.length())), "application/json")
			return _read_template_resource(uri)


func build_server_capabilities() -> Dictionary:
	return {
		"tools": {"listChanged": false},
		"resources": {"listChanged": false},
		"prompts": {"listChanged": false}
	}


func _build_text_resource(uri: String, payload, mime_type: String) -> Dictionary:
	var text := JSON.stringify(_sanitize(payload)) if mime_type == "application/json" else str(payload)
	var max_text_bytes := MAX_BUILTIN_JSON_RESOURCE_TEXT_BYTES if mime_type == "application/json" else MAX_RESOURCE_TEXT_BYTES
	var limited := _limit_text_output(text, max_text_bytes)
	var returned_text := str(limited.get("text", ""))
	if mime_type == "application/json" and bool(limited.get("truncated", false)):
		returned_text = JSON.stringify({
			"truncated": true,
			"originalByteSize": int(limited.get("original_byte_size", 0)),
			"returnedByteSize": returned_text.to_utf8_buffer().size(),
			"maxByteSize": int(limited.get("max_byte_size", max_text_bytes)),
			"message": "JSON resource output exceeded the byte limit."
		})
	var content := {
		"uri": uri,
		"mimeType": mime_type,
		"text": returned_text
	}
	if bool(limited.get("truncated", false)):
		content["truncated"] = true
		content["originalByteSize"] = int(limited.get("original_byte_size", 0))
		content["returnedByteSize"] = int(limited.get("returned_byte_size", 0))
		content["maxByteSize"] = int(limited.get("max_byte_size", MAX_RESOURCE_TEXT_BYTES))
	return {
		"contents": [content]
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


func _build_guides_index_payload() -> Dictionary:
	return {
		"protocolVersion": MCPProtocolFacts.get_protocol_version(),
		"toolSchemaVersion": MCPProtocolFacts.get_tool_schema_version(),
		"canonicalResources": {
			"guides": [GUIDES_INDEX_URI, GUIDES_CAPABILITIES_URI, GUIDES_UI_AUTOMATION_URI],
			"state": [STATE_PROJECT_SUMMARY_URI, STATE_EDITOR_URI],
			"logs": [EDITOR_LOG_OUTPUT_URI, EDITOR_LOG_ERRORS_URI],
			"activity": [ACTIVITY_STATUS_URI, ACTIVITY_RECENT_URI, ACTIVITY_CALL_TEMPLATE_URI],
			"tools": [TOOLS_CATALOG_EXPOSED_URI, TOOLS_CATALOG_VISIBLE_URI]
		},
		"compatibilityResources": [PROJECT_INFO_URI, DIAGNOSTICS_SUMMARY_URI, TOOL_CATALOG_URI],
		"recommendedFlow": [
			{"step": "capabilities", "resource": GUIDES_CAPABILITIES_URI},
			{"step": "project_state", "resource": STATE_PROJECT_SUMMARY_URI},
			{"step": "tool_catalog", "resource": TOOLS_CATALOG_VISIBLE_URI},
			{"step": "activity_audit", "resource": ACTIVITY_STATUS_URI}
		],
		"notes": [
			"Use resources for context, state, catalogs, and diagnostics.",
			"Use prompts for workflow guidance.",
			"Use tools only for actions and computed workflows."
		]
	}


func _build_capabilities_guide_payload() -> Dictionary:
	return {
		"protocolVersion": MCPProtocolFacts.get_protocol_version(),
		"toolSchemaVersion": MCPProtocolFacts.get_tool_schema_version(),
		"serverInfo": MCPProtocolFacts.build_server_info(),
		"capabilities": build_server_capabilities(),
		"toolLoaderStatus": _get_loader_status_safe(),
		"discovery": {
			"resourceIndex": GUIDES_INDEX_URI,
			"projectState": STATE_PROJECT_SUMMARY_URI,
			"editorState": STATE_EDITOR_URI,
			"editorLogOutput": EDITOR_LOG_OUTPUT_URI,
			"editorLogErrors": EDITOR_LOG_ERRORS_URI,
			"visibleToolCatalog": TOOLS_CATALOG_VISIBLE_URI,
			"exposedToolCatalog": TOOLS_CATALOG_EXPOSED_URI,
			"activityStatus": ACTIVITY_STATUS_URI,
			"activityRecent": ACTIVITY_RECENT_URI
		}
	}


func _build_ui_automation_guide_payload() -> Dictionary:
	return {
		"preferredOrder": [
			{"level": "semantic_workflow", "examples": ["system_settings_dialog", "system_inspector"]},
			{"level": "editor_evidence", "examples": ["system_editor_evidence(action=capture, surface=auto/editor/control/popup/active_dialog)"]},
			{"level": "control_action", "examples": ["system_editor_control(action=activate_ui)", "focus_control", "set_control_text"]},
			{"level": "mouse_fallback", "examples": ["click_control", "hover_control", "Control-local coordinates"]}
		],
		"diagnostics": {
			"editorState": STATE_EDITOR_URI,
			"activityStatus": ACTIVITY_STATUS_URI,
			"toolCatalog": TOOLS_CATALOG_VISIBLE_URI
		},
		"rules": [
			"Prefer semantic editor workflows before low-level UI control.",
			"Capture evidence with surface metadata before using coordinate fallback.",
			"Record fallback reasons when visible control enumeration cannot identify the target."
		]
	}


func _build_editor_state_payload() -> Dictionary:
	return {
		"protocolVersion": MCPProtocolFacts.get_protocol_version(),
		"toolSchemaVersion": MCPProtocolFacts.get_tool_schema_version(),
		"projectPath": ProjectSettings.globalize_path("res://"),
		"toolLoaderStatus": _get_loader_status_safe(),
		"resources": {
			"projectSummary": STATE_PROJECT_SUMMARY_URI,
			"diagnostics": DIAGNOSTICS_SUMMARY_URI,
			"editorLogOutput": EDITOR_LOG_OUTPUT_URI,
			"editorLogErrors": EDITOR_LOG_ERRORS_URI,
			"activityStatus": ACTIVITY_STATUS_URI,
			"toolCatalog": TOOLS_CATALOG_VISIBLE_URI
		}
	}


func _build_diagnostics_summary_payload() -> Dictionary:
	return {
		"selfDiagnostics": PluginSelfDiagnosticStoreScript.get_health_snapshot({}, 3),
		"recentLogs": _redact_sensitive_value(MCPDebugBufferScript.get_recent(20)),
		"editorLogResources": [EDITOR_LOG_OUTPUT_URI, EDITOR_LOG_ERRORS_URI],
		"toolLoaderStatus": _get_loader_status_safe()
	}


func _build_editor_log_payload(resource_uri: String, action: String, args: Dictionary) -> Dictionary:
	var payload := {
		"resourceUri": resource_uri,
		"sourceTool": "debug_editor_log",
		"action": action,
		"available": false,
		"readOnly": true
	}
	var loader = _get_loader()
	if loader == null or not loader.has_method("execute_tool"):
		payload["error"] = "Tool loader is unavailable."
		payload["toolLoaderStatus"] = _get_loader_status_safe()
		return payload
	var result = loader.execute_tool("debug", "editor_log", args)
	if not (result is Dictionary):
		payload["error"] = "Editor log reader returned an invalid response."
		return payload
	var result_dict := result as Dictionary
	if not bool(result_dict.get("success", false)):
		payload["error"] = str(result_dict.get("error", result_dict.get("message", "Editor log reader failed.")))
		payload["details"] = result_dict.get("data", {})
		return payload
	payload["available"] = true
	var data = result_dict.get("data", {})
	if data is Dictionary:
		for key in (data as Dictionary).keys():
			payload[str(key)] = _redact_sensitive_value((data as Dictionary)[key])
	else:
		payload["data"] = _redact_sensitive_value(data)
	payload["toolLoaderStatus"] = _get_loader_status_safe()
	return payload


func _build_activity_status_payload() -> Dictionary:
	var registry = _get_activity_registry()
	if registry != null and registry.has_method("get_status"):
		return registry.get_status()
	return _empty_activity_status()


func _build_activity_recent_payload() -> Dictionary:
	var registry = _get_activity_registry()
	if registry != null and registry.has_method("get_recent"):
		return registry.get_recent(20)
	return _empty_activity_recent()


func _build_activity_call_payload(call_id: String) -> Dictionary:
	var normalized_call_id := call_id.strip_edges()
	if normalized_call_id.is_empty():
		return {"found": false, "call_id": normalized_call_id, "error": "Missing activity call id."}
	var registry = _get_activity_registry()
	if registry != null and registry.has_method("get_call"):
		return registry.get_call(normalized_call_id)
	return {"found": false, "call_id": normalized_call_id}


func _empty_activity_status() -> Dictionary:
	return {
		"running_count": 0,
		"recent_count": 0,
		"filtered_running_count": 0,
		"filtered_recent_count": 0,
		"running": [],
		"recent": [],
		"execution_order": [],
		"max_recent": 0,
		"filters": {},
		"slow_threshold_ms": 0.0,
		"slow_running": [],
		"recent_failures": []
	}


func _empty_activity_recent() -> Dictionary:
	return {
		"recent": [],
		"recent_count": 0,
		"filtered_recent_count": 0,
		"max_recent": 0,
		"filters": {},
		"slow_threshold_ms": 0.0,
		"slow_recent": [],
		"recent_failures": []
	}


func _build_tool_catalog_payload() -> Dictionary:
	var loader = _get_loader()
	if loader == null:
		return {"tools": [], "domain_states": [], "presentationVersion": 1, "toolTree": [], "toolGroups": [], "toolLoaderStatus": _get_loader_status_safe()}
	var snapshot: Dictionary = ToolCatalogSnapshotServiceScript.build_snapshot(loader)
	if not bool(snapshot.get("success", false)):
		return {"tools": [], "domain_states": [], "presentationVersion": 1, "toolTree": [], "toolGroups": [], "toolLoaderStatus": _get_loader_status_safe()}
	var exposed_tools: Array = snapshot.get("exposed_tools", [])
	var category_states: Array = snapshot.get("category_states", [])
	var presentation: Dictionary = snapshot.get("presentation", {})
	var loader_status: Dictionary = snapshot.get("tool_loader_status", {})
	if loader_status.is_empty():
		loader_status = _get_loader_status_safe()
	var public_catalog_manifest := ToolCatalogSnapshotServiceScript.build_public_catalog_manifest(snapshot.get("catalog_manifest", {}))
	return {
		"tools": ToolPresentationServiceScript.build_mcp_tool_list(exposed_tools, presentation),
		"domain_states": category_states,
		"presentationVersion": int(presentation.get("presentationVersion", 1)),
		"toolTree": presentation.get("toolTree", []),
		"toolGroups": presentation.get("toolGroups", []),
		"toolLoaderStatus": loader_status,
		"catalogManifest": public_catalog_manifest
	}


func _build_exposed_tool_catalog_payload() -> Dictionary:
	var catalog := _build_tool_catalog_payload()
	return {
		"tools": catalog.get("tools", []),
		"presentationVersion": int(catalog.get("presentationVersion", 1)),
		"toolLoaderStatus": catalog.get("toolLoaderStatus", _get_loader_status_safe())
	}


func _read_template_resource(uri: String) -> Dictionary:
	var relative_path := ""
	var allowed_extensions: Array[String] = []
	if uri.begins_with("godot-dotnet-mcp://scene/"):
		relative_path = uri.substr("godot-dotnet-mcp://scene/".length())
		allowed_extensions = [".tscn"]
	elif uri.begins_with("godot-dotnet-mcp://script/"):
		relative_path = uri.substr("godot-dotnet-mcp://script/".length())
		allowed_extensions = [".gd", ".cs"]
	elif uri.begins_with("godot-dotnet-mcp://resource/"):
		relative_path = uri.substr("godot-dotnet-mcp://resource/".length())
		allowed_extensions = [".tres"]
	else:
		return {"success": false, "error": "Unknown resource URI: %s" % uri}
	var res_path_result: Dictionary = MCPPathArgumentNormalizerScript.normalize_project_path(relative_path, allowed_extensions, "resource path")
	if not bool(res_path_result.get("success", false)):
		return {"success": false, "error": str(res_path_result.get("error", "Invalid resource path"))}
	var res_path := str(res_path_result.get("path", ""))
	if not FileAccess.file_exists(res_path):
		return {"success": false, "error": "Resource file not found: %s" % res_path}
	var file := FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		return {"success": false, "error": "Resource file could not be opened: %s" % res_path}
	var file_size := file.get_length()
	file.close()
	if file_size > MAX_RESOURCE_TEXT_BYTES:
		return {
			"success": false,
			"error": "Resource output exceeds the %d byte limit: %s (%d bytes)" % [MAX_RESOURCE_TEXT_BYTES, res_path, file_size],
			"maxByteSize": MAX_RESOURCE_TEXT_BYTES,
			"originalByteSize": file_size
		}
	var text := FileAccess.get_file_as_string(res_path)
	return _build_text_resource(uri, text, _mime_type_for_path(res_path))
func _mime_type_for_path(path: String) -> String:
	var lower_path := path.to_lower()
	if lower_path.ends_with(".gd"):
		return "text/x-gdscript"
	if lower_path.ends_with(".cs"):
		return "text/x-csharp"
	if lower_path.ends_with(".tscn"):
		return "text/x-godot-scene"
	if lower_path.ends_with(".tres"):
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
	var normalized := key.to_lower().replace("-", "_").replace(".", "_").replace(" ", "_")
	for marker in SENSITIVE_KEY_PARTS:
		if normalized.find(str(marker)) != -1:
			return true
	return false


func _redact_sensitive_text(text: String) -> String:
	var redacted := _redact_url_credentials(text)
	redacted = _redact_after_marker(redacted, "bearer ", true)
	for key in SENSITIVE_TEXT_KEYS:
		redacted = _redact_after_key_delimiter(redacted, str(key))
	return redacted


func _redact_after_marker(text: String, marker: String, stop_on_space: bool = false) -> String:
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
			if start_ch != " " and start_ch != "\t" and start_ch != "\"" and start_ch != "'":
				break
			value_start += 1
		var value_end := value_start
		while value_end < result.length():
			var ch := result.substr(value_end, 1)
			if ch == "\n" or ch == "\r" or ch == ";" or ch == "," or ch == "&" or ch == "\"" or ch == "'" or (stop_on_space and (ch == " " or ch == "\t")):
				break
			value_end += 1
		result = result.substr(0, value_start) + REDACTED_VALUE + result.substr(value_end)
		search_from = value_start + REDACTED_VALUE.length()
	return result


func _redact_after_key_delimiter(text: String, key: String) -> String:
	var search_from := 0
	var result := text
	var lower_key := key.to_lower()
	while true:
		var lower_result := result.to_lower()
		var key_index := lower_result.find(lower_key, search_from)
		if key_index == -1:
			return result
		if not _is_sensitive_text_key_match(result, key_index, key.length()):
			search_from = key_index + key.length()
			continue
		var delimiter_index := key_index + key.length()
		while delimiter_index < result.length():
			var delimiter_ch := result.substr(delimiter_index, 1)
			if delimiter_ch != " " and delimiter_ch != "\t" and delimiter_ch != "\"" and delimiter_ch != "'":
				break
			delimiter_index += 1
		if delimiter_index >= result.length():
			return result
		var delimiter := result.substr(delimiter_index, 1)
		if delimiter != ":" and delimiter != "=":
			search_from = key_index + key.length()
			continue
		var value_start := delimiter_index + 1
		while value_start < result.length():
			var start_ch := result.substr(value_start, 1)
			if start_ch != " " and start_ch != "\t" and start_ch != "\"" and start_ch != "'":
				break
			value_start += 1
		var value_end := value_start
		while value_end < result.length():
			var ch := result.substr(value_end, 1)
			if ch == "\n" or ch == "\r" or ch == ";" or ch == "," or ch == "&" or ch == "\"" or ch == "'":
				break
			value_end += 1
		result = result.substr(0, value_start) + REDACTED_VALUE + result.substr(value_end)
		search_from = value_start + REDACTED_VALUE.length()
	return result


func _is_sensitive_text_key_match(text: String, key_index: int, key_length: int) -> bool:
	if key_index > 0 and _is_key_token_char(text.substr(key_index - 1, 1)):
		return false
	var after_index := key_index + key_length
	if after_index < text.length() and _is_key_token_char(text.substr(after_index, 1)):
		return false
	return true


func _is_key_token_char(ch: String) -> bool:
	return not ch.is_empty() and URL_SCHEME_CHARS.find(ch) != -1


func _redact_url_credentials(text: String) -> String:
	var result := text
	var search_from := 0
	while true:
		var scheme_index := _find_next_url_scheme(result, search_from)
		if scheme_index == -1:
			return result
		var scheme_sep := result.find("://", scheme_index)
		if scheme_sep == -1:
			return result
		var authority_start := scheme_sep + 3
		var authority_end := _find_url_authority_end(result, authority_start)
		var authority := result.substr(authority_start, authority_end - authority_start)
		var at_index := authority.rfind("@")
		if at_index == -1:
			search_from = authority_end
			continue
		var replacement := REDACTED_VALUE + "@"
		result = result.substr(0, authority_start) + replacement + authority.substr(at_index + 1) + result.substr(authority_end)
		search_from = authority_start + replacement.length()
	return result


func _find_next_url_scheme(text: String, from_index: int) -> int:
	var sep_index := text.find("://", from_index)
	while sep_index != -1:
		var scheme_start := sep_index - 1
		while scheme_start >= 0 and _is_url_scheme_char(text.substr(scheme_start, 1)):
			scheme_start -= 1
		scheme_start += 1
		if scheme_start < sep_index and _is_url_scheme_first_char(text.substr(scheme_start, 1)):
			return scheme_start
		sep_index = text.find("://", sep_index + 3)
	return -1


func _is_url_scheme_char(ch: String) -> bool:
	return not ch.is_empty() and URL_SCHEME_CHARS.find(ch) != -1


func _is_url_scheme_first_char(ch: String) -> bool:
	return not ch.is_empty() and URL_SCHEME_FIRST_CHARS.find(ch) != -1


func _find_url_authority_end(text: String, from_index: int) -> int:
	var index := from_index
	while index < text.length():
		var ch := text.substr(index, 1)
		if ch == "/" or ch == "?" or ch == "#" or ch == " " or ch == "\t" or ch == "\n" or ch == "\r":
			return index
		index += 1
	return text.length()

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


func _get_activity_registry():
	if _get_tool_activity_registry.is_valid():
		return _get_tool_activity_registry.call()
	return null


func _sanitize(value):
	if _sanitize_for_json.is_valid():
		return _sanitize_for_json.call(value)
	return value


func _text(key: String, fallback: String) -> String:
	var localization = LocalizationServiceScript.get_instance()
	var text := str(localization.get_text(key)) if localization != null else key
	if text == key or text.is_empty():
		return fallback
	return text


func _with_catalog_metadata(entry: Dictionary, icon_name: String) -> Dictionary:
	var metadata := entry.duplicate(true)
	var name := str(metadata.get("name", ""))
	if not name.is_empty():
		metadata["title"] = name
	metadata["icons"] = [_icon_metadata(icon_name)]
	return metadata


func _icon_metadata(name: String) -> Dictionary:
	return {
		"src": _icon_data_uri(name),
		"mimeType": "image/svg+xml",
		"sizes": ["any"]
	}


func _icon_data_uri(name: String) -> String:
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 16 16\"><title>%s</title><rect x=\"2\" y=\"2\" width=\"12\" height=\"12\" rx=\"2\" fill=\"currentColor\"/></svg>" % name.xml_escape()
	return "data:image/svg+xml;base64,%s" % Marshalls.raw_to_base64(svg.to_utf8_buffer())


func _resource_icon_for_uri(uri: String) -> String:
	match uri:
		GUIDES_INDEX_URI:
			return "book-open"
		GUIDES_CAPABILITIES_URI:
			return "list-checks"
		GUIDES_UI_AUTOMATION_URI:
			return "mouse-pointer-click"
		STATE_PROJECT_SUMMARY_URI:
			return "folder-kanban"
		STATE_EDITOR_URI:
			return "panel-top"
		EDITOR_LOG_OUTPUT_URI:
			return "scroll-text"
		EDITOR_LOG_ERRORS_URI:
			return "triangle-alert"
		ACTIVITY_STATUS_URI:
			return "activity"
		ACTIVITY_RECENT_URI:
			return "history"
		TOOLS_CATALOG_EXPOSED_URI:
			return "wrench"
		TOOLS_CATALOG_VISIBLE_URI:
			return "layout-list"
		PROJECT_INFO_URI:
			return "info"
		DIAGNOSTICS_SUMMARY_URI:
			return "stethoscope"
		TOOL_CATALOG_URI:
			return "boxes"
		_:
			return "file"


func _resource_template_icon_for_uri(uri_template: String) -> String:
	match uri_template:
		ACTIVITY_CALL_TEMPLATE_URI:
			return "activity"
		SCENE_TEMPLATE_URI:
			return "panel-top"
		SCRIPT_TEMPLATE_URI:
			return "file-code"
		RESOURCE_TEMPLATE_URI:
			return "file-json"
		_:
			return "file"


func _limit_text_output(text: String, max_byte_size: int) -> Dictionary:
	var original_byte_size := text.to_utf8_buffer().size()
	if original_byte_size <= max_byte_size:
		return {
			"text": text,
			"truncated": false,
			"original_byte_size": original_byte_size,
			"returned_byte_size": original_byte_size,
			"max_byte_size": max_byte_size
		}
	var limited_text := _truncate_text_to_utf8_byte_limit(text, max_byte_size)
	return {
		"text": limited_text,
		"truncated": true,
		"original_byte_size": original_byte_size,
		"returned_byte_size": limited_text.to_utf8_buffer().size(),
		"max_byte_size": max_byte_size
	}


func _truncate_text_to_utf8_byte_limit(text: String, max_byte_size: int) -> String:
	var low := 0
	var high := text.length()
	while low < high:
		var mid := int(ceil(float(low + high + 1) / 2.0))
		if text.substr(0, mid).to_utf8_buffer().size() <= max_byte_size:
			low = mid
		else:
			high = mid - 1
	return text.substr(0, low)
