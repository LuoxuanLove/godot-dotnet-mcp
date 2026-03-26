@tool
extends RefCounted
class_name ClientConfigFileSupport


func get_backup_path(filepath: String) -> String:
	return "%s.bak" % filepath


func backup_existing_file(filepath: String) -> Dictionary:
	var backup_path = get_backup_path(filepath)
	var copy_result = copy_text_file(filepath, backup_path)
	if not bool(copy_result.get("success", false)):
		return {
			"success": false,
			"backup_path": backup_path
		}
	return {
		"success": true,
		"backup_path": backup_path
	}


func rollback_config_write(filepath: String, backup_path: String, had_existing_file: bool) -> Dictionary:
	if had_existing_file and not backup_path.is_empty() and FileAccess.file_exists(backup_path):
		var restore_result = copy_text_file(backup_path, filepath)
		if not bool(restore_result.get("success", false)):
			return {
				"rollback_restored": false,
				"rollback_error": "restore_failed",
				"rollback_path": filepath,
				"backup_path": backup_path
			}
		return {
			"rollback_restored": true,
			"backup_path": backup_path
		}

	if FileAccess.file_exists(filepath):
		DirAccess.remove_absolute(filepath)
	return {
		"rollback_restored": false,
		"backup_path": backup_path
	}


func merge_rollback_result(result: Dictionary, rollback_result: Dictionary) -> Dictionary:
	for key in rollback_result.keys():
		result[key] = rollback_result[key]
	return result


func copy_text_file(from_path: String, to_path: String) -> Dictionary:
	var read_result = read_text_file(from_path)
	if not bool(read_result.get("success", false)):
		return {"success": false}

	var dir_path = to_path.get_base_dir()
	if not dir_path.is_empty() and not DirAccess.dir_exists_absolute(dir_path):
		var dir_error = DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_error != OK:
			return {"success": false}

	var file = FileAccess.open(to_path, FileAccess.WRITE)
	if file == null:
		return {"success": false}
	file.store_string(str(read_result.get("text", "")))
	file.close()
	return {"success": true}


func read_text_file(filepath: String) -> Dictionary:
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return {"success": false}
	var text = file.get_as_text()
	file.close()
	return {
		"success": true,
		"text": text
	}


func verify_removed_config(serializer, config_type: String, filepath: String, server_name: String) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {
			"success": false,
			"error": "readback_missing_file"
		}

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return {
			"success": false,
			"error": "readback_open_error"
		}
	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(text) != OK:
		return {
			"success": false,
			"error": "readback_parse_error"
		}
	var root = json.get_data()
	if not (root is Dictionary):
		return {
			"success": false,
			"error": "readback_parse_error"
		}

	var container_key = serializer.get_server_container_key(config_type)
	if not root.has(container_key):
		return {
			"success": true
		}

	var actual_servers = root.get(container_key, {})
	if not (actual_servers is Dictionary):
		return {
			"success": false,
			"error": "readback_missing_servers"
		}
	if actual_servers.has(server_name):
		return {
			"success": false,
			"error": "readback_remove_mismatch",
			"server_name": server_name
		}
	return {
		"success": true
	}


func verify_written_config(serializer, config_type: String, filepath: String, expected_servers: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {
			"success": false,
			"error": "readback_missing_file"
		}

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return {
			"success": false,
			"error": "readback_open_error"
		}

	var text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(text) != OK:
		return {
			"success": false,
			"error": "readback_parse_error"
		}

	var root = json.get_data()
	if not (root is Dictionary):
		return {
			"success": false,
			"error": "readback_parse_error"
		}

	var actual_servers = root.get(serializer.get_server_container_key(config_type), {})
	if not (actual_servers is Dictionary):
		return {
			"success": false,
			"error": "readback_missing_servers"
		}

	var verified_servers: Array[String] = []
	for server_name in expected_servers.keys():
		if not actual_servers.has(server_name):
			return {
				"success": false,
				"error": "readback_missing_server",
				"server_name": str(server_name)
			}
		if not _variants_equal_deep(actual_servers[server_name], expected_servers[server_name]):
			return {
				"success": false,
				"error": "readback_mismatch",
				"server_name": str(server_name)
			}
		verified_servers.append(str(server_name))

	return {
		"success": true,
		"verified_servers": verified_servers
	}


func _variants_equal_deep(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false

	match typeof(left):
		TYPE_DICTIONARY:
			var left_dict: Dictionary = left
			var right_dict: Dictionary = right
			if left_dict.size() != right_dict.size():
				return false
			for key in left_dict.keys():
				if not right_dict.has(key):
					return false
				if not _variants_equal_deep(left_dict[key], right_dict[key]):
					return false
			return true
		TYPE_ARRAY:
			var left_array: Array = left
			var right_array: Array = right
			if left_array.size() != right_array.size():
				return false
			for index in range(left_array.size()):
				if not _variants_equal_deep(left_array[index], right_array[index]):
					return false
			return true
		_:
			return left == right
