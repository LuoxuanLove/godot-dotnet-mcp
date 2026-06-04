@tool
extends RefCounted
class_name MCPToolActivityRegistry

const MAX_RECENT := 100
const CONTEXT_TEXT_LIMIT := 160
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


func get_status() -> Dictionary:
	return {
		"running_count": _running.size(),
		"recent_count": _recent.size(),
		"running": _build_running_records(),
		"recent": _build_recent_records(10),
		"execution_order": _build_execution_order(),
		"max_recent": MAX_RECENT
	}


func get_recent(limit: int = 20) -> Dictionary:
	return {
		"recent": _build_recent_records(clamp(limit, 1, MAX_RECENT)),
		"recent_count": _recent.size(),
		"max_recent": MAX_RECENT
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
	return {
		"call_id": str(record.get("call_id", "")),
		"tool": str(record.get("tool", "")),
		"action": str(record.get("action", "")),
		"state": str(record.get("state", "")),
		"duration_ms": float(record.get("duration_ms", 0.0))
	}


func _build_running_records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for call_id in _order:
		if _running.has(call_id):
			out.append(_public_record(_running.get(call_id, {})))
	return out


func _build_recent_records(limit: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var count = min(limit, _recent.size())
	for i in range(count):
		out.append(_public_record(_recent[i]))
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
	out.erase("_started_usec")
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
