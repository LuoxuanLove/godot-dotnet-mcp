@tool
extends RefCounted
class_name MCPEditorLifecycleResponseBuilder


func build_success(data, message: String) -> Dictionary:
	return {
		"success": true,
		"data": data,
		"message": message
	}


func build_error(error: String, message: String, data: Dictionary = {}) -> Dictionary:
	var result := {
		"success": false,
		"error": error,
		"message": message,
		"status": 400
	}
	if not data.is_empty():
		result["data"] = data.duplicate(true)
	return result
