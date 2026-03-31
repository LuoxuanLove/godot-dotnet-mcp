@tool
extends RefCounted
class_name ClientInstallDetectionService

const ClientInstallPathResolver = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_path_resolver.gd")
const ClientInstallRuntimeInspector = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_runtime_inspector.gd")
const ClientInstallConfigEntryInspector = preload("res://addons/godot_dotnet_mcp/plugin/config/client_install_config_entry_inspector.gd")
const ClientDetectorRegistry = preload("res://addons/godot_dotnet_mcp/plugin/config/client_detector_registry.gd")

const STATUS_ERROR := "error"
const CACHE_TTL_MS := 5000

var _cached_all: Dictionary = {}
var _cache_deadline_msec := 0
var _path_resolver = ClientInstallPathResolver.new()
var _runtime_inspector = ClientInstallRuntimeInspector.new()
var _config_entry_inspector = ClientInstallConfigEntryInspector.new()
var _detector_registry = ClientDetectorRegistry.new()


func configure(settings: Dictionary) -> void:
	if _path_resolver != null and _path_resolver.configure(settings):
		invalidate_cache()
	if _detector_registry != null:
		_detector_registry.configure(_path_resolver, _runtime_inspector, _config_entry_inspector)


func detect_all(force_refresh: bool = false) -> Dictionary:
	var now = Time.get_ticks_msec()
	if not force_refresh and not _cached_all.is_empty() and now < _cache_deadline_msec:
		return _cached_all.duplicate(true)

	if _detector_registry == null:
		_detector_registry = ClientDetectorRegistry.new()
		_detector_registry.configure(_path_resolver, _runtime_inspector, _config_entry_inspector)

	var running_processes = _runtime_inspector.collect_running_process_names() if _runtime_inspector != null else PackedStringArray()
	_cached_all = _detector_registry.detect_all(running_processes)
	_cache_deadline_msec = now + CACHE_TTL_MS
	return _cached_all.duplicate(true)


func detect_client(client_id: String) -> Dictionary:
	return detect_all().get(client_id, {
		"id": client_id,
		"status": STATUS_ERROR,
		"message": "Unsupported client."
	})


func invalidate_cache() -> void:
	_cached_all.clear()
	_cache_deadline_msec = 0


func dispose() -> void:
	invalidate_cache()
	if _detector_registry != null:
		_detector_registry.dispose()
	_detector_registry = null
	_path_resolver = null
	_runtime_inspector = null
	_config_entry_inspector = null
