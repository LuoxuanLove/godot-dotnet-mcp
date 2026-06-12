extends RefCounted

const HttpRequestDecoderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_decoder.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var decoder = HttpRequestDecoderScript.new()

	var body := "{\"kind\":\"ping\"}"
	var content_length_request := (
		"POST /mcp HTTP/1.1\r\n"
		+ "Host: localhost\r\n"
		+ "Origin: http://localhost:5173\r\n"
		+ "Content-Type: application/json\r\n"
		+ "Authorization: Bearer test-token\r\n"
		+ "Content-Length: %d\r\n\r\n%sNEXT"
	) % [body.to_utf8_buffer().size(), body]
	var decoded_content_length: Dictionary = decoder.decode_pending_request(content_length_request)
	if not bool(decoded_content_length.get("ready", false)):
		return _failure("Content-Length request should decode successfully.")
	if str((decoded_content_length.get("headers", {}) as Dictionary).get("method", "")) != "POST":
		return _failure("Decoded Content-Length request did not preserve the HTTP method.")
	if str((decoded_content_length.get("headers", {}) as Dictionary).get("path", "")) != "/mcp":
		return _failure("Decoded Content-Length request did not preserve the request path.")
	if str((decoded_content_length.get("headers", {}) as Dictionary).get("origin", "")) != "http://localhost:5173":
		return _failure("Decoded Content-Length request did not preserve the Origin header.")
	if str((decoded_content_length.get("headers", {}) as Dictionary).get("content-type", "")) != "application/json":
		return _failure("Decoded Content-Length request did not preserve the Content-Type header.")
	if str((decoded_content_length.get("headers", {}) as Dictionary).get("authorization", "")) != "Bearer test-token":
		return _failure("Decoded Content-Length request did not preserve the Authorization header.")
	if str(decoded_content_length.get("request_body", "")) != body:
		return _failure("Decoded Content-Length request did not preserve the request body.")
	if str(decoded_content_length.get("remaining_data", "")) != "NEXT":
		return _failure("Decoded Content-Length request did not preserve trailing data.")

	var incomplete_headers: Dictionary = decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nContent-Length: 4\r\n")
	if bool(incomplete_headers.get("ready", false)) or str(incomplete_headers.get("waiting_for", "")) != "headers":
		return _failure("Decoder should wait for complete headers before returning a request.")

	var partial_body_request := "POST /mcp HTTP/1.1\r\nContent-Length: 4\r\n\r\nab"
	var incomplete_body: Dictionary = decoder.decode_pending_request(partial_body_request)
	if bool(incomplete_body.get("ready", false)) or str(incomplete_body.get("waiting_for", "")) != "body":
		return _failure("Decoder should wait for the full Content-Length body.")

	var non_numeric_length := decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nContent-Length: nope\r\n\r\n{}")
	var non_numeric_check := _assert_bad_content_length(non_numeric_length, "non-numeric")
	if not bool(non_numeric_check.get("success", false)):
		return non_numeric_check

	var negative_length := decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nContent-Length: -1\r\n\r\n{}")
	var negative_check := _assert_bad_content_length(negative_length, "negative")
	if not bool(negative_check.get("success", false)):
		return negative_check

	var zero_length: Dictionary = decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nContent-Length: 0\r\n\r\nNEXT")
	if not bool(zero_length.get("ready", false)):
		return _failure("HTTP Content-Length zero should be accepted as a complete empty body.")
	if bool(zero_length.get("framing_error", false)):
		return _failure("HTTP Content-Length zero should not be marked as a framing error.")
	if str(zero_length.get("request_body", "")) != "":
		return _failure("HTTP Content-Length zero should preserve an empty request body.")
	if str(zero_length.get("remaining_data", "")) != "NEXT":
		return _failure("HTTP Content-Length zero should preserve trailing data.")

	var oversized_length := decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nContent-Length: 1048577\r\n\r\n{}")
	var oversized_check := _assert_bad_content_length(oversized_length, "oversized")
	if not bool(oversized_check.get("success", false)):
		return oversized_check
	var duplicate_length := decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nContent-Length: 2\r\nContent-Length: 2\r\n\r\n{}")
	var duplicate_check := _assert_framing_error(duplicate_length, "duplicate_content_length", "duplicate Content-Length")
	if not bool(duplicate_check.get("success", false)):
		return duplicate_check
	var conflicting_framing := decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nContent-Length: 2\r\nTransfer-Encoding: chunked\r\n\r\n{}")
	var conflicting_check := _assert_framing_error(conflicting_framing, "conflicting_framing_headers", "conflicting Content-Length and Transfer-Encoding")
	if not bool(conflicting_check.get("success", false)):
		return conflicting_check

	var chunked_request := (
		"POST /mcp HTTP/1.1\r\n"
		+ "Transfer-Encoding: chunked\r\n\r\n"
		+ "5\r\nhello\r\n"
		+ "0\r\n\r\nNEXT"
	)
	var decoded_chunked: Dictionary = decoder.decode_pending_request(chunked_request)
	if not bool(decoded_chunked.get("ready", false)):
		return _failure("Chunked request should decode successfully.")
	if not bool(decoded_chunked.get("is_chunked", false)):
		return _failure("Chunked request should report is_chunked=true.")
	if str(decoded_chunked.get("request_body", "")) != "hello":
		return _failure("Chunked request body was not decoded correctly.")
	if str(decoded_chunked.get("remaining_data", "")) != "NEXT":
		return _failure("Chunked request should preserve trailing bytes.")
	var invalid_chunk_size := decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\nz\r\nhello\r\n0\r\n\r\n")
	var invalid_chunk_check := _assert_framing_error(invalid_chunk_size, "bad_chunk_size", "invalid chunk size")
	if not bool(invalid_chunk_check.get("success", false)):
		return invalid_chunk_check
	var invalid_chunk_terminator := decoder.decode_pending_request("POST /mcp HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhelloXX0\r\n\r\n")
	var invalid_chunk_terminator_check := _assert_framing_error(invalid_chunk_terminator, "bad_chunk_terminator", "invalid chunk terminator")
	if not bool(invalid_chunk_terminator_check.get("success", false)):
		return invalid_chunk_terminator_check

	var invalid_headers: Dictionary = decoder.decode_pending_request("\r\n\r\norphan-body")
	if not bool(invalid_headers.get("ready", false)):
		return _failure("Decoder should return a ready result when headers are syntactically complete but empty.")
	if not (invalid_headers.get("headers", {}) as Dictionary).is_empty():
		return _failure("Decoder should report empty headers for an invalid header section.")

	return {
		"name": "http_request_decoder_contracts",
		"success": true,
		"error": "",
		"details": {
			"content_length_body_size": int(decoded_content_length.get("body_byte_size", 0)),
			"chunked_remaining": str(decoded_chunked.get("remaining_data", "")),
			"waiting_state": str(incomplete_body.get("waiting_for", ""))
		}
	}


func _assert_bad_content_length(decoded: Dictionary, label: String) -> Dictionary:
	if not bool(decoded.get("ready", false)):
		return _failure("Invalid %s Content-Length should produce a ready framing error." % label)
	if not bool(decoded.get("framing_error", false)):
		return _failure("Invalid %s Content-Length should be marked as a framing error." % label)
	if str(decoded.get("error", "")) != "bad_content_length":
		return _failure("Invalid %s Content-Length should report bad_content_length." % label)
	if not str(decoded.get("message", "")).contains("Content-Length"):
		return _failure("Invalid %s Content-Length should describe the rejected header." % label)
	return {"success": true, "error": ""}


func _assert_framing_error(decoded: Dictionary, expected_error: String, label: String) -> Dictionary:
	if not bool(decoded.get("ready", false)):
		return _failure("Invalid %s should produce a ready framing error." % label)
	if not bool(decoded.get("framing_error", false)):
		return _failure("Invalid %s should be marked as a framing error." % label)
	if str(decoded.get("error", "")) != expected_error:
		return _failure("Invalid %s should report %s. actual=%s" % [label, expected_error, str(decoded.get("error", ""))])
	return {"success": true, "error": ""}


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_request_decoder_contracts",
		"success": false,
		"error": message
	}
