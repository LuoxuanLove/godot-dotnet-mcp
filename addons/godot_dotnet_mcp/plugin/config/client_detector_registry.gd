@tool
extends RefCounted
class_name ClientDetectorRegistry

const ClientConfigFileDetectorScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_file_detector.gd")
const ClientExecutableDetectorScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_executable_detector.gd")
const ClientCapabilityMatrixScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_capability_matrix.gd")
const ConfigPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_paths.gd")

var _path_resolver: Variant = null
var _runtime_inspector: Variant = null
var _config_entry_inspector: Variant = null


func configure(path_resolver: Variant, runtime_inspector: Variant, config_entry_inspector: Variant) -> void:
	_path_resolver = path_resolver
	_runtime_inspector = runtime_inspector
	_config_entry_inspector = config_entry_inspector


func get_supported_client_ids() -> PackedStringArray:
	return ClientCapabilityMatrixScript.get_supported_client_ids()


func detect_all(running_processes: PackedStringArray) -> Dictionary:
	return {
		"claude_desktop": _detect_config_client("claude_desktop", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, false),
		"claude_code": _detect_executable_client("claude_code", running_processes, true),
		"cursor": _detect_config_client("cursor", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, true),
		"trae": _detect_config_client("trae", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, false),
		"antigravity": _detect_config_client("antigravity", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, true),
		"codex_desktop": _detect_executable_client("codex_desktop", running_processes, false),
		"codex": _detect_executable_client("codex", running_processes, true),
		"gemini": _detect_executable_client("gemini", running_processes, true),
		"opencode_desktop": _detect_config_client("opencode_desktop", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, false),
		"opencode": _detect_executable_client("opencode", running_processes, false),
		"windsurf": _detect_config_client("windsurf", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, true),
		"cline": _detect_config_client("cline", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, false),
		"roo_code": _detect_config_client("roo_code", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, false),
		"qwen": _detect_executable_client("qwen", running_processes, true),
		"cherry_studio": _detect_executable_client("cherry_studio", running_processes, false)
	}


func _detect_config_client(client_id: String, config_type: String, running_processes: PackedStringArray, launch_supported: bool) -> Dictionary:
	var detector = ClientConfigFileDetectorScript.new()
	detector.configure_detector(
		client_id,
		_path_resolver,
		_runtime_inspector,
		_config_entry_inspector,
		{
			"config_path": _resolve_config_path(client_id),
			"candidates": [],
			"where_aliases": [client_id],
			"image_names": ["%s.exe" % client_id],
			"launch_supported": launch_supported,
			"config_type": config_type,
			"capability": ClientCapabilityMatrixScript.build_for_client(client_id, launch_supported, true, false, true)
		}
	)
	return detector.detect(running_processes)


func _detect_manual_guidance_client(client_id: String, running_processes: PackedStringArray, launch_supported: bool) -> Dictionary:
	var detector = ClientExecutableDetectorScript.new()
	var guidance_path := _resolve_config_path(client_id)
	detector.configure_detector(
		client_id,
		_path_resolver,
		_runtime_inspector,
		_config_entry_inspector,
		{
			"config_path": "",
			"where_aliases": [client_id],
			"image_names": ["%s.exe" % client_id],
			"launch_supported": launch_supported,
			"auto_add_supported": false,
			"write_supported": false,
			"inspect_config_entry": false,
			"capability": ClientCapabilityMatrixScript.build_for_client(client_id, launch_supported, true, false, false)
		}
	)
	var result: Dictionary = detector.detect(running_processes)
	result["guidance_path"] = guidance_path
	result["config_entry_status"] = {
		"status": "deferred",
		"has_server_entry": false,
		"deferred": true
	}
	result["write_supported"] = false
	result["auto_add_supported"] = false
	return result


func _detect_executable_client(client_id: String, running_processes: PackedStringArray, auto_add_supported: bool) -> Dictionary:
	var detector = ClientExecutableDetectorScript.new()
	var config_path := _resolve_config_path(client_id)
	var support_level := ClientCapabilityMatrixScript.get_support_level(client_id)
	detector.configure_detector(
		client_id,
		_path_resolver,
		_runtime_inspector,
		_config_entry_inspector,
		{
			"config_path": config_path,
			"where_aliases": [client_id],
			"image_names": ["%s.exe" % client_id],
			"launch_supported": true,
			"auto_add_supported": auto_add_supported,
			"write_supported": support_level == "full_write",
			"inspect_config_entry": not config_path.is_empty(),
			"config_type": "opencode" if client_id == "opencode" else "",
			"capability": ClientCapabilityMatrixScript.build_for_client(client_id, true, true, false, not config_path.is_empty())
		}
	)
	return detector.detect(running_processes)


func _resolve_config_path(client_id: String) -> String:
	match client_id:
		"cursor":
			return _path_from_home(".cursor/mcp.json", ConfigPathsScript.get_cursor_config_path())
		"claude_desktop":
			return _path_from_app_data("Claude/claude_desktop_config.json", ConfigPathsScript.get_claude_config_path())
		"trae":
			return _path_from_app_data("Trae/User/mcp.json", ConfigPathsScript.get_trae_config_path())
		"antigravity":
			return _path_from_home(".gemini/config/mcp_config.json", ConfigPathsScript.get_antigravity_mcp_config_path())
		"codex_desktop":
			return ""
		"gemini":
			return _path_from_home(".gemini/settings.json", ConfigPathsScript.get_gemini_config_path())
		"opencode_desktop":
			return ""
		"opencode":
			return _path_from_home(".config/opencode/opencode.json", ConfigPathsScript.get_opencode_config_path())
		"windsurf":
			return _path_from_home(".codeium/windsurf/mcp_config.json", ConfigPathsScript.get_windsurf_config_path())
		"cline":
			return _path_from_app_data("Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json", ConfigPathsScript.get_cline_config_path())
		"roo_code":
			return _path_from_app_data("Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json", ConfigPathsScript.get_roo_config_path())
		"qwen":
			return _path_from_home(".qwen/settings.json", ConfigPathsScript.get_qwen_config_path())
		"cherry_studio":
			return _path_from_app_data("CherryStudio", ConfigPathsScript.get_cherry_studio_config_hint_path())
		_:
			return ""


func _path_from_home(relative_path: String, fallback_path: String) -> String:
	return _path_from_resolver_root("get_home_root", relative_path, fallback_path)


func _path_from_app_data(relative_path: String, fallback_path: String) -> String:
	return _path_from_resolver_root("get_app_data_root", relative_path, fallback_path)


func _path_from_resolver_root(method_name: String, relative_path: String, fallback_path: String) -> String:
	if _path_resolver != null and _path_resolver.has_method(method_name):
		var root := _normalize_path(str(_path_resolver.call(method_name)))
		if not root.is_empty():
			return _normalize_path("%s/%s" % [root, relative_path])
	return fallback_path


func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges().trim_suffix("/")
