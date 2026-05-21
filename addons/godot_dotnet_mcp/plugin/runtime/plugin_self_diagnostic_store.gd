@tool
extends RefCounted
class_name PluginSelfDiagnosticStore

const PluginInstanceFreshness = preload("res://addons/godot_dotnet_mcp/plugin/runtime/plugin_instance_freshness.gd")

const MAX_INCIDENTS := 200
const MAX_OPERATIONS := 100
const DEFAULT_LIMIT := 50
const SLOW_OPERATION_THRESHOLD_MS := 1200.0
const SLOW_OPERATION_WARNING_THRESHOLD_MS := 1500.0

## Operation-kind-specific thresholds (ms)
## Key: operation kind, Value: [warning_threshold_ms, critical_threshold_ms]
## If an operation kind is not listed, the global SLOW_OPERATION_THRESHOLD_MS / SLOW_OPERATION_WARNING_THRESHOLD_MS are used.
const OPERATION_KIND_THRESHOLDS := {
	"server_start": [2500.0, 4000.0],
	"server_reinitialize": [2500.0, 4000.0],
	"runtime_soft_reload": [2500.0, 4000.0],
	"runtime_full_reload": [2500.0, 4000.0],
	"plugin_enter_tree": [3000.0, 5000.0],
}

static var _incidents: Array[Dictionary] = []
static var _operations: Array[Dictionary] = []
static var _next_incident_id := 1
static var _next_operation_id := 1


static func clear() -> void:
	_incidents.clear()
	_operations.clear()
	_next_incident_id = 1
	_next_operation_id = 1


static func begin_operation(kind: String, phase: String = "", context: Dictionary = {}) -> Dictionary:
	var operation_id := "op_%06d" % _next_operation_id
	_next_operation_id += 1

	var operation := {
		"entry_type": "operation",
		"operation_id": operation_id,
		"kind": kind,
		"phase": phase,
		"started_at_ticks_usec": Time.get_ticks_usec(),
		"started_at_unix": int(Time.get_unix_time_from_system()),
		"started_at_text": Time.get_datetime_string_from_system(true, true),
		"ended_at_ticks_usec": 0,
		"ended_at_unix": 0,
		"ended_at_text": "",
		"duration_ms": 0.0,
		"success": false,
		"anomaly_codes": [],
		"phase_timings": [],
		"slowest_phase": {},
		"context": context.duplicate(true)
	}
	_operations.append(operation)
	_trim_operations()
	return operation.duplicate(true)


static func begin_phase() -> int:
	return Time.get_ticks_usec()


static func record_operation_phase(operation_id: String, phase_name: String, started_ticks_usec: int, context: Dictionary = {}) -> Dictionary:
	var ended_ticks_usec = Time.get_ticks_usec()
	var duration_ms = maxf(float(ended_ticks_usec - started_ticks_usec) / 1000.0, 0.0)
	return record_operation_phase_duration(operation_id, phase_name, duration_ms, context)


static func record_operation_phase_duration(operation_id: String, phase_name: String, duration_ms: float, context: Dictionary = {}) -> Dictionary:
	var normalized_phase = phase_name.strip_edges()
	if operation_id.is_empty() or normalized_phase.is_empty():
		return {}
	var timing := {
		"phase": normalized_phase,
		"duration_ms": maxf(duration_ms, 0.0),
		"context": context.duplicate(true)
	}
	for index in range(_operations.size() - 1, -1, -1):
		var operation := _operations[index]
		if str(operation.get("operation_id", "")) != operation_id:
			continue
		var phase_timings: Array = []
		var existing_timings = operation.get("phase_timings", [])
		if existing_timings is Array:
			phase_timings = (existing_timings as Array).duplicate(true)
		phase_timings.append(timing)
		operation["phase_timings"] = phase_timings
		operation["slowest_phase"] = _resolve_slowest_phase(operation)
		_operations[index] = operation
		return timing.duplicate(true)
	return {}


static func end_operation(operation_id: String, success: bool, anomaly_codes: Array = [], context: Dictionary = {}) -> Dictionary:
	for index in range(_operations.size() - 1, -1, -1):
		var operation := _operations[index]
		if str(operation.get("operation_id", "")) != operation_id:
			continue

		var ended_unix = int(Time.get_unix_time_from_system())
		var ended_ticks_usec = Time.get_ticks_usec()
		var duration_ms := maxf(float(ended_ticks_usec - int(operation.get("started_at_ticks_usec", ended_ticks_usec))) / 1000.0, 0.0)

		operation["ended_at_ticks_usec"] = ended_ticks_usec
		operation["ended_at_unix"] = ended_unix
		operation["ended_at_text"] = Time.get_datetime_string_from_system(true, true)
		operation["duration_ms"] = duration_ms
		operation["success"] = success
		operation["anomaly_codes"] = anomaly_codes.duplicate()

		var merged_context: Dictionary = {}
		var existing_context = operation.get("context", {})
		if existing_context is Dictionary:
			merged_context = (existing_context as Dictionary).duplicate(true)
		for key in context.keys():
			merged_context[key] = context[key]
		operation["context"] = merged_context
		operation["slowest_phase"] = _resolve_slowest_phase(operation)

		_operations[index] = operation
		return operation.duplicate(true)

	return {}


static func record_incident(
	severity: String,
	category: String,
	code: String,
	message: String,
	component: String,
	phase: String = "",
	file_path: String = "",
	line = "",
	operation_id: String = "",
	recoverable: bool = true,
	suggested_action: String = "",
	context: Dictionary = {}
) -> Dictionary:
	var normalized_severity = _normalize_severity(severity)
	var normalized_line = _normalize_line(line)
	var dedupe_key = "|".join([
		code,
		component,
		file_path,
		str(normalized_line),
		message
	])
	var now_unix = int(Time.get_unix_time_from_system())
	var now_text = Time.get_datetime_string_from_system(true, true)

	for index in range(_incidents.size() - 1, -1, -1):
		var existing := _incidents[index]
		if str(existing.get("dedupe_key", "")) != dedupe_key:
			continue
		existing["timestamp_unix"] = now_unix
		existing["timestamp_text"] = now_text
		existing["last_seen_unix"] = now_unix
		existing["last_seen_text"] = now_text
		existing["occurrence_count"] = int(existing.get("occurrence_count", 1)) + 1
		existing["severity"] = normalized_severity
		existing["category"] = category
		existing["code"] = code
		existing["message"] = message
		existing["component"] = component
		existing["phase"] = phase
		existing["file_path"] = file_path
		existing["line"] = normalized_line
		existing["operation_id"] = operation_id
		existing["recoverable"] = recoverable
		existing["suggested_action"] = suggested_action
		existing["context"] = context.duplicate(true)
		_incidents[index] = existing
		return existing.duplicate(true)

	var incident := {
		"entry_type": "incident",
		"id": "inc_%06d" % _next_incident_id,
		"timestamp_unix": now_unix,
		"timestamp_text": now_text,
		"first_seen_unix": now_unix,
		"first_seen_text": now_text,
		"last_seen_unix": now_unix,
		"last_seen_text": now_text,
		"severity": normalized_severity,
		"category": category,
		"code": code,
		"message": message,
		"component": component,
		"phase": phase,
		"file_path": file_path,
		"line": normalized_line,
		"operation_id": operation_id,
		"recoverable": recoverable,
		"suggested_action": suggested_action,
		"context": context.duplicate(true),
		"occurrence_count": 1,
		"dedupe_key": dedupe_key
	}
	_next_incident_id += 1
	_incidents.append(incident)
	_trim_incidents()
	return incident.duplicate(true)


static func record_slow_operation(operation: Dictionary, component: String, phase: String = "", threshold_ms: float = SLOW_OPERATION_THRESHOLD_MS) -> Dictionary:
	var duration_ms = float(operation.get("duration_ms", 0.0))
	var resolved_threshold_ms := threshold_ms
	var resolved_warning_threshold_ms := SLOW_OPERATION_WARNING_THRESHOLD_MS
	var operation_kind := str(operation.get("kind", ""))
	if OPERATION_KIND_THRESHOLDS.has(operation_kind):
		var thresholds = OPERATION_KIND_THRESHOLDS[operation_kind]
		resolved_threshold_ms = float(thresholds[0])
		resolved_warning_threshold_ms = float(thresholds[1])
	if duration_ms <= resolved_threshold_ms:
		return {}

	var slowest_phase = _resolve_slowest_phase(operation)
	var phase_timings = _resolve_phase_timings(operation)
	var message = "Operation exceeded the slow-operation threshold (%.1fms > %.1fms)" % [duration_ms, resolved_threshold_ms]
	var slowest_phase_summary = _format_phase_summary(slowest_phase)
	if not slowest_phase_summary.is_empty():
		message = "%s; slowest phase: %s" % [message, slowest_phase_summary]

	var severity := "warning" if duration_ms > resolved_warning_threshold_ms else "info"
	return record_incident(
		severity,
		"performance_warning",
		"operation_duration_slow",
		message,
		component,
		phase if not phase.is_empty() else str(operation.get("phase", "")),
		"",
		"",
		str(operation.get("operation_id", "")),
		true,
		"Inspect the slowest phase and the latest operation timeline.",
		{
			"kind": operation_kind,
			"duration_ms": duration_ms,
			"threshold_ms": resolved_threshold_ms,
			"warning_threshold_ms": resolved_warning_threshold_ms,
			"phase_timings": phase_timings,
			"slowest_phase": slowest_phase
		}
	)


static func get_incidents(severity: String = "", category: String = "", limit: int = DEFAULT_LIMIT) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	for incident in _incidents:
		if not severity.is_empty() and str(incident.get("severity", "")) != severity:
			continue
		if not category.is_empty() and str(incident.get("category", "")) != category:
			continue
		filtered.append(_strip_internal_fields(incident))
	filtered.sort_custom(Callable(PluginSelfDiagnosticStore, "_sort_timeline_desc"))
	return _apply_limit(filtered, limit)


static func get_operations(limit: int = DEFAULT_LIMIT) -> Array[Dictionary]:
	var operations: Array[Dictionary] = []
	for operation in _operations:
		operations.append(operation.duplicate(true))
	operations.sort_custom(Callable(PluginSelfDiagnosticStore, "_sort_timeline_desc"))
	return _apply_limit(operations, limit)


static func get_timeline(limit: int = DEFAULT_LIMIT) -> Array[Dictionary]:
	var timeline: Array[Dictionary] = []
	for operation in _operations:
		timeline.append(operation.duplicate(true))
	for incident in _incidents:
		timeline.append(_strip_internal_fields(incident))
	timeline.sort_custom(Callable(PluginSelfDiagnosticStore, "_sort_timeline_desc"))
	return _apply_limit(timeline, limit)


static func get_health_snapshot(snapshot: Dictionary = {}, limit: int = 3) -> Dictionary:
	var incidents = get_incidents("", "", MAX_INCIDENTS)
	var incident_counts := {
		"error": 0,
		"warning": 0,
		"info": 0
	}
	for incident in incidents:
		var severity = str(incident.get("severity", "info"))
		if not incident_counts.has(severity):
			incident_counts[severity] = 0
		incident_counts[severity] = int(incident_counts.get(severity, 0)) + 1

	var recent_incidents = _apply_limit(incidents, limit)
	var latest_incident = {}
	if not recent_incidents.is_empty():
		latest_incident = recent_incidents[0]
	var last_operation = {}
	var operations = get_operations(1)
	if not operations.is_empty():
		last_operation = operations[0]

	var tool_loader = snapshot.get("tool_loader", {})
	var freshness = snapshot.get("freshness", {})
	if not (freshness is Dictionary):
		freshness = PluginInstanceFreshness.get_freshness_snapshot()
	var tool_load_error_count = 0
	if tool_loader is Dictionary:
		tool_load_error_count = int((tool_loader as Dictionary).get("tool_load_error_count", 0))

	var active_incident_count = int(incident_counts.get("error", 0)) + int(incident_counts.get("warning", 0))
	var status := "ok"
	if int(incident_counts.get("error", 0)) > 0 or tool_load_error_count > 0:
		status = "error"
	elif active_incident_count > 0:
		status = "warning"

	var summary = "Plugin self diagnostics healthy."
	match status:
		"error":
			summary = "Plugin self diagnostics detected blocking incidents."
		"warning":
			summary = "Plugin self diagnostics detected recoverable issues."

	return {
		"status": status,
		"summary": summary,
		"incident_counts": incident_counts,
		"active_incident_count": active_incident_count,
		"latest_incident": latest_incident,
		"last_operation": last_operation,
		"autoload": (snapshot.get("autoload", {}) if snapshot.get("autoload", {}) is Dictionary else {}).duplicate(true),
		"server": (snapshot.get("server", {}) if snapshot.get("server", {}) is Dictionary else {}).duplicate(true),
		"dock": (snapshot.get("dock", {}) if snapshot.get("dock", {}) is Dictionary else {}).duplicate(true),
		"tool_loader": (tool_loader if tool_loader is Dictionary else {}).duplicate(true),
		"freshness": (freshness if freshness is Dictionary else {}).duplicate(true),
		"recent_incidents": recent_incidents
	}


static func build_copy_text(snapshot: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Plugin Self Diagnostics")
	lines.append("Status: %s" % str(snapshot.get("status", "ok")))
	lines.append("Summary: %s" % str(snapshot.get("summary", "")))
	lines.append("Active incidents: %d" % int(snapshot.get("active_incident_count", 0)))

	var tool_loader = snapshot.get("tool_loader", {})
	if tool_loader is Dictionary:
		lines.append("Tool load errors: %d" % int((tool_loader as Dictionary).get("tool_load_error_count", 0)))

	var last_operation = snapshot.get("last_operation", {})
	if last_operation is Dictionary and not (last_operation as Dictionary).is_empty():
		var last_operation_dict := last_operation as Dictionary
		lines.append("Last operation: %s (%sms)" % [
			str(last_operation_dict.get("kind", "")),
			str(last_operation_dict.get("duration_ms", 0.0))
		])
		var last_operation_phase = _format_phase_summary(last_operation_dict.get("slowest_phase", {}))
		if not last_operation_phase.is_empty():
			lines.append("Slowest operation phase: %s" % last_operation_phase)
		_append_phase_timing_lines(lines, "Operation phase timings", _resolve_phase_timings(last_operation_dict))
	var latest_incident = snapshot.get("latest_incident", {})
	if latest_incident is Dictionary and not (latest_incident as Dictionary).is_empty():
		var latest_incident_dict := latest_incident as Dictionary
		lines.append("Latest incident: [%s] %s: %s" % [
			str(latest_incident_dict.get("severity", "info")),
			str(latest_incident_dict.get("code", "")),
			str(latest_incident_dict.get("message", ""))
		])
		var latest_context = latest_incident_dict.get("context", {})
		if latest_context is Dictionary:
			var latest_phase = _format_phase_summary((latest_context as Dictionary).get("slowest_phase", {}))
			if not latest_phase.is_empty():
				lines.append("Slowest incident phase: %s" % latest_phase)
			_append_phase_timing_lines(lines, "Incident phase timings", _resolve_phase_timings(latest_context as Dictionary))

	for incident in snapshot.get("recent_incidents", []):
		if not (incident is Dictionary):
			continue
		lines.append("- [%s] %s: %s" % [
			str(incident.get("severity", "info")),
			str(incident.get("code", "")),
			str(incident.get("message", ""))
		])
	return "\n".join(lines)


static func _append_phase_timing_lines(lines: Array[String], title: String, phase_timings: Array) -> void:
	if phase_timings.is_empty():
		return
	lines.append("%s:" % title)
	for timing in phase_timings:
		var summary = _format_phase_summary(timing)
		if not summary.is_empty():
			lines.append("- %s" % summary)


static func _resolve_phase_timings(operation: Dictionary) -> Array:
	var phase_timings: Array = []
	var raw_timings = operation.get("phase_timings", [])
	if raw_timings is Array:
		for raw_timing in raw_timings:
			if raw_timing is Dictionary:
				phase_timings.append((raw_timing as Dictionary).duplicate(true))
	return phase_timings


static func _resolve_slowest_phase(operation: Dictionary) -> Dictionary:
	var phase_timings = _resolve_phase_timings(operation)
	if phase_timings.is_empty():
		return {}
	var slowest := {}
	for timing in phase_timings:
		var timing_dict := timing as Dictionary
		if slowest.is_empty() or float(timing_dict.get("duration_ms", 0.0)) > float(slowest.get("duration_ms", 0.0)):
			slowest = timing_dict.duplicate(true)
	return slowest


static func _format_phase_summary(phase) -> String:
	if not (phase is Dictionary) or (phase as Dictionary).is_empty():
		return ""
	var phase_dict := phase as Dictionary
	return "%s (%.1fms)" % [
		str(phase_dict.get("phase", "")),
		float(phase_dict.get("duration_ms", 0.0))
	]


static func _strip_internal_fields(incident: Dictionary) -> Dictionary:
	var cleaned = incident.duplicate(true)
	cleaned.erase("dedupe_key")
	return cleaned


static func _normalize_severity(severity: String) -> String:
	match str(severity).to_lower():
		"error":
			return "error"
		"warning":
			return "warning"
		_:
			return "info"


static func _normalize_line(line) -> Variant:
	if line is int:
		return int(line)
	var text = str(line).strip_edges()
	if text.is_valid_int():
		return int(text)
	return ""


static func _apply_limit(items: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var resolved_limit = maxi(limit, 0)
	if resolved_limit == 0 or items.size() <= resolved_limit:
		return items
	return items.slice(0, resolved_limit)


static func _trim_incidents() -> void:
	if _incidents.size() > MAX_INCIDENTS:
		_incidents = _incidents.slice(_incidents.size() - MAX_INCIDENTS)


static func _trim_operations() -> void:
	if _operations.size() > MAX_OPERATIONS:
		_operations = _operations.slice(_operations.size() - MAX_OPERATIONS)


static func _sort_timeline_desc(a: Dictionary, b: Dictionary) -> bool:
	var a_time = int(_resolve_sort_time(a))
	var b_time = int(_resolve_sort_time(b))
	if a_time != b_time:
		return a_time > b_time
	return str(a.get("id", a.get("operation_id", ""))) > str(b.get("id", b.get("operation_id", "")))


static func _resolve_sort_time(entry: Dictionary) -> int:
	if entry.has("timestamp_unix"):
		return int(entry.get("timestamp_unix", 0))
	return int(entry.get("ended_at_unix", entry.get("started_at_unix", 0)))
