@tool
extends RefCounted
class_name ClientDetectorRegistry

const ConfigPathsScript = preload("res://addons/godot_dotnet_mcp/plugin/config/config_paths.gd")
const ClientConfigFileDetector = preload("res://addons/godot_dotnet_mcp/plugin/config/client_config_file_detector.gd")
const ClientExecutableDetector = preload("res://addons/godot_dotnet_mcp/plugin/config/client_executable_detector.gd")

var _path_resolver = null
var _runtime_inspector = null
var _config_entry_inspector = null
var _detector_order: Array[String] = []
var _detectors: Dictionary = {}


func configure(path_resolver, runtime_inspector, config_entry_inspector) -> void:
	_path_resolver = path_resolver
	_runtime_inspector = runtime_inspector
	_config_entry_inspector = config_entry_inspector
	_rebuild_detectors()


func detect_all(running_processes: PackedStringArray) -> Dictionary:
	var results := {}
	for client_id in _detector_order:
		var detector = _detectors.get(client_id, null)
		if detector == null:
			continue
		results[client_id] = detector.detect(running_processes)
	return results


func detect_client(client_id: String, running_processes: PackedStringArray = PackedStringArray()) -> Dictionary:
	var detector = _detectors.get(client_id, null)
	if detector == null:
		return {}
	return detector.detect(running_processes)


func get_supported_client_ids() -> Array[String]:
	return _copy_string_array(_detector_order)


func dispose() -> void:
	for detector in _detectors.values():
		if detector != null and detector.has_method("dispose"):
			detector.dispose()
	_detectors.clear()
	_detector_order.clear()
	_path_resolver = null
	_runtime_inspector = null
	_config_entry_inspector = null


func _rebuild_detectors() -> void:
	for detector in _detectors.values():
		if detector != null and detector.has_method("dispose"):
			detector.dispose()
	_detectors.clear()
	_detector_order.clear()

	for detector in _build_detectors():
		if detector == null or not detector.has_method("get_client_id"):
			continue
		var client_id = str(detector.get_client_id())
		if client_id.is_empty():
			continue
		_detector_order.append(client_id)
		_detectors[client_id] = detector


func _build_detectors() -> Array:
	if _path_resolver == null:
		return []
	return [
		_build_config_detector("claude_desktop", {
			"config_path": ConfigPathsScript.get_claude_config_path(),
			"candidates": [
				"%s/Programs/Claude/Claude.exe" % _path_resolver.get_local_app_data_root(),
				"%s/Programs/Claude/claude.exe" % _path_resolver.get_local_app_data_root(),
				"%s/Claude/Claude.exe" % _path_resolver.get_program_files_root(),
				"%s/Claude/claude.exe" % _path_resolver.get_program_files_root(),
				"%s/Claude/Claude.exe" % _path_resolver.get_secondary_program_files_root(),
				"%s/Claude/claude.exe" % _path_resolver.get_secondary_program_files_root()
			],
			"where_aliases": ["claude"],
			"image_names": ["claude.exe"],
			"launch_supported": false
		}),
		_build_executable_detector("claude_code", {
			"candidates": [
				"%s/npm/claude.cmd" % _path_resolver.get_app_data_root(),
				"%s/npm/claude" % _path_resolver.get_app_data_root(),
				"%s/.local/bin/claude.exe" % _path_resolver.get_home_root()
			],
			"where_aliases": ["claude"],
			"image_names": ["claude.exe"],
			"launch_supported": true
		}),
		_build_config_detector("cursor", {
			"config_path": ConfigPathsScript.get_cursor_config_path(),
			"candidates": [
				"%s/Cursor/Cursor.exe" % _path_resolver.get_local_app_data_root(),
				"%s/Programs/Cursor/Cursor.exe" % _path_resolver.get_local_app_data_root(),
				"%s/cursor/Cursor.exe" % _path_resolver.get_program_files_root(),
				"%s/cursor/resources/app/bin/cursor.cmd" % _path_resolver.get_program_files_root(),
				"%s/cursor/resources/app/bin/cursor" % _path_resolver.get_program_files_root(),
				"%s/cursor/Cursor.exe" % _path_resolver.get_secondary_program_files_root(),
				"%s/cursor/resources/app/bin/cursor.cmd" % _path_resolver.get_secondary_program_files_root(),
				"%s/cursor/resources/app/bin/cursor" % _path_resolver.get_secondary_program_files_root()
			],
			"where_aliases": ["cursor"],
			"image_names": ["cursor.exe"],
			"launch_supported": true
		}),
		_build_config_detector("trae", {
			"config_path": ConfigPathsScript.get_trae_config_path(),
			"candidates": [
				"%s/Trae CN/Trae CN.exe" % _path_resolver.get_program_files_root(),
				"%s/Trae/Trae.exe" % _path_resolver.get_program_files_root(),
				"%s/Programs/Trae CN/Trae CN.exe" % _path_resolver.get_local_app_data_root(),
				"%s/Programs/Trae/Trae.exe" % _path_resolver.get_local_app_data_root(),
				"%s/Trae CN/Trae CN.exe" % _path_resolver.get_secondary_program_files_root(),
				"%s/Trae/Trae.exe" % _path_resolver.get_secondary_program_files_root()
			],
			"where_aliases": ["trae-cn", "trae"],
			"image_names": ["trae cn.exe", "trae.exe"],
			"launch_supported": true
		}),
		_build_executable_detector("codex_desktop", {
			"candidates": _build_codex_desktop_candidates(),
			"where_aliases": ["codex-desktop", "codexdesktop", "openai-codex"],
			"extra_candidates": _path_resolver.collect_appx_package_candidates(
				"OpenAI.Codex",
				_to_string_array(["app/Codex.exe"])
			),
			"image_names": ["codex.exe", "codex desktop.exe"]
		}),
		_build_executable_detector("codex", {
			"config_path": ConfigPathsScript.get_codex_config_path(),
			"candidates": [
				"%s/npm/codex.cmd" % _path_resolver.get_app_data_root(),
				"%s/npm/codex" % _path_resolver.get_app_data_root(),
				"%s/.vscode/extensions/openai.chatgpt-26.318.11754-win32-x64/bin/windows-x86_64/codex.exe" % _path_resolver.get_home_root()
			],
			"where_aliases": ["codex"],
			"image_names": ["codex.exe"],
			"launch_supported": true,
			"auto_add_supported": true
		}),
		_build_executable_detector("opencode_desktop", {
			"config_path": ConfigPathsScript.get_opencode_config_path(),
			"config_type": "opencode",
			"candidates": [
				"%s/OpenCode/OpenCode.exe" % _path_resolver.get_program_files_root(),
				"%s/OpenCode/OpenCode.exe" % _path_resolver.get_secondary_program_files_root(),
				"%s/Programs/OpenCode/OpenCode.exe" % _path_resolver.get_local_app_data_root()
			],
			"where_aliases": ["opencode-desktop"],
			"image_names": ["opencode.exe", "opencode-desktop.exe", "opencode desktop.exe"],
			"inspect_config_entry": true
		}),
		_build_config_detector("opencode", {
			"config_path": ConfigPathsScript.get_opencode_config_path(),
			"config_type": "opencode",
			"candidates": [
				"%s/OpenCode/opencode-cli.exe" % _path_resolver.get_program_files_root(),
				"%s/OpenCode/opencode-cli.exe" % _path_resolver.get_secondary_program_files_root(),
				"%s/npm/opencode.cmd" % _path_resolver.get_app_data_root(),
				"%s/npm/opencode" % _path_resolver.get_app_data_root()
			],
			"where_aliases": ["opencode"],
			"image_names": ["opencode-cli.exe", "opencode.exe"],
			"launch_supported": true
		}),
	]


func _build_config_detector(client_id: String, spec: Dictionary):
	var detector = ClientConfigFileDetector.new()
	detector.configure_detector(client_id, _path_resolver, _runtime_inspector, _config_entry_inspector, spec)
	return detector


func _build_executable_detector(client_id: String, spec: Dictionary):
	var detector = ClientExecutableDetector.new()
	detector.configure_detector(client_id, _path_resolver, _runtime_inspector, _config_entry_inspector, spec)
	return detector


func _build_codex_desktop_candidates() -> Array[String]:
	return _to_string_array([
		"%s/Codex Desktop/Codex Desktop.exe" % _path_resolver.get_program_files_root(),
		"%s/Codex Desktop/Codex.exe" % _path_resolver.get_program_files_root(),
		"%s/Codex Desktop/resources/app/bin/codex.cmd" % _path_resolver.get_program_files_root(),
		"%s/Codex Desktop/resources/app/bin/codex" % _path_resolver.get_program_files_root(),
		"%s/Codex/Codex.exe" % _path_resolver.get_program_files_root(),
		"%s/Codex/codex.exe" % _path_resolver.get_program_files_root(),
		"%s/Codex/resources/app/bin/codex.cmd" % _path_resolver.get_program_files_root(),
		"%s/Codex/resources/app/bin/codex" % _path_resolver.get_program_files_root(),
		"%s/OpenAI Codex/Codex.exe" % _path_resolver.get_program_files_root(),
		"%s/OpenAI Codex/codex.exe" % _path_resolver.get_program_files_root(),
		"%s/OpenAI/Codex Desktop/Codex Desktop.exe" % _path_resolver.get_program_files_root(),
		"%s/OpenAI/Codex Desktop/Codex.exe" % _path_resolver.get_program_files_root(),
		"%s/OpenAI/Codex/Codex.exe" % _path_resolver.get_program_files_root(),
		"%s/OpenAI/Codex/codex.exe" % _path_resolver.get_program_files_root(),
		"%s/OpenAI/Codex.exe" % _path_resolver.get_program_files_root(),
		"%s/Codex Desktop/Codex Desktop.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/Codex Desktop/Codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/Codex Desktop/resources/app/bin/codex.cmd" % _path_resolver.get_secondary_program_files_root(),
		"%s/Codex Desktop/resources/app/bin/codex" % _path_resolver.get_secondary_program_files_root(),
		"%s/Codex/Codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/Codex/codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/Codex/resources/app/bin/codex.cmd" % _path_resolver.get_secondary_program_files_root(),
		"%s/Codex/resources/app/bin/codex" % _path_resolver.get_secondary_program_files_root(),
		"%s/OpenAI Codex/Codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/OpenAI Codex/codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/OpenAI/Codex Desktop/Codex Desktop.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/OpenAI/Codex Desktop/Codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/OpenAI/Codex/Codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/OpenAI/Codex/codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/OpenAI/Codex.exe" % _path_resolver.get_secondary_program_files_root(),
		"%s/Programs/Codex Desktop/Codex Desktop.exe" % _path_resolver.get_local_app_data_root(),
		"%s/Programs/Codex Desktop/resources/app/bin/codex.cmd" % _path_resolver.get_local_app_data_root(),
		"%s/Programs/Codex/Codex.exe" % _path_resolver.get_local_app_data_root(),
		"%s/Programs/Codex/codex.exe" % _path_resolver.get_local_app_data_root(),
		"%s/Programs/Codex/resources/app/bin/codex.cmd" % _path_resolver.get_local_app_data_root(),
		"%s/Programs/OpenAI Codex/Codex.exe" % _path_resolver.get_local_app_data_root(),
		"%s/Programs/OpenAI Codex/codex.exe" % _path_resolver.get_local_app_data_root(),
		"%s/Programs/OpenAI/Codex Desktop/Codex Desktop.exe" % _path_resolver.get_local_app_data_root(),
		"%s/Programs/OpenAI/Codex/Codex.exe" % _path_resolver.get_local_app_data_root()
	])


func _copy_string_array(values: Array[String]) -> Array[String]:
	return _to_string_array(values)


func _to_string_array(value) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result
