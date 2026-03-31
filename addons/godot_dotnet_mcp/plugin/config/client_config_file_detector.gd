@tool
extends "res://addons/godot_dotnet_mcp/plugin/config/client_detector_base.gd"
class_name ClientConfigFileDetector

const STATUS_READY := "ready"
const STATUS_CONFIG_ONLY := "config_only"

var _config_path := ""
var _config_type := ""
var _candidates: Array[String] = []
var _where_aliases: Array[String] = []
var _extra_candidates: Array[String] = []
var _image_names: Array[String] = []
var _launch_supported := false


func configure_detector(
	client_id: String,
	path_resolver,
	runtime_inspector,
	config_entry_inspector,
	spec: Dictionary
) -> void:
	configure(client_id, path_resolver, runtime_inspector, config_entry_inspector)
	_config_path = str(spec.get("config_path", ""))
	_config_type = str(spec.get("config_type", ""))
	_candidates = _to_string_array(spec.get("candidates", []))
	_where_aliases = _to_string_array(spec.get("where_aliases", []))
	_extra_candidates = _to_string_array(spec.get("extra_candidates", []))
	_image_names = _to_string_array(spec.get("image_names", []))
	_launch_supported = bool(spec.get("launch_supported", false))


func detect(running_processes: PackedStringArray) -> Dictionary:
	var resolved = _path_resolver.resolve_executable_path(_client_id, _candidates, _where_aliases, _extra_candidates)
	var entry_state = _config_entry_inspector.inspect_config_entry(_config_path, _config_type)
	var runtime_state = _runtime_inspector.build_runtime_state(
		str(resolved.get("path", "")),
		_image_names,
		running_processes
	)
	var config_supported = _config_entry_inspector.can_prepare_file_path(_config_path)
	var result = _build_common_result(resolved, runtime_state, entry_state)
	result["config_path"] = _config_path
	result["write_supported"] = config_supported
	result["launch_supported"] = _launch_supported and not str(resolved.get("path", "")).is_empty()
	result["path_pick_supported"] = true
	result["path_clear_supported"] = bool(resolved.get("has_manual_path", false))
	if not str(resolved.get("path", "")).is_empty() and config_supported:
		result["status"] = STATUS_READY
	elif config_supported:
		result["status"] = STATUS_CONFIG_ONLY
	else:
		result["status"] = STATUS_MISSING
	return result


func dispose() -> void:
	super.dispose()
	_config_path = ""
	_config_type = ""
	_candidates = []
	_where_aliases = []
	_extra_candidates = []
	_image_names = []
	_launch_supported = false


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result
