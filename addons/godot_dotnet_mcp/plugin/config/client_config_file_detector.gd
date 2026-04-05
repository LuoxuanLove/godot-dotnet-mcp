@tool
extends RefCounted
class_name ClientConfigFileDetector

var _client_id := ""
var _path_resolver: Variant = null
var _runtime_inspector: Variant = null
var _config_entry_inspector: Variant = null
var _options: Dictionary = {}


func configure_detector(client_id: String, path_resolver: Variant, runtime_inspector: Variant, config_entry_inspector: Variant, options: Dictionary = {}) -> void:
	_client_id = client_id
	_path_resolver = path_resolver
	_runtime_inspector = runtime_inspector
	_config_entry_inspector = config_entry_inspector
	_options = options.duplicate(true)


func detect(running_processes: PackedStringArray) -> Dictionary:
	var config_path = str(_options.get("config_path", ""))
	var candidates: Array[String] = _to_typed_string_array(_options.get("candidates", []))
	var where_aliases: Array[String] = _to_typed_string_array(_options.get("where_aliases", []))
	var extra_candidates: Array[String] = _to_typed_string_array(_options.get("extra_candidates", []))
	var image_names: Array[String] = _to_typed_string_array(_options.get("image_names", []))
	var resolved = _path_resolver.resolve_executable_path(
		_client_id,
		candidates,
		where_aliases,
		extra_candidates
	)
	var runtime_state = _runtime_inspector.build_runtime_state(str(resolved.get("path", "")), image_names, running_processes)
	var config_entry_status = _config_entry_inspector.inspect_config_entry(config_path, str(_options.get("config_type", "")))
	var can_write = bool(_options.get("launch_supported", false)) or not config_path.is_empty()
	var has_path = not str(resolved.get("path", "")).is_empty()

	return {
		"id": _client_id,
		"status": "ready" if has_path and can_write else ("config_only" if can_write else "missing"),
		"path": str(resolved.get("path", "")),
		"detected_via": str(resolved.get("detected_via", "")),
		"using_manual_path": bool(resolved.get("using_manual_path", false)),
		"has_manual_path": bool(resolved.get("has_manual_path", false)),
		"manual_path_invalid": bool(resolved.get("manual_path_invalid", false)),
		"manual_path": str(resolved.get("manual_path", "")),
		"config_path": config_path,
		"write_supported": can_write,
		"launch_supported": bool(_options.get("launch_supported", false)),
		"path_pick_supported": true,
		"path_clear_supported": bool(resolved.get("has_manual_path", false)),
		"runtime_state": runtime_state,
		"config_entry_status": config_entry_status
	}


func _to_typed_string_array(values: Variant) -> Array[String]:
	var typed_values: Array[String] = []
	if values is Array:
		for value in values:
			typed_values.append(str(value))
	return typed_values
