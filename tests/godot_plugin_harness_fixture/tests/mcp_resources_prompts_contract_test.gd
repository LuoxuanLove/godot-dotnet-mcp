extends RefCounted

# {"name": "mcp_resources_prompts_contracts"}

const HttpServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")
const ProtocolFactsScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const JsonRpcMethodServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_json_rpc_method_service.gd")
const MCPDebugBufferScript = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")
const ToolActivityRegistryScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_tool_activity_registry.gd")

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
const ACTIVITY_MISSING_CALL_URI := "godot-dotnet-mcp://activity/call/tool-contract-missing"
const TOOLS_CATALOG_EXPOSED_URI := "godot-dotnet-mcp://tools/catalog/exposed"
const TOOLS_CATALOG_VISIBLE_URI := "godot-dotnet-mcp://tools/catalog/visible"
const SCENE_READ_URI := "godot-dotnet-mcp://scene/tests/headless_suite_entry.tscn"
const SCRIPT_READ_URI := "godot-dotnet-mcp://script/tests/headless_case_support.gd"
const RESOURCE_READ_URI := "godot-dotnet-mcp://resource/tests/_fixtures/mcp_resources_prompts_sample.tres"
const TRAVERSAL_URI := "godot-dotnet-mcp://script/../project.godot"
const PROJECT_ORIENTATION_PROMPT := "godot.project_orientation"
const CONTENT_AUTHORING_PROMPT := "godot.content_authoring"
const DEBUG_TRIAGE_PROMPT := "godot.debug_triage"
const REFERENCE_INTEGRITY_PROMPT := "godot.reference_integrity"
const RUNTIME_VALIDATION_PROMPT := "godot.runtime_validation"
const EDITOR_UI_CONTROL_PROMPT := "godot.editor_ui_control"
const JSON_SCHEMA_2020_12_URI := "https://json-schema.org/draft/2020-12/schema"

var _server = null
var _temp_paths: Array[String] = []
var _previous_language := ""


class FakeStdioToolLoader extends RefCounted:
	var _tool_activity_registry = null

	func set_tool_activity_registry(registry) -> void:
		_tool_activity_registry = registry

	func get_tool_activity_registry():
		return _tool_activity_registry

	func get_tool_definitions() -> Array[Dictionary]:
		return [{
			"name": "system_project_state",
			"category": "system"
		}]

	func get_exposed_tool_definitions() -> Array[Dictionary]:
		return get_tool_definitions()

	func get_domain_states() -> Array:
		return [{"category": "system", "status": "ready"}]

	func is_tool_exposed(_tool_name: String) -> bool:
		return true

	func execute_tool_async(category: String, tool_name: String, args: Dictionary) -> Dictionary:
		var call_id := ""
		if _tool_activity_registry != null:
			var record: Dictionary = _tool_activity_registry.begin_call("%s_%s" % [category, tool_name], category, tool_name, args)
			call_id = str(record.get("call_id", ""))
		if _tool_activity_registry != null and not call_id.is_empty():
			_tool_activity_registry.finish_call(call_id, true)
		return {"success": true, "data": {"summary": true}}


func run_case(_tree: SceneTree) -> Dictionary:
	var localization = LocalizationServiceScript.get_instance()
	if localization != null:
		_previous_language = localization.get_language()
		localization.set_language("zh_CN")
	_server = HttpServerScript.new()
	_server.initialize(0, "127.0.0.1", false)

	var initialize_response: Dictionary = await _json_rpc("initialize", {}, 1)
	var initialize_result = initialize_response.get("result", {})
	if not (initialize_result is Dictionary):
		return _failure("initialize should return a result object.")
	if str((initialize_result as Dictionary).get("protocolVersion", "")) != "2025-11-25":
		return _failure("initialize should advertise the MCP 2025-11-25 protocol version.")
	var server_info = (initialize_result as Dictionary).get("serverInfo", {})
	if not (server_info is Dictionary):
		return _failure("initialize should expose serverInfo as an object.")
	if str((server_info as Dictionary).get("name", "")) != ProtocolFactsScript.get_server_name():
		return _failure("initialize serverInfo should include the protocol facts server name.")
	if str((server_info as Dictionary).get("description", "")) != ProtocolFactsScript.get_server_description():
		return _failure("initialize serverInfo should include the protocol facts server description.")
	var capabilities = (initialize_result as Dictionary).get("capabilities", {})
	var capability_failure := _validate_initialize_capabilities(capabilities, "initialize")
	if not capability_failure.is_empty():
		return _failure(capability_failure)
	var fallback_method_service = JsonRpcMethodServiceScript.new()
	var fallback_initialize := fallback_method_service.handle_initialize({}, 99)
	var fallback_result = fallback_initialize.get("result", {})
	if not (fallback_result is Dictionary):
		return _failure("fallback initialize should return a result object.")
	capability_failure = _validate_initialize_capabilities((fallback_result as Dictionary).get("capabilities", {}), "fallback initialize")
	if not capability_failure.is_empty():
		return _failure(capability_failure)

	var resources_response: Dictionary = await _json_rpc("resources/list", {}, 2)
	var resources_result = resources_response.get("result", {})
	if not (resources_result is Dictionary):
		return _failure("resources/list should return a result object.")
	var resources = (resources_result as Dictionary).get("resources", [])
	if not (resources is Array) or (resources as Array).is_empty():
		return _failure("resources/list should return built-in resources.")
	if not _has_resource(resources, PROJECT_INFO_URI):
		return _failure("resources/list should expose the project info resource.")
	if not _has_resource(resources, DIAGNOSTICS_SUMMARY_URI):
		return _failure("resources/list should expose the diagnostics summary resource.")
	if not _has_resource(resources, TOOL_CATALOG_URI):
		return _failure("resources/list should expose the tool catalog resource.")
	for expected_resource in [
		GUIDES_INDEX_URI,
		GUIDES_CAPABILITIES_URI,
		GUIDES_UI_AUTOMATION_URI,
		STATE_PROJECT_SUMMARY_URI,
		STATE_EDITOR_URI,
		EDITOR_LOG_OUTPUT_URI,
		EDITOR_LOG_ERRORS_URI,
		ACTIVITY_STATUS_URI,
		ACTIVITY_RECENT_URI,
		TOOLS_CATALOG_EXPOSED_URI,
		TOOLS_CATALOG_VISIBLE_URI
	]:
		if not _has_resource(resources, expected_resource):
			return _failure("resources/list should expose canonical MCP resource: %s" % expected_resource)
	for resource in resources as Array:
		if not _has_display_metadata(resource):
			return _failure("resources/list should expose 2025-11-25 title/icons metadata for every resource.")
		if not _has_meta_kind(resource, "resourceKind"):
			return _failure("resources/list should keep Dock resource classification in _meta.resourceKind.")
		if not _has_meta_kind(resource, "resourceGroup"):
			return _failure("resources/list should keep Dock resource grouping in _meta.resourceGroup.")
		if (resource as Dictionary).has("resourceKind"):
			return _failure("resources/list should not expose Dock resource classification as a top-level protocol field.")
		if (resource as Dictionary).has("resourceGroup"):
			return _failure("resources/list should not expose Dock resource grouping as a top-level protocol field.")
	var project_info_metadata := _find_resource(resources, PROJECT_INFO_URI)
	if str(project_info_metadata.get("name", "")) != "项目信息":
		return _failure("resources/list should localize resource metadata through the active locale.")
	if str(project_info_metadata.get("title", "")) != str(project_info_metadata.get("name", "")):
		return _failure("resources/list should mirror localized resource names into title metadata.")
	if str(project_info_metadata.get("description", "")).find("工具加载器状态") == -1:
		return _failure("resources/list should localize resource descriptions through the active locale.")

	var templates_response: Dictionary = await _json_rpc("resources/templates/list", {}, 3)
	var templates_result = templates_response.get("result", {})
	if not (templates_result is Dictionary):
		return _failure("resources/templates/list should return a result object.")
	var templates = (templates_result as Dictionary).get("resourceTemplates", [])
	if not (templates is Array):
		return _failure("resources/templates/list should return resourceTemplates as an array.")
	for expected_template in [ACTIVITY_CALL_TEMPLATE_URI, "godot-dotnet-mcp://scene/{path}", "godot-dotnet-mcp://script/{path}", "godot-dotnet-mcp://resource/{path}"]:
		if not _has_template(templates, expected_template):
			return _failure("resources/templates/list should expose template: %s" % expected_template)
	for template in templates as Array:
		if not _has_display_metadata(template):
			return _failure("resources/templates/list should expose 2025-11-25 title/icons metadata for every template.")
		if not _has_meta_kind(template, "resourceKind"):
			return _failure("resources/templates/list should keep Dock template classification in _meta.resourceKind.")
		if not _has_meta_kind(template, "resourceGroup"):
			return _failure("resources/templates/list should keep Dock template grouping in _meta.resourceGroup.")
		if (template as Dictionary).has("resourceKind"):
			return _failure("resources/templates/list should not expose Dock template classification as a top-level protocol field.")
		if (template as Dictionary).has("resourceGroup"):
			return _failure("resources/templates/list should not expose Dock template grouping as a top-level protocol field.")
	var scene_template_metadata := _find_template(templates, "godot-dotnet-mcp://scene/{path}")
	if str(scene_template_metadata.get("name", "")) != "场景文本":
		return _failure("resources/templates/list should localize template names through the active locale.")
	if str(scene_template_metadata.get("title", "")) != str(scene_template_metadata.get("name", "")):
		return _failure("resources/templates/list should mirror localized template names into title metadata.")
	var activity_template_metadata := _find_template(templates, ACTIVITY_CALL_TEMPLATE_URI)
	if str(activity_template_metadata.get("name", "")) != "活动调用":
		return _failure("resources/templates/list should localize canonical activity call template names.")

	var project_info := await _read_json_resource(PROJECT_INFO_URI, 4)
	if not bool(project_info.get("ok", false)):
		return _failure(str(project_info.get("error", "project info resource failed")))
	var project_payload: Dictionary = project_info.get("payload", {})
	if str(project_payload.get("protocolVersion", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("project info resource should include the current protocol version.")
	if str(project_payload.get("projectPath", "")).is_empty():
		return _failure("project info resource should include the project path.")

	var guide_index := await _read_json_resource(GUIDES_INDEX_URI, 23)
	if not bool(guide_index.get("ok", false)):
		return _failure(str(guide_index.get("error", "guide index resource failed")))
	var guide_index_payload: Dictionary = guide_index.get("payload", {})
	var canonical_resources = guide_index_payload.get("canonicalResources", {})
	if not (canonical_resources is Dictionary) or not ((canonical_resources as Dictionary).get("state", []) as Array).has(STATE_PROJECT_SUMMARY_URI):
		return _failure("guide index resource should map canonical state resources.")
	var compatibility_resources = guide_index_payload.get("compatibilityResources", [])
	if not (compatibility_resources is Array) or not (compatibility_resources as Array).has(PROJECT_INFO_URI):
		return _failure("guide index resource should keep compatibility resource mapping.")

	var capabilities_guide := await _read_json_resource(GUIDES_CAPABILITIES_URI, 24)
	if not bool(capabilities_guide.get("ok", false)):
		return _failure(str(capabilities_guide.get("error", "capability guide resource failed")))
	var capabilities_payload: Dictionary = capabilities_guide.get("payload", {})
	if str(capabilities_payload.get("protocolVersion", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("capability guide should include the current protocol version.")
	if str((capabilities_payload.get("discovery", {}) as Dictionary).get("visibleToolCatalog", "")) != TOOLS_CATALOG_VISIBLE_URI:
		return _failure("capability guide should direct clients to the canonical visible tool catalog.")

	var ui_automation_guide := await _read_json_resource(GUIDES_UI_AUTOMATION_URI, 25)
	if not bool(ui_automation_guide.get("ok", false)):
		return _failure(str(ui_automation_guide.get("error", "UI automation guide resource failed")))
	var ui_payload: Dictionary = ui_automation_guide.get("payload", {})
	var preferred_order = ui_payload.get("preferredOrder", [])
	if not (preferred_order is Array) or JSON.stringify(preferred_order).find("semantic_workflow") == -1 or JSON.stringify(preferred_order).find("mouse_fallback") == -1:
		return _failure("UI automation guide should describe semantic-first and fallback order.")

	var project_summary := await _read_json_resource(STATE_PROJECT_SUMMARY_URI, 26)
	if not bool(project_summary.get("ok", false)):
		return _failure(str(project_summary.get("error", "project summary resource failed")))
	var project_summary_payload: Dictionary = project_summary.get("payload", {})
	if str(project_summary_payload.get("projectPath", "")) != str(project_payload.get("projectPath", "")):
		return _failure("canonical project summary should preserve the legacy project info payload.")

	var editor_state := await _read_json_resource(STATE_EDITOR_URI, 27)
	if not bool(editor_state.get("ok", false)):
		return _failure(str(editor_state.get("error", "editor state resource failed")))
	var editor_state_payload: Dictionary = editor_state.get("payload", {})
	if not (editor_state_payload.get("resources", {}) is Dictionary):
		return _failure("editor state resource should include resource pointers.")
	var editor_state_resources: Dictionary = editor_state_payload.get("resources", {})
	if str(editor_state_resources.get("editorLogOutput", "")) != EDITOR_LOG_OUTPUT_URI or str(editor_state_resources.get("editorLogErrors", "")) != EDITOR_LOG_ERRORS_URI:
		return _failure("editor state resource should point clients to canonical editor log resources.")

	var editor_log_output := await _read_json_resource(EDITOR_LOG_OUTPUT_URI, 33)
	if not bool(editor_log_output.get("ok", false)):
		return _failure(str(editor_log_output.get("error", "editor log output resource failed")))
	var editor_log_output_payload: Dictionary = editor_log_output.get("payload", {})
	if str(editor_log_output_payload.get("resourceUri", "")) != EDITOR_LOG_OUTPUT_URI or str(editor_log_output_payload.get("action", "")) != "get_output":
		return _failure("editor log output resource should read Output lines with get_output.")
	if not bool(editor_log_output_payload.get("readOnly", false)) or JSON.stringify(editor_log_output_payload).find("clear_output") != -1:
		return _failure("editor log output resource should be read-only and avoid clear_output guidance.")

	var editor_log_errors := await _read_json_resource(EDITOR_LOG_ERRORS_URI, 34)
	if not bool(editor_log_errors.get("ok", false)):
		return _failure(str(editor_log_errors.get("error", "editor log errors resource failed")))
	var editor_log_errors_payload: Dictionary = editor_log_errors.get("payload", {})
	if str(editor_log_errors_payload.get("resourceUri", "")) != EDITOR_LOG_ERRORS_URI or str(editor_log_errors_payload.get("action", "")) != "get_errors":
		return _failure("editor log errors resource should read warning/error entries with get_errors.")
	if not bool(editor_log_errors_payload.get("readOnly", false)):
		return _failure("editor log errors resource should be read-only.")

	MCPDebugBufferScript.clear()
	MCPDebugBufferScript.record("warning", "contract", "token=super-secret-value Authorization: Bearer top-secret-bearer", "", {"password": "hunter2", "safe": "visible"})
	MCPDebugBufferScript.record("warning", "contract", "https://agent:super-url-secret@example.test/path", "", {})
	MCPDebugBufferScript.record("warning", "contract", "HTTPS://agent:upper-url-secret@example.test/path", "", {})
	MCPDebugBufferScript.record("warning", "contract", "ws://agent:ws-url-secret@example.test/socket", "", {})
	MCPDebugBufferScript.record("warning", "contract", "postgres://agent:postgres-url-secret@db.example/app", "", {})
	MCPDebugBufferScript.record("warning", "contract", "redis://:redis-url-secret@cache.example/0", "", {})
	MCPDebugBufferScript.record("warning", "contract", "postgres://agent:comma,url-secret@db.example/app", "", {})
	MCPDebugBufferScript.record("warning", "contract", "https://agent:semicolon;url-secret@example.test/path", "", {})
	MCPDebugBufferScript.record("warning", "contract", "bearer loose-bearer-secret", "", {})
	MCPDebugBufferScript.record("warning", "contract", "x-api-key : header-secret", "", {})
	MCPDebugBufferScript.record("warning", "contract", "api-key = hyphen-secret", "", {})
	MCPDebugBufferScript.record("warning", "contract", "{\"access-token\" : \"json-secret\"}", "", {})
	MCPDebugBufferScript.record("warning", "contract", "{accessToken:camel-access-secret}", "", {})
	MCPDebugBufferScript.record("warning", "contract", "refreshToken = camel-refresh-secret", "", {})
	MCPDebugBufferScript.record("warning", "contract", "apiKey=camel-api-secret", "", {})
	MCPDebugBufferScript.record("warning", "contract", "privateKey : camel-private-secret", "", {})
	MCPDebugBufferScript.record("warning", "contract", "clientSecret=camel-client-secret", "", {})
	MCPDebugBufferScript.record(
		"warning",
		"contract",
		"safe metadata record",
		"",
		{
			"api-key": "metadata-secret",
			"x.api.key": "dot-key-secret",
			"privateKey": "metadata-private-key-secret",
			"nested": {"refresh-token": "refresh-secret"},
			"safe": "still-visible"
		}
	)
	var diagnostics := await _read_json_resource(DIAGNOSTICS_SUMMARY_URI, 5)
	if not bool(diagnostics.get("ok", false)):
		return _failure(str(diagnostics.get("error", "diagnostics resource failed")))
	var diagnostics_payload: Dictionary = diagnostics.get("payload", {})
	if not (diagnostics_payload.get("selfDiagnostics", {}) is Dictionary):
		return _failure("diagnostics summary resource should include selfDiagnostics.")
	if not (diagnostics_payload.get("recentLogs", []) is Array):
		return _failure("diagnostics summary resource should include recentLogs.")
	var diagnostics_text := JSON.stringify(diagnostics_payload.get("recentLogs", []))
	if diagnostics_text.contains("super-secret-value") or diagnostics_text.contains("hunter2") or diagnostics_text.contains("top-secret-bearer"):
		return _failure("diagnostics summary resource should redact sensitive log content.")
	for leaked_secret in ["super-url-secret", "upper-url-secret", "ws-url-secret", "postgres-url-secret", "redis-url-secret", "comma,url-secret", "semicolon;url-secret", "loose-bearer-secret", "header-secret", "hyphen-secret", "json-secret", "camel-access-secret", "camel-refresh-secret", "camel-api-secret", "camel-private-secret", "camel-client-secret", "metadata-secret", "dot-key-secret", "metadata-private-key-secret", "refresh-secret"]:
		if diagnostics_text.contains(leaked_secret):
			return _failure("diagnostics summary resource should redact extended sensitive pattern: %s." % leaked_secret)
	if not diagnostics_text.contains("visible") or not diagnostics_text.contains("still-visible") or not diagnostics_text.contains("[redacted]"):
		return _failure("diagnostics summary resource should preserve safe log metadata while redacting sensitive fields.")

	var tool_catalog := await _read_json_resource(TOOL_CATALOG_URI, 15)
	if not bool(tool_catalog.get("ok", false)):
		return _failure(str(tool_catalog.get("error", "tool catalog resource failed")))
	var tool_catalog_payload: Dictionary = tool_catalog.get("payload", {})
	if not (tool_catalog_payload.get("tools", []) is Array):
		return _failure("tool catalog resource should include the MCP tools array.")
	var tool_catalog_schema_error := _first_tool_json_schema_2020_12_error(tool_catalog_payload.get("tools", []))
	if not tool_catalog_schema_error.is_empty():
		return _failure("tool catalog resource should advertise JSON Schema 2020-12 on tool schemas: %s" % tool_catalog_schema_error)
	for removed_tool_name in ["system_help", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze"]:
		if _contains_tool_name_recursive(tool_catalog_payload, removed_tool_name):
			return _failure("tool catalog resource should not expose removed public tool %s." % removed_tool_name)

	var exposed_tool_catalog := await _read_json_resource(TOOLS_CATALOG_EXPOSED_URI, 28)
	if not bool(exposed_tool_catalog.get("ok", false)):
		return _failure(str(exposed_tool_catalog.get("error", "exposed tool catalog resource failed")))
	var exposed_tool_catalog_payload: Dictionary = exposed_tool_catalog.get("payload", {})
	if not (exposed_tool_catalog_payload.get("tools", []) is Array) or exposed_tool_catalog_payload.has("toolTree") or exposed_tool_catalog_payload.has("domain_states"):
		return _failure("exposed tool catalog should include only the public tools slice, not visible tree metadata.")
	var exposed_tool_catalog_schema_error := _first_tool_json_schema_2020_12_error(exposed_tool_catalog_payload.get("tools", []))
	if not exposed_tool_catalog_schema_error.is_empty():
		return _failure("exposed tool catalog should advertise JSON Schema 2020-12 on tool schemas: %s" % exposed_tool_catalog_schema_error)
	for removed_tool_name in ["system_help", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze"]:
		if _contains_tool_name_recursive(exposed_tool_catalog_payload, removed_tool_name):
			return _failure("exposed tool catalog should not expose removed public tool %s." % removed_tool_name)
	var visible_tool_catalog := await _read_json_resource(TOOLS_CATALOG_VISIBLE_URI, 29)
	if not bool(visible_tool_catalog.get("ok", false)):
		return _failure(str(visible_tool_catalog.get("error", "visible tool catalog resource failed")))
	var visible_tool_catalog_payload: Dictionary = visible_tool_catalog.get("payload", {})
	if not (visible_tool_catalog_payload.get("toolTree", []) is Array) or not (visible_tool_catalog_payload.get("toolGroups", []) is Array):
		return _failure("visible tool catalog should include tree and group presentation metadata.")
	var visible_catalog_manifest = visible_tool_catalog_payload.get("catalogManifest", {})
	if not (visible_catalog_manifest is Dictionary) or int((visible_catalog_manifest as Dictionary).get("removed_public_tool_count", 0)) < 1:
		return _failure("visible tool catalog should expose canonical catalog manifest metadata.")
	if (visible_catalog_manifest as Dictionary).has("removed_public_tools"):
		return _failure("visible tool catalog manifest should not expose removed public tool names.")
	if not (visible_tool_catalog_payload.get("domain_states", []) is Array):
		return _failure("visible tool catalog should expose raw domain_states promised by its resource metadata.")
	var system_domain_state := _find_domain_state(visible_tool_catalog_payload.get("domain_states", []), "system")
	if system_domain_state.is_empty():
		return _failure("visible tool catalog should preserve loader domain state entries.")
	if str(system_domain_state.get("load_state", "")).is_empty() or int(system_domain_state.get("tool_count", -1)) < 1:
		return _failure("visible tool catalog domain_states should keep raw loader state fields.")
	for removed_tool_name in ["system_help", "system_editor_log", "system_tool_catalog", "system_tool_activity", "system_scene_validate", "system_scene_analyze"]:
		if _contains_tool_name_recursive(visible_tool_catalog_payload, removed_tool_name):
			return _failure("visible tool catalog should not expose removed public tool %s." % removed_tool_name)

	var activity_status := await _read_json_resource(ACTIVITY_STATUS_URI, 30)
	if not bool(activity_status.get("ok", false)):
		return _failure(str(activity_status.get("error", "activity status resource failed")))
	var activity_status_payload: Dictionary = activity_status.get("payload", {})
	if not activity_status_payload.has("running_count") or not (activity_status_payload.get("execution_order", []) is Array):
		return _failure("activity status resource should expose running counts and execution order.")
	var activity_recent := await _read_json_resource(ACTIVITY_RECENT_URI, 31)
	if not bool(activity_recent.get("ok", false)):
		return _failure(str(activity_recent.get("error", "activity recent resource failed")))
	var activity_recent_payload: Dictionary = activity_recent.get("payload", {})
	if not activity_recent_payload.has("recent_count") or not (activity_recent_payload.get("recent", []) is Array):
		return _failure("activity recent resource should expose recent activity records.")
	var missing_activity_call := await _read_json_resource(ACTIVITY_MISSING_CALL_URI, 32)
	if not bool(missing_activity_call.get("ok", false)):
		return _failure(str(missing_activity_call.get("error", "activity call resource failed")))
	var missing_activity_call_payload: Dictionary = missing_activity_call.get("payload", {})
	if bool(missing_activity_call_payload.get("found", true)) or str(missing_activity_call_payload.get("call_id", "")) != "tool-contract-missing":
		return _failure("activity call template should return a stable not-found payload for unknown call ids.")

	var scene_read := await _read_text_resource(SCENE_READ_URI, 6)
	if not bool(scene_read.get("ok", false)):
		return _failure(str(scene_read.get("error", "scene read failed")))
	if str(scene_read.get("text", "")).find("[gd_scene") == -1:
		return _failure("scene template resource should read scene text.")

	var script_read := await _read_text_resource(SCRIPT_READ_URI, 7)
	if not bool(script_read.get("ok", false)):
		return _failure(str(script_read.get("error", "script read failed")))
	if str(script_read.get("text", "")).find("discover_test_cases") == -1:
		return _failure("script template resource should read script text.")

	var resource_read := await _read_text_resource(RESOURCE_READ_URI, 8)
	if not bool(resource_read.get("ok", false)):
		return _failure(str(resource_read.get("error", "resource read failed")))
	if str(resource_read.get("text", "")).find("resource_name") == -1:
		return _failure("resource template resource should read resource text.")
	var binary_scene_path := "res://tests_tmp/mcp_resources_prompts_contracts/binary_scene.scn"
	var binary_resource_path := "res://tests_tmp/mcp_resources_prompts_contracts/binary_resource.res"
	_write_binary_file(binary_scene_path)
	_write_binary_file(binary_resource_path)
	var binary_scene_response: Dictionary = await _json_rpc("resources/read", {"uri": "godot-dotnet-mcp://scene/tests_tmp/mcp_resources_prompts_contracts/binary_scene.scn"}, 35)
	if not _is_invalid_extension_response(binary_scene_response):
		return _failure("scene text resource should reject binary .scn files with invalid params.")
	var binary_resource_response: Dictionary = await _json_rpc("resources/read", {"uri": "godot-dotnet-mcp://resource/tests_tmp/mcp_resources_prompts_contracts/binary_resource.res"}, 36)
	if not _is_invalid_extension_response(binary_resource_response):
		return _failure("resource text resource should reject binary .res files with invalid params.")
	var large_script_path := "res://tests_tmp/mcp_resources_prompts_contracts/large_script.gd"
	_write_large_text_file(large_script_path, 600000)
	var large_resource_response: Dictionary = await _json_rpc("resources/read", {"uri": "godot-dotnet-mcp://script/tests_tmp/mcp_resources_prompts_contracts/large_script.gd"}, 20)
	if not (large_resource_response.get("error", null) is Dictionary):
		return _failure("resources/read should reject oversized template file resources with a JSON-RPC error.")
	var large_resource_error: Dictionary = large_resource_response.get("error", {})
	if int(large_resource_error.get("code", 0)) != -32602 or str(large_resource_error.get("message", "")).find("exceeds") == -1:
		return _failure("resources/read oversized template resource errors should use -32602 and describe the output limit.")

	var traversal_response: Dictionary = await _json_rpc("resources/read", {"uri": TRAVERSAL_URI}, 9)
	if not (traversal_response.get("error", null) is Dictionary):
		return _failure("resources/read should reject traversal attempts with a JSON-RPC error.")
	var external_scheme_response: Dictionary = await _json_rpc("resources/read", {"uri": "godot-dotnet-mcp://script/user://outside.gd"}, 38)
	if not (external_scheme_response.get("error", null) is Dictionary):
		return _failure("resources/read should reject user:// template paths with a JSON-RPC error.")
	var absolute_path_response: Dictionary = await _json_rpc("resources/read", {"uri": "godot-dotnet-mcp://script/C:/outside.gd"}, 39)
	if not (absolute_path_response.get("error", null) is Dictionary):
		return _failure("resources/read should reject absolute template paths with a JSON-RPC error.")

	var prompts_response: Dictionary = await _json_rpc("prompts/list", {}, 10)
	var prompts_result = prompts_response.get("result", {})
	if not (prompts_result is Dictionary):
		return _failure("prompts/list should return a result object.")
	var prompts = (prompts_result as Dictionary).get("prompts", [])
	if not (prompts is Array) or (prompts as Array).size() != 6:
		return _failure("prompts/list should expose exactly the six high-level built-in prompt guides.")
	for expected_prompt in [PROJECT_ORIENTATION_PROMPT, CONTENT_AUTHORING_PROMPT, DEBUG_TRIAGE_PROMPT, REFERENCE_INTEGRITY_PROMPT, RUNTIME_VALIDATION_PROMPT, EDITOR_UI_CONTROL_PROMPT]:
		if not _has_prompt(prompts, expected_prompt):
			return _failure("prompts/list should expose prompt: %s" % expected_prompt)
		var prompt_metadata := _find_prompt(prompts, expected_prompt)
		if str(prompt_metadata.get("description", "")).length() < 40:
			return _failure("prompts/list should describe when and why to use prompt: %s" % expected_prompt)
		if not _has_icon_metadata(prompt_metadata):
			return _failure("prompts/list should expose 2025-11-25 icons metadata for prompt: %s" % expected_prompt)
		if not _prompt_arguments_are_documented(prompt_metadata):
			return _failure("prompts/list should document argument descriptions for prompt: %s" % expected_prompt)
		if not _has_meta_kind(prompt_metadata, "promptKind"):
			return _failure("prompts/list should keep Dock prompt classification in _meta.promptKind.")
		if prompt_metadata.has("promptKind"):
			return _failure("prompts/list should not expose Dock prompt classification as a top-level protocol field.")
	var orientation_metadata := _find_prompt(prompts, PROJECT_ORIENTATION_PROMPT)
	if str(orientation_metadata.get("title", "")) != "项目定位工作流":
		return _failure("prompts/list should localize prompt titles through the active locale.")
	if str(orientation_metadata.get("description", "")).find("Godot 项目") == -1:
		return _failure("prompts/list should localize prompt descriptions through the active locale.")
	var debug_metadata := _find_prompt(prompts, DEBUG_TRIAGE_PROMPT)
	var include_runtime_desc := _find_prompt_argument_description(debug_metadata, "include_runtime")
	if include_runtime_desc.find("true") == -1 or include_runtime_desc.find("false") == -1 or include_runtime_desc.find("字符串") == -1:
		return _failure("prompts/list should describe include_runtime as a true/false string in localized metadata.")

	var orientation_prompt := await _get_prompt_text(PROJECT_ORIENTATION_PROMPT, {"goal": "understand project", "symbol": "Player"}, 11)
	if not bool(orientation_prompt.get("ok", false)):
		return _failure(str(orientation_prompt.get("error", "project orientation prompt failed")))
	var orientation_text := str(orientation_prompt.get("text", ""))
	var required_orientation_fragments: Array[String] = ["resources/list", "godot-dotnet-mcp://guides/index", "godot-dotnet-mcp://guides/capabilities", "prompts/list", "prompts/get", "system_project_state", "system_project_index_build"]
	if not _prompt_text_is_actionable(orientation_text, required_orientation_fragments):
		for required_fragment in required_orientation_fragments:
			if not _has_any_fragment(orientation_text, required_fragment):
				return _failure("project orientation prompt is missing required fragment: %s" % required_fragment)
		return _failure("project orientation prompt should provide actionable read-only orientation workflow sections.")
	if orientation_text.find("system_help") != -1:
		return _failure("project orientation prompt should not recommend removed system_help.")
	var unknown_argument_response: Dictionary = await _json_rpc("prompts/get", {"name": PROJECT_ORIENTATION_PROMPT, "arguments": {"goal": "understand project", "bogus": "ignored"}}, 22)
	if not (unknown_argument_response.get("error", null) is Dictionary):
		return _failure("prompts/get should reject unknown prompt arguments.")
	var unknown_argument_error: Dictionary = unknown_argument_response.get("error", {})
	if int(unknown_argument_error.get("code", 0)) != -32602:
		return _failure("unknown prompt arguments should return invalid params.")
	var unknown_argument_message := str(unknown_argument_error.get("message", ""))
	if unknown_argument_message.find(PROJECT_ORIENTATION_PROMPT) == -1 or unknown_argument_message.find("bogus") == -1 or unknown_argument_message.find("goal") == -1 or unknown_argument_message.find("symbol") == -1:
		return _failure("unknown prompt argument error should include the prompt name, unknown key, and allowed arguments.")
	var invalid_goal_type_response: Dictionary = await _json_rpc("prompts/get", {"name": PROJECT_ORIENTATION_PROMPT, "arguments": {"goal": []}}, 31)
	if not (invalid_goal_type_response.get("error", null) is Dictionary):
		return _failure("prompts/get should reject non-string string prompt arguments.")
	var invalid_goal_type_error: Dictionary = invalid_goal_type_response.get("error", {})
	if int(invalid_goal_type_error.get("code", 0)) != -32602:
		return _failure("non-string prompt arguments should return invalid params.")
	var invalid_goal_type_message := str(invalid_goal_type_error.get("message", ""))
	if invalid_goal_type_message.find(PROJECT_ORIENTATION_PROMPT) == -1 or invalid_goal_type_message.find("goal") == -1 or invalid_goal_type_message.find("string") == -1:
		return _failure("non-string prompt argument error should include the prompt name, argument name, and expected type.")
	var long_goal_prompt: Dictionary = await _json_rpc("prompts/get", {"name": PROJECT_ORIENTATION_PROMPT, "arguments": {"goal": "G".repeat(40000)}}, 21)
	var long_goal_result = long_goal_prompt.get("result", {})
	if not (long_goal_result is Dictionary):
		return _failure("prompts/get should return a result object when prompt text is oversized.")
	var long_goal_meta = (long_goal_result as Dictionary).get("_meta", {})
	if not (long_goal_meta is Dictionary):
		return _failure("prompts/get should include _meta when prompt text is truncated.")
	var output_meta = ((long_goal_meta as Dictionary).get("godotDotnetMcp", {}) as Dictionary).get("output", {})
	if not (output_meta is Dictionary) or not bool((output_meta as Dictionary).get("truncated", false)):
		return _failure("prompts/get output metadata should mark oversized prompt text as truncated.")
	if int((output_meta as Dictionary).get("returnedByteSize", 0)) > int((output_meta as Dictionary).get("maxByteSize", 0)):
		return _failure("prompts/get truncated output should not exceed maxByteSize.")

	var content_prompt := await _get_prompt_text(CONTENT_AUTHORING_PROMPT, {"scene_path": "tests/headless_suite_entry.tscn", "script_path": "tests/headless_case_support.gd", "goal": "add a menu"}, 12)
	if not bool(content_prompt.get("ok", false)):
		return _failure(str(content_prompt.get("error", "content authoring prompt failed")))
	if str(content_prompt.get("text", "")).find("res://tests/headless_suite_entry.tscn") == -1 or str(content_prompt.get("text", "")).find("res://tests/headless_case_support.gd") == -1:
		return _failure("content authoring prompt should normalize scene_path and script_path to res://.")
	var invalid_content_scene_response: Dictionary = await _json_rpc("prompts/get", {"name": CONTENT_AUTHORING_PROMPT, "arguments": {"scene_path": "res://BinaryScene.scn"}}, 37)
	if not _is_invalid_extension_response(invalid_content_scene_response):
		return _failure("content authoring prompt should reject binary .scn scene_path arguments.")
	if not _prompt_text_is_actionable(str(content_prompt.get("text", "")), ["Use when||适用场景", "Recommended workflow||推荐流程", "Validation||验证", "Avoid||避免事项", "system_scene_inspect", "action=analyze", "system_script_patch"]):
		return _failure("content authoring prompt should provide actionable scene and script authoring sections.")

	var debug_prompt := await _get_prompt_text(DEBUG_TRIAGE_PROMPT, {"error_summary": "NullReferenceException", "include_runtime": "true"}, 13)
	if not bool(debug_prompt.get("ok", false)):
		return _failure(str(debug_prompt.get("error", "debug prompt failed")))
	if str(debug_prompt.get("text", "")).find("runtime_diagnose") == -1 or str(debug_prompt.get("text", "")).find("NullReferenceException") == -1 or str(debug_prompt.get("text", "")).find("system_dap_debugger") == -1:
		return _failure("debug triage prompt should mention runtime_diagnose, DAP escalation, and include the error summary.")
	var debug_prompt_text := str(debug_prompt.get("text", ""))
	if debug_prompt_text.find("system_editor_log") != -1:
		return _failure("debug triage prompt should not recommend removed system_editor_log.")
	if not _prompt_text_is_actionable(debug_prompt_text, ["Use when||适用场景", "Recommended workflow||推荐流程", "Validation||验证", "Avoid||避免事项", EDITOR_LOG_ERRORS_URI, "resources/read", "system_project_state"]):
		return _failure("debug triage prompt should provide actionable workflow sections and resource-first diagnostic inputs.")
	var debug_prompt_without_runtime := await _get_prompt_text(DEBUG_TRIAGE_PROMPT, {"include_runtime": "false"}, 32)
	if not bool(debug_prompt_without_runtime.get("ok", false)):
		return _failure(str(debug_prompt_without_runtime.get("error", "debug prompt without runtime failed")))
	if str(debug_prompt_without_runtime.get("text", "")).find("Include runtime_diagnose output") != -1:
		return _failure("debug triage prompt should not append runtime-specific guidance when include_runtime=false.")
	var invalid_runtime_non_string_cases := [
		{"value": true, "label": "boolean"},
		{"value": 0, "label": "number"},
		{"value": [], "label": "array"},
		{"value": {}, "label": "object"}
	]
	var invalid_runtime_id := 33
	for invalid_runtime_case in invalid_runtime_non_string_cases:
		var invalid_runtime_type_response: Dictionary = await _json_rpc("prompts/get", {"name": DEBUG_TRIAGE_PROMPT, "arguments": {"include_runtime": invalid_runtime_case.get("value")}}, invalid_runtime_id)
		invalid_runtime_id += 1
		if not (invalid_runtime_type_response.get("error", null) is Dictionary):
			return _failure("prompts/get should reject non-string include_runtime %s values." % str(invalid_runtime_case.get("label", "")))
		var invalid_runtime_type_error: Dictionary = invalid_runtime_type_response.get("error", {})
		if int(invalid_runtime_type_error.get("code", 0)) != -32602:
			return _failure("non-string include_runtime should return invalid params.")
		var invalid_runtime_type_message := str(invalid_runtime_type_error.get("message", ""))
		if invalid_runtime_type_message.find(DEBUG_TRIAGE_PROMPT) == -1 or invalid_runtime_type_message.find("include_runtime") == -1 or invalid_runtime_type_message.find("string") == -1:
			return _failure("non-string include_runtime error should include the prompt name, argument name, and expected type.")
	var invalid_runtime_value_response: Dictionary = await _json_rpc("prompts/get", {"name": DEBUG_TRIAGE_PROMPT, "arguments": {"include_runtime": "yes"}}, invalid_runtime_id)
	if not (invalid_runtime_value_response.get("error", null) is Dictionary):
		return _failure("prompts/get should reject unsupported include_runtime string values.")
	var invalid_runtime_value_error: Dictionary = invalid_runtime_value_response.get("error", {})
	if int(invalid_runtime_value_error.get("code", 0)) != -32602:
		return _failure("unsupported include_runtime string should return invalid params.")
	var invalid_runtime_value_message := str(invalid_runtime_value_error.get("message", ""))
	if invalid_runtime_value_message.find(DEBUG_TRIAGE_PROMPT) == -1 or invalid_runtime_value_message.find("include_runtime") == -1 or invalid_runtime_value_message.find("true") == -1 or invalid_runtime_value_message.find("false") == -1:
		return _failure("unsupported include_runtime string error should include the prompt name, argument name, and accepted values.")

	var reference_prompt := await _get_prompt_text(REFERENCE_INTEGRITY_PROMPT, {"script_path": "res://Player.cs", "scene_path": "Main.tscn", "resource_path": "tests/_fixtures/mcp_resources_prompts_sample.tres", "binding_name": "HealthLabel"}, 14)
	if not bool(reference_prompt.get("ok", false)):
		return _failure(str(reference_prompt.get("error", "reference integrity prompt failed")))
	if str(reference_prompt.get("text", "")).find("bindings_audit") == -1 or str(reference_prompt.get("text", "")).find("resource_reference_audit") == -1 or str(reference_prompt.get("text", "")).find("res://Main.tscn") == -1:
		return _failure("reference integrity prompt should mention binding and resource audits and normalize scene_path.")
	if not _prompt_text_is_actionable(str(reference_prompt.get("text", "")), ["Use when||适用场景", "Recommended workflow||推荐流程", "Validation||验证", "Avoid||避免事项", "system_script_analyze", "system_scene_inspect", "action=validate"]):
		return _failure("reference integrity prompt should provide actionable workflow sections and validation tools.")
	var gd_reference_prompt := await _get_prompt_text(REFERENCE_INTEGRITY_PROMPT, {"script_path": "res://Player.gd"}, 16)
	if not bool(gd_reference_prompt.get("ok", false)):
		return _failure("reference integrity prompt should accept GDScript paths.")
	var invalid_res_prompt_response: Dictionary = await _json_rpc("prompts/get", {"name": REFERENCE_INTEGRITY_PROMPT, "arguments": {"resource_path": "res://PackedResource.res"}}, 17)
	if not (invalid_res_prompt_response.get("error", null) is Dictionary):
		return _failure("reference integrity prompt should reject .res resource_path because resource_reference_audit accepts text scene/resource files.")
	var invalid_reference_scene_response: Dictionary = await _json_rpc("prompts/get", {"name": REFERENCE_INTEGRITY_PROMPT, "arguments": {"scene_path": "res://BinaryScene.scn"}}, 38)
	if not _is_invalid_extension_response(invalid_reference_scene_response):
		return _failure("reference integrity prompt should reject binary .scn scene_path arguments.")

	var runtime_prompt := await _get_prompt_text(RUNTIME_VALIDATION_PROMPT, {"scene_path": "tests/headless_suite_entry.tscn", "goal": "verify menu", "success_marker": "MENU_READY"}, 18)
	if not bool(runtime_prompt.get("ok", false)):
		return _failure(str(runtime_prompt.get("error", "runtime validation prompt failed")))
	if str(runtime_prompt.get("text", "")).find("res://tests/headless_suite_entry.tscn") == -1 or str(runtime_prompt.get("text", "")).find("MENU_READY") == -1:
		return _failure("runtime validation prompt should normalize scene_path and include success marker context.")
	var invalid_runtime_scene_response: Dictionary = await _json_rpc("prompts/get", {"name": RUNTIME_VALIDATION_PROMPT, "arguments": {"scene_path": "res://BinaryScene.scn"}}, 39)
	if not _is_invalid_extension_response(invalid_runtime_scene_response):
		return _failure("runtime validation prompt should reject binary .scn scene_path arguments.")
	if not _prompt_text_is_actionable(str(runtime_prompt.get("text", "")), ["Use when||适用场景", "Recommended workflow||推荐流程", "Validation||验证", "Avoid||避免事项", "system_project_lifecycle(action=start)", "system_project_lifecycle(action=stop)", "system_runtime_step"]):
		return _failure("runtime validation prompt should provide actionable run/input/capture workflow sections.")

	var editor_prompt := await _get_prompt_text(EDITOR_UI_CONTROL_PROMPT, {"ui_goal": "open settings", "target_path": "MCPDock/settings"}, 19)
	if not bool(editor_prompt.get("ok", false)):
		return _failure(str(editor_prompt.get("error", "editor UI control prompt failed")))
	if not _prompt_text_is_actionable(str(editor_prompt.get("text", "")), ["Use when||适用场景", "Recommended workflow||推荐流程", "Validation||验证", "Avoid||避免事项", "system_editor_state", "system_editor_evidence", "system_editor_control"]):
		return _failure("editor UI control prompt should provide actionable editor UI workflow sections.")
	var editor_prompt_text := str(editor_prompt.get("text", ""))
	if editor_prompt_text.find("run_task") == -1 or editor_prompt_text.find("resolve_row") == -1 or editor_prompt_text.find("system_inspector") == -1 or editor_prompt_text.find("resolve_property") == -1:
		return _failure("editor UI control prompt should mention settings_dialog and inspector semantic workflows in the localized prompt text.")
	if not _fragment_order_is_increasing(editor_prompt_text, ["system_settings_dialog", "system_inspector", "system_editor_evidence(action=capture)", "system_editor_control(action=activate_ui)", "focus_control", "click_control"]):
		return _failure("editor UI control prompt should order semantic settings/inspector/evidence/UI actions before control-level focus and click fallback.")
	if not _all_fragments_before(editor_prompt_text, ["focus_control", "activate_control", "set_control_text"], "click_control"):
		return _failure("editor UI control prompt should order control-level actions before mouse fallback actions.")
	for expected_editor_action in ["surface=auto/editor/control/popup/active_dialog", "fallback reasons", "degraded", "list_menus/open_menu/select_menu_item", "list_tree_items/select_tree_item", "hover_control", "leave_control", "Control-local"]:
		if editor_prompt_text.find(expected_editor_action) == -1:
			return _failure("editor UI control prompt should mention preference-order action: %s" % expected_editor_action)

	var invalid_prompt_response: Dictionary = await _json_rpc("prompts/get", {"name": REFERENCE_INTEGRITY_PROMPT, "arguments": {"script_path": "../Player.cs"}}, 15)
	if not (invalid_prompt_response.get("error", null) is Dictionary):
		return _failure("prompts/get should reject invalid reference_integrity path arguments.")
	var stdio_server = StdioServerScript.new()
	await stdio_server._handle_request(JSON.stringify({
		"jsonrpc": "2.0",
		"id": 22,
		"method": "initialize",
		"params": []
	}))
	var invalid_stdio_request_response = stdio_server.get("_last_written_response")
	if not (invalid_stdio_request_response is Dictionary):
		return _failure("stdio full request path should record the invalid params response.")
	if int(((invalid_stdio_request_response as Dictionary).get("error", {}) as Dictionary).get("code", 0)) != -32602:
		return _failure("stdio full request path should reject non-object params before method dispatch.")
	stdio_server.set("_last_written_response", {})
	var shared_stdio_loader := FakeStdioToolLoader.new()
	var shared_stdio_registry = ToolActivityRegistryScript.new()
	shared_stdio_loader.set_tool_activity_registry(shared_stdio_registry)
	stdio_server.initialize(shared_stdio_loader)
	if shared_stdio_loader.get_tool_activity_registry() != shared_stdio_registry:
		return _failure("stdio initialization should not replace an existing shared tool activity registry.")
	var stdio_tool_call_result: Dictionary = await stdio_server._handle_tools_call_async({
		"name": "system_project_state",
		"arguments": {"summary": true}
	}, 23)
	if bool(stdio_tool_call_result.get("error", null) is Dictionary):
		return _failure("stdio tool call should route through the fake loader before activity resource verification.")
	var stdio_activity_recent_response: Dictionary = stdio_server._handle_resources_read({"uri": ACTIVITY_RECENT_URI}, 24)
	var stdio_activity_result = stdio_activity_recent_response.get("result", {})
	if not (stdio_activity_result is Dictionary):
		return _failure("stdio activity recent resource should return a result object.")
	var stdio_activity_contents = (stdio_activity_result as Dictionary).get("contents", [])
	if not (stdio_activity_contents is Array) or (stdio_activity_contents as Array).is_empty():
		return _failure("stdio activity recent resource should return content entries.")
	var stdio_activity_payload = JSON.parse_string(str(((stdio_activity_contents as Array)[0] as Dictionary).get("text", "")))
	if not (stdio_activity_payload is Dictionary):
		return _failure("stdio activity recent resource text should parse as JSON.")
	var stdio_recent = (stdio_activity_payload as Dictionary).get("recent", [])
	if not (stdio_recent is Array) or (stdio_recent as Array).is_empty():
		return _failure("stdio activity resources should read the same activity registry used by stdio tool calls.")
	var stdio_recent_tool := str(((stdio_recent as Array)[0] as Dictionary).get("tool", ""))
	if stdio_recent_tool != "system_project_state":
		return _failure("stdio activity resources should preserve the stdio tool call record.")
	var stdio_tools_list_response: Dictionary = stdio_server._handle_tools_list(25)
	var stdio_tools = (stdio_tools_list_response.get("result", {}) as Dictionary).get("tools", [])
	if not (stdio_tools is Array) or (stdio_tools as Array).is_empty():
		return _failure("stdio tools/list should expose tools for schema dialect verification.")
	var stdio_tool_schema_error := _first_tool_json_schema_2020_12_error(stdio_tools)
	if not stdio_tool_schema_error.is_empty():
		return _failure("stdio tools/list should advertise JSON Schema 2020-12 on tool schemas: %s" % stdio_tool_schema_error)
	await stdio_server._handle_request(JSON.stringify({
		"jsonrpc": "2.0",
		"method": "tools/list",
		"params": []
	}))
	if not (stdio_server.get("_last_written_response") as Dictionary).is_empty():
		return _failure("stdio notifications with non-object params should not write a response.")
	var invalid_stdio_params_response: Dictionary = stdio_server._handle_resources_read([], 17)
	if int((invalid_stdio_params_response.get("error", {}) as Dictionary).get("code", 0)) != -32602:
		return _failure("stdio resources/read should reject non-object params with -32602.")
	var invalid_stdio_tool_params: Dictionary = await stdio_server._handle_tools_call_async([], 20)
	if int((invalid_stdio_tool_params.get("error", {}) as Dictionary).get("code", 0)) != -32602:
		return _failure("stdio tools/call should reject non-object params with -32602.")
	var invalid_stdio_tool_arguments: Dictionary = await stdio_server._handle_tools_call_async({"name": "system_help", "arguments": []}, 21)
	var invalid_stdio_tool_arguments_error: Dictionary = invalid_stdio_tool_arguments.get("error", {})
	if int(invalid_stdio_tool_arguments_error.get("code", 0)) != -32602:
		return _failure("stdio tools/call should reject non-object arguments with -32602.")
	if str(invalid_stdio_tool_arguments_error.get("message", "")).find("arguments must be an object") == -1:
		return _failure("stdio tools/call non-object arguments should describe the invalid request shape.")
	stdio_server.free()
	_restore_language()

	return {
		"name": "mcp_resources_prompts_contracts",
		"success": true,
		"error": "",
		"details": {
			"resource_count": (resources as Array).size(),
			"template_count": (templates as Array).size(),
			"prompt_count": (prompts as Array).size(),
			"protocol_version": ProtocolFactsScript.get_protocol_version()
		}
	}


func cleanup_case(tree: SceneTree) -> void:
	_restore_language()
	for path in _temp_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for i in range(_temp_paths.size() - 1, -1, -1):
		var path := _temp_paths[i]
		var absolute_path := ProjectSettings.globalize_path(path)
		if DirAccess.dir_exists_absolute(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	_temp_paths.clear()
	if _server == null:
		return
	if _server.has_method("stop"):
		_server.stop()
	if _server.has_method("dispose"):
		_server.dispose()
	_server.free()
	_server = null
	await tree.process_frame
	await tree.process_frame


func _restore_language() -> void:
	if _previous_language.is_empty():
		return
	var localization = LocalizationServiceScript.get_instance()
	if localization != null:
		localization.set_language(_previous_language)
	_previous_language = ""


func _json_rpc(method: String, params: Dictionary, id: int) -> Dictionary:
	return await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": id,
		"method": method,
		"params": params
	}))


func _write_large_text_file(path: String, size: int) -> void:
	var dir_path := path.get_base_dir()
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		DirAccess.make_dir_recursive_absolute(absolute_dir)
		_temp_paths.append(dir_path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("# oversized contract fixture\n")
	file.store_string("A".repeat(size))
	file.close()
	_temp_paths.append(path)


func _write_binary_file(path: String) -> void:
	var dir_path := path.get_base_dir()
	var absolute_dir := ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(absolute_dir):
		DirAccess.make_dir_recursive_absolute(absolute_dir)
		_temp_paths.append(dir_path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(PackedByteArray([0, 1, 2, 3, 255]))
	file.close()
	_temp_paths.append(path)


func _read_json_resource(uri: String, id: int) -> Dictionary:
	var read_result := await _read_text_resource(uri, id)
	if not bool(read_result.get("ok", false)):
		return read_result
	var parsed = JSON.parse_string(str(read_result.get("text", "")))
	if not (parsed is Dictionary):
		return {"ok": false, "error": "Resource JSON text could not be parsed: %s" % uri}
	return {"ok": true, "payload": parsed}


func _read_text_resource(uri: String, id: int) -> Dictionary:
	var response: Dictionary = await _json_rpc("resources/read", {"uri": uri}, id)
	var result = response.get("result", {})
	if not (result is Dictionary):
		return {"ok": false, "error": "resources/read should return a result object for %s." % uri}
	var contents = (result as Dictionary).get("contents", [])
	if not (contents is Array) or (contents as Array).is_empty():
		return {"ok": false, "error": "resources/read should return content entries for %s." % uri}
	var content = (contents as Array)[0]
	if not (content is Dictionary):
		return {"ok": false, "error": "resources/read content should be an object for %s." % uri}
	if str((content as Dictionary).get("uri", "")) != uri:
		return {"ok": false, "error": "resources/read should preserve the requested URI for %s." % uri}
	return {"ok": true, "mimeType": str((content as Dictionary).get("mimeType", "")), "text": str((content as Dictionary).get("text", ""))}


func _is_invalid_extension_response(response: Dictionary) -> bool:
	var error = response.get("error", null)
	if not (error is Dictionary):
		return false
	var message := str((error as Dictionary).get("message", "")).to_lower()
	return int((error as Dictionary).get("code", 0)) == -32602 and message.find("unsupported extension") != -1


func _get_prompt_text(name: String, arguments: Dictionary, id: int) -> Dictionary:
	var response: Dictionary = await _json_rpc("prompts/get", {"name": name, "arguments": arguments}, id)
	var result = response.get("result", {})
	if not (result is Dictionary):
		return {"ok": false, "error": "prompts/get should return a result object for %s." % name}
	var messages = (result as Dictionary).get("messages", [])
	var prompt_text := _first_message_text(messages)
	if prompt_text.is_empty():
		return {"ok": false, "error": "prompts/get should return prompt message text for %s." % name}
	return {"ok": true, "text": prompt_text}


func _has_resource(resources, uri: String) -> bool:
	if not (resources is Array):
		return false
	for resource in resources:
		if resource is Dictionary and str((resource as Dictionary).get("uri", "")) == uri:
			return true
	return false


func _find_resource(resources, uri: String) -> Dictionary:
	if not (resources is Array):
		return {}
	for resource in resources:
		if resource is Dictionary and str((resource as Dictionary).get("uri", "")) == uri:
			return resource as Dictionary
	return {}


func _find_domain_state(states, category: String) -> Dictionary:
	if not (states is Array):
		return {}
	for state in states:
		if state is Dictionary and str((state as Dictionary).get("category", "")) == category:
			return state as Dictionary
	return {}


func _has_template(templates, uri_template: String) -> bool:
	if not (templates is Array):
		return false
	for template in templates:
		if template is Dictionary and str((template as Dictionary).get("uriTemplate", "")) == uri_template:
			return true
	return false


func _find_template(templates, uri_template: String) -> Dictionary:
	if not (templates is Array):
		return {}
	for template in templates:
		if template is Dictionary and str((template as Dictionary).get("uriTemplate", "")) == uri_template:
			return template as Dictionary
	return {}


func _has_prompt(prompts, name: String) -> bool:
	if not (prompts is Array):
		return false
	for prompt in prompts:
		if prompt is Dictionary and str((prompt as Dictionary).get("name", "")) == name:
			return true
	return false


func _find_prompt(prompts, name: String) -> Dictionary:
	if not (prompts is Array):
		return {}
	for prompt in prompts:
		if prompt is Dictionary and str((prompt as Dictionary).get("name", "")) == name:
			return (prompt as Dictionary)
	return {}


func _has_display_metadata(entry) -> bool:
	if not (entry is Dictionary):
		return false
	var metadata := entry as Dictionary
	if str(metadata.get("title", "")).is_empty():
		return false
	return _has_icon_metadata(metadata)


func _has_meta_kind(entry, key: String) -> bool:
	if not (entry is Dictionary):
		return false
	var meta = (entry as Dictionary).get("_meta", {})
	return meta is Dictionary and not str((meta as Dictionary).get(key, "")).strip_edges().is_empty()


func _has_icon_metadata(entry: Dictionary) -> bool:
	var icons = entry.get("icons", [])
	if not (icons is Array) or (icons as Array).is_empty():
		return false
	for icon in icons as Array:
		if not (icon is Dictionary):
			return false
		var icon_dict := icon as Dictionary
		var src := str(icon_dict.get("src", ""))
		if not src.begins_with("data:image/svg+xml;base64,"):
			return false
		if src.trim_prefix("data:image/svg+xml;base64,").strip_edges().is_empty():
			return false
		if src.find("%3Csvg") != -1:
			return false
		if str(icon_dict.get("mimeType", "")) != "image/svg+xml":
			return false
		var sizes = icon_dict.get("sizes", [])
		if not (sizes is Array) or not (sizes as Array).has("any"):
			return false
	return true


func _validate_initialize_capabilities(capabilities, label: String) -> String:
	if not (capabilities is Dictionary):
		return "%s should expose capabilities as an object." % label
	for capability_name in (capabilities as Dictionary).keys():
		if not ["tools", "resources", "prompts"].has(str(capability_name)):
			return "%s should only advertise implemented top-level MCP capabilities, got: %s" % [label, str(capability_name)]
	if not ((capabilities as Dictionary).get("resources", {}) is Dictionary):
		return "%s should advertise MCP resources capability." % label
	if not ((capabilities as Dictionary).get("prompts", {}) is Dictionary):
		return "%s should advertise MCP prompts capability." % label
	var resources_capability := (capabilities as Dictionary).get("resources", {}) as Dictionary
	var prompts_capability := (capabilities as Dictionary).get("prompts", {}) as Dictionary
	for capability_field in resources_capability.keys():
		if str(capability_field) != "listChanged":
			return "%s resources capability should not advertise unsupported optional field: %s" % [label, str(capability_field)]
	for capability_field in prompts_capability.keys():
		if str(capability_field) != "listChanged":
			return "%s prompts capability should not advertise unsupported optional field: %s" % [label, str(capability_field)]
	if bool(resources_capability.get("listChanged", true)):
		return "%s resources capability should declare listChanged=false for static built-ins." % label
	if bool(prompts_capability.get("listChanged", true)):
		return "%s prompts capability should declare listChanged=false for static built-ins." % label
	for optional_capability in ["sampling", "elicitation", "tasks"]:
		if (capabilities as Dictionary).has(optional_capability):
			return "%s should not advertise optional MCP 2025-11-25 capability before implementation: %s" % [label, optional_capability]
	return ""

func _prompt_arguments_are_documented(prompt: Dictionary) -> bool:
	var arguments = prompt.get("arguments", [])
	if not (arguments is Array):
		return false
	for argument in arguments:
		if not (argument is Dictionary):
			return false
		var argument_dict := argument as Dictionary
		if str(argument_dict.get("name", "")).is_empty():
			return false
		if str(argument_dict.get("description", "")).length() < 20:
			return false
		if not argument_dict.has("required"):
			return false
	return true


func _find_prompt_argument_description(prompt: Dictionary, argument_name: String) -> String:
	var arguments = prompt.get("arguments", [])
	if not (arguments is Array):
		return ""
	for argument in arguments:
		if argument is Dictionary and str((argument as Dictionary).get("name", "")) == argument_name:
			return str((argument as Dictionary).get("description", ""))
	return ""


func _prompt_text_is_actionable(text: String, required_fragments: Array[String]) -> bool:
	if text.length() < 250:
		return false
	for fragment in required_fragments:
		if not _has_any_fragment(text, fragment):
			return false
	return true


func _has_any_fragment(text: String, fragment_group: String) -> bool:
	for fragment in fragment_group.split("||"):
		if text.find(fragment) != -1:
			return true
	return false


func _fragment_order_is_increasing(text: String, fragments: Array[String]) -> bool:
	var last_index := -1
	for fragment in fragments:
		var index := text.find(fragment)
		if index == -1 or index <= last_index:
			return false
		last_index = index
	return true


func _all_fragments_before(text: String, fragments: Array[String], later_fragment: String) -> bool:
	var later_index := text.find(later_fragment)
	if later_index == -1:
		return false
	for fragment in fragments:
		var index := text.find(fragment)
		if index == -1 or index >= later_index:
			return false
	return true


func _first_message_text(messages) -> String:
	if not (messages is Array) or (messages as Array).is_empty():
		return ""
	var message = (messages as Array)[0]
	if not (message is Dictionary):
		return ""
	var content = (message as Dictionary).get("content", {})
	if not (content is Dictionary):
		return ""
	return str((content as Dictionary).get("text", ""))


func _contains_tool_name_recursive(value, tool_name: String) -> bool:
	if value is String:
		return str(value) == tool_name
	if value is Array:
		for item in value:
			if _contains_tool_name_recursive(item, tool_name):
				return true
		return false
	if value is Dictionary:
		var dict := value as Dictionary
		for key in ["name", "fullName", "full_name"]:
			if str(dict.get(key, "")) == tool_name:
				return true
		for nested in dict.values():
			if _contains_tool_name_recursive(nested, tool_name):
				return true
	return false


func _failure(message: String) -> Dictionary:
	return {
		"name": "mcp_resources_prompts_contracts",
		"success": false,
		"error": message
	}


func _first_tool_json_schema_2020_12_error(tools) -> String:
	if not (tools is Array) or (tools as Array).is_empty():
		return "tools array is empty or missing"
	for tool in tools:
		if not (tool is Dictionary):
			return "tool entry is not an object"
		var tool_dict := tool as Dictionary
		var tool_name := str(tool_dict.get("name", "<unnamed>"))
		for key in ["inputSchema", "outputSchema"]:
			var schema = tool_dict.get(key, {})
			if not (schema is Dictionary):
				return "%s %s is not an object" % [tool_name, key]
			var actual_schema := str((schema as Dictionary).get("$schema", ""))
			if actual_schema != JSON_SCHEMA_2020_12_URI:
				return "%s %s has $schema '%s'" % [tool_name, key, actual_schema]
	return ""
