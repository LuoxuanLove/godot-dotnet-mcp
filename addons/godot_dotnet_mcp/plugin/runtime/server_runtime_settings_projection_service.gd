@tool
extends RefCounted
class_name ServerRuntimeSettingsProjectionService

const ENV_RUNTIME_SERVER_HOST := "GODOT_DOTNET_MCP_SERVER_HOST"
const ENV_RUNTIME_SERVER_PORT := "GODOT_DOTNET_MCP_SERVER_PORT"
const DEFAULT_HOST := "127.0.0.1"
const DEFAULT_PORT := 3000
const DEFAULT_TRANSPORT_MODE := "http"
const SUPPORTED_TRANSPORT_MODES := {
	"http": true,
	"stdio": true,
	"both": true
}


func project(settings: Dictionary) -> Dictionary:
	var runtime_settings := settings.duplicate(true)
	var has_explicit_host := _has_explicit_host(runtime_settings.get("host", DEFAULT_HOST))
	var has_explicit_port := _has_explicit_port(runtime_settings.get("port", DEFAULT_PORT))
	_apply_environment_overrides(runtime_settings, has_explicit_host, has_explicit_port)
	runtime_settings["host"] = _resolve_host(runtime_settings.get("host", DEFAULT_HOST))
	runtime_settings["port"] = _resolve_port(runtime_settings.get("port", DEFAULT_PORT))
	runtime_settings["debug_mode"] = _coerce_bool(runtime_settings.get("debug_mode", true))
	runtime_settings["disabled_tools"] = _normalize_disabled_tools(runtime_settings.get("disabled_tools", []))
	runtime_settings["transport_mode"] = _resolve_transport_mode(runtime_settings.get("transport_mode", DEFAULT_TRANSPORT_MODE))
	return runtime_settings


func _apply_environment_overrides(runtime_settings: Dictionary, has_explicit_host: bool, has_explicit_port: bool) -> void:
	if not has_explicit_host and OS.has_environment(ENV_RUNTIME_SERVER_HOST):
		var env_host := OS.get_environment(ENV_RUNTIME_SERVER_HOST).strip_edges()
		if not env_host.is_empty():
			runtime_settings["host"] = env_host
	if not has_explicit_port and OS.has_environment(ENV_RUNTIME_SERVER_PORT):
		var env_port_text := OS.get_environment(ENV_RUNTIME_SERVER_PORT).strip_edges()
		if env_port_text.is_valid_int() and int(env_port_text) > 0:
			runtime_settings["port"] = int(env_port_text)


func _has_explicit_host(value) -> bool:
	return _resolve_host(value) != DEFAULT_HOST


func _has_explicit_port(value) -> bool:
	return _resolve_port(value) != DEFAULT_PORT


func _resolve_host(value) -> String:
	var normalized := str(value).strip_edges()
	if normalized.is_empty():
		return DEFAULT_HOST
	return normalized


func _resolve_port(value) -> int:
	if value is int and int(value) > 0:
		return int(value)
	if value is float and float(value) > 0.0 and is_equal_approx(float(value), float(int(value))):
		return int(value)
	if value is String and String(value).strip_edges().is_valid_int():
		var parsed_port := int(String(value).strip_edges())
		if parsed_port > 0:
			return parsed_port
	return DEFAULT_PORT


func _resolve_transport_mode(value) -> String:
	var normalized := str(value).strip_edges().to_lower()
	if SUPPORTED_TRANSPORT_MODES.has(normalized):
		return normalized
	return DEFAULT_TRANSPORT_MODE


func _normalize_disabled_tools(value) -> Array[String]:
	var normalized_tools: Array[String] = []
	if not (value is Array):
		return normalized_tools
	for tool_variant in value:
		var tool_name := str(tool_variant).strip_edges()
		if tool_name.is_empty():
			continue
		normalized_tools.append(tool_name)
	return normalized_tools


func _coerce_bool(value) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return not is_zero_approx(value)
	if value is String:
		var normalized = value.strip_edges().to_lower()
		return normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on"
	return value != null
