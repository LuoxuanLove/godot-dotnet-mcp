@tool
extends RefCounted
class_name ClientDetectorRegistry

const ClientConfigFileDetectorScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_file_detector.gd")
const ClientExecutableDetectorScript = preload("res://addons/godot_dotnet_mcp/plugin/config/client_executable_detector.gd")

var _path_resolver: Variant = null
var _runtime_inspector: Variant = null
var _config_entry_inspector: Variant = null


func configure(path_resolver: Variant, runtime_inspector: Variant, config_entry_inspector: Variant) -> void:
	_path_resolver = path_resolver
	_runtime_inspector = runtime_inspector
	_config_entry_inspector = config_entry_inspector


func get_supported_client_ids() -> PackedStringArray:
	return PackedStringArray([
		"claude_desktop",
		"claude_code",
		"cursor",
		"trae",
		"codex_desktop",
		"codex",
		"gemini",
		"opencode_desktop",
		"opencode",
		"windsurf",
		"cline",
		"roo_code",
		"qwen",
		"cherry_studio"
	])


func detect_all(running_processes: PackedStringArray) -> Dictionary:
	return {
		"claude_desktop": _detect_config_client("claude_desktop", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, false),
		"claude_code": _detect_executable_client("claude_code", running_processes, false),
		"cursor": _detect_config_client("cursor", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, true),
		"trae": _detect_config_client("trae", "res://addons/godot_dotnet_mcp/plugin/config/client_config_service.gd", running_processes, false),
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
			"config_type": config_type
		}
	)
	return detector.detect(running_processes)


func _detect_executable_client(client_id: String, running_processes: PackedStringArray, auto_add_supported: bool) -> Dictionary:
	var detector = ClientExecutableDetectorScript.new()
	detector.configure_detector(
		client_id,
		_path_resolver,
		_runtime_inspector,
		_config_entry_inspector,
		{
			"config_path": _resolve_config_path(client_id),
			"where_aliases": [client_id],
			"image_names": ["%s.exe" % client_id],
			"launch_supported": true,
			"auto_add_supported": auto_add_supported,
			"inspect_config_entry": true,
			"config_type": "opencode" if client_id == "opencode" else ""
		}
	)
	return detector.detect(running_processes)


func _resolve_config_path(client_id: String) -> String:
	match client_id:
		"cursor":
			return "C:/Users/Test/.cursor/mcp.json"
		"claude_desktop":
			return "C:/Users/Test/Claude/claude_desktop.json"
		"trae":
			return "C:/Users/Test/Trae/config.json"
		"codex_desktop":
			return "C:/Users/Test/Codex/config.json"
		"gemini":
			return "C:/Users/Test/.gemini/settings.json"
		"opencode_desktop":
			return "C:/Users/Test/.opencode/config.json"
		"opencode":
			return "C:/Users/Test/.config/opencode/opencode.json"
		"windsurf":
			return "C:/Users/Test/.codeium/windsurf/mcp_config.json"
		"cline":
			return "C:/Users/Test/AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
		"roo_code":
			return "C:/Users/Test/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json"
		"qwen":
			return "C:/Users/Test/.qwen/settings.json"
		"cherry_studio":
			return "C:/Users/Test/AppData/Roaming/CherryStudio"
		_:
			return ""
