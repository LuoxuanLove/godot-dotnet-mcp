extends RefCounted

# {"name": "mcp_2025_11_25_conformance_contracts"}

const ProtocolFactsScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const StdioServerScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_stdio_server.gd")
const HttpRequestRouterContractScript = preload("res://tests/http_request_router_contract_test.gd")
const HttpTransportServiceContractScript = preload("res://tests/http_transport_service_contract_test.gd")

const CASE_NAME := "mcp_2025_11_25_conformance_contracts"
const MANIFEST_PATH := "res://scripts/contract_case_manifest.json"
const PROTOCOL_VERSION := "2025-11-25"

const REQUIRED_STREAMABLE_HTTP_SEMANTICS := {
	"http_request_router_contracts": [
		"post_accept_negotiation",
		"get_sse_negotiation",
		"protocol_version_headers",
		"sse_resume_metadata",
		"finite_post_sse",
		"session_termination"
	],
	"http_transport_service_contracts": [
		"long_lived_get_sse",
		"sse_heartbeat",
		"queued_event_delivery",
		"session_delete_disconnect",
		"bounded_cursor_replay"
	]
}

const REQUIRED_CASES := {
	"mcp_2025_11_25_conformance_contracts": {"axis": "aggregate_gate", "layer": "protocol", "domain": "conformance"},
	"json_rpc_request_service_contracts": {"axis": "json_rpc", "layer": "transport", "domain": "json_rpc"},
	"mcp_resources_prompts_contracts": {"axis": "resources_prompts", "layer": "protocol", "domain": "resources_prompts"},
	"tool_rpc_router_contracts": {"axis": "tools", "layer": "protocol", "domain": "tools"},
	"tool_manifest_contracts": {"axis": "catalog", "layer": "tooling", "domain": "catalog"},
	"tool_catalog_snapshot_service_contracts": {"axis": "catalog", "layer": "tooling", "domain": "catalog"},
	"tool_presentation_service_contracts": {"axis": "schema_metadata", "layer": "tooling", "domain": "catalog"},
	"tool_root_monolith_closure_contracts": {"axis": "tool_surface_cleanup", "layer": "tooling", "domain": "monolith", "conformance": "compat"},
	"tool_execution_service_contracts": {"axis": "service_convergence", "layer": "tooling", "domain": "loader"},
	"tool_loader_execution_context_service_contracts": {"axis": "service_convergence", "layer": "tooling", "domain": "loader"},
	"tool_loader_context_service_contracts": {"axis": "service_convergence", "layer": "tooling", "domain": "loader"},
	"http_request_router_contracts": {"axis": "streamable_http", "layer": "transport", "domain": "http"},
	"http_response_service_contracts": {"axis": "streamable_http", "layer": "transport", "domain": "http"},
	"http_transport_service_contracts": {"axis": "streamable_http", "layer": "transport", "domain": "http"},
	"stdio_tool_error_parity_contracts": {"axis": "stdio", "layer": "transport", "domain": "stdio"},
	"dock_model_service_contracts": {"axis": "ui_metadata", "layer": "dock", "domain": "model", "conformance": "optional"},
	"dock_mcp_catalog_preview_service_contracts": {"axis": "ui_metadata", "layer": "dock", "domain": "resources_prompts", "conformance": "optional"},
	"mcp_catalog_tab_rendering_contracts": {"axis": "ui_metadata", "layer": "dock", "domain": "resources_prompts", "conformance": "optional"},
	"tools_tab_rendering_contracts": {"axis": "ui_metadata", "layer": "dock", "domain": "tools", "conformance": "optional"}
}

const REQUIRED_AXES := [
	"aggregate_gate",
	"json_rpc",
	"resources_prompts",
	"tools",
	"catalog",
	"schema_metadata",
	"tool_surface_cleanup",
	"service_convergence",
	"streamable_http",
	"stdio",
	"ui_metadata"
]


func run_case(tree: SceneTree) -> Dictionary:
	var facts_check := _assert_protocol_facts()
	if not bool(facts_check.get("success", false)):
		return facts_check

	var stdio_framing := _get_stdio_framing_mode()
	var stdio_check := _assert_stdio_defaults()
	if not bool(stdio_check.get("success", false)):
		return stdio_check

	var manifest_result := _load_manifest()
	if not bool(manifest_result.get("success", false)):
		return manifest_result

	var manifest = manifest_result.get("manifest", [])
	if not (manifest is Array):
		return _failure("Contract case manifest should parse as an array.")

	var coverage_check := _assert_manifest_coverage(manifest)
	if not bool(coverage_check.get("success", false)):
		return coverage_check

	var transport_gate_check := await _assert_streamable_http_contract_semantics(tree)
	if not bool(transport_gate_check.get("success", false)):
		return transport_gate_check

	return {
		"name": CASE_NAME,
		"success": true,
		"error": "",
		"details": {
			"required_cases": REQUIRED_CASES.size(),
			"required_axes": REQUIRED_AXES,
			"protocol_version": ProtocolFactsScript.get_protocol_version(),
			"tool_schema_version": ProtocolFactsScript.get_tool_schema_version(),
			"stdio_framing": stdio_framing
		}
	}


func _assert_protocol_facts() -> Dictionary:
	if ProtocolFactsScript.get_protocol_version() != PROTOCOL_VERSION:
		return _failure("Protocol facts should default to MCP %s." % PROTOCOL_VERSION)
	if ProtocolFactsScript.get_server_name().is_empty():
		return _failure("Protocol facts should expose serverInfo.name.")
	if ProtocolFactsScript.get_server_version().is_empty():
		return _failure("Protocol facts should expose serverInfo.version.")
	if ProtocolFactsScript.get_server_description().is_empty():
		return _failure("Protocol facts should expose serverInfo.description for MCP 2025-11-25 metadata.")
	if ProtocolFactsScript.get_tool_schema_version().is_empty():
		return _failure("Protocol facts should expose the internal tool schema version.")
	return _success()


func _assert_stdio_defaults() -> Dictionary:
	var framing_mode := _get_stdio_framing_mode()
	if framing_mode != "newline":
		return _failure("Stdio transport should default to newline-delimited JSON-RPC framing.")
	return _success()


func _get_stdio_framing_mode() -> String:
	var stdio_server = StdioServerScript.new()
	var framing_mode := stdio_server.get_framing_mode()
	stdio_server.free()
	return framing_mode


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _failure("Harness stage should expose the contract case manifest at %s." % MANIFEST_PATH)
	var raw_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	if raw_text.strip_edges().is_empty():
		return _failure("Contract case manifest should not be empty.")
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		return _failure("Contract case manifest should parse as JSON: %s" % json.get_error_message())
	return {"success": true, "manifest": json.get_data()}


func _assert_manifest_coverage(manifest: Array) -> Dictionary:
	var entries_by_name := {}
	for raw_entry in manifest:
		if not (raw_entry is Dictionary):
			return _failure("Contract case manifest entries should be objects.")
		var entry: Dictionary = raw_entry
		var name := str(entry.get("name", ""))
		if name.is_empty():
			return _failure("Contract case manifest entries should have names.")
		if entries_by_name.has(name):
			return _failure("Contract case manifest should not contain duplicate case names: %s" % name)
		entries_by_name[name] = entry

	var seen_axes := {}
	for case_name in REQUIRED_CASES.keys():
		if not entries_by_name.has(case_name):
			return _failure("MCP 2025-11-25 conformance gate requires manifest case: %s" % case_name)
		var expected: Dictionary = REQUIRED_CASES[case_name]
		var entry: Dictionary = entries_by_name[case_name]
		var case_check := _assert_required_entry(case_name, entry, expected)
		if not bool(case_check.get("success", false)):
			return case_check
		seen_axes[str(expected.get("axis", ""))] = true

	for axis in REQUIRED_AXES:
		if not seen_axes.has(axis):
			return _failure("MCP 2025-11-25 conformance gate should cover axis: %s" % axis)

	return _success()


func _assert_required_entry(case_name: String, entry: Dictionary, expected: Dictionary) -> Dictionary:
	if str(entry.get("mcp_version", "")) != PROTOCOL_VERSION:
		return _failure("Required conformance case %s should target MCP %s." % [case_name, PROTOCOL_VERSION])
	var expected_conformance := str(expected.get("conformance", "required"))
	if str(entry.get("conformance", "")) != expected_conformance:
		return _failure("Required conformance case %s should be marked conformance=%s." % [case_name, expected_conformance])
	if str(entry.get("speed", "")) != "headless":
		return _failure("Required conformance case %s should stay in the headless gate." % case_name)
	if not ["pure", "stage_root"].has(str(entry.get("isolation", ""))):
		return _failure("Required conformance case %s should declare pure or stage_root isolation." % case_name)
	if not ["keep", "rewrite"].has(str(entry.get("v1_4_disposition", ""))):
		return _failure("Required conformance case %s should not be legacy/delete/remove disposition." % case_name)
	if str(entry.get("layer", "")) != str(expected.get("layer", "")):
		return _failure("Required conformance case %s should remain in layer=%s." % [case_name, expected.get("layer", "")])
	if str(entry.get("domain", "")) != str(expected.get("domain", "")):
		return _failure("Required conformance case %s should remain in domain=%s." % [case_name, expected.get("domain", "")])
	return _success()


func _assert_streamable_http_contract_semantics(tree: SceneTree) -> Dictionary:
	var router_contract = HttpRequestRouterContractScript.new()
	var router_result: Dictionary = await router_contract.run_case(tree)
	var router_check := _assert_streamable_http_semantics_result("http_request_router_contracts", router_result)
	if not bool(router_check.get("success", false)):
		return router_check

	var transport_contract = HttpTransportServiceContractScript.new()
	var transport_result: Dictionary = await transport_contract.run_case(tree)
	var transport_check := _assert_streamable_http_semantics_result("http_transport_service_contracts", transport_result)
	if not bool(transport_check.get("success", false)):
		return transport_check

	return _success()


func _assert_streamable_http_semantics_result(case_name: String, result: Dictionary) -> Dictionary:
	if not bool(result.get("success", false)):
		return _failure("Streamable HTTP conformance gate dependency failed: %s: %s" % [case_name, result.get("error", "")])
	var details: Dictionary = result.get("details", {})
	var semantics: Dictionary = details.get("streamable_http_semantics", {})
	if semantics.is_empty():
		return _failure("Streamable HTTP conformance dependency %s should report structured semantic coverage." % case_name)
	for semantic_name in REQUIRED_STREAMABLE_HTTP_SEMANTICS.get(case_name, []):
		if not bool(semantics.get(semantic_name, false)):
			return _failure("Streamable HTTP conformance dependency %s should prove semantic guard: %s" % [case_name, semantic_name])
	return _success()


func _success() -> Dictionary:
	return {"name": CASE_NAME, "success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {
		"name": CASE_NAME,
		"success": false,
		"error": message
	}
