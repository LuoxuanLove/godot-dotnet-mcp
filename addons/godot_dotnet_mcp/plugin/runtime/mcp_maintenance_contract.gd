@tool
extends RefCounted
class_name MCPMaintenanceContract

const LocalizationServiceScript = preload("res://addons/godot_dotnet_mcp/localization/localization_service.gd")

const RECONNECT_RETRY_AFTER_MS := 500
const LIFECYCLE_RECONNECT_HINT_KEY := "maintenance_lifecycle_reconnect_hint"
const UPDATE_SYNC_RECONNECT_HINT_KEY := "maintenance_update_sync_reconnect_hint"


static func build_from_freshness(freshness: Dictionary = {}) -> Dictionary:
	var lifecycle_reload: Dictionary = freshness.get("lifecycle_reload", {})
	var state := str(lifecycle_reload.get("state", "idle"))
	var pending := bool(lifecycle_reload.get("pending", false))
	var needs_lifecycle_reload := bool(freshness.get("needs_lifecycle_reload", false))
	var transport_may_disconnect := pending or state == "requested" or state == "scheduled"
	var active := transport_may_disconnect or needs_lifecycle_reload
	return {
		"active": active,
		"kind": "plugin_lifecycle_reload" if active else "",
		"state": state,
		"transport_state": _transport_state_for(active, transport_may_disconnect, state),
		"availability": "temporarily_unavailable" if transport_may_disconnect else ("stale_instance" if needs_lifecycle_reload else "ready"),
		"pending": pending,
		"request_id": str(lifecycle_reload.get("last_request_id", "")),
		"source": str(lifecycle_reload.get("last_source", "")),
		"transport_may_disconnect": transport_may_disconnect,
		"disconnect_expected": transport_may_disconnect,
		"reconnect_required": active,
		"retry_after_ms": RECONNECT_RETRY_AFTER_MS if active else 0,
		"refresh_tools_after_reconnect": active,
		"refetch_tools_required": active,
		"safe_to_retry": not transport_may_disconnect,
		"completion_observed": bool(lifecycle_reload.get("completion_observed", false)),
		"completed_instance_id": str(lifecycle_reload.get("completed_instance_id", "")),
		"reconnect_hint": _localized_hint(LIFECYCLE_RECONNECT_HINT_KEY) if active else ""
	}


static func build_from_lifecycle(lifecycle_reload: Dictionary = {}, freshness: Dictionary = {}) -> Dictionary:
	var merged := freshness.duplicate()
	merged["lifecycle_reload"] = lifecycle_reload.duplicate()
	return build_from_freshness(merged)


static func build_update_sync_maintenance(status_snapshot: Dictionary = {}) -> Dictionary:
	var current: Dictionary = status_snapshot.get("current", {})
	var freshness := {
		"needs_lifecycle_reload": bool(current.get("needs_lifecycle_reload", false)),
		"lifecycle_reload": status_snapshot.get("lifecycle_reload", {})
	}
	var maintenance := build_from_freshness(freshness)
	var sync: Dictionary = status_snapshot.get("sync", {})
	var sync_state := str(sync.get("state", ""))
	if sync_state == "loading":
		maintenance["active"] = true
		maintenance["kind"] = "plugin_update_sync"
		maintenance["state"] = "loading"
		maintenance["transport_state"] = "updating"
		maintenance["availability"] = "temporarily_unavailable"
		maintenance["pending"] = true
		maintenance["disconnect_expected"] = true
		maintenance["transport_may_disconnect"] = true
		maintenance["reconnect_required"] = true
		maintenance["retry_after_ms"] = RECONNECT_RETRY_AFTER_MS
		maintenance["refresh_tools_after_reconnect"] = true
		maintenance["refetch_tools_required"] = true
		maintenance["safe_to_retry"] = true
		maintenance["reconnect_hint"] = _localized_hint(UPDATE_SYNC_RECONNECT_HINT_KEY)
	return maintenance


static func enrich_response(response: Dictionary, maintenance: Dictionary) -> Dictionary:
	var enriched := response.duplicate(true)
	enriched["maintenance"] = maintenance.duplicate(true)
	enriched["maintenance_window"] = maintenance.duplicate(true)
	var data = enriched.get("data", {})
	if data is Dictionary:
		var data_dict: Dictionary = (data as Dictionary).duplicate(true)
		data_dict["maintenance"] = maintenance.duplicate(true)
		data_dict["maintenance_window"] = maintenance.duplicate(true)
		if not data_dict.has("reconnect_hint") and not str(maintenance.get("reconnect_hint", "")).is_empty():
			data_dict["reconnect_hint"] = str(maintenance.get("reconnect_hint", ""))
		enriched["data"] = data_dict
	return enriched


static func _transport_state_for(active: bool, transport_may_disconnect: bool, state: String) -> String:
	if transport_may_disconnect:
		return "disconnecting"
	if active:
		return "stale_schema"
	if state == "completed":
		return "reconnecting"
	return "ready"


static func _localized_hint(key: String) -> String:
	return LocalizationServiceScript.translate(key)
