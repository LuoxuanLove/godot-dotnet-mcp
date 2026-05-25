@tool
extends RefCounted
class_name PluginInstanceFreshness

const PLUGIN_ID := "godot_dotnet_mcp"
const ADDON_ROOT := "res://addons/godot_dotnet_mcp"
const PLUGIN_CFG_PATH := ADDON_ROOT + "/plugin.cfg"
const PROTOCOL_FACTS_PATH := ADDON_ROOT + "/plugin/runtime/mcp_protocol_facts.json"
const PLUGIN_SCRIPT_PATH := ADDON_ROOT + "/plugin.gd"
const SYNC_MARKER_PATH := ADDON_ROOT + "/.mcp_sync.json"
const SYNC_MARKER_MAX_BYTES := 16384
const FINGERPRINT_EXTENSIONS := ["cfg", "gd", "json", "tscn"]
const FINGERPRINT_EXCLUDED_DIRS := {
	".git": true,
	"custom_tools": true,
	"dotnet_bridge/bin": true,
	"dotnet_bridge/obj": true
}

const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")

static var _running_instance: Dictionary = {}
static var _lifecycle_reload: Dictionary = {
	"state": "idle",
	"pending": false,
	"last_requested_at_unix": 0,
	"last_scheduled_at_unix": 0,
	"last_completed_at_unix": 0,
	"last_request_id": "",
	"last_source": "",
	"last_error": "",
	"completed_instance_id": "",
	"completion_observed": false,
	"force_fresh_load_pending": false
}


static func capture_running_instance(source: String = "plugin_enter_tree") -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	_running_instance = {
		"plugin_id": PLUGIN_ID,
		"instance_id": "%s_%d_%d" % [PLUGIN_ID, now_unix, Time.get_ticks_usec()],
		"loaded_at_unix": now_unix,
		"loaded_at_text": Time.get_datetime_string_from_system(true, true),
		"source": source,
		"source_root": ADDON_ROOT,
		"plugin_cfg_path": PLUGIN_CFG_PATH,
		"source_version": _read_plugin_cfg_version(PLUGIN_CFG_PATH),
		"server_version": MCPProtocolFacts.get_server_version(),
		"protocol_version": MCPProtocolFacts.get_protocol_version(),
		"tool_schema_version": MCPProtocolFacts.get_tool_schema_version(),
		"source_fingerprint": _build_fingerprint()
	}
	if source != "freshness_lazy_capture":
		_complete_lifecycle_reload_if_pending(now_unix)
	return _running_instance.duplicate(true)


static func mark_lifecycle_reload_requested(source: String = "tool") -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	var request_id := "reload_%d_%d" % [now_unix, Time.get_ticks_usec()]
	_lifecycle_reload["pending"] = true
	_lifecycle_reload["state"] = "requested"
	_lifecycle_reload["last_requested_at_unix"] = now_unix
	_lifecycle_reload["last_scheduled_at_unix"] = 0
	_lifecycle_reload["last_completed_at_unix"] = 0
	_lifecycle_reload["last_request_id"] = request_id
	_lifecycle_reload["last_source"] = source
	_lifecycle_reload["last_error"] = ""
	_lifecycle_reload["completed_instance_id"] = ""
	_lifecycle_reload["completion_observed"] = false
	_lifecycle_reload["force_fresh_load_pending"] = true
	return _lifecycle_reload.duplicate(true)


static func mark_lifecycle_reload_scheduled(request_id: String = "") -> Dictionary:
	if not request_id.is_empty() and str(_lifecycle_reload.get("last_request_id", "")) != request_id:
		return _lifecycle_reload.duplicate(true)
	_lifecycle_reload["state"] = "scheduled"
	_lifecycle_reload["pending"] = true
	_lifecycle_reload["last_scheduled_at_unix"] = int(Time.get_unix_time_from_system())
	_lifecycle_reload["last_error"] = ""
	_lifecycle_reload["force_fresh_load_pending"] = true
	return _lifecycle_reload.duplicate(true)


static func mark_lifecycle_reload_failed(error_message: String, request_id: String = "") -> Dictionary:
	if not request_id.is_empty() and str(_lifecycle_reload.get("last_request_id", "")) != request_id:
		return _lifecycle_reload.duplicate(true)
	_lifecycle_reload["state"] = "failed"
	_lifecycle_reload["pending"] = false
	_lifecycle_reload["last_error"] = error_message
	_lifecycle_reload["force_fresh_load_pending"] = false
	return _lifecycle_reload.duplicate(true)


static func consume_force_fresh_load() -> bool:
	var should_force := bool(_lifecycle_reload.get("force_fresh_load_pending", false))
	_lifecycle_reload["force_fresh_load_pending"] = false
	return should_force


static func should_force_fresh_load() -> bool:
	return bool(_lifecycle_reload.get("force_fresh_load_pending", false))


static func reset_for_contract_tests() -> void:
	_running_instance = {}
	_lifecycle_reload = {
		"state": "idle",
		"pending": false,
		"last_requested_at_unix": 0,
		"last_scheduled_at_unix": 0,
		"last_completed_at_unix": 0,
		"last_request_id": "",
		"last_source": "",
		"last_error": "",
		"completed_instance_id": "",
		"completion_observed": false,
		"force_fresh_load_pending": false
	}


static func get_freshness_snapshot() -> Dictionary:
	var running := _running_instance.duplicate(true)
	if running.is_empty():
		running = capture_running_instance("freshness_lazy_capture")
	var disk_source := _build_disk_source_snapshot()
	var sync_snapshot := _build_sync_snapshot()
	var comparison := _compare_running_to_disk(running, disk_source, sync_snapshot)
	var status := "unknown"
	if bool(comparison.get("version_changed_since_load", false)) or \
		bool(comparison.get("schema_changed_since_load", false)) or \
		bool(comparison.get("source_fingerprint_changed_since_load", false)) or \
		bool(comparison.get("disk_newer_than_running", false)) or \
		bool(comparison.get("sync_newer_than_running", false)):
		status = "stale"
	elif not running.is_empty() and not disk_source.is_empty():
		status = "fresh"
	return {
		"status": status,
		"needs_lifecycle_reload": status == "stale",
		"running_instance": running,
		"disk_source": disk_source,
		"sync": sync_snapshot,
		"lifecycle_reload": _lifecycle_reload.duplicate(true),
		"comparison": comparison
	}


static func _complete_lifecycle_reload_if_pending(completed_at_unix: int) -> void:
	if not bool(_lifecycle_reload.get("pending", false)):
		return
	_lifecycle_reload["state"] = "completed"
	_lifecycle_reload["pending"] = false
	_lifecycle_reload["last_completed_at_unix"] = completed_at_unix
	_lifecycle_reload["completed_instance_id"] = str(_running_instance.get("instance_id", ""))
	_lifecycle_reload["completion_observed"] = true


static func _build_disk_source_snapshot() -> Dictionary:
	return {
		"source_root": ADDON_ROOT,
		"plugin_cfg_path": PLUGIN_CFG_PATH,
		"source_version": _read_plugin_cfg_version(PLUGIN_CFG_PATH),
		"server_version": MCPProtocolFacts.get_server_version(),
		"protocol_version": MCPProtocolFacts.get_protocol_version(),
		"tool_schema_version": MCPProtocolFacts.get_tool_schema_version(),
		"latest_modified_at_unix": _latest_modified_time(_get_fingerprint_paths()),
		"source_fingerprint": _build_fingerprint()
	}


static func _build_sync_snapshot() -> Dictionary:
	var snapshot := {
		"marker_path": SYNC_MARKER_PATH,
		"marker_available": false,
		"last_sync_at_unix": _latest_modified_time(_get_fingerprint_paths()),
		"source_repo_path": "",
		"target_addon_path": ADDON_ROOT,
		"source_git_commit": "",
		"source_ref_kind": "",
		"source_ref": "",
		"written_files": 0,
		"fallback_used": true,
		"error": ""
	}
	if not FileAccess.file_exists(SYNC_MARKER_PATH):
		return snapshot
	var marker_file := FileAccess.open(SYNC_MARKER_PATH, FileAccess.READ)
	if marker_file == null:
		snapshot["error"] = "sync_marker_open_failed"
		return snapshot
	if marker_file.get_length() > SYNC_MARKER_MAX_BYTES:
		snapshot["error"] = "sync_marker_too_large"
		return snapshot
	var raw_text := marker_file.get_as_text()
	var json := JSON.new()
	if json.parse(raw_text) != OK:
		snapshot["error"] = "sync_marker_parse_failed"
		return snapshot
	var data = json.get_data()
	if not (data is Dictionary):
		return snapshot
	var marker: Dictionary = data
	snapshot["marker_available"] = true
	snapshot["last_sync_at_unix"] = int(marker.get("last_sync_at_unix", marker.get("synced_at_unix", 0)))
	snapshot["source_repo_path"] = str(marker.get("source_repo_path", ""))
	snapshot["target_addon_path"] = str(marker.get("target_addon_path", ADDON_ROOT))
	snapshot["source_git_commit"] = str(marker.get("source_git_commit", ""))
	snapshot["source_ref_kind"] = str(marker.get("source_ref_kind", ""))
	snapshot["source_ref"] = str(marker.get("source_ref", ""))
	snapshot["written_files"] = int(marker.get("written_files", 0))
	snapshot["fallback_used"] = false
	return snapshot


static func _compare_running_to_disk(running: Dictionary, disk_source: Dictionary, sync_snapshot: Dictionary) -> Dictionary:
	var loaded_at := int(running.get("loaded_at_unix", 0))
	var disk_modified_at := int(disk_source.get("latest_modified_at_unix", 0))
	var last_sync_at := int(sync_snapshot.get("last_sync_at_unix", 0))
	var version_changed := str(running.get("source_version", "")) != str(disk_source.get("source_version", ""))
	var schema_changed := str(running.get("tool_schema_version", "")) != str(disk_source.get("tool_schema_version", ""))
	var fingerprint_changed := str(running.get("source_fingerprint", "")) != str(disk_source.get("source_fingerprint", ""))
	var disk_newer := loaded_at > 0 and disk_modified_at > loaded_at
	var sync_newer := loaded_at > 0 and last_sync_at > loaded_at
	var reasons: Array[String] = []
	if version_changed:
		reasons.append("version_changed_since_load")
	if schema_changed:
		reasons.append("schema_changed_since_load")
	if fingerprint_changed:
		reasons.append("source_fingerprint_changed_since_load")
	if disk_newer:
		reasons.append("disk_newer_than_running")
	if sync_newer:
		reasons.append("sync_newer_than_running")
	return {
		"disk_newer_than_running": disk_newer,
		"sync_newer_than_running": sync_newer,
		"version_changed_since_load": version_changed,
		"schema_changed_since_load": schema_changed,
		"source_fingerprint_changed_since_load": fingerprint_changed,
		"staleness_reason": reasons
	}


static func _read_plugin_cfg_version(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return ""
	return str(config.get_value("plugin", "version", ""))


static func _build_fingerprint() -> String:
	var parts := PackedStringArray()
	for path in _get_fingerprint_paths():
		parts.append("%s:%d" % [path, FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0])
	return "|".join(parts)


static func _get_fingerprint_paths() -> Array[String]:
	var paths: Array[String] = []
	_collect_fingerprint_paths(ADDON_ROOT, "", paths)
	paths.sort()
	return paths


static func _collect_fingerprint_paths(dir_path: String, relative_dir: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var relative_path := entry if relative_dir.is_empty() else "%s/%s" % [relative_dir, entry]
		var full_path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			if not FINGERPRINT_EXCLUDED_DIRS.has(relative_path):
				_collect_fingerprint_paths(full_path, relative_path, paths)
			continue
		if _is_fingerprint_file(entry):
			paths.append(full_path)
	dir.list_dir_end()


static func _is_fingerprint_file(file_name: String) -> bool:
	var extension := file_name.get_extension().to_lower()
	return extension in FINGERPRINT_EXTENSIONS


static func _latest_modified_time(paths: Array) -> int:
	var latest := 0
	for path in paths:
		if FileAccess.file_exists(str(path)):
			latest = maxi(latest, int(FileAccess.get_modified_time(str(path))))
	return latest
