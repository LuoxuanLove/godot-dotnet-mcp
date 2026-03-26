extends RefCounted

const ClientConfigSerializerScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_serializer.gd")
const ClientConfigInspectionServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_inspection_service.gd")
const ClientConfigFileSupportScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_file_support.gd")

const INSPECTION_FILE := "user://client_config_inspection_contract.json"


func run_case(_tree: SceneTree) -> Dictionary:
	_cleanup_file(INSPECTION_FILE)

	var serializer = ClientConfigSerializerScript.new()
	var support = ClientConfigFileSupportScript.new()
	var inspection = ClientConfigInspectionServiceScript.new()
	inspection.configure(serializer, support)

	var missing_result: Dictionary = inspection.inspect_config_entry("", INSPECTION_FILE)
	if str(missing_result.get("status", "")) != "missing_file":
		return _failure("Inspection service should report missing_file when no config exists.")

	_write_text(INSPECTION_FILE, "{\"mcpServers\":[]}")
	var incompatible_result: Dictionary = inspection.inspect_config_entry("", INSPECTION_FILE)
	if str(incompatible_result.get("status", "")) != "incompatible_mcp_servers":
		return _failure("Inspection service should report incompatible_mcp_servers for non-dictionary mcpServers.")

	_write_text(INSPECTION_FILE, "{\"mcp\":\"invalid\"}")
	var opencode_preflight: Dictionary = inspection.preflight_write_config("opencode", INSPECTION_FILE, JSON.stringify({
		"mcp": {
			"godot-mcp": {
				"transport": "stdio"
			}
		}
	}, "  "))
	if str(opencode_preflight.get("status", "")) != "incompatible_mcp":
		return _failure("Inspection preflight should report incompatible_mcp for opencode.")
	if not bool(opencode_preflight.get("requires_confirmation", false)):
		return _failure("Inspection preflight should require confirmation for incompatible_mcp.")

	return {
		"name": "client_config_inspection_service_contracts",
		"success": true,
		"error": "",
		"details": {
			"missing_status": str(missing_result.get("status", "")),
			"incompatible_status": str(incompatible_result.get("status", "")),
			"opencode_status": str(opencode_preflight.get("status", "")),
			"opencode_requires_confirmation": bool(opencode_preflight.get("requires_confirmation", false))
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_cleanup_file(INSPECTION_FILE)


func _write_text(path: String, text: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	var directory := absolute_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var file = FileAccess.open(absolute_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _failure(message: String) -> Dictionary:
	return {
		"name": "client_config_inspection_service_contracts",
		"success": false,
		"error": message
	}
