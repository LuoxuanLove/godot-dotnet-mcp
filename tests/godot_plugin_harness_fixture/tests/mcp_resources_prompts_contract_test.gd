extends RefCounted

# {"name": "mcp_resources_prompts_contracts"}

const HttpServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_server.gd")
const ProtocolFactsScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const MCPDebugBufferScript = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")
const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")

const PROJECT_INFO_URI := "godot-dotnet-mcp://project/info"
const DIAGNOSTICS_SUMMARY_URI := "godot-dotnet-mcp://diagnostics/summary"
const TOOL_CATALOG_URI := "godot-dotnet-mcp://tools/catalog"
const SCENE_READ_URI := "godot-dotnet-mcp://scene/tests/headless_suite_entry.tscn"
const SCRIPT_READ_URI := "godot-dotnet-mcp://script/tests/headless_case_support.gd"
const RESOURCE_READ_URI := "godot-dotnet-mcp://resource/tests/_fixtures/mcp_resources_prompts_sample.tres"
const TRAVERSAL_URI := "godot-dotnet-mcp://script/../project.godot"
const SCENE_BOOTSTRAP_PROMPT := "godot.scene_bootstrap"
const DEBUG_TRIAGE_PROMPT := "godot.debug_triage"
const BINDING_FIX_PROMPT := "godot.binding_fix"

var _server = null


func run_case(_tree: SceneTree) -> Dictionary:
	_server = HttpServerScript.new()
	_server.initialize(0, "127.0.0.1", false)

	var initialize_response: Dictionary = await _json_rpc("initialize", {}, 1)
	var initialize_result = initialize_response.get("result", {})
	if not (initialize_result is Dictionary):
		return _failure("initialize should return a result object.")
	var capabilities = (initialize_result as Dictionary).get("capabilities", {})
	if not (capabilities is Dictionary):
		return _failure("initialize should expose capabilities as an object.")
	if not ((capabilities as Dictionary).get("resources", {}) is Dictionary):
		return _failure("initialize should advertise MCP resources capability.")
	if not ((capabilities as Dictionary).get("prompts", {}) is Dictionary):
		return _failure("initialize should advertise MCP prompts capability.")
	if bool(((capabilities as Dictionary).get("resources", {}) as Dictionary).get("listChanged", true)):
		return _failure("resources capability should declare listChanged=false for static built-ins.")
	if bool(((capabilities as Dictionary).get("prompts", {}) as Dictionary).get("listChanged", true)):
		return _failure("prompts capability should declare listChanged=false for static built-ins.")

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

	var templates_response: Dictionary = await _json_rpc("resources/templates/list", {}, 3)
	var templates_result = templates_response.get("result", {})
	if not (templates_result is Dictionary):
		return _failure("resources/templates/list should return a result object.")
	var templates = (templates_result as Dictionary).get("resourceTemplates", [])
	if not (templates is Array):
		return _failure("resources/templates/list should return resourceTemplates as an array.")
	for expected_template in ["godot-dotnet-mcp://scene/{path}", "godot-dotnet-mcp://script/{path}", "godot-dotnet-mcp://resource/{path}"]:
		if not _has_template(templates, expected_template):
			return _failure("resources/templates/list should expose template: %s" % expected_template)

	var project_info := await _read_json_resource(PROJECT_INFO_URI, 4)
	if not bool(project_info.get("ok", false)):
		return _failure(str(project_info.get("error", "project info resource failed")))
	var project_payload: Dictionary = project_info.get("payload", {})
	if str(project_payload.get("protocolVersion", "")) != ProtocolFactsScript.get_protocol_version():
		return _failure("project info resource should include the current protocol version.")
	if str(project_payload.get("projectPath", "")).is_empty():
		return _failure("project info resource should include the project path.")

	MCPDebugBufferScript.clear()
	MCPDebugBufferScript.record("warning", "contract", "token=super-secret-value Authorization: Bearer top-secret-bearer", "", {"password": "hunter2", "safe": "visible"})
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
	if not diagnostics_text.contains("visible") or not diagnostics_text.contains("[redacted]"):
		return _failure("diagnostics summary resource should preserve safe log metadata while redacting sensitive fields.")

	var tool_catalog := await _read_json_resource(TOOL_CATALOG_URI, 15)
	if not bool(tool_catalog.get("ok", false)):
		return _failure(str(tool_catalog.get("error", "tool catalog resource failed")))
	var tool_catalog_payload: Dictionary = tool_catalog.get("payload", {})
	if not (tool_catalog_payload.get("tools", []) is Array):
		return _failure("tool catalog resource should include the MCP tools array.")

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

	var traversal_response: Dictionary = await _json_rpc("resources/read", {"uri": TRAVERSAL_URI}, 9)
	if not (traversal_response.get("error", null) is Dictionary):
		return _failure("resources/read should reject traversal attempts with a JSON-RPC error.")

	var prompts_response: Dictionary = await _json_rpc("prompts/list", {}, 10)
	var prompts_result = prompts_response.get("result", {})
	if not (prompts_result is Dictionary):
		return _failure("prompts/list should return a result object.")
	var prompts = (prompts_result as Dictionary).get("prompts", [])
	if not (prompts is Array) or (prompts as Array).size() != 3:
		return _failure("prompts/list should expose exactly the three built-in prompt guides.")
	for expected_prompt in [SCENE_BOOTSTRAP_PROMPT, DEBUG_TRIAGE_PROMPT, BINDING_FIX_PROMPT]:
		if not _has_prompt(prompts, expected_prompt):
			return _failure("prompts/list should expose prompt: %s" % expected_prompt)
		var prompt_metadata := _find_prompt(prompts, expected_prompt)
		if str(prompt_metadata.get("description", "")).length() < 40:
			return _failure("prompts/list should describe when and why to use prompt: %s" % expected_prompt)
		if not _prompt_arguments_are_documented(prompt_metadata):
			return _failure("prompts/list should document argument descriptions for prompt: %s" % expected_prompt)

	var scene_prompt := await _get_prompt_text(SCENE_BOOTSTRAP_PROMPT, {"scene_path": "tests/headless_suite_entry.tscn", "goal": "add a menu"}, 11)
	if not bool(scene_prompt.get("ok", false)):
		return _failure(str(scene_prompt.get("error", "scene prompt failed")))
	if str(scene_prompt.get("text", "")).find("res://tests/headless_suite_entry.tscn") == -1:
		return _failure("scene bootstrap prompt should normalize scene_path to res://.")
	if not _prompt_text_is_actionable(str(scene_prompt.get("text", "")), ["Use when", "Recommended workflow", "Validation", "system_scene_analyze", "system_scene_patch"]):
		return _failure("scene bootstrap prompt should provide actionable workflow sections and scene tools.")

	var debug_prompt := await _get_prompt_text(DEBUG_TRIAGE_PROMPT, {"error_summary": "NullReferenceException", "include_runtime": true}, 12)
	if not bool(debug_prompt.get("ok", false)):
		return _failure(str(debug_prompt.get("error", "debug prompt failed")))
	if str(debug_prompt.get("text", "")).find("runtime_diagnose") == -1 or str(debug_prompt.get("text", "")).find("NullReferenceException") == -1:
		return _failure("debug triage prompt should mention runtime_diagnose and include the error summary.")
	if not _prompt_text_is_actionable(str(debug_prompt.get("text", "")), ["Use when", "Recommended workflow", "Validation", "system_editor_log", "system_project_state"]):
		return _failure("debug triage prompt should provide actionable workflow sections and diagnostic tools.")

	var binding_prompt := await _get_prompt_text(BINDING_FIX_PROMPT, {"script_path": "res://Player.cs", "scene_path": "Main.tscn", "binding_name": "HealthLabel"}, 13)
	if not bool(binding_prompt.get("ok", false)):
		return _failure(str(binding_prompt.get("error", "binding prompt failed")))
	if str(binding_prompt.get("text", "")).find("bindings_audit") == -1 or str(binding_prompt.get("text", "")).find("res://Main.tscn") == -1:
		return _failure("binding fix prompt should mention bindings_audit and normalize scene_path.")
	if not _prompt_text_is_actionable(str(binding_prompt.get("text", "")), ["Use when", "Recommended workflow", "Validation", "system_script_analyze", "system_scene_validate"]):
		return _failure("binding fix prompt should provide actionable workflow sections and validation tools.")
	var gd_binding_prompt := await _get_prompt_text(BINDING_FIX_PROMPT, {"script_path": "res://Player.gd"}, 16)
	if not bool(gd_binding_prompt.get("ok", false)):
		return _failure("binding fix prompt should accept GDScript paths.")

	var invalid_prompt_response: Dictionary = await _json_rpc("prompts/get", {"name": BINDING_FIX_PROMPT, "arguments": {"script_path": "../Player.cs"}}, 14)
	if not (invalid_prompt_response.get("error", null) is Dictionary):
		return _failure("prompts/get should reject invalid binding_fix path arguments.")
	var stdio_server = StdioServerScript.new()
	var invalid_stdio_params_response: Dictionary = stdio_server._handle_resources_read([], 17)
	stdio_server.free()
	if int((invalid_stdio_params_response.get("error", {}) as Dictionary).get("code", 0)) != -32602:
		return _failure("stdio resources/read should reject non-object params with -32602.")

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


func _json_rpc(method: String, params: Dictionary, id: int) -> Dictionary:
	return await _server.handle_jsonrpc_request_async(JSON.stringify({
		"jsonrpc": "2.0",
		"id": id,
		"method": method,
		"params": params
	}))


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


func _has_template(templates, uri_template: String) -> bool:
	if not (templates is Array):
		return false
	for template in templates:
		if template is Dictionary and str((template as Dictionary).get("uriTemplate", "")) == uri_template:
			return true
	return false


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


func _prompt_text_is_actionable(text: String, required_fragments: Array[String]) -> bool:
	if text.length() < 450:
		return false
	for fragment in required_fragments:
		if text.find(fragment) == -1:
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


func _failure(message: String) -> Dictionary:
	return {
		"name": "mcp_resources_prompts_contracts",
		"success": false,
		"error": message
	}
