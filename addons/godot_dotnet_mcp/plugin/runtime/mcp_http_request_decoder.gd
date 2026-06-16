@tool
extends RefCounted
class_name MCPHttpRequestDecoder

const MAX_CONTENT_LENGTH := 1024 * 1024


func decode_pending_request(data: String) -> Dictionary:
	return decode_pending_request_bytes(data.to_utf8_buffer())


func decode_pending_request_bytes(data: PackedByteArray) -> Dictionary:
	if data.is_empty():
		return _pending_result("empty")

	var header_end = _find_double_crlf_bytes(data, 0)
	if header_end == -1:
		return _pending_result("headers")

	var header_section = data.slice(0, max(header_end - 4, 0)).get_string_from_utf8()
	var headers = _parse_http_headers(header_section)
	if headers.is_empty():
		return {
			"ready": true,
			"headers": {},
			"request_body": "",
			"remaining_data": "",
			"request_body_bytes": PackedByteArray(),
			"remaining_bytes": PackedByteArray(),
			"content_length": 0,
			"body_byte_size": 0,
			"is_chunked": false
		}
	var duplicate_headers: Dictionary = headers.get("_duplicate_headers", {})
	if int(duplicate_headers.get("content-length", 0)) > 0:
		return _framing_error_result(
			"duplicate_content_length",
			"Duplicate Content-Length headers are not allowed.",
			headers
		)
	if headers.has("content-length") and headers.has("transfer-encoding"):
		return _framing_error_result(
			"conflicting_framing_headers",
			"Content-Length must not be combined with Transfer-Encoding.",
			headers
		)

	var content_length = 0
	var is_chunked = false
	if headers.has("content-length"):
		var content_length_result := _parse_content_length(str(headers["content-length"]))
		if not bool(content_length_result.get("success", false)):
			return _framing_error_result(
				"bad_content_length",
				str(content_length_result.get("error", "Invalid Content-Length header.")),
				headers
			)
		content_length = int(content_length_result.get("content_length", 0))
	elif headers.has("transfer-encoding") and str(headers["transfer-encoding"]).to_lower().contains("chunked"):
		is_chunked = true

	var body_start = header_end
	var body_bytes = data.slice(body_start, data.size())
	var body_byte_size = body_bytes.size()

	if is_chunked:
		var decoded_chunked = _decode_chunked_body_bytes(body_bytes)
		if bool(decoded_chunked.get("framing_error", false)):
			return _framing_error_result(
				str(decoded_chunked.get("error", "bad_chunked_body")),
				str(decoded_chunked.get("message", "Invalid chunked request body.")),
				headers,
				content_length,
				body_byte_size,
				true
			)
		if not bool(decoded_chunked.get("complete", false)):
			return _pending_result("chunked_body", headers, content_length, body_byte_size, true)
		var request_bytes: PackedByteArray = decoded_chunked.get("body", PackedByteArray())
		var remaining_bytes: PackedByteArray = decoded_chunked.get("remaining", PackedByteArray())
		return {
			"ready": true,
			"headers": headers,
			"request_body": request_bytes.get_string_from_utf8(),
			"remaining_data": remaining_bytes.get_string_from_utf8(),
			"request_body_bytes": request_bytes,
			"remaining_bytes": remaining_bytes,
			"content_length": content_length,
			"body_byte_size": body_byte_size,
			"is_chunked": true
		}

	if body_byte_size < content_length:
		return _pending_result("body", headers, content_length, body_byte_size, false)

	var request_bytes = body_bytes.slice(0, content_length)
	var remaining_bytes := PackedByteArray()
	if body_byte_size > content_length:
		remaining_bytes = body_bytes.slice(content_length, body_bytes.size())

	return {
		"ready": true,
		"headers": headers,
		"request_body": request_bytes.get_string_from_utf8(),
		"remaining_data": remaining_bytes.get_string_from_utf8(),
		"request_body_bytes": request_bytes,
		"remaining_bytes": remaining_bytes,
		"content_length": content_length,
		"body_byte_size": body_byte_size,
		"is_chunked": false
	}


func _parse_content_length(value: String) -> Dictionary:
	var text := value.strip_edges()
	if not text.is_valid_int():
		return {"success": false, "error": "Content-Length must be a positive integer."}
	var parsed := int(text)
	if parsed < 0:
		return {"success": false, "error": "Content-Length must not be negative."}
	if parsed > MAX_CONTENT_LENGTH:
		return {"success": false, "error": "Content-Length exceeds maximum supported size of %d bytes." % MAX_CONTENT_LENGTH}
	return {"success": true, "content_length": parsed}


func _framing_error_result(error_type: String, message: String, headers: Dictionary = {}, content_length: int = 0, body_byte_size: int = 0, is_chunked: bool = false) -> Dictionary:
	return {
		"ready": true,
		"framing_error": true,
		"error": error_type,
		"message": message,
		"headers": headers,
		"request_body": "",
		"remaining_data": "",
		"request_body_bytes": PackedByteArray(),
		"remaining_bytes": PackedByteArray(),
		"content_length": content_length,
		"body_byte_size": body_byte_size,
		"is_chunked": is_chunked
	}


func _pending_result(waiting_for: String, headers: Dictionary = {}, content_length: int = 0, body_byte_size: int = 0, is_chunked: bool = false) -> Dictionary:
	return {
		"ready": false,
		"waiting_for": waiting_for,
		"headers": headers,
		"request_body": "",
		"remaining_data": "",
		"request_body_bytes": PackedByteArray(),
		"remaining_bytes": PackedByteArray(),
		"content_length": content_length,
		"body_byte_size": body_byte_size,
		"is_chunked": is_chunked
	}


func _parse_http_headers(header_section: String) -> Dictionary:
	var result: Dictionary = {}
	var duplicate_headers: Dictionary = {}
	var lines = header_section.split("\r\n")
	if lines.is_empty():
		return result

	var request_line = lines[0].split(" ")
	if request_line.size() >= 2:
		result["method"] = request_line[0]
		result["path"] = request_line[1]

	for i in range(1, lines.size()):
		var line = lines[i]
		var colon_pos = line.find(":")
		if colon_pos > 0:
			var key = line.substr(0, colon_pos).strip_edges().to_lower()
			var value = line.substr(colon_pos + 1).strip_edges()
			if result.has(key):
				duplicate_headers[key] = int(duplicate_headers.get(key, 0)) + 1
			result[key] = value
	if not duplicate_headers.is_empty():
		result["_duplicate_headers"] = duplicate_headers

	return result


func _decode_chunked_body_bytes(data: PackedByteArray) -> Dictionary:
	var result := PackedByteArray()
	var pos = 0

	while pos < data.size():
		var line_end = _find_crlf_bytes(data, pos)
		if line_end == -1:
			return {"complete": false}

		var size_str = data.slice(pos, line_end).get_string_from_utf8().strip_edges()
		var semicolon = size_str.find(";")
		if semicolon != -1:
			size_str = size_str.substr(0, semicolon)
		size_str = size_str.strip_edges()
		if not _is_valid_chunk_size(size_str):
			return {
				"complete": true,
				"framing_error": true,
				"error": "bad_chunk_size",
				"message": "Chunk size must be a non-empty hexadecimal integer."
			}

		var chunk_size = size_str.hex_to_int()
		var chunk_start = line_end + 2

		if chunk_size == 0:
			if chunk_start + 1 < data.size() and data[chunk_start] == 13 and data[chunk_start + 1] == 10:
				return {
					"complete": true,
					"body": result,
					"remaining": data.slice(chunk_start + 2, data.size())
				}
			var trailer_end = _find_double_crlf_bytes(data, chunk_start)
			if trailer_end == -1:
				return {"complete": false}
			return {
				"complete": true,
				"body": result,
				"remaining": data.slice(trailer_end, data.size())
			}

		var chunk_end = chunk_start + chunk_size
		if chunk_end + 2 > data.size():
			return {"complete": false}
		if data[chunk_end] != 13 or data[chunk_end + 1] != 10:
			return {
				"complete": true,
				"framing_error": true,
				"error": "bad_chunk_terminator",
				"message": "Chunk data must be followed by CRLF."
			}

		result.append_array(data.slice(chunk_start, chunk_end))
		pos = chunk_end + 2

	return {"complete": false}


func _is_valid_chunk_size(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper_hex := code >= 65 and code <= 70
		var is_lower_hex := code >= 97 and code <= 102
		if not (is_digit or is_upper_hex or is_lower_hex):
			return false
	return true


func _find_crlf_bytes(data: PackedByteArray, start: int) -> int:
	for index in range(start, data.size() - 1):
		if data[index] == 13 and data[index + 1] == 10:
			return index
	return -1


func _find_double_crlf_bytes(data: PackedByteArray, start: int) -> int:
	for index in range(start, data.size() - 3):
		if data[index] == 13 and data[index + 1] == 10 and data[index + 2] == 13 and data[index + 3] == 10:
			return index + 4
	return -1
