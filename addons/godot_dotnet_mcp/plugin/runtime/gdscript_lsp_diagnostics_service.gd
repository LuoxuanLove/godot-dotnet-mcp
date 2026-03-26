@tool
extends RefCounted
class_name GDScriptLspDiagnosticsService

const LspClientPath := "res://addons/godot_dotnet_mcp/tools/system/lsp_client.gd"
const MCPDebugBuffer = preload("res://addons/godot_dotnet_mcp/tools/mcp_debug_buffer.gd")

const CACHE_LIMIT := 32
const DEFAULT_TIMEOUT_MS := 15000
const STATE_IDLE := "idle"
const STATE_QUEUED := "queued"
const STATE_CONNECTING := "connecting"
const STATE_WAITING_INITIALIZE := "waiting_initialize"
const STATE_WAITING_DIAGNOSTICS := "waiting_diagnostics"
const STATE_READY := "ready"
const STATE_FAILED := "failed"

var _client
var _queue: Array[Dictionary] = []
var _active_key := ""
var _status: Dictionary = {
	"available": false,
	"pending": false,
	"finished": true,
	"state": STATE_IDLE,
	"phase": STATE_IDLE,
	"parse_errors": [],
	"error_count": 0,
	"warning_count": 0
}
var _cache_by_key: Dictionary = {}
var _cache_order: Array[String] = []
var _pending_script_path := ""
var _pending_source_code := ""
var _pending_source_hash := ""
var _pending_timeout_ms := DEFAULT_TIMEOUT_MS
var _request_count := 0
var _last_completed_status: Dictionary = {}
var _last_completed_key := ""
var _last_started_script_path := ""
static var _singleton = null


static func get_singleton():
	if _singleton == null or not is_instance_valid(_singleton):
		_singleton = preload("res://addons/godot_dotnet_mcp/plugin/runtime/gdscript_lsp_diagnostics_service.gd").new()
	return _singleton


func request_diagnostics(script_path: String, source_code: String, timeout_ms: int = DEFAULT_TIMEOUT_MS) -> Dictionary:
	var source_hash := _hash_source(source_code)
	var key := _make_key(script_path, source_hash)
	MCPDebugBuffer.record("info", "gdscript_lsp_diagnostics_service",
		"request script=%s key=%s active=%s" % [script_path, key, str(_active_key)])

	var cached_entry: Variant = _cache_by_key.get(key, null)
	if cached_entry is Dictionary:
		var cached_result_raw: Variant = (cached_entry as Dictionary).get("result", {})
		var cached_result: Dictionary = {}
		if cached_result_raw is Dictionary:
			cached_result = cached_result_raw
		if not cached_result.is_empty() and bool(cached_result.get("available", false)):
			_status = _duplicate_status(cached_result)
			MCPDebugBuffer.record("info", "gdscript_lsp_diagnostics_service",
				"request cache hit state=%s" % str(_status.get("state", "unknown")))
			return _status.duplicate(true)

	if _active_key == key and bool(_status.get("pending", false)):
		if _client != null and _client.has_method("tick") and _client.has_active_request():
			_client.tick(0.0)
			var live_status_raw: Variant = _client.get_status()
			if live_status_raw is Dictionary:
				var live_status: Dictionary = live_status_raw
				if bool(live_status.get("finished", false)):
					_commit_client_status(live_status)
					return _status.duplicate(true)
				_status = _duplicate_status(live_status)
		MCPDebugBuffer.record("info", "gdscript_lsp_diagnostics_service",
			"request reuse active pending state=%s" % str(_status.get("state", "unknown")))
		return _status.duplicate(true)

	if _client != null and _client.has_method("has_active_request") and _client.has_active_request():
		if not _active_key.is_empty() and _active_key != key:
			MCPDebugBuffer.record("info", "gdscript_lsp_diagnostics_service",
				"request replacing stale active key=%s new_key=%s" % [_active_key, key])
			_client.cancel()
			_client = null
			_active_key = ""

	_pending_script_path = script_path
	_pending_source_code = source_code
	_pending_source_hash = source_hash
	_pending_timeout_ms = maxi(timeout_ms, 1)
	_status = _build_pending_status(script_path, source_hash, STATE_QUEUED)
	MCPDebugBuffer.record("info", "gdscript_lsp_diagnostics_service",
		"request queued state=%s" % str(_status.get("state", "unknown")))
	if _client == null or not _client.has_active_request():
		_start_next_job()
	return _status.duplicate(true)


func has_active_request() -> bool:
	if _client != null and _client.has_method("has_active_request") and _client.has_active_request():
		return true
	return not _pending_script_path.is_empty() or not _active_key.is_empty()


func get_debug_snapshot() -> Dictionary:
	var client_snapshot: Dictionary = {}
	if _client != null and _client.has_method("get_debug_snapshot"):
		var client_snapshot_raw = _client.get_debug_snapshot()
		if client_snapshot_raw is Dictionary:
			client_snapshot = (client_snapshot_raw as Dictionary).duplicate(true)
	return {
		"status": _status.duplicate(true),
		"request_count": _request_count,
		"active_key": _active_key,
		"pending_script_path": _pending_script_path,
		"pending_source_hash": _pending_source_hash,
		"pending_timeout_ms": _pending_timeout_ms,
		"cache_entry_count": _cache_by_key.size(),
		"cache_keys": _cache_order.duplicate(),
		"last_started_script_path": _last_started_script_path,
		"last_completed_key": _last_completed_key,
		"last_completed_status": _last_completed_status.duplicate(true),
		"client": client_snapshot
	}


func get_status_summary() -> Dictionary:
	var summary_status: Dictionary = _status.duplicate(true)
	if summary_status.is_empty() and not _last_completed_status.is_empty():
		summary_status = _last_completed_status.duplicate(true)
	var phase := str(summary_status.get("phase", summary_status.get("state", STATE_IDLE)))
	return {
		"source": "godot_lsp",
		"enabled": true,
		"available": bool(summary_status.get("available", false)),
		"pending": bool(summary_status.get("pending", false)),
		"finished": bool(summary_status.get("finished", false)),
		"phase": phase,
		"last_state": str(summary_status.get("state", phase)),
		"last_error": _extract_status_error(summary_status)
	}


func tick(delta: float) -> void:
	MCPDebugBuffer.record("info", "gdscript_lsp_diagnostics_service",
		"tick active=%s pending=%s state=%s" % [
			str(has_active_request()),
			str(not _pending_script_path.is_empty()),
			str(_status.get("state", "idle"))
		])
	if _client != null and _client.has_method("tick") and _client.has_active_request():
		_client.tick(delta)
		var client_status_raw: Variant = _client.get_status()
		var client_status: Dictionary = {}
		if client_status_raw is Dictionary:
			client_status = client_status_raw
		if not client_status.is_empty() and bool(client_status.get("finished", false)):
			_commit_client_status(client_status)

	if _client == null or not _client.has_active_request():
		_start_next_job()


func clear() -> void:
	if _client != null and _client.has_method("cancel"):
		_client.cancel()
	_client = null
	_pending_script_path = ""
	_pending_source_code = ""
	_pending_source_hash = ""
	_pending_timeout_ms = DEFAULT_TIMEOUT_MS
	_queue.clear()
	_active_key = ""
	_last_completed_status = {}
	_last_completed_key = ""
	_last_started_script_path = ""
	_request_count = 0
	_status = {
		"available": false,
		"pending": false,
		"finished": true,
		"state": STATE_IDLE,
		"phase": STATE_IDLE,
		"parse_errors": [],
		"error_count": 0,
		"warning_count": 0
	}


func _start_next_job() -> void:
	if _pending_script_path.is_empty():
		return

	MCPDebugBuffer.record("info", "gdscript_lsp_diagnostics_service",
		"start pending job: %s" % _pending_script_path)
	_active_key = _make_key(_pending_script_path, _pending_source_hash)
	_last_started_script_path = _pending_script_path
	_request_count += 1
	_ensure_client()
	var start_status_raw: Variant = _client.start_diagnostics(
		_pending_script_path,
		_pending_source_code,
		_pending_timeout_ms
	)
	var start_status: Dictionary = {}
	if start_status_raw is Dictionary:
		start_status = start_status_raw
	_pending_script_path = ""
	_pending_source_code = ""
	_pending_source_hash = ""
	_pending_timeout_ms = DEFAULT_TIMEOUT_MS
	if not start_status.is_empty() and bool(start_status.get("finished", false)):
		_commit_status_for_job(_build_job_from_key(_active_key), start_status)
		return
	if not start_status.is_empty():
		_status = _duplicate_status(start_status)
	else:
		var job := _build_job_from_key(_active_key)
		_status = _build_pending_status(
			str(job.get("script_path", "")),
			str(job.get("source_hash", "")),
			STATE_CONNECTING
		)


func _commit_client_status(client_status: Dictionary) -> void:
	if _active_key.is_empty():
		return
	var job := _build_job_from_key(_active_key)
	_commit_status_for_job(job, client_status)


func _commit_status_for_job(job: Dictionary, status: Dictionary) -> void:
	var key := str(job.get("key", ""))
	if key.is_empty():
		return
	var stored := status.duplicate(true)
	stored["script"] = str(job.get("script_path", stored.get("script", "")))
	stored["source_hash"] = str(job.get("source_hash", stored.get("source_hash", "")))
	if bool(stored.get("available", false)):
		_store_cache(key, stored)
	else:
		_cache_by_key.erase(key)
		_cache_order.erase(key)
	_status = _duplicate_status(stored)
	_last_completed_key = key
	_last_completed_status = stored.duplicate(true)
	_active_key = ""


func _ensure_client() -> void:
	if _client != null and _client.has_method("tick"):
		return
	var lsp_client_script = ResourceLoader.load(
		LspClientPath,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)
	if lsp_client_script == null:
		return
	_client = lsp_client_script.new()


func _build_job_from_key(key: String) -> Dictionary:
	var parts := key.split("|", false, 1)
	if parts.size() < 2:
		return {}
	return {
		"key": key,
		"script_path": parts[0],
		"source_hash": parts[1]
	}


func _drop_queued_jobs_for_path(script_path: String) -> void:
	for index in range(_queue.size() - 1, -1, -1):
		if str(_queue[index].get("script_path", "")) == script_path:
			_queue.remove_at(index)


func _store_cache(key: String, result: Dictionary) -> void:
	_cache_by_key[key] = {
		"result": result.duplicate(true),
		"stored_at_unix": int(Time.get_unix_time_from_system())
	}
	_cache_order.erase(key)
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		var removed_key := _cache_order[0]
		_cache_order.remove_at(0)
		_cache_by_key.erase(removed_key)


func _build_pending_status(script_path: String, source_hash: String, state: String) -> Dictionary:
	return {
		"available": false,
		"pending": true,
		"finished": false,
		"state": state,
		"phase": state,
		"script": script_path,
		"source_hash": source_hash,
		"parse_errors": [],
		"error_count": 0,
		"warning_count": 0,
		"note": "Diagnostics are being resolved in the background."
	}


func _duplicate_status(status: Dictionary) -> Dictionary:
	var copy := status.duplicate(true)
	copy["available"] = bool(copy.get("available", false))
	copy["pending"] = bool(copy.get("pending", false))
	copy["finished"] = bool(copy.get("finished", false))
	if not copy.has("state"):
		copy["state"] = "ready" if bool(copy.get("available", false)) else "pending"
	if not copy.has("phase"):
		copy["phase"] = str(copy.get("state", STATE_IDLE))
	return copy


func _extract_status_error(status: Dictionary) -> String:
	return str(status.get("error", ""))


func _hash_source(source_code: String) -> String:
	return str(source_code.hash())


func _make_key(script_path: String, source_hash: String) -> String:
	return "%s|%s" % [script_path, source_hash]
