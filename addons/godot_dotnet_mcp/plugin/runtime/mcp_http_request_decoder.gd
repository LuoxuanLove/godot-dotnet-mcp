@tool
extends RefCounted
class_name MCPHttpRequestDecoder


func decode_pending_request(data: String) -> Dictionary:
	if data.is_empty():
		return _pending_result("empty")

	var header_end = data.find("\r\n\r\n")
	if header_end == -1:
		return _pending_result("headers")

	var header_section = data.substr(0, header_end)
	var headers = _parse_http_headers(header_section)
	if headers.is_empty():
		return {
			"ready": true,
			"headers": {},
			"request_body": "",
			"remaining_data": "",
			"content_length": 0,
			"body_byte_size": 0,
			"is_chunked": false
		}

	var content_length = 0
	var is_chunked = false
	if headers.has("content-length"):
		content_length = int(headers["content-length"])
	elif headers.has("transfer-encoding") and str(headers["transfer-encoding"]).to_lower().contains("chunked"):
		is_chunked = true

	var body_start = header_end + 4
	var body = data.substr(body_start)
	var body_bytes = body.to_utf8_buffer()
	var body_byte_size = body_bytes.size()

	if is_chunked:
		var decoded_chunked = _decode_chunked_body_bytes(body_bytes)
		if not bool(decoded_chunked.get("complete", false)):
			return _pending_result("chunked_body", headers, content_length, body_byte_size, true)
		var request_bytes: PackedByteArray = decoded_chunked.get("body", PackedByteArray())
		var remaining_bytes: PackedByteArray = decoded_chunked.get("remaining", PackedByteArray())
		return {
			"ready": true,
			"headers": headers,
			"request_body": request_bytes.get_string_from_utf8(),
			"remaining_data": remaining_bytes.get_string_from_utf8(),
			"content_length": content_length,
			"body_byte_size": body_byte_size,
			"is_chunked": true
		}

	if body_byte_size < content_length:
		return _pending_result("body", headers, content_length, body_byte_size, false)

	var request_bytes = body_bytes.slice(0, content_length)
	var remaining_data := ""
	if body_byte_size > content_length:
		remaining_data = body_bytes.slice(content_length).get_string_from_utf8()

	return {
		"ready": true,
		"headers": headers,
		"request_body": request_bytes.get_string_from_utf8(),
		"remaining_data": remaining_data,
		"content_length": content_length,
		"body_byte_size": body_byte_size,
		"is_chunked": false
	}


func _pending_result(waiting_for: String, headers: Dictionary = {}, content_length: int = 0, body_byte_size: int = 0, is_chunked: bool = false) -> Dictionary:
	return {
		"ready": false,
		"waiting_for": waiting_for,
		"headers": headers,
		"request_body": "",
		"remaining_data": "",
		"content_length": content_length,
		"body_byte_size": body_byte_size,
		"is_chunked": is_chunked
	}


func _parse_http_headers(header_section: String) -> Dictionary:
	var result: Dictionary = {}
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
			result[key] = value

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
			return {"complete": false}

		result.append_array(data.slice(chunk_start, chunk_end))
		pos = chunk_end + 2

	return {"complete": false}


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
