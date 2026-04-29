extends RefCounted

const ClientConfigSerializerScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_serializer.gd")
const ClientConfigFileTransactionScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_file_transaction.gd")

const DESKTOP_FILE := "user://client_config_transaction_contract_desktop.json"
const OPENCODE_FILE := "user://client_config_transaction_contract_opencode.json"


func run_case(_tree: SceneTree) -> Dictionary:
	_cleanup_file(DESKTOP_FILE)
	_cleanup_file("%s.bak" % DESKTOP_FILE)
	_cleanup_file(OPENCODE_FILE)
	_cleanup_file("%s.bak" % OPENCODE_FILE)

	var serializer = ClientConfigSerializerScript.new()
	var transaction = ClientConfigFileTransactionScript.new()
	transaction.call("configure", serializer)

	_write_text(DESKTOP_FILE, JSON.stringify({
		"mcpServers": {
			"existing-server": {
				"url": "http://localhost:3999/mcp"
			}
		}
	}, "  "))

	var new_desktop_config := JSON.stringify({
		"mcpServers": {
			"godot-mcp": {
				"url": "http://127.0.0.1:3000/mcp"
			}
		}
	}, "  ")
	var preflight: Dictionary = transaction.call("preflight_write_config", "", DESKTOP_FILE, new_desktop_config)
	if str(preflight.get("status", "")) != "mergeable":
		return _failure("Desktop preflight should be mergeable when the file already contains mcpServers.")

	var write_result: Dictionary = transaction.call("write_config_file", "", DESKTOP_FILE, new_desktop_config, {"preflight": preflight})
	if not bool(write_result.get("success", false)):
		return _failure("Desktop write_config_file should merge into an existing config file.")

	var merged_root = _read_json(DESKTOP_FILE)
	var merged_servers = merged_root.get("mcpServers", {})
	if not (merged_servers is Dictionary):
		return _failure("Merged desktop config should keep an mcpServers dictionary.")
	if not (merged_servers as Dictionary).has("existing-server") or not (merged_servers as Dictionary).has("godot-mcp"):
		return _failure("Merged desktop config should preserve existing servers and add godot-mcp.")

	var remove_result: Dictionary = transaction.call("remove_config_entry", "", DESKTOP_FILE)
	if not bool(remove_result.get("success", false)) or not bool(remove_result.get("removed", false)):
		return _failure("remove_config_entry should remove the injected godot-mcp server.")

	var after_remove_root = _read_json(DESKTOP_FILE)
	var after_remove_servers = after_remove_root.get("mcpServers", {})
	if not (after_remove_servers is Dictionary) or not (after_remove_servers as Dictionary).has("existing-server"):
		return _failure("remove_config_entry should preserve other servers.")
	if (after_remove_servers as Dictionary).has("godot-mcp"):
		return _failure("remove_config_entry should remove the godot-mcp entry.")

	_write_text(OPENCODE_FILE, "{\"mcp\":\"invalid\"}")
	var opencode_config := JSON.stringify({
		"mcp": {
			"godot-mcp": {
				"transport": "stdio"
			}
		}
	}, "  ")
	var opencode_preflight: Dictionary = transaction.call("preflight_write_config", "opencode", OPENCODE_FILE, opencode_config)
	if str(opencode_preflight.get("status", "")) != "incompatible_mcp":
		return _failure("Opencode preflight should report incompatible_mcp for invalid mcp roots.")
	if not bool(opencode_preflight.get("requires_confirmation", false)):
		return _failure("Opencode incompatible_mcp should require confirmation.")

	var blocked_write: Dictionary = transaction.call("write_config_file", "opencode", OPENCODE_FILE, opencode_config, {"preflight": opencode_preflight})
	if bool(blocked_write.get("success", false)) or str(blocked_write.get("error", "")) != "precheck_confirmation_required":
		return _failure("Opencode write should stop when confirmation is required.")

	return {
		"name": "client_config_file_transaction_contracts",
		"success": true,
		"error": "",
		"details": {
			"desktop_preflight_status": str(preflight.get("status", "")),
			"backup_created": FileAccess.file_exists("%s.bak" % DESKTOP_FILE),
			"opencode_preflight_status": str(opencode_preflight.get("status", "")),
			"opencode_requires_confirmation": bool(opencode_preflight.get("requires_confirmation", false))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_cleanup_file(DESKTOP_FILE)
	_cleanup_file("%s.bak" % DESKTOP_FILE)
	_cleanup_file(OPENCODE_FILE)
	_cleanup_file("%s.bak" % OPENCODE_FILE)


func _write_text(path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var file = FileAccess.open(absolute_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_json(path: String) -> Dictionary:
	var absolute_path := ProjectSettings.globalize_path(path)
	var file = FileAccess.open(absolute_path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var json = JSON.new()
	var parse_error = json.parse(text)
	if parse_error != OK:
		return {}
	var data = json.get_data()
	return data if data is Dictionary else {}


func _cleanup_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_config_file_transaction_contracts",
		"success": false,
		"error": message
	}
