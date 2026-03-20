@tool
extends RefCounted

const _CUSTOM_TOOLS_DIR = "res://addons/godot_dotnet_mcp/custom_tools"
const _CUSTOM_TOOLS_ENABLED_SETTING = "godot_dotnet_mcp/user_tools/enable_runtime_loading"
const _CUSTOM_TOOLS_ENABLED_SETTING_LEGACY = "user_tools/enable_runtime_loading"
const _RELOAD_DEBOUNCE_MSEC := 300

var _runtime_context: Dictionary = {}
var _slots_by_script: Dictionary = {}
var _tool_index: Dictionary = {}
var _requested_missing_scripts: Dictionary = {}
var _pending_refresh := false
var _last_scan_msec := 0


func _init() -> void:
	_request_full_refresh("initialize")


func configure_runtime(context: Dictionary) -> void:
	_runtime_context = context.duplicate(true)
	for slot in _slots_by_script.values():
		var instance = (slot as Dictionary).get("instance", null)
		if instance != null and instance.has_method("configure_runtime"):
			instance.configure_runtime(_runtime_context.duplicate(true))


func get_tools() -> Array[Dictionary]:
	_refresh_if_needed("get_tools")
	var tools: Array[Dictionary] = []
	for script_path in _get_sorted_script_paths():
		var slot: Dictionary = _slots_by_script.get(script_path, {})
		if slot.is_empty():
			continue
		for tool_def in slot.get("tool_defs", []):
			var tool_copy: Dictionary = (tool_def as Dictionary).duplicate(true)
			tool_copy["ui_category"] = "user"
			tool_copy["source"] = "user_tool"
			tool_copy["script_path"] = script_path
			tool_copy["runtime_domain"] = str(slot.get("runtime_domain", ""))
			tool_copy["runtime_version"] = int(slot.get("version", 0))
			tool_copy["state"] = str(slot.get("state", "uninitialized"))
			tool_copy["pending_reload"] = _as_bool(slot.get("pending_reload", false))
			tool_copy["last_error"] = slot.get("last_error", null)
			tool_copy["discovery_source"] = str(slot.get("discovery_source", "plugin_flow"))
			tool_copy["last_refresh_reason"] = str(slot.get("last_refresh_reason", ""))
			tools.append(tool_copy)
	return tools


func execute(tool_name: String, args: Dictionary) -> Dictionary:
	_refresh_if_needed("execute")
	var script_path = str(_tool_index.get(tool_name, ""))
	if script_path.is_empty():
		return {"success": false, "error": "Unknown user tool: %s" % tool_name}

	var slot: Dictionary = _slots_by_script.get(script_path, {})
	if slot.is_empty():
		return {"success": false, "error": "User tool runtime missing: %s" % tool_name}

	if _as_bool(slot.get("removed_pending", false)):
		return {"success": false, "error": "User tool is pending unload: %s" % tool_name}

	var instance = slot.get("instance", null)
	if instance == null:
		return {"success": false, "error": "User tool instance unavailable: %s" % tool_name}

	slot["active_calls"] = int(slot.get("active_calls", 0)) + 1
	_slots_by_script[script_path] = slot
	var result = instance.execute(tool_name, args)
	slot = _slots_by_script.get(script_path, slot)
	slot["active_calls"] = maxi(0, int(slot.get("active_calls", 1)) - 1)
	_slots_by_script[script_path] = slot
	_process_pending_slot_change(script_path)
	return result


func tick(_delta: float) -> void:
	if not _is_runtime_loading_enabled():
		if not _slots_by_script.is_empty():
			_request_full_refresh("runtime_loading_disabled")
		return
	var now_msec := Time.get_ticks_msec()
	if _pending_refresh or now_msec - _last_scan_msec >= _RELOAD_DEBOUNCE_MSEC:
		_refresh_if_needed("tick")
	for script_path in _get_sorted_script_paths():
		_process_pending_slot_change(script_path)


func handles(tool_name: String) -> bool:
	_refresh_if_needed("handles")
	return _tool_index.has(tool_name)


func before_unload(reason: String) -> void:
	for script_path in _get_sorted_script_paths():
		var slot: Dictionary = _slots_by_script.get(script_path, {})
		var instance = slot.get("instance", null)
		if instance != null and instance.has_method("before_unload"):
			instance.before_unload(reason)
		slot["state"] = "definitions_only"
		slot["instance"] = null
		_slots_by_script[script_path] = slot
	_tool_index.clear()


func get_runtime_state_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for script_path in _get_sorted_script_paths():
		var slot: Dictionary = _slots_by_script.get(script_path, {})
		if slot.is_empty():
			continue
		snapshot.append({
			"script_path": script_path,
			"runtime_domain": str(slot.get("runtime_domain", "")),
			"version": int(slot.get("version", 0)),
			"state": str(slot.get("state", "uninitialized")),
			"active_calls": int(slot.get("active_calls", 0)),
			"pending_reload": _as_bool(slot.get("pending_reload", false)),
			"removed_pending": _as_bool(slot.get("removed_pending", false)),
			"last_loaded_at_unix": int(slot.get("last_loaded_at_unix", 0)),
			"last_error": slot.get("last_error", null),
			"discovery_source": str(slot.get("discovery_source", "plugin_flow")),
			"last_refresh_reason": str(slot.get("last_refresh_reason", ""))
		})
	return snapshot


func should_unload_runtime() -> bool:
	if _pending_refresh:
		return false
	if not _requested_missing_scripts.is_empty():
		return false
	return _slots_by_script.is_empty()


func request_reload_by_script(script_path: String, reason: String = "manual") -> void:
	var normalized_path = _normalize_script_path(script_path)
	if normalized_path.is_empty():
		return
	var slot: Dictionary = _slots_by_script.get(normalized_path, {})
	if slot.is_empty():
		_requested_missing_scripts[normalized_path] = reason
		_pending_refresh = true
		return
	slot["pending_reload"] = true
	slot["pending_reason"] = reason
	slot["last_refresh_reason"] = reason
	slot["discovery_source"] = _get_discovery_source(reason)
	slot["state"] = "reload_pending"
	_slots_by_script[normalized_path] = slot


func request_reload_all(reason: String = "manual") -> void:
	for script_path in _get_sorted_script_paths():
		request_reload_by_script(script_path, reason)
	_pending_refresh = true


func _refresh_if_needed(reason: String) -> void:
	if not _is_runtime_loading_enabled():
		MCPDebugBuffer.record("info", "user", "User tool runtime loading disabled; unloading all slots")
		_unload_all("runtime_loading_disabled")
		_last_scan_msec = Time.get_ticks_msec()
		_pending_refresh = false
		return
	_reconcile_script_inventory(reason)
	_last_scan_msec = Time.get_ticks_msec()
	_pending_refresh = false


func _reconcile_script_inventory(reason: String) -> void:
	var discovered := {}
	var script_paths := _scan_custom_tool_scripts()
	MCPDebugBuffer.record("info", "user", "Discovered %d user tool scripts" % script_paths.size())
	for script_path in script_paths:
		discovered[script_path] = true
		var modified_unix = FileAccess.get_modified_time(script_path)
		var slot: Dictionary = _slots_by_script.get(script_path, {})
		if slot.is_empty():
			var slot_reason = str(_requested_missing_scripts.get(script_path, reason))
			_requested_missing_scripts.erase(script_path)
			var created = _create_slot(script_path, modified_unix, slot_reason)
			_slots_by_script[script_path] = created
			MCPDebugBuffer.record("info", "user", "Created runtime slot for %s" % script_path)
			continue
		if slot.get("instance", null) == null or (slot.get("tool_defs", []) as Array).is_empty():
			slot["pending_reload"] = true
			slot["pending_reason"] = "recover_empty_slot"
			slot["state"] = "reload_pending"
			_slots_by_script[script_path] = slot
			MCPDebugBuffer.record("info", "user", "Marked empty user tool slot for reload: %s" % script_path)
		if int(slot.get("last_seen_modified_unix", 0)) != modified_unix:
			slot["last_seen_modified_unix"] = modified_unix
			slot["pending_reload"] = true
			if not str(slot.get("pending_reason", "")).begins_with("watcher_"):
				slot["pending_reason"] = "file_changed"
			slot["last_refresh_reason"] = str(slot.get("pending_reason", "file_changed"))
			slot["discovery_source"] = _get_discovery_source(str(slot.get("pending_reason", "file_changed")))
			slot["state"] = "reload_pending"
			_slots_by_script[script_path] = slot

	for script_path in _slots_by_script.keys():
		if discovered.has(script_path):
			continue
		var slot: Dictionary = _slots_by_script.get(script_path, {})
		if int(slot.get("active_calls", 0)) > 0:
			slot["removed_pending"] = true
			slot["state"] = "waiting_quiesce"
			_slots_by_script[script_path] = slot
			continue
		_unload_slot(script_path, "script_removed")

	for script_path in _get_sorted_script_paths():
		var slot: Dictionary = _slots_by_script.get(script_path, {})
		if not _as_bool(slot.get("pending_reload", false)):
			continue
		if int(slot.get("active_calls", 0)) > 0 or not _can_slot_reload_now(slot):
			slot["state"] = "waiting_quiesce"
			_slots_by_script[script_path] = slot
			continue
		_reload_slot(script_path, str(slot.get("pending_reason", reason)))

	_rebuild_tool_index()


func _process_pending_slot_change(script_path: String) -> void:
	var slot: Dictionary = _slots_by_script.get(script_path, {})
	if slot.is_empty():
		return
	if int(slot.get("active_calls", 0)) > 0:
		return
	if _as_bool(slot.get("removed_pending", false)):
		_unload_slot(script_path, "script_removed")
		_rebuild_tool_index()
		return
	if _as_bool(slot.get("pending_reload", false)):
		MCPDebugBuffer.record("info", "user", "Processing pending reload for %s" % script_path)
		_reload_slot(script_path, str(slot.get("pending_reason", "pending_reload")))
		_rebuild_tool_index()


func _create_slot(script_path: String, modified_unix: int, reason: String) -> Dictionary:
	var slot := {
		"script_path": script_path,
		"runtime_domain": _build_runtime_domain(script_path),
		"instance": null,
		"tool_defs": [],
		"version": 0,
		"state": "reload_pending",
		"active_calls": 0,
		"pending_reload": true,
		"pending_reason": reason,
		"removed_pending": false,
		"last_loaded_at_unix": 0,
		"last_seen_modified_unix": modified_unix,
		"last_error": null,
		"discovery_source": _get_discovery_source(reason),
		"last_refresh_reason": reason
	}
	return slot


func _reload_slot(script_path: String, reason: String) -> void:
	var slot: Dictionary = _slots_by_script.get(script_path, {})
	if slot.is_empty():
		return
	MCPDebugBuffer.record("info", "user", "Reloading user tool slot %s (%s)" % [script_path, reason])
	var old_instance = slot.get("instance", null)
	var state_snapshot = null
	if old_instance != null and old_instance.has_method("snapshot_state"):
		state_snapshot = old_instance.snapshot_state()
	if old_instance != null and old_instance.has_method("before_unload"):
		old_instance.before_unload(reason)

	var load_result = _instantiate_user_tool(script_path, true)
	if not _as_bool(load_result.get("success", false)):
		slot["pending_reload"] = false
		slot["pending_reason"] = ""
		slot["state"] = "reload_failed"
		slot["last_error"] = str(load_result.get("error", "reload_failed"))
		slot["last_refresh_reason"] = reason
		slot["discovery_source"] = _get_discovery_source(reason)
		slot["instance"] = old_instance
		_slots_by_script[script_path] = slot
		MCPDebugBuffer.record("warning", "user", "Reload failed for %s: %s" % [script_path, slot["last_error"]])
		return

	var instance = load_result.get("instance", null)
	if instance != null and instance.has_method("restore_state") and state_snapshot != null:
		instance.restore_state(state_snapshot)
	if instance != null and instance.has_method("after_load"):
		instance.after_load(_runtime_context.duplicate(true))

	slot["instance"] = instance
	slot["tool_defs"] = load_result.get("tool_defs", []).duplicate(true)
	slot["version"] = int(slot.get("version", 0)) + 1
	slot["state"] = "loaded"
	slot["pending_reload"] = false
	slot["pending_reason"] = ""
	slot["removed_pending"] = false
	slot["last_loaded_at_unix"] = int(Time.get_unix_time_from_system())
	slot["last_error"] = null
	slot["last_refresh_reason"] = reason
	slot["discovery_source"] = _get_discovery_source(reason)
	_slots_by_script[script_path] = slot
	MCPDebugBuffer.record("info", "user", "Reloaded user tool runtime: %s v%d" % [script_path, int(slot.get("version", 0))])


func _instantiate_user_tool(script_path: String, force_reload: bool) -> Dictionary:
	var cache_mode = ResourceLoader.CACHE_MODE_IGNORE if force_reload else ResourceLoader.CACHE_MODE_REUSE
	var script = ResourceLoader.load(script_path, "", cache_mode)
	if script == null or not (script is Script):
		MCPDebugBuffer.record("warning", "user", "Failed to load user tool script: %s" % script_path)
		return {"success": false, "error": "Failed to load user tool script"}
	var executor_target = null
	var executor_mode := "instance"
	if (script as Script).can_instantiate():
		executor_target = (script as Script).new()
		if executor_target == null:
			MCPDebugBuffer.record("warning", "user", "User tool instance returned null: %s" % script_path)
			return {"success": false, "error": "User tool instance creation returned null"}
		if not executor_target.has_method("get_tools") or not executor_target.has_method("execute"):
			MCPDebugBuffer.record("warning", "user", "User tool missing required methods get_tools/execute: %s" % script_path)
			return {"success": false, "error": "User tool executor missing get_tools/execute"}
	else:
		MCPDebugBuffer.record("info", "user", "User tool will use static execution mode: %s" % script_path)
		if not script.has_method("get_tools") or not script.has_method("execute"):
			MCPDebugBuffer.record("warning", "user", "User tool static script is missing required methods get_tools/execute: %s" % script_path)
			return {"success": false, "error": "User tool static script missing get_tools/execute"}
		executor_target = script
		executor_mode = "static"
	if executor_target.has_method("configure_runtime"):
		executor_target.configure_runtime(_runtime_context.duplicate(true))

	var normalized_defs: Array[Dictionary] = []
	var raw_defs = executor_target.get_tools()
	if raw_defs is Array:
		MCPDebugBuffer.record("info", "user", "User tool %s returned %d definitions" % [script_path, (raw_defs as Array).size()])
	for tool_def in raw_defs:
		if not (tool_def is Dictionary):
			MCPDebugBuffer.record("warning", "user", "User tool returned non-dictionary definition: %s" % script_path)
			return {"success": false, "error": "User tool returned a non-dictionary tool definition"}
		var logical_name = _normalize_logical_tool_name(str(tool_def.get("name", "")))
		if logical_name.is_empty():
			MCPDebugBuffer.record("warning", "user", "User tool declared empty logical name: %s" % script_path)
			return {"success": false, "error": "User tool declared an empty tool name"}
		var tool_copy: Dictionary = (tool_def as Dictionary).duplicate(true)
		tool_copy["name"] = logical_name
		tool_copy["source"] = "user_tool"
		tool_copy["script_path"] = script_path
		normalized_defs.append(tool_copy)

	return {
		"success": true,
		"instance": executor_target,
		"executor_mode": executor_mode,
		"tool_defs": normalized_defs
	}


func _rebuild_tool_index() -> void:
	_tool_index.clear()
	for script_path in _get_sorted_script_paths():
		var slot: Dictionary = _slots_by_script.get(script_path, {})
		for tool_def in slot.get("tool_defs", []):
			var logical_name = str((tool_def as Dictionary).get("name", ""))
			if logical_name.is_empty():
				continue
			if _tool_index.has(logical_name):
				var conflict_slot: Dictionary = _slots_by_script.get(script_path, {})
				conflict_slot["last_error"] = "Duplicate user tool logical name: %s" % logical_name
				conflict_slot["state"] = "reload_failed"
				conflict_slot["tool_defs"] = []
				_slots_by_script[script_path] = conflict_slot
				continue
			_tool_index[logical_name] = script_path


func _unload_all(reason: String) -> void:
	for script_path in _get_sorted_script_paths():
		_unload_slot(script_path, reason)
	_slots_by_script.clear()
	_tool_index.clear()


func _unload_slot(script_path: String, reason: String) -> void:
	var slot: Dictionary = _slots_by_script.get(script_path, {})
	if slot.is_empty():
		return
	var instance = slot.get("instance", null)
	if instance != null and instance.has_method("before_unload"):
		instance.before_unload(reason)
	_slots_by_script.erase(script_path)


func _scan_custom_tool_scripts() -> Array[String]:
	var script_paths: Array[String] = []
	_collect_script_paths(_CUSTOM_TOOLS_DIR, script_paths)
	script_paths.sort()
	return script_paths


func _collect_script_paths(dir_path: String, output: Array[String]) -> void:
	var global_path = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(global_path):
		return
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry = dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path = "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_collect_script_paths(child_path, output)
		elif entry.ends_with(".gd"):
			var normalized_path = _normalize_script_path(child_path)
			if not normalized_path.is_empty():
				output.append(normalized_path)
	dir.list_dir_end()


func _normalize_script_path(script_path: String) -> String:
	var normalized = script_path.replace("\\", "/").trim_suffix("/")
	if normalized.is_empty():
		return ""
	if normalized.begins_with("res://"):
		return normalized
	var absolute_path = ProjectSettings.globalize_path(normalized)
	var tools_root = ProjectSettings.globalize_path(_CUSTOM_TOOLS_DIR)
	if absolute_path.is_empty() or not absolute_path.begins_with(tools_root):
		return ""
	return ProjectSettings.localize_path(absolute_path).replace("\\", "/")


func _build_runtime_domain(script_path: String) -> String:
	var relative_path = script_path.trim_prefix(_CUSTOM_TOOLS_DIR).trim_prefix("/")
	var slug = relative_path.get_basename().replace("/", "::")
	return "user::%s" % slug


func _normalize_logical_tool_name(tool_name: String) -> String:
	var normalized = tool_name.strip_edges()
	if normalized.begins_with("user_"):
		normalized = normalized.trim_prefix("user_")
	return normalized


func _is_runtime_loading_enabled() -> bool:
	if ProjectSettings.has_setting(_CUSTOM_TOOLS_ENABLED_SETTING):
		return true if ProjectSettings.get_setting(_CUSTOM_TOOLS_ENABLED_SETTING, false) else false
	return true if ProjectSettings.get_setting(_CUSTOM_TOOLS_ENABLED_SETTING_LEGACY, false) else false


func _request_full_refresh(_reason: String) -> void:
	_pending_refresh = true


func _get_sorted_script_paths() -> Array[String]:
	var paths: Array[String] = []
	for script_path in _slots_by_script.keys():
		paths.append(str(script_path))
	paths.sort()
	return paths


func _can_slot_reload_now(slot: Dictionary) -> bool:
	var instance = slot.get("instance", null)
	if instance == null:
		return true
	if instance.has_method("can_reload_now"):
		return _as_bool(instance.can_reload_now())
	return true


func _as_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return !is_zero_approx(value)
	if value is String:
		var normalized = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null


func _get_discovery_source(reason: String) -> String:
	return "external_watch" if reason.begins_with("watcher_") else "plugin_flow"
