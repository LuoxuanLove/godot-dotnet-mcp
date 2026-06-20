@tool
extends RefCounted
class_name PluginUpdateToolFacadeService

const MCPMaintenanceContract = preload("res://addons/godot_dotnet_mcp/plugin/runtime/mcp_maintenance_contract.gd")
const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")


func build_current_snapshot() -> Dictionary:
	var freshness := PluginInstanceFreshness.get_freshness_snapshot()
	var running_instance: Dictionary = _duplicate_dictionary(freshness.get("running_instance", {}))
	var disk_source: Dictionary = _duplicate_dictionary(freshness.get("disk_source", {}))
	var sync_snapshot: Dictionary = _duplicate_dictionary(freshness.get("sync", {}))
	var source_snapshot := disk_source if not disk_source.is_empty() else running_instance
	var source_fingerprint := str(source_snapshot.get("source_fingerprint", running_instance.get("source_fingerprint", "")))
	var short_fingerprint := shorten_fingerprint(source_fingerprint)
	return {
		"status": str(freshness.get("status", "unknown")),
		"needs_lifecycle_reload": bool(freshness.get("needs_lifecycle_reload", false)),
		"source_version": str(source_snapshot.get("source_version", running_instance.get("source_version", ""))),
		"server_version": str(source_snapshot.get("server_version", running_instance.get("server_version", ""))),
		"protocol_version": str(source_snapshot.get("protocol_version", running_instance.get("protocol_version", ""))),
		"tool_schema_version": str(source_snapshot.get("tool_schema_version", running_instance.get("tool_schema_version", ""))),
		"source_fingerprint": source_fingerprint,
		"source_fingerprint_short": short_fingerprint,
		"short_source_fingerprint": short_fingerprint,
		"source_git_commit": str(sync_snapshot.get("source_git_commit", "")),
		"source_ref_kind": str(sync_snapshot.get("source_ref_kind", "")),
		"source_ref": str(sync_snapshot.get("source_ref", "")),
		"written_files": int(sync_snapshot.get("written_files", 0)),
		"running_instance": running_instance,
		"disk_source": disk_source,
		"sync": sync_snapshot,
		"lifecycle_reload": _duplicate_dictionary(freshness.get("lifecycle_reload", {})),
		"comparison": _duplicate_dictionary(freshness.get("comparison", {}))
	}


func build_status_snapshot(context: Dictionary) -> Dictionary:
	return {
		"status": resolve_overall_status(context),
		"current": build_current_snapshot(),
		"source": str(context.get("source", "")),
		"custom_branch": str(context.get("custom_branch", "")),
		"release_tag": str(context.get("release_tag", "")),
		"target": _duplicate_dictionary(context.get("target", {})),
		"current_commit": str(context.get("current_commit", "")),
		"request_host_available": bool(context.get("request_host_available", false)),
		"discovery_retry_pending": bool(context.get("discovery_retry_pending", false)),
		"pending_sync_after_refs_discovery": bool(context.get("pending_sync_after_refs_discovery", false)),
		"next_action": "poll_update_status" if bool(context.get("pending_sync_after_refs_discovery", false)) else "",
		"refs": build_refs_status(context),
		"compare": build_compare_status(context),
		"sync": build_sync_status(context),
		"lifecycle_reload": _duplicate_dictionary(PluginInstanceFreshness.get_freshness_snapshot().get("lifecycle_reload", {}))
	}


func enrich_tool_response(response: Dictionary) -> Dictionary:
	var data = response.get("data", {})
	if not (data is Dictionary):
		data = {}
	var data_dict: Dictionary = (data as Dictionary).duplicate(true)
	var maintenance := MCPMaintenanceContract.build_update_sync_maintenance(data_dict)
	data_dict["maintenance"] = maintenance
	data_dict["maintenance_window"] = maintenance
	response["data"] = data_dict
	return MCPMaintenanceContract.enrich_response(response, maintenance)


func build_current_response() -> Dictionary:
	var data := build_current_snapshot()
	var maintenance := MCPMaintenanceContract.build_from_freshness(PluginInstanceFreshness.get_freshness_snapshot())
	data["maintenance"] = maintenance
	data["maintenance_window"] = maintenance
	return MCPMaintenanceContract.enrich_response({
		"success": true,
		"data": data,
		"message": "Plugin update current fetched"
	}, maintenance)


func build_status_response(status_snapshot: Dictionary) -> Dictionary:
	var data := status_snapshot.duplicate(true)
	var maintenance := MCPMaintenanceContract.build_update_sync_maintenance(data)
	data["maintenance"] = maintenance
	data["maintenance_window"] = maintenance
	return MCPMaintenanceContract.enrich_response({
		"success": true,
		"data": data,
		"message": "Plugin update status fetched"
	}, maintenance)


func resolve_overall_status(context: Dictionary) -> String:
	if str(context.get("sync_state", "")) == "loading":
		return "syncing"
	if bool(context.get("pending_sync_after_refs_discovery", false)):
		return "preparing_sync"
	if str(context.get("refs_state", "")) == "loading" or str(context.get("compare_state", "")) == "loading":
		return "loading"
	if str(context.get("sync_state", "")) == "error" or str(context.get("refs_state", "")) == "error" or str(context.get("compare_state", "")) == "error":
		return "error"
	if bool(context.get("discovery_retry_pending", false)):
		return "pending"
	return "ready"


func resolve_request_status(kind: String, accepted: bool, context: Dictionary) -> String:
	if accepted:
		return "accepted"
	if not bool(context.get("request_host_available", false)) and (kind == "refs" or kind == "sync"):
		return "pending" if bool(context.get("discovery_retry_pending", false)) else "unavailable"
	if kind == "sync":
		return str(context.get("sync_state", ""))
	return str(context.get("refs_state", ""))


func shorten_fingerprint(source_fingerprint: String) -> String:
	var normalized := source_fingerprint.strip_edges()
	if normalized.length() <= 16:
		return normalized
	return normalized.substr(0, 16)


func build_refs_status(context: Dictionary) -> Dictionary:
	return {
		"state": str(context.get("refs_state", "")),
		"status": str(context.get("refs_status", "")),
		"error": str(context.get("refs_error", "")),
		"branches": _duplicate_array(context.get("branches", [])),
		"releases": _duplicate_array(context.get("releases", [])),
		"latest_stable_release": str(context.get("latest_stable_release", "")),
		"latest_release": str(context.get("latest_release", "")),
		"release_source": str(context.get("release_source", "")),
		"commits": _duplicate_dictionary(context.get("commits", {})),
		"versions": _duplicate_dictionary(context.get("versions", {}))
	}


func build_compare_status(context: Dictionary) -> Dictionary:
	return {
		"state": str(context.get("compare_state", "")),
		"error": str(context.get("compare_error", "")),
		"base_commit": str(context.get("compare_base_commit", "")),
		"target_ref": str(context.get("compare_target_ref", "")),
		"target_commit": str(context.get("compare_target_commit", "")),
		"ahead_by": int(context.get("compare_ahead_by", 0)),
		"behind_by": int(context.get("compare_behind_by", 0))
	}


func build_sync_status(context: Dictionary) -> Dictionary:
	return {
		"state": str(context.get("sync_state", "")),
		"status": str(context.get("sync_status", "")),
		"error": str(context.get("sync_error", "")),
		"target_ref": str(context.get("sync_target_ref", "")),
		"target_kind": str(context.get("sync_target_kind", "")),
		"pending_after_refs_discovery": bool(context.get("pending_sync_after_refs_discovery", false))
	}


func _duplicate_array(value) -> Array:
	if value is Array:
		return (value as Array).duplicate()
	return []


func _duplicate_dictionary(value) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
