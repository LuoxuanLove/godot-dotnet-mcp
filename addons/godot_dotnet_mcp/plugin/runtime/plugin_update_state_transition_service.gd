@tool
extends RefCounted
class_name PluginUpdateStateTransitionService


func build_pending_sync_failure(message: String) -> Dictionary:
	return {
		"pending_sync_after_refs_discovery": false,
		"sync_state": "error",
		"sync_error": message,
		"sync_status": "",
		"sync_progress": 0.0
	}


func build_sync_failure(message: String) -> Dictionary:
	return {
		"sync_state": "error",
		"sync_error": message,
		"sync_status": "",
		"sync_progress": 0.0
	}


func build_sync_success(target_ref: String, written: int, success_template: String) -> Dictionary:
	var template := success_template
	if template.is_empty():
		template = "Synced %s (%s files)."
	return {
		"sync_state": "success",
		"sync_error": "",
		"sync_status": template % [target_ref, written],
		"sync_progress": 1.0
	}


func build_compare_reset() -> Dictionary:
	return {
		"compare_state": "idle",
		"compare_error": "",
		"compare_base_commit": "",
		"compare_target_ref": "",
		"compare_target_commit": "",
		"compare_ahead_by": -1,
		"compare_behind_by": -1
	}


func build_compare_failure(message: String) -> Dictionary:
	return {
		"compare_state": "error",
		"compare_error": message,
		"compare_ahead_by": -1,
		"compare_behind_by": -1
	}


func build_compare_success(base_commit: String, target_commit: String, parse_result: Dictionary) -> Dictionary:
	return {
		"compare_state": "success",
		"compare_error": "",
		"compare_base_commit": base_commit,
		"compare_target_commit": target_commit,
		"compare_ahead_by": int(parse_result.get("ahead_by", -1)),
		"compare_behind_by": int(parse_result.get("behind_by", -1))
	}


func build_refs_success(success_status: String) -> Dictionary:
	return {
		"refs_state": "success",
		"refs_error": "",
		"refs_status": success_status,
		"refs_discovery_loaded": true
	}


func build_refs_failure(errors: Array) -> Dictionary:
	return {
		"refs_state": "error",
		"refs_error": "; ".join(errors),
		"refs_status": "",
		"refs_discovery_loaded": false
	}
