@tool
extends RefCounted
class_name CentralServerProcessService

const CENTRAL_SERVER_DLL_NAME := "GodotDotnetMcp.CentralServer.dll"
const CENTRAL_SERVER_EXE_NAME := "GodotDotnetMcp.CentralServer.exe"
const DEFAULT_DOTNET_PATH := "C:/Program Files/dotnet/dotnet.exe"
const PROBE_INTERVAL_MS := 3000
const AUTO_START_RETRY_INTERVAL_MS := 15000
const LOCAL_INSTALL_RELATIVE_DIR := "GodotDotnetMcp/CentralServer/runtime"
const DOWNLOAD_CACHE_RELATIVE_DIR := "GodotDotnetMcp/CentralServer/downloads"
const LOG_RELATIVE_DIR := "GodotDotnetMcp/CentralServer/logs"
const INSTALL_METADATA_NAME := "central_server_install.json"
const SERVER_SHUTDOWN_PATH := "/api/server/shutdown"
const RELEASE_MANIFEST_PATH := "res://addons/godot_dotnet_mcp/central_server_release_manifest.json"
const BUNDLED_PACKAGE_DIR_PATH := "res://addons/godot_dotnet_mcp/central_server_packages"
const HTTP_REDIRECT_LIMIT := 5
const INSTALL_CLEAR_RETRY_COUNT := 60
const INSTALL_CLEAR_RETRY_DELAY_MS := 100
const CentralServerRuntimeFilesServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_runtime_files_service.gd")
const CentralServerProbeServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_probe_service.gd")
const CentralServerLaunchResolverScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_launch_resolver.gd")
const CentralServerInstallServiceScript = preload("res://addons/godot_dotnet_mcp/plugin/runtime/central_server_install_service.gd")

var _plugin: EditorPlugin
var _settings: Dictionary = {}
var _pid := 0
var _status := "idle"
var _last_error := ""
var _last_command := ""
var _launch_info: Dictionary = {}
var _endpoint_reachable := false
var _last_probe_msec := 0
var _last_auto_start_attempt_msec := 0
var _source_runtime_info: Dictionary = {}
var _runtime_files_service = CentralServerRuntimeFilesServiceScript.new()
var _probe_service = CentralServerProbeServiceScript.new()
var _launch_resolver = CentralServerLaunchResolverScript.new()
var _install_service = CentralServerInstallServiceScript.new()


func configure(plugin: EditorPlugin, settings: Dictionary) -> void:
	_plugin = plugin
	_settings = settings
	if _runtime_files_service == null:
		_runtime_files_service = CentralServerRuntimeFilesServiceScript.new()
	_runtime_files_service.configure({
		"local_install_relative_dir": LOCAL_INSTALL_RELATIVE_DIR,
		"download_cache_relative_dir": DOWNLOAD_CACHE_RELATIVE_DIR,
		"log_relative_dir": LOG_RELATIVE_DIR,
		"install_metadata_name": INSTALL_METADATA_NAME
	})
	if _probe_service == null:
		_probe_service = CentralServerProbeServiceScript.new()
	_probe_service.configure(_settings, SERVER_SHUTDOWN_PATH)
	if _launch_resolver == null:
		_launch_resolver = CentralServerLaunchResolverScript.new()
	_launch_resolver.configure(
		_settings,
		_runtime_files_service,
		{
			"central_server_dll_name": CENTRAL_SERVER_DLL_NAME,
			"central_server_exe_name": CENTRAL_SERVER_EXE_NAME,
			"default_dotnet_path": DEFAULT_DOTNET_PATH,
			"release_manifest_path": RELEASE_MANIFEST_PATH,
			"bundled_package_dir_path": BUNDLED_PACKAGE_DIR_PATH
		}
	)
	if _install_service == null:
		_install_service = CentralServerInstallServiceScript.new()
	_install_service.configure(
		_runtime_files_service,
		{
			"http_redirect_limit": HTTP_REDIRECT_LIMIT,
			"install_clear_retry_count": INSTALL_CLEAR_RETRY_COUNT,
			"install_clear_retry_delay_ms": INSTALL_CLEAR_RETRY_DELAY_MS
		}
	)
	refresh_detection()


func tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_probe_msec >= PROBE_INTERVAL_MS:
		_probe_endpoint()
		_last_probe_msec = now

	if _pid > 0:
		if OS.is_process_running(_pid):
			if _status != "running":
				_status = "running"
			return
		_pid = 0
		if _status == "running" or _status == "starting":
			_status = "exited"
			if _endpoint_reachable:
				_status = "running"


func refresh_detection() -> Dictionary:
	_source_runtime_info = _detect_install_source_info()
	_launch_info = _detect_launch_command()
	_probe_endpoint()
	return get_status()


func start_service() -> Dictionary:
	_last_auto_start_attempt_msec = Time.get_ticks_msec()
	_probe_endpoint()
	if _endpoint_reachable:
		_status = "running"
		_last_error = ""
		return get_status()

	if _pid > 0 and OS.is_process_running(_pid):
		_status = "running"
		return get_status()

	if _launch_info.is_empty():
		refresh_detection()
	if not bool(_launch_info.get("success", false)):
		_status = "launch_error"
		_last_error = str(_launch_info.get("message", "Central server launch command was not found."))
		return get_status()

	var executable_path := str(_launch_info.get("executable_path", "")).strip_edges()
	var arguments: PackedStringArray = _launch_info.get("arguments", PackedStringArray())
	var pid = OS.create_process(executable_path, arguments, false)
	if pid <= 0:
		_status = "launch_error"
		_last_error = "Failed to start central server process."
		return get_status()

	_pid = pid
	_status = "starting"
	_last_error = ""
	_last_command = str(_launch_info.get("display_command", ""))
	return get_status()


func stop_service() -> Dictionary:
	if _pid <= 0:
		_probe_endpoint()
		_status = "running" if _endpoint_reachable else "stopped"
		return get_status()

	var stop_result = _stop_owned_process()
	if not bool(stop_result.get("success", false)):
		return get_status()
	return get_status()


func get_status() -> Dictionary:
	if _launch_info.is_empty():
		refresh_detection()

	var install_dir = _get_local_install_dir()
	var install_manifest = _load_install_manifest(install_dir)
	var local_install_ready = _has_runtime_in_dir(install_dir)
	var source_launch = _source_runtime_info
	if source_launch.is_empty():
		source_launch = _detect_install_source_info()
		_source_runtime_info = source_launch
	var source_runtime_available = bool(source_launch.get("success", false))
	var launch_available = bool(_launch_info.get("success", false))
	var launch_source = str(_launch_info.get("source", ""))
	var client_launch = _build_client_stdio_launch_info()
	var detected_command = str(_launch_info.get("display_command", ""))
	var install_version = str(install_manifest.get("version", ""))
	var install_source_dir = str(install_manifest.get("source_runtime_dir", ""))
	var install_runtime_kind = str(install_manifest.get("runtime_kind", ""))
	var install_updated_at = int(install_manifest.get("installed_at_unix", 0))
	var message = _last_error
	if _endpoint_reachable and message.is_empty():
		message = "Central server endpoint is reachable."
	if message.is_empty():
		message = str(_launch_info.get("message", ""))

	return {
		"status": _status,
		"pid": _pid,
		"launch_available": launch_available,
		"launch_source": launch_source,
		"launch_executable_path": str(_launch_info.get("executable_path", "")),
		"launch_arguments": Array(_launch_info.get("arguments", PackedStringArray())),
		"client_launch_available": bool(client_launch.get("success", false)),
		"client_executable_path": str(client_launch.get("executable_path", "")),
		"client_arguments": Array(client_launch.get("arguments", PackedStringArray())),
		"client_command": str(client_launch.get("display_command", "")),
		"log_dir": _get_log_dir(),
		"log_file_path": _get_log_file_path(),
		"endpoint_reachable": _endpoint_reachable,
		"auto_launch_enabled": _is_auto_launch_enabled(),
		"local_endpoint": _build_endpoint(),
		"local_install_dir": install_dir,
		"local_install_ready": local_install_ready,
		"install_version": install_version,
		"install_source_dir": install_source_dir,
		"install_runtime_kind": install_runtime_kind,
		"install_updated_at_unix": install_updated_at,
		"source_runtime_available": source_runtime_available,
		"install_available": source_runtime_available,
		"install_action": "upgrade" if local_install_ready else "install",
		"source_runtime_dir": str(source_launch.get("runtime_dir", "")),
		"source_runtime_version": str(source_launch.get("version", "")),
		"source_runtime_kind": str(source_launch.get("runtime_kind", "")),
		"detected_command": detected_command,
		"last_command": _last_command,
		"last_error": _last_error,
		"message": message
	}


func ensure_service_running() -> Dictionary:
	if not _is_auto_launch_enabled() or not _is_local_target():
		return get_status()

	_probe_endpoint()
	if _endpoint_reachable:
		_status = "running"
		_last_error = ""
		return get_status()

	if _pid > 0 and OS.is_process_running(_pid):
		_status = "running"
		return get_status()

	var now := Time.get_ticks_msec()
	if now - _last_auto_start_attempt_msec < AUTO_START_RETRY_INTERVAL_MS:
		return get_status()

	return start_service()


func validate_client_transport(http_host: String = "127.0.0.1", http_port: int = 3000) -> Dictionary:
	var client_launch = _build_client_stdio_launch_info()
	if bool(client_launch.get("success", false)):
		return _validate_client_stdio_launch(client_launch)
	return _validate_http_transport(http_host, http_port)


func open_install_directory() -> Dictionary:
	return _runtime_files_service.open_install_directory()


func open_log_location() -> Dictionary:
	return _runtime_files_service.open_log_location()


func install_or_update_service() -> Dictionary:
	var source_launch = _source_runtime_info
	if source_launch.is_empty():
		source_launch = _detect_install_source_info()
		_source_runtime_info = source_launch
	if not bool(source_launch.get("success", false)):
		return {
			"success": false,
			"status": "install_error",
			"message": str(source_launch.get("message", "No central server runtime is available for installation."))
		}

	var restart_after_install := false
	if _endpoint_reachable and _pid <= 0 and str(_launch_info.get("source", "")) == "local_install":
		var remote_shutdown_result = _request_endpoint_shutdown()
		if not bool(remote_shutdown_result.get("success", false)):
			return {
				"success": false,
				"status": "install_error",
				"message": str(remote_shutdown_result.get("message", "Failed to stop the running local central server before upgrade."))
			}
		restart_after_install = true

	if _pid > 0 and OS.is_process_running(_pid):
		if str(_launch_info.get("source", "")) != "local_install":
			return {
				"success": false,
				"status": "install_error",
				"message": "Stop the running local central server before upgrading it."
			}
		var stop_result = _stop_owned_process()
		if not bool(stop_result.get("success", false)):
			return {
				"success": false,
				"status": "install_error",
				"message": str(stop_result.get("message", "Failed to stop the running local central server before upgrade."))
			}
		restart_after_install = true

	var bootstrap := _install_service.install_from_source_launch(source_launch)
	_source_runtime_info = _detect_install_source_info()
	_launch_info = _detect_launch_command()
	_probe_endpoint()

	var status = get_status()
	status["success"] = bool(bootstrap.get("success", false))
	status["status"] = "installed" if bool(bootstrap.get("success", false)) else "install_error"
	status["message"] = str(bootstrap.get("message", status.get("message", "")))
	status["restart_after_install"] = restart_after_install
	if restart_after_install and bool(bootstrap.get("success", false)):
		var restart_status = start_service()
		status["restart_status"] = restart_status
	return status


func _detect_launch_command() -> Dictionary:
	return _launch_resolver.detect_launch_command(_source_runtime_info)


func _probe_endpoint() -> bool:
	var probe_result = _probe_service.probe_endpoint(_pid, _status)
	_endpoint_reachable = bool(probe_result.get("reachable", false))
	_status = str(probe_result.get("status", _status))
	return _endpoint_reachable


func _is_local_target() -> bool:
	return _probe_service.is_local_target()


func _is_auto_launch_enabled() -> bool:
	return _probe_service.is_auto_launch_enabled()


func _build_endpoint() -> String:
	return _probe_service.build_endpoint()


func _build_client_stdio_launch_info() -> Dictionary:
	return _launch_resolver.build_client_stdio_launch_info(_launch_info)


func _has_runtime_in_dir(runtime_dir: String) -> bool:
	return _launch_resolver.has_runtime_in_dir(runtime_dir)


func _detect_install_source_info() -> Dictionary:
	return _launch_resolver.detect_install_source_info()


func _get_local_install_dir() -> String:
	return _runtime_files_service.get_local_install_dir()


func _get_log_dir() -> String:
	return _runtime_files_service.get_log_dir()


func _get_log_file_path() -> String:
	return _runtime_files_service.get_log_file_path()


func _request_endpoint_shutdown(wait_timeout_msec: int = 3000) -> Dictionary:
	return _probe_service.request_endpoint_shutdown(wait_timeout_msec)


func _validate_client_stdio_launch(client_launch: Dictionary) -> Dictionary:
	var executable_path = str(client_launch.get("executable_path", "")).strip_edges()
	if executable_path.is_empty():
		return {
			"success": false,
			"message": "No local central server stdio command is available for validation."
		}

	var validation_arguments := PackedStringArray()
	var raw_arguments = client_launch.get("arguments", PackedStringArray())
	if raw_arguments is PackedStringArray:
		validation_arguments = raw_arguments
	elif raw_arguments is Array:
		validation_arguments.append_array(raw_arguments)

	var filtered_arguments := PackedStringArray()
	for argument in validation_arguments:
		if str(argument) == "--stdio":
			continue
		filtered_arguments.append(str(argument))
	filtered_arguments.append("--health")

	var output: Array = []
	var exit_code := OS.execute(executable_path, filtered_arguments, output, true, false)
	if exit_code != 0:
		return {
			"success": false,
			"message": "Local central server health validation failed."
		}

	var payload_text = str(output[0]).strip_edges() if not output.is_empty() else ""
	var parsed = JSON.parse_string(payload_text)
	if parsed is Dictionary and str((parsed as Dictionary).get("status", "")).strip_edges() == "ok":
		return {
			"success": true,
			"mode": "stdio",
			"message": "Local central server stdio command validated successfully.",
			"payload": parsed,
			"command": str(client_launch.get("display_command", ""))
		}

	return {
		"success": false,
		"message": "Local central server health validation returned an unexpected response.",
		"payload_text": payload_text
	}


func _validate_http_transport(http_host: String, http_port: int) -> Dictionary:
	return _probe_service.validate_http_transport(http_host, http_port)


func _stop_owned_process(wait_timeout_msec: int = 3000) -> Dictionary:
	if _pid <= 0:
		_status = "stopped"
		_last_error = ""
		_endpoint_reachable = false
		return {
			"success": true,
			"message": "Local central server is already stopped."
		}

	var stopping_pid := _pid
	var error := OS.kill(stopping_pid)
	if error != OK:
		_status = "launch_error"
		_last_error = "Failed to stop central server process: %s" % error
		return {
			"success": false,
			"message": _last_error
		}

	var deadline := Time.get_ticks_msec() + wait_timeout_msec
	while OS.is_process_running(stopping_pid) and Time.get_ticks_msec() < deadline:
		OS.delay_msec(25)

	if OS.is_process_running(stopping_pid):
		_status = "launch_error"
		_last_error = "Timed out while stopping the local central server process."
		return {
			"success": false,
			"message": _last_error
		}

	_pid = 0
	_status = "stopped"
	_last_error = ""
	_endpoint_reachable = false
	_last_probe_msec = 0
	return {
		"success": true,
		"message": "Local central server stopped."
	}


func _load_install_manifest(install_dir: String) -> Dictionary:
	return _runtime_files_service.load_install_manifest(install_dir)
