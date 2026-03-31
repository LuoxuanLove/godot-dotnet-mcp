@tool
extends RefCounted
class_name UserToolService

const UserToolCatalogService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_catalog_service.gd")
const UserToolMaintenanceService = preload("res://addons/godot_dotnet_mcp/plugin/runtime/user_tool_maintenance_service.gd")
const CUSTOM_TOOLS_DIR := "res://addons/godot_dotnet_mcp/custom_tools"
const USER_CATEGORY := "user"
const USER_DOMAIN := "user"
const SCAFFOLD_VERSION := "0.4.0"

var _session_id := ""
var _catalog_service := UserToolCatalogService.new()
var _maintenance_service := UserToolMaintenanceService.new()


func _init() -> void:
	_session_id = _build_session_id()
	_catalog_service.configure(CUSTOM_TOOLS_DIR, USER_CATEGORY, USER_DOMAIN, SCAFFOLD_VERSION)
	_maintenance_service.configure(
		CUSTOM_TOOLS_DIR,
		"res://addons/godot_dotnet_mcp/custom_tools/.backup",
		"user://godot_dotnet_mcp_user_tool_audit.log",
		_session_id,
		SCAFFOLD_VERSION
	)


func list_user_tools() -> Array[Dictionary]:
	return _catalog_service.list_user_tools()


func create_tool_scaffold(tool_name: String, display_name: String, description: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	return _maintenance_service.create_tool_scaffold(tool_name, display_name, description, authorized, agent_hint)


func delete_tool(script_path: String, authorized: bool, agent_hint: String = "") -> Dictionary:
	return _maintenance_service.delete_tool(script_path, authorized, agent_hint)


func restore_latest_backup(authorized: bool, agent_hint: String = "") -> Dictionary:
	return _maintenance_service.restore_latest_backup(authorized, agent_hint)


func get_audit_entries(limit: int = 20, filter_action: String = "", filter_session: String = "") -> Array[Dictionary]:
	return _maintenance_service.get_audit_entries(limit, filter_action, filter_session)


func get_compatibility_report() -> Dictionary:
	return _catalog_service.get_compatibility_report()


func _build_session_id() -> String:
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace("-", "").replace("T", "_")
	return "%s_%010d" % [timestamp, randi()]
