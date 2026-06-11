@tool
extends RefCounted
class_name MCPJsonRpcEnvelopeValidator


static func validate_request_envelope(request: Dictionary) -> Dictionary:
	var has_id := request.has("id")
	var id = request.get("id")
	if str(request.get("jsonrpc", "")) != "2.0":
		return _invalid(has_id, id, "Invalid Request: jsonrpc must be \"2.0\"")

	var method = request.get("method")
	if not (method is String) or str(method).strip_edges().is_empty():
		return _invalid(has_id, id, "Invalid Request: method must be a non-empty string")

	if has_id and not _is_valid_request_id(id):
		var invalid_id_result := _invalid(true, null, "Invalid Request: id must be a string, number, or null")
		invalid_id_result["invalid_id"] = true
		return invalid_id_result

	return {
		"success": true,
		"has_id": has_id,
		"id": id,
		"method": str(method)
	}


static func _invalid(has_id: bool, id, message: String) -> Dictionary:
	return {
		"success": false,
		"has_id": true,
		"id": id,
		"request_had_id": has_id,
		"code": -32600,
		"message": message
	}


static func _is_valid_request_id(id) -> bool:
	if id == null:
		return true
	if id is String:
		return true
	if id is int:
		return true
	if id is float:
		return true
	return false
