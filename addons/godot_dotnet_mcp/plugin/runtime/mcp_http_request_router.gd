@tool
extends RefCounted
class_name MCPHttpRequestRouter

const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")
const MCPHttpSseEventQueueScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_sse_event_queue.gd")
const ENV_ALLOWED_CORS_ORIGINS := "GODOT_DOTNET_MCP_ALLOWED_CORS_ORIGINS"
const STREAMABLE_HTTP_ALLOW_HEADERS := "Content-Type, Accept, MCP-Protocol-Version, Mcp-Session-Id, Last-Event-ID"
const SESSION_ID_PREFIX := "godot-dotnet-mcp-http"

var _handle_mcp_request_async := Callable()
var _build_health_response := Callable()
var _build_tools_list_response := Callable()
var _handle_editor_lifecycle_request := Callable()
var _handle_editor_lifecycle_post_request := Callable()
var _build_cors_response := Callable()
var _sse_event_queue = null
var _owns_sse_event_queue := false
var _allowed_cors_origins: Array[String] = []
var _allowed_hosts: Array[String] = []


func configure(context = null) -> void:
	if context == null:
		dispose()
		return
	_handle_mcp_request_async = context.handle_mcp_request_async
	_build_health_response = context.build_health_response
	_build_tools_list_response = context.build_tools_list_response
	_handle_editor_lifecycle_request = context.handle_editor_lifecycle_request
	_handle_editor_lifecycle_post_request = context.handle_editor_lifecycle_post_request
	_build_cors_response = context.build_cors_response
	_sse_event_queue = context.sse_event_queue
	_owns_sse_event_queue = false
	if _sse_event_queue == null:
		_sse_event_queue = MCPHttpSseEventQueueScript.new()
		_owns_sse_event_queue = true
	_allowed_cors_origins = _read_allowed_cors_origins()


func dispose() -> void:
	_handle_mcp_request_async = Callable()
	_build_health_response = Callable()
	_build_tools_list_response = Callable()
	_handle_editor_lifecycle_request = Callable()
	_handle_editor_lifecycle_post_request = Callable()
	_build_cors_response = Callable()
	if _owns_sse_event_queue and _sse_event_queue != null and _sse_event_queue.has_method("dispose"):
		_sse_event_queue.dispose()
	_sse_event_queue = null
	_owns_sse_event_queue = false
	_allowed_cors_origins = []
	_allowed_hosts = []


func set_allowed_cors_origins(value) -> void:
	_allowed_cors_origins = _normalize_allowed_origins(value)


func set_allowed_hosts(value) -> void:
	_allowed_hosts = _normalize_allowed_hosts(value)


func route_request_async(method: String, path: String, request_body: String, headers: Dictionary = {}) -> Dictionary:
	var normalized_headers := _normalize_headers(headers)
	if method == "POST" and path == "/mcp":
		normalized_headers["_request_body"] = request_body
	if not _is_host_allowed(str(normalized_headers.get("host", ""))):
		return _forbidden("HTTP Host is not allowed")

	var origin := str(normalized_headers.get("origin", "")).strip_edges()
	var has_origin := not origin.is_empty()
	if has_origin and not _is_origin_allowed(origin):
		return _forbidden("HTTP Origin is not allowed")

	if method == "OPTIONS":
		return _build_options_response(path, origin)

	if method == "POST" and _requires_json_content_type(path):
		var content_type := str(normalized_headers.get("content-type", "")).strip_edges().to_lower()
		if content_type.is_empty() and path == "/mcp":
			return {
				"error": "Unsupported media type",
				"status": 415,
				"details": "POST /mcp requires Content-Type: application/json."
			}
		if not content_type.is_empty() and not _is_json_content_type(content_type):
			return {
				"error": "Unsupported media type",
				"status": 415
			}

	var response: Dictionary
	if method == "POST" and path == "/mcp":
		var transport_guard := _validate_mcp_transport_headers(normalized_headers)
		if not transport_guard.is_empty():
			return _attach_cors_headers(_attach_mcp_transport_headers(transport_guard, normalized_headers), origin, path)
		var terminated_guard := _validate_mcp_session_active(normalized_headers)
		if not terminated_guard.is_empty():
			return _attach_cors_headers(_attach_mcp_transport_headers(terminated_guard, normalized_headers), origin, path)
		response = await _call_async(_handle_mcp_request_async, [request_body], {"error": "MCP request handler is unavailable", "status": 500})
		if _prefers_sse_response(str(normalized_headers.get("accept", ""))) and _is_json_rpc_message(response):
			return _attach_cors_headers(_attach_mcp_transport_headers(_build_mcp_post_sse_response(normalized_headers, response), normalized_headers), origin, path)
		return _attach_cors_headers(_attach_mcp_transport_headers(response, normalized_headers), origin, path)

	if method == "GET" and path == "/mcp":
		var sse_guard := _validate_mcp_sse_headers(normalized_headers)
		if not sse_guard.is_empty():
			return _attach_cors_headers(_attach_mcp_transport_headers(sse_guard, normalized_headers), origin, path)
		var terminated_sse_guard := _validate_mcp_session_active(normalized_headers)
		if not terminated_sse_guard.is_empty():
			return _attach_cors_headers(_attach_mcp_transport_headers(terminated_sse_guard, normalized_headers), origin, path)
		return _attach_cors_headers(_attach_mcp_transport_headers(_build_mcp_sse_stream_response(normalized_headers), normalized_headers), origin, path)

	if method == "DELETE" and path == "/mcp":
		var delete_guard := _validate_mcp_delete_headers(normalized_headers)
		if not delete_guard.is_empty():
			return _attach_cors_headers(_attach_mcp_transport_headers(delete_guard, normalized_headers), origin, path)
		return _attach_cors_headers(_attach_mcp_transport_headers(_build_mcp_session_terminated_response(normalized_headers), normalized_headers), origin, path)

	if method == "GET" and path == "/health":
		response = _call_dict(_build_health_response, [], {"status": "degraded", "error": "Health response builder is unavailable", "status_code": 500})
		return _attach_cors_headers(response, origin, path)

	if method == "GET" and path == "/api/tools":
		response = _call_dict(_build_tools_list_response, [], {})
		return _attach_cors_headers(response, origin, path)

	if method == "GET" and path == "/api/editor/lifecycle":
		response = _call_dict(_handle_editor_lifecycle_request, ["status", {}], {"error": "editor_lifecycle_unavailable", "status": 500})
		return _attach_cors_headers(response, origin, path)

	if method == "POST" and path == "/api/editor/lifecycle":
		response = _call_dict(_handle_editor_lifecycle_post_request, [request_body], {"error": "editor_lifecycle_unavailable", "status": 500})
		return _attach_cors_headers(response, origin, path)

	return {"error": "Not found", "status": 404}


func _build_options_response(path: String, origin: String) -> Dictionary:
	var allowed_methods := _allowed_methods_for_path(path)
	if allowed_methods.is_empty():
		return {"error": "Not found", "status": 404}
	if origin.strip_edges().is_empty():
		return {
			"status": 405,
			"_no_body": true,
			"_headers": {
				"Allow": allowed_methods
			}
		}
	return _call_dict(
		_build_cors_response,
		[origin, allowed_methods, STREAMABLE_HTTP_ALLOW_HEADERS],
		{
			"_status_code": 204,
			"_no_body": true,
			"_headers": _build_cors_headers(origin, allowed_methods)
		}
	)


func _attach_cors_headers(response: Dictionary, origin: String, path: String) -> Dictionary:
	if origin.strip_edges().is_empty():
		return response
	var enriched := response.duplicate(true)
	var response_headers := {}
	if enriched.has("_headers") and enriched["_headers"] is Dictionary:
		response_headers = (enriched["_headers"] as Dictionary).duplicate(true)
	var cors_headers := _build_cors_headers(origin, _allowed_methods_for_path(path))
	for header_name in cors_headers:
		response_headers[header_name] = cors_headers[header_name]
	enriched["_headers"] = response_headers
	return enriched


func _build_cors_headers(origin: String, allow_methods: String) -> Dictionary:
	return {
		"Access-Control-Allow-Origin": origin.strip_edges(),
		"Access-Control-Allow-Methods": allow_methods,
		"Access-Control-Allow-Headers": STREAMABLE_HTTP_ALLOW_HEADERS,
		"Access-Control-Max-Age": "86400",
		"Vary": "Origin"
	}


func _allowed_methods_for_path(path: String) -> String:
	match path:
		"/mcp":
			return "GET, POST, DELETE"
		"/health", "/api/tools":
			return "GET"
		"/api/editor/lifecycle":
			return "GET, POST"
		_:
			return ""


func _requires_json_content_type(path: String) -> bool:
	return path == "/mcp" or path == "/api/editor/lifecycle"


func _validate_mcp_transport_headers(headers: Dictionary) -> Dictionary:
	var session_guard := _validate_mcp_session_id_header(headers)
	if not session_guard.is_empty():
		return session_guard
	var active_session_guard := _validate_mcp_existing_session(headers)
	if not active_session_guard.is_empty():
		return active_session_guard

	var accept_header := str(headers.get("accept", "")).strip_edges()
	if not _accepts_mcp_response(accept_header):
		return {
			"error": "Not acceptable",
			"status": 406,
			"details": "POST /mcp requires Accept to include both application/json and text/event-stream."
		}

	var requested_version := str(headers.get("mcp-protocol-version", "")).strip_edges()
	var supported_version := MCPProtocolFacts.get_protocol_version()
	if requested_version.is_empty() and _is_initialize_request_body(str(headers.get("_request_body", ""))):
		return {}
	if requested_version.is_empty():
		return {
			"error": "Missing MCP protocol version",
			"status": 400,
			"supported_protocol_version": supported_version,
			"details": "POST /mcp requires MCP-Protocol-Version: %s." % supported_version
		}
	if requested_version != supported_version:
		return {
			"error": "Unsupported MCP protocol version",
			"status": 400,
			"supported_protocol_version": supported_version,
			"requested_protocol_version": requested_version
		}

	return {}


func _validate_mcp_sse_headers(headers: Dictionary) -> Dictionary:
	var session_guard := _validate_mcp_session_id_header(headers)
	if not session_guard.is_empty():
		return session_guard
	var active_session_guard := _validate_mcp_existing_session(headers)
	if not active_session_guard.is_empty():
		return active_session_guard

	var accept_header := str(headers.get("accept", "")).strip_edges()
	if not _accepts_sse_response(accept_header):
		return {
			"error": "Not acceptable",
			"status": 406,
			"details": "GET /mcp requires Accept to include text/event-stream."
		}

	var requested_version := str(headers.get("mcp-protocol-version", "")).strip_edges()
	var supported_version := MCPProtocolFacts.get_protocol_version()
	if requested_version.is_empty():
		return {
			"error": "Missing MCP protocol version",
			"status": 400,
			"supported_protocol_version": supported_version,
			"details": "GET /mcp requires MCP-Protocol-Version: %s." % supported_version
		}
	if requested_version != supported_version:
		return {
			"error": "Unsupported MCP protocol version",
			"status": 400,
			"supported_protocol_version": supported_version,
			"requested_protocol_version": requested_version
		}

	return {}


func _validate_mcp_delete_headers(headers: Dictionary) -> Dictionary:
	var session_guard := _validate_mcp_session_id_header(headers)
	if not session_guard.is_empty():
		return session_guard
	var requested_session := str(headers.get("mcp-session-id", "")).strip_edges()
	if requested_session.is_empty():
		return {
			"error": "Missing MCP session id",
			"status": 400,
			"details": "DELETE /mcp requires Mcp-Session-Id."
		}
	var requested_version := str(headers.get("mcp-protocol-version", "")).strip_edges()
	var supported_version := MCPProtocolFacts.get_protocol_version()
	if requested_version.is_empty():
		return {
			"error": "Missing MCP protocol version",
			"status": 400,
			"supported_protocol_version": supported_version,
			"details": "DELETE /mcp requires MCP-Protocol-Version: %s." % supported_version
		}
	if requested_version != supported_version:
		return {
			"error": "Unsupported MCP protocol version",
			"status": 400,
			"supported_protocol_version": supported_version,
			"requested_protocol_version": requested_version
		}
	if not _has_mcp_session(requested_session):
		return {
			"error": "MCP session not found",
			"status": 404,
			"details": "The MCP session is unknown or expired."
		}
	if _is_mcp_session_terminated(requested_session):
		return {
			"error": "MCP session not found",
			"status": 404,
			"details": "The MCP session has already been terminated."
		}
	return {}


func _validate_mcp_session_active(headers: Dictionary) -> Dictionary:
	var requested_session := str(headers.get("mcp-session-id", "")).strip_edges()
	if requested_session.is_empty():
		return {}
	if _is_mcp_session_terminated(requested_session):
		return {
			"error": "MCP session not found",
			"status": 404,
			"details": "The MCP session has been terminated."
		}
	return {}


func _validate_mcp_existing_session(headers: Dictionary) -> Dictionary:
	var requested_session := str(headers.get("mcp-session-id", "")).strip_edges()
	if requested_session.is_empty():
		return {}
	if not _has_mcp_session(requested_session) or _is_mcp_session_terminated(requested_session):
		return {
			"error": "MCP session not found",
			"status": 404,
			"details": "The MCP session is unknown or expired."
		}
	return {}


func _build_mcp_sse_stream_response(headers: Dictionary) -> Dictionary:
	var session_id := _resolve_mcp_session_id(headers)
	var last_event_id := str(headers.get("last-event-id", "")).strip_edges()
	var event := _append_sse_open_event(session_id, last_event_id)
	var events := _sse_events_after_cursor(session_id, last_event_id)
	if events.is_empty():
		events = [event]
	var next_event_index := _sse_event_count(session_id)
	return {
		"status": 200,
		"_stream_mode": "sse",
		"_raw_body": _format_sse_events(events),
		"_content_type": "text/event-stream; charset=utf-8",
		"_mcp_session_id": session_id,
		"_sse_session_id": session_id,
		"_sse_next_event_index": next_event_index,
		"_headers": {
			"Cache-Control": "no-cache, no-transform",
			"X-Accel-Buffering": "no"
		}
	}


func _build_mcp_post_sse_response(headers: Dictionary, json_rpc_response: Dictionary) -> Dictionary:
	var establish_session := _is_successful_initialize_response(json_rpc_response)
	var requested_session := str(headers.get("mcp-session-id", "")).strip_edges()
	var has_existing_session := not requested_session.is_empty() and _has_mcp_session(requested_session) and not _is_mcp_session_terminated(requested_session)
	var should_queue_event := establish_session or has_existing_session
	var session_id := _resolve_mcp_session_id(headers) if should_queue_event else ""
	var event := _append_sse_event(session_id, json_rpc_response.duplicate(true), "streamable-http-post") if should_queue_event else _build_one_shot_sse_event(json_rpc_response)
	var response := {
		"status": 200,
		"_raw_body": _format_sse_events([event]),
		"_content_type": "text/event-stream; charset=utf-8",
		"_headers": {
			"Cache-Control": "no-cache, no-transform",
			"X-Accel-Buffering": "no"
		}
	}
	if should_queue_event:
		response["_mcp_session_id"] = session_id
	if establish_session:
		response["_establish_mcp_session"] = true
	return response


func _build_mcp_session_terminated_response(headers: Dictionary) -> Dictionary:
	var session_id := _resolve_mcp_session_id(headers)
	var termination := _terminate_mcp_session(session_id)
	return {
		"status": 204,
		"_no_body": true,
		"_mcp_session_id": session_id,
		"_terminate_mcp_session_id": session_id,
		"_headers": {
			"Cache-Control": "no-cache, no-transform",
			"X-MCP-Session-Terminated": "true",
			"X-MCP-Terminated-Event-Count": str(int(termination.get("event_count_before", 0)))
		}
	}


func _append_sse_open_event(session_id: String, last_event_id: String) -> Dictionary:
	var resume_status := _sse_resume_status(session_id, last_event_id)
	return _append_sse_event(session_id, {
		"transport": "streamable_http",
		"mode": "sse_stream",
		"resume_from_event_id": last_event_id,
		"resume_cursor_found": bool(resume_status.get("found", false)),
		"resume_status": str(resume_status.get("status", "matched" if bool(resume_status.get("found", false)) else "unknown_session")),
		"replay_event_count": int(resume_status.get("event_count_after_cursor", 0)),
		"resume_start_index": int(resume_status.get("start_index", 0)),
		"resume_base_index": int(resume_status.get("base_index", 0)),
		"resume_next_index": int(resume_status.get("next_index", 0))
	}, "streamable-http-get")


func _append_sse_event(session_id: String, payload: Dictionary, id_prefix: String) -> Dictionary:
	if _sse_event_queue != null and _sse_event_queue.has_method("append_event"):
		return _sse_event_queue.append_event(session_id, "message", payload, id_prefix)
	return {}


func _build_one_shot_sse_event(json_rpc_response: Dictionary) -> Dictionary:
	return {
		"id": "streamable-http-one-shot-%s" % str(Time.get_ticks_usec()),
		"event": "message",
		"retry": MCPHttpSseEventQueueScript.SSE_RETRY_MS,
		"data": json_rpc_response.duplicate(true)
	}


func _sse_events_after_cursor(session_id: String, last_event_id: String) -> Array:
	if _sse_event_queue != null and _sse_event_queue.has_method("events_after_cursor"):
		return _sse_event_queue.events_after_cursor(session_id, last_event_id)
	return []


func _sse_event_count(session_id: String) -> int:
	if _sse_event_queue != null and _sse_event_queue.has_method("event_count"):
		return int(_sse_event_queue.event_count(session_id))
	return 0


func _sse_resume_status(session_id: String, last_event_id: String) -> Dictionary:
	if _sse_event_queue != null and _sse_event_queue.has_method("resume_status"):
		return _sse_event_queue.resume_status(session_id, last_event_id)
	return {"found": false, "event_count_after_cursor": 0}


func _terminate_mcp_session(session_id: String) -> Dictionary:
	if _sse_event_queue != null and _sse_event_queue.has_method("terminate_session"):
		var result = _sse_event_queue.terminate_session(session_id)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return {"session_id": session_id, "terminated": false, "event_count_before": 0}


func _remember_mcp_session(session_id: String) -> void:
	if _sse_event_queue != null and _sse_event_queue.has_method("remember_session"):
		_sse_event_queue.remember_session(session_id)


func _should_remember_mcp_session(response: Dictionary) -> bool:
	if bool(response.get("_establish_mcp_session", false)):
		return true
	if response.has("_terminate_mcp_session_id"):
		return false
	return false


func _is_mcp_session_terminated(session_id: String) -> bool:
	if _sse_event_queue != null and _sse_event_queue.has_method("is_session_terminated"):
		return bool(_sse_event_queue.is_session_terminated(session_id))
	return false


func _has_mcp_session(session_id: String) -> bool:
	if _sse_event_queue != null and _sse_event_queue.has_method("has_session"):
		return bool(_sse_event_queue.has_session(session_id))
	return false


func _format_sse_events(events: Array) -> String:
	if _sse_event_queue != null and _sse_event_queue.has_method("format_events"):
		return str(_sse_event_queue.format_events(events))
	return ""


func _attach_mcp_transport_headers(response: Dictionary, request_headers: Dictionary) -> Dictionary:
	var enriched := response.duplicate(true)
	var response_session_id := str(enriched.get("_mcp_session_id", "")).strip_edges()
	if enriched.has("_mcp_session_id"):
		enriched.erase("_mcp_session_id")
	var establish_session := bool(enriched.get("_establish_mcp_session", false)) or _is_successful_initialize_response(enriched)
	if enriched.has("_establish_mcp_session"):
		enriched.erase("_establish_mcp_session")
	var response_headers := {}
	if enriched.has("_headers") and enriched["_headers"] is Dictionary:
		response_headers = (enriched["_headers"] as Dictionary).duplicate(true)
	response_headers["MCP-Protocol-Version"] = MCPProtocolFacts.get_protocol_version()
	if establish_session:
		enriched["_establish_mcp_session"] = true
	if _should_remember_mcp_session(enriched):
		var resolved_session_id := response_session_id if not response_session_id.is_empty() else _resolve_mcp_session_id(request_headers)
		response_headers["Mcp-Session-Id"] = resolved_session_id
		_remember_mcp_session(resolved_session_id)
	elif not response_session_id.is_empty() and _has_mcp_session(response_session_id) and not _is_mcp_session_terminated(response_session_id):
		response_headers["Mcp-Session-Id"] = response_session_id
	else:
		var request_session_id := str(request_headers.get("mcp-session-id", "")).strip_edges()
		if not request_session_id.is_empty() and _has_mcp_session(request_session_id) and not _is_mcp_session_terminated(request_session_id):
			response_headers["Mcp-Session-Id"] = request_session_id
	if enriched.has("_establish_mcp_session"):
		enriched.erase("_establish_mcp_session")
	enriched["_headers"] = response_headers
	return enriched


func _resolve_mcp_session_id(headers: Dictionary) -> String:
	var requested_session := str(headers.get("mcp-session-id", "")).strip_edges()
	if not requested_session.is_empty() and _is_safe_http_header_value(requested_session):
		return requested_session
	return _generate_mcp_session_id()


func _validate_mcp_session_id_header(headers: Dictionary) -> Dictionary:
	var requested_session := str(headers.get("mcp-session-id", ""))
	if requested_session.strip_edges().is_empty():
		return {}
	if not _is_safe_http_header_value(requested_session):
		return {
			"error": "Invalid MCP session id",
			"status": 400,
			"details": "Mcp-Session-Id must be a single-line printable HTTP header value."
		}
	return {}


func _is_safe_http_header_value(value: String) -> bool:
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code < 32 or code == 127:
			return false
	return true


func _generate_mcp_session_id() -> String:
	return "%s-%s-%s-%s-%s" % [
		SESSION_ID_PREFIX,
		MCPProtocolFacts.get_server_version().replace(".", "-"),
		str(Time.get_ticks_usec()),
		str(get_instance_id()),
		str(randi())
	]


func _is_initialize_request_body(body: String) -> bool:
	var json := JSON.new()
	if json.parse(body) != OK:
		return false
	var data: Variant = json.get_data()
	if not (data is Dictionary):
		return false
	return str((data as Dictionary).get("method", "")) == "initialize"


func _is_successful_initialize_response(response: Dictionary) -> bool:
	if str(response.get("jsonrpc", "")) != "2.0":
		return false
	if response.has("error"):
		return false
	if not (response.get("result") is Dictionary):
		return false
	var result: Dictionary = response.get("result", {})
	return result.has("protocolVersion") and result.has("serverInfo")


func _accepts_json_response(accept_header: String) -> bool:
	for raw_part in accept_header.split(",", false):
		var media_type := str(raw_part).strip_edges().to_lower()
		var semicolon_pos := media_type.find(";")
		if semicolon_pos >= 0:
			media_type = media_type.substr(0, semicolon_pos).strip_edges()
		if media_type == "application/json" or media_type == "*/*" or media_type == "application/*":
			return true
	return false


func _is_json_content_type(content_type: String) -> bool:
	return content_type == "application/json" or content_type.begins_with("application/json;")


func _accepts_mcp_response(accept_header: String) -> bool:
	var normalized := accept_header.strip_edges().to_lower()
	if normalized.is_empty():
		return false
	var accepts_json := false
	var accepts_sse := false
	for raw_part in normalized.split(",", false):
		var parsed := _parse_accept_part(str(raw_part))
		var media_range := str(parsed.get("media_range", ""))
		var quality := float(parsed.get("q", 1.0))
		if quality <= 0.0:
			continue
		if media_range == "application/json":
			accepts_json = true
		elif media_range == "text/event-stream":
			accepts_sse = true
	return accepts_json and accepts_sse


func _prefers_sse_response(accept_header: String) -> bool:
	var json_q := -1.0
	var sse_q := -1.0
	for raw_part in accept_header.split(",", false):
		var parsed := _parse_accept_part(str(raw_part))
		var media_range := str(parsed.get("media_range", ""))
		var quality := float(parsed.get("q", 1.0))
		if media_range == "text/event-stream":
			sse_q = max(sse_q, quality)
		elif media_range == "application/json":
			json_q = max(json_q, quality)
	return sse_q > json_q and sse_q > 0.0


func _parse_accept_part(raw_part: String) -> Dictionary:
	var parts := raw_part.strip_edges().to_lower().split(";", false)
	var media_range := str(parts[0]).strip_edges() if parts.size() > 0 else ""
	var quality := 1.0
	for index in range(1, parts.size()):
		var parameter := str(parts[index]).strip_edges()
		if not parameter.begins_with("q="):
			continue
		var q_text := parameter.substr(2).strip_edges()
		if q_text.is_valid_float():
			quality = clamp(float(q_text), 0.0, 1.0)
	return {
		"media_range": media_range,
		"q": quality
	}


func _accepts_sse_response(accept_header: String) -> bool:
	var normalized := accept_header.strip_edges().to_lower()
	if normalized.is_empty():
		return false
	for raw_part in normalized.split(",", false):
		var parsed := _parse_accept_part(str(raw_part))
		var media_range := str(parsed.get("media_range", ""))
		var quality := float(parsed.get("q", 1.0))
		if media_range == "text/event-stream" and quality > 0.0:
			return true
	return false


func _is_json_rpc_message(value: Dictionary) -> bool:
	return str(value.get("jsonrpc", "")) == "2.0" and (value.has("result") or value.has("error"))


func _sanitize_sse_token(value: String) -> String:
	var sanitized := value.strip_edges()
	if sanitized.is_empty():
		return "anonymous"
	return sanitized.replace("\r", "_").replace("\n", "_").replace(" ", "_").replace(":", "-")


func _is_origin_allowed(origin: String) -> bool:
	var normalized_origin := origin.strip_edges()
	if normalized_origin.is_empty() or normalized_origin == "null":
		return false
	for allowed_origin in _allowed_cors_origins:
		if normalized_origin == allowed_origin:
			return true
	return false


func _is_host_allowed(host_header: String) -> bool:
	var hostname := _normalize_host_name(host_header)
	if hostname.is_empty():
		return true
	if hostname == "127.0.0.1" or hostname == "localhost" or hostname == "::1":
		return true
	return _allowed_hosts.has(hostname)


func _normalize_host_name(host_value: String) -> String:
	var normalized_host := host_value.strip_edges().to_lower()
	if normalized_host.is_empty():
		return ""
	if normalized_host.begins_with("["):
		var closing_bracket := normalized_host.find("]")
		if closing_bracket == -1:
			return ""
		return normalized_host.substr(1, closing_bracket - 1)
	var colon_pos := normalized_host.rfind(":")
	if colon_pos > -1 and normalized_host.count(":") == 1:
		return normalized_host.substr(0, colon_pos)
	return normalized_host


func _normalize_headers(headers: Dictionary) -> Dictionary:
	var normalized := {}
	for key in headers:
		normalized[str(key).strip_edges().to_lower()] = headers[key]
	return normalized


func _normalize_allowed_origins(value) -> Array[String]:
	var origins: Array[String] = []
	if not (value is Array):
		return origins
	for origin_value in value:
		var origin := str(origin_value).strip_edges()
		if origin.is_empty():
			continue
		origins.append(origin)
	return origins


func _normalize_allowed_hosts(value) -> Array[String]:
	var hosts: Array[String] = []
	if not (value is Array):
		return hosts
	for host_value in value:
		var hostname := _normalize_host_name(str(host_value))
		if hostname.is_empty() or hostname == "0.0.0.0" or hostname == "::" or hostname == "*":
			continue
		if hosts.has(hostname):
			continue
		hosts.append(hostname)
	return hosts


func _read_allowed_cors_origins() -> Array[String]:
	if not OS.has_environment(ENV_ALLOWED_CORS_ORIGINS):
		return []
	var raw_origins := OS.get_environment(ENV_ALLOWED_CORS_ORIGINS).replace(";", ",").split(",", false)
	return _normalize_allowed_origins(raw_origins)


func _forbidden(message: String) -> Dictionary:
	return {
		"error": message,
		"status": 403
	}


func _call_dict(callable_obj: Callable, args: Array, fallback: Dictionary) -> Dictionary:
	if callable_obj.is_valid():
		var result = callable_obj.callv(args)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
	return fallback.duplicate(true)


func _call_async(callable_obj: Callable, args: Array, fallback: Dictionary) -> Dictionary:
	if callable_obj.is_valid():
		var result = callable_obj.callv(args)
		if result is Dictionary:
			return (result as Dictionary).duplicate(true)
		if result != null:
			result = await result
			if result is Dictionary:
				return (result as Dictionary).duplicate(true)
	return fallback.duplicate(true)
