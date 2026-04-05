@tool
extends RefCounted
class_name BridgeInstallService

const PluginRoslynServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_roslyn_service.gd")

const STATUS_NOT_CONFIGURED := "not_configured"
const STATUS_VALIDATING := "validating"
const STATUS_INSTALLED := "installed"
const STATUS_INVALID := "invalid"


static func build_snapshot(settings: Dictionary) -> Dictionary:
	var snapshot := _build_roslyn_snapshot()
	var legacy_path := _normalize_path(str(settings.get("bridge_executable_path", "")))
	if not legacy_path.is_empty():
		snapshot["install_message"] = "%s Legacy external runtime paths are ignored." % str(snapshot.get("install_message", ""))
	return snapshot


static func validate_executable(executable_path: String) -> Dictionary:
	var normalized_path := _normalize_path(executable_path)
	var snapshot := _build_roslyn_snapshot()
	if normalized_path.is_empty():
		return {
			"success": false,
			"error_code": "in_process_runtime_only",
			"message": "The plugin uses in-process Roslyn and does not require an external runtime path."
		}

	if bool(snapshot.get("installed", false)):
		return {
			"success": true,
			"error_code": "",
			"message": "%s External runtime paths are ignored." % str(snapshot.get("install_message", "Plugin-internal Roslyn syntax support is available.")),
			"executable_path": "",
			"legacy_path": normalized_path,
			"version": str(snapshot.get("install_version", "")),
			"health": {
				"engine": "roslyn",
				"transport": "in_process",
				"status": str(snapshot.get("install_state", STATUS_INSTALLED))
			},
			"launch_command": ""
		}

	return {
		"success": false,
		"error_code": "roslyn_runtime_unavailable",
		"message": "%s External runtime paths are ignored." % str(snapshot.get("install_message", "Plugin-internal Roslyn syntax support is unavailable in this environment.")),
		"executable_path": "",
		"legacy_path": normalized_path,
		"version": str(snapshot.get("install_version", "")),
		"health": {
			"engine": "roslyn",
			"transport": "in_process",
			"status": str(snapshot.get("install_state", STATUS_INVALID))
		},
		"launch_command": ""
	}


static func register_executable(settings: Dictionary, executable_path: String, install_source: String = "manual_file") -> Dictionary:
	var validation = validate_executable(executable_path)
	if not bool(validation.get("success", false)):
		return validation

	var snapshot := _build_roslyn_snapshot()
	settings["bridge_executable_path"] = ""
	settings["bridge_install_source"] = "in_process_roslyn"
	settings["bridge_install_state"] = str(snapshot.get("install_state", STATUS_NOT_CONFIGURED))
	settings["bridge_install_version"] = str(snapshot.get("install_version", ""))
	settings["bridge_install_message"] = str(snapshot.get("install_message", "Plugin-internal Roslyn syntax support is available."))
	settings["bridge_install_checked_at"] = Time.get_datetime_string_from_system(true, true)

	return {
		"success": true,
		"settings": settings,
		"snapshot": build_snapshot(settings),
		"message": "%s Legacy external runtime registration was not stored." % str(snapshot.get("install_message", "Plugin-internal Roslyn syntax support is available."))
	}


static func clear_executable(settings: Dictionary) -> Dictionary:
	settings["bridge_executable_path"] = ""
	settings["bridge_install_source"] = ""
	settings["bridge_install_state"] = STATUS_NOT_CONFIGURED
	settings["bridge_install_version"] = ""
	settings["bridge_install_message"] = ""
	settings.erase("bridge_install_checked_at")

	return {
		"success": true,
		"settings": settings,
		"snapshot": build_snapshot(settings),
		"message": "Legacy external runtime registration cleared."
	}


static func _build_roslyn_snapshot() -> Dictionary:
	var roslyn_service = PluginRoslynServiceScript.new()
	var capabilities = roslyn_service.get_capabilities()
	var installed := false
	var install_state := STATUS_INVALID
	var install_version := ""
	var install_message := "Plugin-internal Roslyn syntax support is unavailable in this environment."

	if capabilities is Dictionary:
		var capabilities_dict := capabilities as Dictionary
		var capability_data: Dictionary = {}
		var raw_data: Variant = capabilities_dict.get("data", {})
		if raw_data is Dictionary:
			capability_data = (raw_data as Dictionary).duplicate(true)
			install_version = str(capability_data.get("load_mode", ""))
		installed = bool(capabilities_dict.get("success", false)) and not bool(capability_data.get("degraded", true))
		install_state = STATUS_INSTALLED if installed else STATUS_INVALID
		install_message = str(capabilities_dict.get(
			"message",
			"Plugin-internal Roslyn syntax support is available." if installed else install_message
		))

	if roslyn_service != null:
		if roslyn_service.has_method("clear"):
			roslyn_service.clear()
		roslyn_service.free()
		roslyn_service = null
	return {
		"executable_path": "",
		"install_state": install_state,
		"install_source": "in_process_roslyn",
		"install_version": install_version,
		"install_message": install_message,
		"installed": installed,
		"launch_command": ""
	}


static func _normalize_path(path_value: String) -> String:
	var normalized := path_value.strip_edges().replace("\\", "/")
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized).replace("\\", "/")
	return normalized
