extends RefCounted

const HttpRequestDecoderScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_http_request_decoder.gd")


func run_case(_tree: SceneTree) -> Dictionary:
	var decoder = HttpRequestDecoderScript.new()

	var body := "{\"kind\":\"ping\"}"
	var content_length_request := (
		"POST /mcp HTTP/1.1\r\n"
		+ "Host: localhost\r\n"
		+ "Content-Length: %d\r\n\r\n%sNEXT"
	) % [body.to_utf8_buffer().size(), body]
	var decoded_content_length: Dictionary = decoder.decode_pending_request(content_length_request)
	if not bool(decoded_content_length.get("ready", false)):
		return _failure("Content-Length request should decode successfully.")
	if str((decoded_content_length.get("headers", {}) as Dictionary).get("method", "")) != "POST":
		return _failure("Decoded Content-Length request did not preserve the HTTP method.")
	if str((decoded_content_length.get("headers", {}) as Dictionary).get("path", "")) != "/mcp":
		return _failure("Decoded Content-Length request did not preserve the request path.")
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


func _failure(message: String) -> Dictionary:
	return {
		"name": "http_request_decoder_contracts",
		"success": false,
		"error": message
	}
