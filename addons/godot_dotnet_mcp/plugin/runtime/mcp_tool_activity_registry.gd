@tool
extends RefCounted
class_name MCPToolActivityRegistry

const MAX_RECENT := 100
const CONTEXT_TEXT_LIMIT := 160
const DEFAULT_SLOW_THRESHOLD_MS := 0.0
const CONTEXT_KEYS := [
	"agent_id",
	"agent_role",
	"parent_agent_id",
	"session_label",
	"task",
	"purpose",
	"risk",
	"notes"
]

var _next_sequence := 1
var _running: Dictionary = {}
var _recent: Array[Dictionary] = []
var _order: Array[String] = []


static func is_protocol_activity_summary(value) -> bool:
	if not (value is Dictionary):
		return false
	return not str((value as Dictionary).get("call_id", "")).is_empty() and not str((value as Dictionary).get("state", "")).is_empty()


func begin_call(full_name: String, category: String, tool_name: String, args: Dictionary, agent_context: Dictionary = {}, transport: Dictionary = {}) -> Dictionary:
	var sequence := _next_sequence
	_next_sequence += 1
	var call_id := "tool-%d-%d" % [int(Time.get_unix_time_from_system()), sequence]
	var started_usec := Time.get_ticks_usec()
	var record := {
		"call_id": call_id,
		"sequence": sequence,
		"tool": full_name,
		"category": category,
		"tool_name": tool_name,
		"action": str(args.get("action", "")),
		"state": "running",
		"started_at_unix": int(Time.get_unix_time_from_system()),
		"finished_at_unix": 0,
		"duration_ms": 0.0,
		"connection_id": str(transport.get("connection_id", "")),
		"request_id": str(transport.get("request_id", "")),
		"transport": str(transport.get("transport", "")),
		"agent_context": _sanitize_agent_context(agent_context),
		"scope": _infer_scope(full_name, args),
		"error": "",
		"_started_usec": started_usec
	}
	_running[call_id] = record
	_order.append(call_id)
	return _public_record(record)


func finish_call(call_id: String, success: bool, error_message: String = "") -> Dictionary:
	if call_id.is_empty() or not _running.has(call_id):
		return {}
	var record: Dictionary = _running.get(call_id, {}).duplicate(true)
	_running.erase(call_id)
	_order.erase(call_id)
	record["state"] = "completed" if success else "failed"
	record["finished_at_unix"] = int(Time.get_unix_time_from_system())
	record["duration_ms"] = _elapsed_ms(int(record.get("_started_usec", Time.get_ticks_usec())))
	record["error"] = error_message if not success else ""
	_recent.push_front(record)
	while _recent.size() > MAX_RECENT:
		_recent.pop_back()
	return _public_record(record)


func get_status(options: Dictionary = {}) -> Dictionary:
	var filters := _normalize_filters(options)
	var running_records := _build_running_records(filters)
	var recent_records := _build_recent_records(10, filters)
	var slow_threshold_ms := float(filters.get("slow_threshold_ms", DEFAULT_SLOW_THRESHOLD_MS))
	var failure_limit := int(filters.get("failure_limit", 10))
	return {
		"running_count": _running.size(),
		"recent_count": _recent.size(),
		"filtered_running_count": running_records.size(),
		"filtered_recent_count": _count_recent_matches(filters),
		"running": running_records,
		"recent": recent_records,
		"execution_order": _build_execution_order(),
		"max_recent": MAX_RECENT,
		"filters": _public_filters(filters),
		"slow_threshold_ms": slow_threshold_ms,
		"slow_running": _build_slow_running_records(slow_threshold_ms, filters),
		"recent_failures": _build_recent_failure_records(failure_limit, filters)
	}


func get_recent(limit: int = 20, options: Dictionary = {}) -> Dictionary:
	var filters := _normalize_filters(options)
	var recent_limit := clamp(limit, 1, MAX_RECENT)
	var recent_records := _build_recent_records(recent_limit, filters)
	var slow_threshold_ms := float(filters.get("slow_threshold_ms", DEFAULT_SLOW_THRESHOLD_MS))
	var failure_limit := int(filters.get("failure_limit", recent_limit))
	return {
		"recent": recent_records,
		"recent_count": _recent.size(),
		"filtered_recent_count": _count_recent_matches(filters),
		"max_recent": MAX_RECENT,
		"filters": _public_filters(filters),
		"slow_threshold_ms": slow_threshold_ms,
		"slow_recent": _build_slow_recent_records(recent_limit, slow_threshold_ms, filters),
		"recent_failures": _build_recent_failure_records(failure_limit, filters)
	}


func get_call(call_id: String) -> Dictionary:
	if _running.has(call_id):
		return {
			"found": true,
			"call": _public_record(_running.get(call_id, {}))
		}
	for record in _recent:
		if str(record.get("call_id", "")) == call_id:
			return {
				"found": true,
				"call": _public_record(record)
			}
	return {
		"found": false,
		"call_id": call_id
	}


func summarize_record(record: Dictionary) -> Dictionary:
	if record.is_empty():
		return {}
	var public_record := _public_record(record)
	return {
		"call_id": str(public_record.get("call_id", "")),
		"tool": str(public_record.get("tool", "")),
		"action": str(public_record.get("action", "")),
		"state": str(public_record.get("state", "")),
		"duration_ms": float(public_record.get("duration_ms", 0.0))
	}


func _build_running_records(filters: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for call_id in _order:
		if _running.has(call_id):
			var record: Dictionary = _running.get(call_id, {})
			if _record_matches(record, filters):
				out.append(_public_record(record))
	return out


func _build_recent_records(limit: int, filters: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if limit <= 0:
		return out
	for record in _recent:
		if not _record_matches(record, filters):
			continue
		out.append(_public_record(record))
		if out.size() >= limit:
			break
	return out


func _build_execution_order() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for call_id in _order:
		var record: Dictionary = _running.get(call_id, {})
		out.append({
			"call_id": call_id,
			"tool": str(record.get("tool", "")),
			"state": str(record.get("state", "running"))
		})
	return out


func _public_record(record: Dictionary) -> Dictionary:
	var out := record.duplicate(true)
	if str(out.get("state", "")) == "running":
		out["duration_ms"] = _elapsed_ms(int(out.get("_started_usec", Time.get_ticks_usec())))
	out.erase("_started_usec")
	return out


func _normalize_filters(options: Dictionary) -> Dictionary:
	var state := str(options.get("state", "")).strip_edges().to_lower()
	var tool := str(options.get("tool", "")).strip_edges().to_lower()
	var slow_threshold_ms := float(options.get("slow_threshold_ms", DEFAULT_SLOW_THRESHOLD_MS))
	if options.has("threshold_ms") and not options.has("slow_threshold_ms"):
		slow_threshold_ms = float(options.get("threshold_ms", DEFAULT_SLOW_THRESHOLD_MS))
	if slow_threshold_ms < 0.0:
		slow_threshold_ms = 0.0
	var failure_limit := int(options.get("failure_limit", 10))
	failure_limit = clamp(failure_limit, 0, MAX_RECENT)
	return {
		"state": state,
		"tool": tool,
		"slow_threshold_ms": slow_threshold_ms,
		"failure_limit": failure_limit
	}


func _public_filters(filters: Dictionary) -> Dictionary:
	var out := {}
	for key in ["state", "tool"]:
		var value := str(filters.get(key, ""))
		if not value.is_empty():
			out[key] = value
	var slow_threshold_ms := float(filters.get("slow_threshold_ms", DEFAULT_SLOW_THRESHOLD_MS))
	if slow_threshold_ms > 0.0:
		out["slow_threshold_ms"] = slow_threshold_ms
	var failure_limit := int(filters.get("failure_limit", 10))
	if failure_limit != 10:
		out["failure_limit"] = failure_limit
	return out


func _record_matches(record: Dictionary, filters: Dictionary) -> bool:
	var state_filter := str(filters.get("state", ""))
	if not state_filter.is_empty() and str(record.get("state", "")).to_lower() != state_filter:
		return false
	var tool_filter := str(filters.get("tool", ""))
	if tool_filter.is_empty():
		return true
	for field in ["tool", "tool_name", "category", "action"]:
		if str(record.get(field, "")).to_lower().find(tool_filter) >= 0:
			return true
	return false


func _count_recent_matches(filters: Dictionary) -> int:
	var count := 0
	for record in _recent:
		if _record_matches(record, filters):
			count += 1
	return count


func _build_slow_running_records(threshold_ms: float, filters: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if threshold_ms <= 0.0:
		return out
	for record in _build_running_records(filters):
		if float(record.get("duration_ms", 0.0)) >= threshold_ms:
			out.append(record)
	return out


func _build_slow_recent_records(limit: int, threshold_ms: float, filters: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if threshold_ms <= 0.0:
		return out
	for record in _recent:
		if not _record_matches(record, filters):
			continue
		var public_record := _public_record(record)
		if float(public_record.get("duration_ms", 0.0)) < threshold_ms:
			continue
		out.append(public_record)
		if out.size() >= limit:
			break
	return out


func _build_recent_failure_records(limit: int, filters: Dictionary) -> Array[Dictionary]:
	var state_filter := str(filters.get("state", ""))
	if not state_filter.is_empty() and state_filter != "failed":
		return []
	var failure_filters := filters.duplicate()
	failure_filters["state"] = "failed"
	var out: Array[Dictionary] = []
	if limit <= 0:
		return out
	for record in _recent:
		if not _record_matches(record, failure_filters):
			continue
		out.append(_failure_summary(record))
		if out.size() >= limit:
			break
	return out


func _failure_summary(record: Dictionary) -> Dictionary:
	var public_record := _public_record(record)
	var out := summarize_record(public_record)
	out["finished_at_unix"] = int(public_record.get("finished_at_unix", 0))
	var error_message := str(public_record.get("error", ""))
	if not error_message.is_empty():
		out["error"] = error_message
	return out


func _sanitize_agent_context(context: Dictionary) -> Dictionary:
	var out := {}
	for key in CONTEXT_KEYS:
		if not context.has(key):
			continue
		var value := str(context.get(key, "")).strip_edges()
		if value.is_empty():
			continue
		if value.length() > CONTEXT_TEXT_LIMIT:
			value = value.substr(0, CONTEXT_TEXT_LIMIT)
		out[key] = value
	return out


func _infer_scope(full_name: String, args: Dictionary) -> Dictionary:
	var scope := {
		"tool": full_name,
		"action": str(args.get("action", "")),
		"risk": "observed"
	}
	for key in ["scene", "script", "path", "source", "dest"]:
		if args.has(key):
			scope[key] = str(args.get(key, ""))
	return scope


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
