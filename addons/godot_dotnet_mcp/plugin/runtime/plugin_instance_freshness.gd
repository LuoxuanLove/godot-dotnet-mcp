@tool
extends RefCounted
class_name PluginInstanceFreshness

const PLUGIN_ID := "godot_dotnet_mcp"
const ADDON_ROOT := "res://addons/godot_dotnet_mcp"
const PLUGIN_CFG_PATH := ADDON_ROOT + "/plugin.cfg"
const PROTOCOL_FACTS_PATH := ADDON_ROOT + "/plugin/runtime/mcp_protocol_facts.json"
const PLUGIN_SCRIPT_PATH := ADDON_ROOT + "/plugin.gd"
const SYNC_MARKER_PATH := ADDON_ROOT + "/.mcp_sync.json"

const MCPProtocolFacts = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_protocol_facts.gd")

static var _running_instance: Dictionary = {}
static var _lifecycle_reload: Dictionary = {
	"pending": false,
	"last_requested_at_unix": 0,
	"last_completed_at_unix": 0,
	"last_request_id": "",
	"last_source": ""
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
	_complete_lifecycle_reload_if_pending(now_unix)
	return _running_instance.duplicate(true)


static func mark_lifecycle_reload_requested(source: String = "tool") -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	var request_id := "reload_%d_%d" % [now_unix, Time.get_ticks_usec()]
	_lifecycle_reload["pending"] = true
	_lifecycle_reload["last_requested_at_unix"] = now_unix
	_lifecycle_reload["last_completed_at_unix"] = 0
	_lifecycle_reload["last_request_id"] = request_id
	_lifecycle_reload["last_source"] = source
	return _lifecycle_reload.duplicate(true)


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
	_lifecycle_reload["pending"] = false
	_lifecycle_reload["last_completed_at_unix"] = completed_at_unix


static func _build_disk_source_snapshot() -> Dictionary:
	return {
		"source_root": ADDON_ROOT,
		"plugin_cfg_path": PLUGIN_CFG_PATH,
		"source_version": _read_plugin_cfg_version(PLUGIN_CFG_PATH),
		"server_version": MCPProtocolFacts.get_server_version(),
		"protocol_version": MCPProtocolFacts.get_protocol_version(),
		"tool_schema_version": MCPProtocolFacts.get_tool_schema_version(),
		"latest_modified_at_unix": _latest_modified_time([PLUGIN_CFG_PATH, PROTOCOL_FACTS_PATH, PLUGIN_SCRIPT_PATH]),
		"source_fingerprint": _build_fingerprint()
	}


static func _build_sync_snapshot() -> Dictionary:
	var snapshot := {
		"marker_path": SYNC_MARKER_PATH,
		"marker_available": false,
		"last_sync_at_unix": _latest_modified_time([PLUGIN_CFG_PATH, PROTOCOL_FACTS_PATH, PLUGIN_SCRIPT_PATH]),
		"source_repo_path": "",
		"target_addon_path": ADDON_ROOT,
		"source_git_commit": "",
		"fallback_used": true
	}
	if not FileAccess.file_exists(SYNC_MARKER_PATH):
		return snapshot
	var raw_text := FileAccess.get_file_as_string(SYNC_MARKER_PATH)
	var json := JSON.new()
	if json.parse(raw_text) != OK:
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
	snapshot["fallback_used"] = false
	return snapshot


static func _compare_running_to_disk(running: Dictionary, disk_source: Dictionary, sync_snapshot: Dictionary) -> Dictionary:
	var loaded_at := int(running.get("loaded_at_unix", 0))
	var disk_modified_at := int(disk_source.get("latest_modified_at_unix", 0))
	var last_sync_at := int(sync_snapshot.get("last_sync_at_unix", 0))
	var version_changed := str(running.get("source_version", "")) != str(disk_source.get("source_version", ""))
	var schema_changed := str(running.get("tool_schema_version", "")) != str(disk_source.get("tool_schema_version", ""))
	var disk_newer := loaded_at > 0 and disk_modified_at > loaded_at
	var sync_newer := loaded_at > 0 and last_sync_at > loaded_at
	var reasons: Array[String] = []
	if version_changed:
		reasons.append("version_changed_since_load")
	if schema_changed:
		reasons.append("schema_changed_since_load")
	if disk_newer:
		reasons.append("disk_newer_than_running")
	if sync_newer:
		reasons.append("sync_newer_than_running")
	return {
		"disk_newer_than_running": disk_newer,
		"sync_newer_than_running": sync_newer,
		"version_changed_since_load": version_changed,
		"schema_changed_since_load": schema_changed,
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
	for path in [PLUGIN_CFG_PATH, PROTOCOL_FACTS_PATH, PLUGIN_SCRIPT_PATH]:
		parts.append("%s:%d" % [path, FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0])
	return "|".join(parts)


static func _latest_modified_time(paths: Array) -> int:
	var latest := 0
	for path in paths:
		if FileAccess.file_exists(str(path)):
			latest = maxi(latest, int(FileAccess.get_modified_time(str(path))))
	return latest
